-- Gunworks reload rules: which strokes and loads a reload is made of, decided by the gun's state.
--
-- A reload is a chain of steps. Each step is one vanilla timed action, so it has its own AnimSet node and
-- its own server timing:
--
--   open          ISRackFirearm, opening stroke (GunworksRackPhase = "open")
--   close         ISRackFirearm, closing stroke (GunworksRackPhase = "close")
--   rack          ISRackFirearm, full rack
--   ejectMag      ISEjectMagazine
--   insertMag     ISInsertMagazine with a magazine
--   insertClip    ISInsertMagazine with a stripper clip or speedloader (SpeedLoader registry)
--   loadRounds    ISReloadWeaponAction, rounds one by one
--   loadChamber   ISReloadWeaponAction that puts one round straight into the open chamber
--   unloadRounds  ISUnloadBulletsFromFirearm
--
-- A rule says which steps must come before, after or instead of a step, given the gun's state:
--
--   ReloadRules.Register("openWhenChamberEmpty", {
--       before = {
--           ejectMag = function(ctx)
--               if not ctx.chambered and not ctx.boltOpen then return { "open" } end
--           end,
--       },
--   })
--
-- A gun lists its rules in its reload profile: `rules = { "openToLoad", "stripperClips" }`, or a preset
-- name such as `rules = "boltAction"`. Rules run where the action queue lives (client or singleplayer),
-- when each step's action begins, against the gun as it is at that moment. A reload started from the
-- reload key, the radial menu or the inventory menu follows the same rules, and an interrupted reload
-- picks up where it stopped. Each action is checked once. For each moment the first rule in the gun's
-- list that answers wins; an empty list under `instead` drops the step.

---@class GunworksReloadAnim
local ReloadAnim = require("WeaponSystems/Utils/ReloadAnim")
require("WeaponSystems/ReloadAnim/RackPhases")
local SpeedLoader = require("WeaponSystems/Utils/SpeedLoader")
local Magazine = require("WeaponSystems/Utils/Magazine")

---@class GunworksReloadRuleContext
---@field step string                     the step being decided
---@field action ISBaseTimedAction|nil    its action (nil when a reload is being planned)
---@field character IsoGameCharacter
---@field gun HandWeapon
---@field handler GunworksReloadAnimHandler|nil
---@field hasChamber boolean
---@field chambered boolean
---@field boltOpen boolean
---@field jammed boolean
---@field rounds number                   rounds in the magazine or tube, not counting the chamber
---@field maxAmmo number
---@field freeSpace number                maxAmmo - rounds
---@field magazineFed boolean             the gun takes detachable magazines
---@field hasMagazine boolean             a magazine is in the gun
---@field aiming boolean
---@field bestClip InventoryItem|nil      the loaded stripper clip / speedloader the gun would take
---@field clipRounds number               rounds on bestClip (0 without one)
---@field rackQueued boolean              `after` only: a rack already follows this step

---@alias GunworksReloadRuleAnswer string|string[]|nil
---@alias GunworksReloadRuleHook fun(ctx:GunworksReloadRuleContext):GunworksReloadRuleAnswer

---@class GunworksReloadRule
---@field before table<string,GunworksReloadRuleHook|string|string[]>|nil
---@field after table<string,GunworksReloadRuleHook|string|string[]>|nil
---@field instead table<string,GunworksReloadRuleHook|string|string[]>|nil

---@class GunworksReloadStep
---@field create fun(ctx:GunworksReloadRuleContext):(table|table[]|nil)  the timed action(s) for this step, or nil to skip it
---@field dropsRackAfter boolean|nil  vanilla queues a rack after this step's action, and the step does not want it

---@class GunworksReloadRules
local ReloadRules = {}
ReloadAnim.Rules = ReloadRules

--- Anim variable set to the step name on every action of a gun with a reload profile, so AnimSet nodes
--- can tell the steps apart (for example a stripper clip from a single round, both ISInsertMagazine / load).
ReloadRules.STEP_VARIABLE = "GunworksReloadStep"
ReloadRules.STEP_LOAD_CHAMBER = "loadChamber"

--- Steps a rule may add in a row (a rule answering with a step that triggers the same rule again stops here).
ReloadRules.MAX_DEPTH = 6

---@type table<string,GunworksReloadRule>
ReloadRules.rules = {}
---@type table<string,(string|GunworksReloadRule)[]>
ReloadRules.presets = {}
---@type table<string,GunworksReloadStep>
ReloadRules.steps = {}

-- Gun ID -> true while an opening stroke this client played has not been closed. The bolt flag in mod data
-- comes from the strokes' rackStart / rackEnd events on this client, and in multiplayer a server sync sent
-- before the server recorded the stroke (RackPhases.recordStrokeOnServer) can replace it, so the rules keep
-- their own note of the strokes they ran.
ReloadRules.openedBolts = {}

-- Gun ID -> true when vanilla's perform is about to queue a rack that the step just finished does not want.
ReloadRules.unwantedRacks = {}

local warned = {}

---@param message string
local function warnOnce(message)
    if warned[message] then
        return
    end
    warned[message] = true
    print("[Gunworks/ReloadRules] " .. message)
end

-------------------------------------------------
-- Registration
-------------------------------------------------

--- Register (or replace) a named rule.
---@param name string
---@param rule GunworksReloadRule
---@return nil
function ReloadRules.Register(name, rule)
    if type(name) ~= "string" or name == "" or type(rule) ~= "table" then
        warnOnce("Register needs a name and a rule table")
        return
    end
    ReloadRules.rules[name] = rule
end

--- Register (or replace) a preset: a named list of rules. Entries are rule names, rule tables or other presets.
---@param name string
---@param entries (string|GunworksReloadRule)[]
---@return nil
function ReloadRules.RegisterPreset(name, entries)
    if type(name) ~= "string" or name == "" or type(entries) ~= "table" then
        warnOnce("RegisterPreset needs a name and a list of rules")
        return
    end
    ReloadRules.presets[name] = entries
end

--- Register (or replace) a step. create(ctx) returns the step's timed action, a list of actions (for example
--- an inventory transfer, then the action), or nil to skip the step.
---@param name string
---@param step GunworksReloadStep
---@return nil
function ReloadRules.RegisterStep(name, step)
    if type(name) ~= "string" or name == "" or type(step) ~= "table" or type(step.create) ~= "function" then
        warnOnce("RegisterStep needs a name and a table with a create(ctx) function")
        return
    end
    ReloadRules.steps[name] = step
end

-------------------------------------------------
-- Profiles
-------------------------------------------------

---@param value any
---@return boolean
local function isRuleTable(value)
    return type(value) == "table" and (value.before ~= nil or value.after ~= nil or value.instead ~= nil)
end

--- The rule list a reload profile asks for: its `rules` (a rule or preset name, a rule table, or a list of
--- them), then the older flags. `splitRack` stands for "openWhenChamberEmpty" + "rackInTwoStrokes";
--- `openToLoad` stands for "openToLoad" + "rackInTwoStrokes".
---@param options table
---@nodiscard
---@return (string|GunworksReloadRule)[]|nil
function ReloadRules.profileRules(options)
    local list = {}
    local seen = {}

    local function add(entry)
        if type(entry) == "string" and entry ~= "" then
            if seen[entry] then
                return
            end
            seen[entry] = true
        elseif not isRuleTable(entry) then
            warnOnce("a reload profile's rules may hold rule names, preset names and rule tables, not " .. tostring(entry))
            return
        end
        list[#list + 1] = entry
    end

    local rules = options.rules
    if type(rules) == "string" or isRuleTable(rules) then
        add(rules)
    elseif type(rules) == "table" then
        for i = 1, #rules do
            add(rules[i])
        end
    end

    if options.openToLoad then
        add("openToLoad")
        add("rackInTwoStrokes")
    elseif options.splitRack then
        add("openWhenChamberEmpty")
        add("rackInTwoStrokes")
    end

    if #list == 0 then
        return nil
    end
    return list
end

---@param entries (string|GunworksReloadRule)[]
---@param out GunworksReloadRule[]
---@param seen table<string,boolean>
---@param depth number
---@return GunworksReloadRule[]
local function collectRules(entries, out, seen, depth)
    for i = 1, #entries do
        local entry = entries[i]
        if type(entry) == "table" then
            out[#out + 1] = entry
        elseif type(entry) == "string" then
            local rule = ReloadRules.rules[entry]
            local preset = ReloadRules.presets[entry]
            if rule then
                out[#out + 1] = rule
            elseif preset then
                if not seen[entry] and depth < ReloadRules.MAX_DEPTH then
                    seen[entry] = true
                    collectRules(preset, out, seen, depth + 1)
                end
            else
                warnOnce("no rule or preset named '" .. entry .. "'")
            end
        end
    end
    return out
end

---@param handler GunworksReloadAnimHandler|nil
---@nodiscard
---@return boolean
function ReloadRules.hasRules(handler)
    return handler ~= nil and type(handler.rules) == "table" and #handler.rules > 0
end

--- Does this gun reload by rules? Then its opening and closing strokes own the action visual, and a load or an
--- unload leaves the action as it is (AnimationsHooks).
---@param gun HandWeapon
---@nodiscard
---@return boolean
function ReloadRules.gunHasRules(gun)
    return ReloadRules.hasRules(ReloadAnim.GetHandlerForGun(gun))
end

--- The handler's rules in order, presets expanded. Names resolve when asked, so a profile may name a rule
--- that another file registers later.
---@param handler GunworksReloadAnimHandler|nil
---@nodiscard
---@return GunworksReloadRule[]|nil
function ReloadRules.getRules(handler)
    if not ReloadRules.hasRules(handler) then
        return nil
    end
    return collectRules(handler.rules, {}, {}, 0)
end

--- Ask the handler's rules about one moment ("before", "after" or "instead") of a step. The first rule
--- that answers wins. A rule that throws counts as no answer.
---@param handler GunworksReloadAnimHandler|nil
---@param moment string
---@param step string
---@param ctx GunworksReloadRuleContext
---@nodiscard
---@return string[]|nil
function ReloadRules.evaluate(handler, moment, step, ctx)
    local rules = ReloadRules.getRules(handler)
    if not rules then
        return nil
    end

    for i = 1, #rules do
        local hooks = rules[i][moment]
        local hook = type(hooks) == "table" and hooks[step] or nil
        local answer = nil
        if type(hook) == "function" then
            local ok, result = pcall(hook, ctx)
            if ok then
                answer = result
            else
                warnOnce("a rule for '" .. moment .. " " .. step .. "' failed: " .. tostring(result))
            end
        elseif type(hook) == "table" or type(hook) == "string" then
            answer = hook
        end

        if type(answer) == "string" then
            return { answer }
        end
        if type(answer) == "table" then
            return answer
        end
    end
    return nil
end

-------------------------------------------------
-- State
-------------------------------------------------

---@param a HandWeapon|nil
---@param b HandWeapon|nil
---@return boolean
local function sameGun(a, b)
    if a == nil or b == nil then
        return false
    end
    return a == b or a:getID() == b:getID()
end

--- Is the gun's action open? True while the bolt flag says so or a stroke this client played opened it.
---@param gun HandWeapon|nil
---@nodiscard
---@return boolean
function ReloadRules.isBoltOpen(gun)
    if not gun then
        return false
    end
    return ReloadAnim.isBoltOpen(gun) or ReloadRules.openedBolts[gun:getID()] == true
end

---@param gun HandWeapon
---@param step string
---@return nil
function ReloadRules.recordStroke(gun, step)
    if step == "open" then
        ReloadRules.openedBolts[gun:getID()] = true
    elseif step == "close" or step == "rack" then
        ReloadRules.openedBolts[gun:getID()] = nil
    end
end

--- The step an action stands for.
---@param action table|nil
---@nodiscard
---@return string|nil
function ReloadRules.stepOf(action)
    if not action then
        return nil
    end
    if action.gunworksReloadStep then
        return action.gunworksReloadStep
    end

    local actionType = action.Type
    if actionType == "ISRackFirearm" then
        if action.gunworksRackPhase == ReloadAnim.RACK_PHASE_OPEN then
            return "open"
        end
        if action.gunworksRackPhase == ReloadAnim.RACK_PHASE_CLOSE then
            return "close"
        end
        return "rack"
    elseif actionType == "ISEjectMagazine" then
        return "ejectMag"
    elseif actionType == "ISInsertMagazine" then
        if action.magazine and action.gun
            and SpeedLoader.IsCompatibleTypeForGun(action.magazine:getFullType(), action.gun) then
            return "insertClip"
        end
        return "insertMag"
    elseif actionType == "ISReloadWeaponAction" then
        return "loadRounds"
    elseif actionType == "ISUnloadBulletsFromFirearm" then
        return "unloadRounds"
    end
    return nil
end

--- What the rules see of the gun.
---@param character IsoGameCharacter|nil
---@param gun HandWeapon
---@param step string
---@param action table|nil
---@nodiscard
---@return GunworksReloadRuleContext
function ReloadRules.buildContext(character, gun, step, action)
    local hasChamber = gun:haveChamber()
    local rounds = gun:getCurrentAmmoCount()
    local maxAmmo = gun:getMaxAmmo()
    local ctx = {
        step = step,
        action = action,
        character = character,
        gun = gun,
        handler = ReloadAnim.GetHandlerForGun(gun),
        hasChamber = hasChamber,
        chambered = hasChamber and gun:isRoundChambered(),
        boltOpen = ReloadRules.isBoltOpen(gun),
        jammed = gun:isJammed(),
        rounds = rounds,
        maxAmmo = maxAmmo,
        freeSpace = math.max(0, maxAmmo - rounds),
        magazineFed = gun:getMagazineType() ~= nil,
        hasMagazine = gun:isContainsClip(),
        aiming = character ~= nil and character:isAiming(),
        clipRounds = 0,
        rackQueued = false,
    }
    if character and SpeedLoader.IsRegisteredGun(gun) then
        ctx.bestClip = SpeedLoader.GetBestSpeedLoaderForGun(character, gun)
        if ctx.bestClip then
            ctx.clipRounds = ctx.bestClip:getCurrentAmmoCount()
        end
    end
    return ctx
end

--- Will vanilla's perform of this action queue a rack? Clients only: singleplayer queues it earlier, from
--- loadAmmo, so it is already in the queue. Same checks as vanilla's perform, on the same state.
---@param action table
---@nodiscard
---@return boolean
function ReloadRules.vanillaQueuesRack(action)
    if not isClient() then
        return false
    end
    local gun = action.gun
    if action.Type == "ISReloadWeaponAction" then
        return gun:haveChamber() and not gun:isRoundChambered()
    end
    if action.Type == "ISInsertMagazine" then
        return not gun:isRoundChambered() and gun:getCurrentAmmoCount() >= gun:getAmmoPerShoot()
    end
    return false
end

-------------------------------------------------
-- Turning step names into actions
-------------------------------------------------

--- Build the actions for a list of step names. Unknown steps and steps whose create returns nil are skipped.
---@param names string[]
---@param ctx GunworksReloadRuleContext
---@param parent table|nil  the action the steps were added for
---@nodiscard
---@return table[]
function ReloadRules.createSteps(names, ctx, parent)
    local actions = {}
    local depth = ((parent and parent.gunworksRuleDepth) or 0) + 1
    for i = 1, #names do
        local name = names[i]
        local step = ReloadRules.steps[name]
        if not step then
            warnOnce("no step named '" .. tostring(name) .. "'")
        else
            local ok, made = pcall(step.create, ctx)
            if not ok then
                warnOnce("step '" .. name .. "' failed: " .. tostring(made))
            elseif made then
                if made.Type then
                    made = { made }
                end
                for j = 1, #made do
                    made[j].gunworksRuleDepth = depth
                    actions[#actions + 1] = made[j]
                end
            end
        end
    end
    return actions
end

---@param character IsoGameCharacter|nil
---@return table|nil
local function getQueue(character)
    if not character or not ISTimedActionQueue or not ISTimedActionQueue.getTimedActionQueue then
        return nil
    end
    return ISTimedActionQueue.getTimedActionQueue(character)
end

-- Queue `action` right behind `anchor` through ISTimedActionQueue.addAfter, the way vanilla queues its own
-- follow-up racks, so a mod that filters follow-ups still applies: Hot Brass manual racking refuses every
-- ISRackFirearm queued this way, leaving the player to rack by hand. True when the action went in (checked in
-- the queue, as not every addAfter wrapper passes vanilla's return value on).
---@param queue table
---@param anchor table
---@param action table
---@return boolean
local function queueAfter(queue, anchor, action)
    ISTimedActionQueue.addAfter(anchor, action)
    return queue:indexOf(action) ~= -1
end

-- Begin `actions` at the head of the queue, in front of `action` (keepAction, the `before` steps: what the
-- action needs first, always queued) or in its place (`instead`). In place, the first step takes the action's
-- spot and the rest follow it as follow-ups (queueAfter), so with Hot Brass manual racking a rack that becomes
-- open + close only opens, and the next rack closes.
---@param queue table
---@param actions table[]
---@param keepAction boolean
local function replaceHead(queue, actions, keepAction)
    if keepAction then
        for i = #actions, 1, -1 do
            table.insert(queue.queue, 1, actions[i])
        end
    else
        table.remove(queue.queue, 1)
        if actions[1] then
            table.insert(queue.queue, 1, actions[1])
            local anchor = actions[1]
            for i = 2, #actions do
                if queueAfter(queue, anchor, actions[i]) then
                    anchor = actions[i]
                end
            end
        end
    end
    local head = queue.queue[1]
    queue.current = head
    if head then
        head:begin()
    end
end

-------------------------------------------------
-- Dispatch (called by Hooks/ReloadAnimHooks.lua)
-------------------------------------------------

--- An action of a gun with rules is about to begin: apply `instead`, then `before`. The queue calls begin
--- for every action however it was queued, before the action exists in the engine or on the server, so
--- steps can still go in front of it or replace it here.
---@param action table
---@return boolean true when other actions began in its place
function ReloadRules.beginAction(action)
    if action.gunworksRulesChecked then
        return false
    end
    action.gunworksRulesChecked = true

    local handler = ReloadAnim.getHandlerForAction(action)
    if not ReloadRules.hasRules(handler) then
        return false
    end
    local queue = getQueue(action.character)
    if not queue or queue.queue[1] ~= action then
        return false
    end
    local step = ReloadRules.stepOf(action)
    if not step then
        return false
    end
    local gun = action.gun

    local gunId = gun:getID()
    local unwanted = ReloadRules.unwantedRacks[gunId]
    ReloadRules.unwantedRacks[gunId] = nil
    if unwanted and step == "rack" then
        replaceHead(queue, {}, false)
        return true
    end

    if (action.gunworksRuleDepth or 0) >= ReloadRules.MAX_DEPTH then
        warnOnce("the rules of " .. tostring(gun:getFullType()) .. " keep adding steps; stopped after "
            .. ReloadRules.MAX_DEPTH)
        return false
    end

    local ctx = ReloadRules.buildContext(action.character, gun, step, action)
    local instead = ReloadRules.evaluate(handler, "instead", step, ctx)
    if instead then
        replaceHead(queue, ReloadRules.createSteps(instead, ctx, action), false)
        return true
    end

    local before = ReloadRules.evaluate(handler, "before", step, ctx)
    if before and #before > 0 then
        local actions = ReloadRules.createSteps(before, ctx, action)
        if #actions > 0 then
            replaceHead(queue, actions, true)
            return true
        end
    end
    return false
end

--- An action of a gun with rules has finished (perform): note the stroke, then apply `after`. Runs before
--- vanilla's perform, which hands the queue to the next action. The steps go behind the rack vanilla
--- queues after a load, where a client's vanilla perform puts that rack too, and are queued as follow-ups
--- (queueAfter), so Hot Brass manual racking drops an automatic closing stroke like it drops vanilla's rack.
---@param action table
---@return nil
function ReloadRules.afterAction(action)
    local handler = ReloadAnim.getHandlerForAction(action)
    if not ReloadRules.hasRules(handler) then
        return
    end
    local step = ReloadRules.stepOf(action)
    if not step then
        return
    end
    local gun = action.gun
    ReloadRules.recordStroke(gun, step)

    local vanillaRack = ReloadRules.vanillaQueuesRack(action)
    local stepDef = ReloadRules.steps[step]
    if vanillaRack and stepDef and stepDef.dropsRackAfter then
        ReloadRules.unwantedRacks[gun:getID()] = true
        vanillaRack = false
    end

    local queue = getQueue(action.character)
    local index = queue and queue:indexOf(action) or -1
    if index == -1 then
        return
    end
    local behind = queue.queue[index + 1]
    local rackBehind = behind ~= nil and behind.Type == "ISRackFirearm" and sameGun(behind.gun, gun)

    local ctx = ReloadRules.buildContext(action.character, gun, step, action)
    ctx.rackQueued = rackBehind or vanillaRack
    local after = ReloadRules.evaluate(handler, "after", step, ctx)
    if not after or #after == 0 then
        return
    end

    local actions = ReloadRules.createSteps(after, ctx, action)
    local anchor = rackBehind and behind or action
    for i = 1, #actions do
        if queueAfter(queue, anchor, actions[i]) then
            anchor = actions[i]
        end
    end
end

--- The reload key on a gun without magazines: ask the rules about `loadRounds` before vanilla moves any
--- rounds. An empty answer means there is nothing to load; another answer is queued as it stands (a
--- stripper clip loads even with no loose rounds to move).
---@param playerObj IsoPlayer
---@param gun HandWeapon
---@return boolean true when the rules handled the reload
function ReloadRules.planReload(playerObj, gun)
    if not instanceof(gun, "HandWeapon") or gun:getMagazineType() or gun:isJammed() then
        return false
    end
    local handler = ReloadAnim.GetHandlerForGun(gun)
    if not ReloadRules.hasRules(handler) then
        return false
    end
    local ctx = ReloadRules.buildContext(playerObj, gun, "loadRounds", nil)
    local instead = ReloadRules.evaluate(handler, "instead", "loadRounds", ctx)
    if not instead then
        return false
    end
    local actions = ReloadRules.createSteps(instead, ctx, nil)
    for i = 1, #actions do
        ISTimedActionQueue.add(actions[i])
    end
    return true
end

return ReloadRules
