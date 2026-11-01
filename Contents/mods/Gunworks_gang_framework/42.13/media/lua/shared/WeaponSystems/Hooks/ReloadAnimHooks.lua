-- Gunworks reload-animation framework: composed timed-action hooks.
--
-- This file MUST load after the other Gunworks hook files so its captured originals
-- already include their wrappers. Within media/lua/shared/WeaponSystems/Hooks/ the
-- engine auto-loads alphabetically: AnimationsHooks -> CustomSystemHooks ->
-- ReloadAnimHooks -> WeaponUpgradeHooks. So every "prev" captured below is the
-- Gunworks+vanilla chain, and this layer wraps it OUTERMOST: run the reload-anim
-- handler dispatch, then defer to prev. Guns without a registered reload-anim profile
-- fall straight through to prev, so vanilla and every other Gunworks weapon are
-- unaffected.

require("TimedActions/ISEjectMagazine")
require("TimedActions/ISInsertMagazine")
require("TimedActions/ISRackFirearm")
require("TimedActions/ISReloadWeaponAction")
require("TimedActions/ISUnloadBulletsFromFirearm")

---@class GunworksReloadAnim
local ReloadAnim = require("WeaponSystems/Utils/ReloadAnim")
require("WeaponSystems/ReloadAnim/HandlerFactory")
require("WeaponSystems/ReloadAnim/Timing")
require("WeaponSystems/ReloadAnim/Visuals")
require("WeaponSystems/ReloadAnim/Sync")
require("WeaponSystems/ReloadAnim/PartState")
require("WeaponSystems/ReloadAnim/PartSwap")
require("WeaponSystems/ReloadAnim/RackPhases")
local ReloadRules = require("WeaponSystems/ReloadAnim/Rules")
local SpeedLoader = require("WeaponSystems/Utils/SpeedLoader")

-- Re-wrap on every load. A Core.ResetLua (e.g. a client joining a modded MP server)
-- resets the vanilla timed-action classes to unwrapped, so these hooks MUST re-apply
-- each time this file runs. We deliberately do NOT guard on a flag: the require cache
-- can return the same ReloadAnim table across a ResetLua while the vanilla classes are
-- fresh, so a flag would wrongly skip re-wrapping and silently disable the reload anims.
-- Capturing the current (already Gunworks+vanilla-wrapped) method as "prev" each load is
-- safe because PZ runs this file once per VM via the module loader.

-- NetTimedAction serializes fields named by the final constructor's parameters. Keep
-- existing parameters (including Gunworks' ammo overrides) and append the captured aim
-- flag. Capture at start, not construction: actions can spend time waiting in a queue.
local prevEjectNew = ISEjectMagazine.new
function ISEjectMagazine:new(character, gun, gunworksReloadAiming)
    local action = prevEjectNew(self, character, gun)
    action.gunworksReloadAiming = gunworksReloadAiming
    return action
end

local prevInsertNew = ISInsertMagazine.new
function ISInsertMagazine:new(character, gun, magazine, gunworksReloadAiming)
    local action = prevInsertNew(self, character, gun, magazine)
    action.gunworksReloadAiming = gunworksReloadAiming
    return action
end

-- gunworksReloadStep marks a load that is a rule step of its own (loadChamber), for the server too.
local prevReloadNew = ISReloadWeaponAction.new
function ISReloadWeaponAction:new(character, gun, ammoLimit, ammoTypeOverride, gunworksReloadAiming, gunworksReloadStep)
    local action = prevReloadNew(self, character, gun, ammoLimit, ammoTypeOverride)
    action.gunworksReloadAiming = gunworksReloadAiming
    action.gunworksReloadStep = gunworksReloadStep
    return action
end

local prevUnloadNew = ISUnloadBulletsFromFirearm.new
function ISUnloadBulletsFromFirearm:new(character, gun, gunworksReloadAiming)
    local action = prevUnloadNew(self, character, gun)
    action.gunworksReloadAiming = gunworksReloadAiming
    return action
end

-- Vanilla sets its reload type immediately before setActionAnim snapshots the action.
-- Set our selectors and the fixed aim flag before that snapshot, for owners and observers.
-- setAnimVariable also lets the engine clear the flag when the action stops or completes.
local function wrapReloadActionAnim(actionClass, nonMagazine, customUnload)
    local previous = actionClass.setActionAnim
    function actionClass:setActionAnim(actionAnim, displayItemModels)
        local handler = ReloadAnim.getHandlerForAction(self)
        if handler and handler.animId
            and (not nonMagazine or ReloadAnim.isNonMagArchetype(handler.archetype))
            and (not customUnload or handler.customUnload) then
            self:setAnimVariable(ReloadAnim.AIM_VARIABLE, ReloadAnim.captureReloadAiming(self))
            self:setAnimVariable(ReloadAnim.ANIM_VARIABLE, handler.animId)
            self:setAnimVariable("WeaponReloadType", handler.animId)
            self:setAnimVariable(ReloadRules.STEP_VARIABLE, ReloadRules.stepOf(self))
        end
        return previous(self, actionAnim, displayItemModels)
    end
end

-- Reload rules (ReloadAnim/Rules.lua): `instead` and `before` steps go in when an action begins, `after`
-- steps when it performs. The queue calls begin however the action was queued; guns without rules fall
-- straight through.
local function applyRulesOnBegin(actionClass)
    local previous = actionClass.begin
    function actionClass:begin()
        if ReloadRules.beginAction(self) then
            return
        end
        return previous(self)
    end
end

applyRulesOnBegin(ISEjectMagazine)
applyRulesOnBegin(ISInsertMagazine)
applyRulesOnBegin(ISRackFirearm)
applyRulesOnBegin(ISReloadWeaponAction)
applyRulesOnBegin(ISUnloadBulletsFromFirearm)

wrapReloadActionAnim(ISEjectMagazine, false, false)
wrapReloadActionAnim(ISInsertMagazine, false, false)
wrapReloadActionAnim(ISReloadWeaponAction, true, false)
wrapReloadActionAnim(ISUnloadBulletsFromFirearm, true, true)

-------------------------------------------------
-- ISEjectMagazine
-------------------------------------------------
local prevEjectStart = ISEjectMagazine.start
---@param self ISEjectMagazine
function ISEjectMagazine:start()
    local handler = ReloadAnim.getHandlerForAction(self)
    prevEjectStart(self)
    -- Vanilla start() just set WeaponReloadType to the gun's engine reload type. A registered
    -- gun's custom node is gated on GunworksReloadAnim (or, for a "none"-style profile authored
    -- the old way, on WeaponReloadType directly), so overwrite WeaponReloadType with animId here
    -- too so no vanilla/unrelated node can win the tie - same fix as the ISReloadWeaponAction
    -- override below, extended to the magazine chain (Eject/Insert/Rack all had this gap).
    if handler and handler.animId then
        self:setAnimVariable("WeaponReloadType", handler.animId)
    end
    if handler and handler.onEjectStart then
        if handler.onEjectStart(self) then
            return
        end
    end
end

-- Gunworks does not wrap Eject.serverStart, so prev is vanilla. For a registered gun
-- we replace it with a custom-duration finish event; unregistered guns keep vanilla.
local prevEjectServerStart = ISEjectMagazine.serverStart
---@param self ISEjectMagazine
function ISEjectMagazine:serverStart()
    local handler = ReloadAnim.getHandlerForAction(self)
    if not handler then
        return prevEjectServerStart(self)
    end

    self:initVars()
    local durationMs = ReloadAnim.getActionDurationMs(self, ReloadAnim.getProfileDuration(self, handler, "unload"), 1200)
    emulateAnimEventOnce(self.netAction, durationMs, "unloadFinished", nil)
end

local prevEjectAnimEvent = ISEjectMagazine.animEvent
---@param self ISEjectMagazine
---@param event string
---@param parameter string
function ISEjectMagazine:animEvent(event, parameter)
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onEjectAnimEvent then
        if handler.onEjectAnimEvent(self, event, parameter) then
            return
        end
    end

    prevEjectAnimEvent(self, event, parameter)
end

local prevEjectStop = ISEjectMagazine.stop
---@param self ISEjectMagazine
function ISEjectMagazine:stop()
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onEjectStop then
        if handler.onEjectStop(self) then
            return
        end
    end

    prevEjectStop(self)
    if handler then
        ReloadAnim.resetWeaponModel(self, handler)
    end
end

local prevEjectPerform = ISEjectMagazine.perform
---@param self ISEjectMagazine
function ISEjectMagazine:perform()
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onEjectPerform then
        if handler.onEjectPerform(self) then
            return
        end
    end

    ReloadRules.afterAction(self)
    prevEjectPerform(self)
    if handler then
        ReloadAnim.resetWeaponModel(self, handler)
    end
end

-------------------------------------------------
-- ISInsertMagazine
-------------------------------------------------
local prevInsertStart = ISInsertMagazine.start
---@param self ISInsertMagazine
function ISInsertMagazine:start()
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onInsertStart then
        handler.onInsertStart(self)
    end

    prevInsertStart(self)

    -- Must run AFTER prevInsertStart: vanilla's own start() (inside prev) re-sets
    -- WeaponReloadType from the gun's engine reload type, so an override placed before prev
    -- would just get clobbered. See the matching ISEjectMagazine comment above.
    if handler and handler.animId then
        self:setAnimVariable("WeaponReloadType", handler.animId)
    end

    if handler then
        if self.shouldShortRackAfterInsert and ReloadAnim.shouldQueueShortRackAfterInsert(self) then
            self:setAnimVariable("isLoadingShort", true)
            if self.character then
                self.character:clearVariable("isLoading")
            end
        end
    end
end

-- Gunworks DOES wrap Insert.serverStart (vanilla + a speedloader eject side-effect).
-- The registered-gun path uses a custom finish-event duration and skips prev, so it
-- must inline that one side-effect; unregistered guns keep the full Gunworks+vanilla path.
local prevInsertServerStart = ISInsertMagazine.serverStart
---@param self ISInsertMagazine
function ISInsertMagazine:serverStart()
    local handler = ReloadAnim.getHandlerForAction(self)
    if not handler then
        return prevInsertServerStart(self)
    end

    self:initVars()
    local isClip = self.magazine and SpeedLoader.IsCompatibleTypeForGun(self.magazine:getFullType(), self.gun)
    if isClip then
        ISReloadWeaponAction.ejectSpentRounds(self)
    end

    local loadSeconds = ReloadAnim.getProfileDuration(self, handler, "load")
    if isClip then
        loadSeconds = ReloadAnim.getProfileDuration(self, handler, "clip") or loadSeconds
    end
    if ReloadAnim.shouldUseShortLoad(self, handler) then
        loadSeconds = ReloadAnim.getProfileDuration(self, handler, "loadShort") or loadSeconds
    end
    local durationMs = ReloadAnim.getActionDurationMs(self, loadSeconds, 1500)
    emulateAnimEventOnce(self.netAction, durationMs, "loadFinished", nil)
end

local prevInsertAnimEvent = ISInsertMagazine.animEvent
---@param self ISInsertMagazine
---@param event string
---@param parameter string
function ISInsertMagazine:animEvent(event, parameter)
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onInsertAnimEvent then
        if handler.onInsertAnimEvent(self, event, parameter) then
            return
        end
    end

    prevInsertAnimEvent(self, event, parameter)
end

local prevInsertLoadAmmo = ISInsertMagazine.loadAmmo
---@param self ISInsertMagazine
function ISInsertMagazine:loadAmmo()
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onInsertLoadAmmo then
        if handler.onInsertLoadAmmo(self) then
            return
        end
    end

    prevInsertLoadAmmo(self)
end

local prevInsertStop = ISInsertMagazine.stop
---@param self ISInsertMagazine
function ISInsertMagazine:stop()
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onInsertStop then
        if handler.onInsertStop(self) then
            return
        end
    end

    prevInsertStop(self)
    if handler then
        ReloadAnim.resetWeaponModel(self, handler)
    end
end

local prevInsertPerform = ISInsertMagazine.perform
---@param self ISInsertMagazine
function ISInsertMagazine:perform()
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onInsertPerform then
        if handler.onInsertPerform(self) then
            return
        end
    end

    ReloadRules.afterAction(self)
    prevInsertPerform(self)
    if handler then
        ReloadAnim.resetWeaponModel(self, handler)
    end
end

-------------------------------------------------
-- ISRackFirearm
-------------------------------------------------
-- Vanilla start sets the engine reload type, then setActionAnim enters PlayerActionsState
-- and snapshots the action variables for observers. Correct the type BEFORE that call;
-- overriding it only after prevRackStart returns changes the local animation too late
-- for the snapshot. This also covers handleShortRackStart's early-return path.
local prevRackSetActionAnim = ISRackFirearm.setActionAnim
function ISRackFirearm:setActionAnim(actionAnim, displayItemModels)
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.animId then
        self:setAnimVariable("WeaponReloadType", handler.animId)
    end
    if handler and self.gunworksRackPhase then
        self:setAnimVariable(ReloadAnim.RACK_PHASE_VARIABLE, self.gunworksRackPhase)
    end
    if handler then
        self:setAnimVariable(ReloadRules.STEP_VARIABLE, ReloadRules.stepOf(self))
    end
    return prevRackSetActionAnim(self, actionAnim, displayItemModels)
end

-- The opening and closing strokes (rule steps "open" / "close", RackPhases.lua) carry the stroke to the
-- server as a constructor argument, so the server times the same stroke the owner plays.
local prevRackNew = ISRackFirearm.new
function ISRackFirearm:new(character, gun, gunworksRackPhase)
    local action = prevRackNew(self, character, gun)
    action.gunworksRackPhase = gunworksRackPhase
    return action
end

-- An open bolt of a gun with reload rules can always be closed, even on an empty gun.
local prevCanRack = ISReloadWeaponAction.canRack
ISReloadWeaponAction.canRack = function(weapon)
    if prevCanRack(weapon) then
        return true
    end
    return ReloadRules.isBoltOpen(weapon) and ReloadRules.hasRules(ReloadAnim.GetHandlerForGun(weapon))
end

-- The reload key asks the rules first: a full open-to-load gun has nothing to gain, and a stripper clip can
-- load a gun even without loose rounds to move.
local prevBeginAutomaticReload = ISReloadWeaponAction.BeginAutomaticReload
ISReloadWeaponAction.BeginAutomaticReload = function(playerObj, gun)
    if ReloadRules.planReload(playerObj, gun) then
        return
    end
    return prevBeginAutomaticReload(playerObj, gun)
end

local prevRackStart = ISRackFirearm.start
---@param self ISRackFirearm
function ISRackFirearm:start()
    if self and self.gun then
        local modData = self.gun:getModData()
        if modData and modData.shortRackAfterInsert then
            self.useShortRack = true
            modData.shortRackAfterInsert = nil
        end
    end

    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and self.gunworksRackPhase == ReloadAnim.RACK_PHASE_OPEN then
        ReloadAnim.startOpeningStroke(self)
        return
    end
    if handler and ReloadAnim.closesOverHandRound(self) then
        self.gunworksKeepChamber = true
    end

    if handler and handler.onRackStart then
        if handler.onRackStart(self) then
            return
        end
    end

    prevRackStart(self)
    -- Same override as Eject/Insert above, run after prev for the same reason. Racking chambers
    -- the first round after EITHER a magazine reload or a non-mag one (ISReloadWeaponAction
    -- queues an ISRackFirearm when the gun needs a chambered round), so this also covers a
    -- non-mag gun's rack-to-chamber stage, which previously had no override at all.
    if handler and handler.animId then
        self:setAnimVariable("WeaponReloadType", handler.animId)
    end
end

-- Gunworks does not wrap Rack.serverStart, so prev is vanilla. Registered guns get a
-- custom-duration rack; unregistered keep vanilla.
local prevRackServerStart = ISRackFirearm.serverStart
---@param self ISRackFirearm
function ISRackFirearm:serverStart()
    local handler = ReloadAnim.getHandlerForAction(self)
    if not handler then
        return prevRackServerStart(self)
    end

    -- First, so every weapon sync from here on carries the bolt the stroke leaves (RackPhases.lua).
    ReloadAnim.recordStrokeOnServer(self)

    -- The opening stroke only animates: no ejectSpentRounds or rackBullet, the closing stroke racks.
    if self.gunworksRackPhase == ReloadAnim.RACK_PHASE_OPEN then
        self:initVars()
        local openSeconds = ReloadAnim.getProfileDuration(self, handler, "rackOpen")
            or ReloadAnim.getProfileDuration(self, handler, "rack")
        emulateAnimEventOnce(self.netAction, ReloadAnim.getActionDurationMs(self, openSeconds, 1200), "rackingFinished", nil)
        return
    end

    -- A closing stroke has its own clip when the gun also keeps a full one-stroke rack (pumps, levers).
    local rackSeconds = ReloadAnim.getProfileDuration(self, handler, "rack")
    if self.gunworksRackPhase == ReloadAnim.RACK_PHASE_CLOSE then
        rackSeconds = ReloadAnim.getProfileDuration(self, handler, "rackClose") or rackSeconds
    end
    local durationMs = ReloadAnim.getActionDurationMs(self, rackSeconds, 1200)

    -- A closing stroke over a round loaded by hand leaves the rounds alone: no ejectSpentRounds (Hot Brass
    -- ejects the chambered round there) and no rackBullet.
    if ReloadAnim.closesOverHandRound(self) then
        self.gunworksKeepChamber = true
        self:initVars()
        emulateAnimEventOnce(self.netAction, durationMs, "rackingFinished", nil)
        return
    end

    self:ejectSpentRounds()
    self:initVars()
    emulateAnimEventOnce(self.netAction, math.min(100, durationMs), "rackBullet", nil)
    emulateAnimEventOnce(self.netAction, durationMs, "rackingFinished", nil)
end

-- A closing stroke over a round loaded by hand skips the rack's round events (vanilla rackBullet, Hot Brass
-- ejectCasing / chamberRound); the bolt visual and the finish still play.
local prevRackAnimEvent = ISRackFirearm.animEvent
function ISRackFirearm:animEvent(event, parameter)
    if self.gunworksKeepChamber and ReloadAnim.isRoundEvent(event) then
        return
    end
    return prevRackAnimEvent(self, event, parameter)
end

-- Server and singleplayer: once a rack completes, the chambered round is no longer one loaded by hand.
local prevRackComplete = ISRackFirearm.complete
function ISRackFirearm:complete()
    if not isClient() and ReloadAnim.getHandlerForAction(self) then
        ReloadAnim.setHandChambered(self.gun, false)
    end
    return prevRackComplete(self)
end

local prevRackStop = ISRackFirearm.stop
---@param self ISRackFirearm
function ISRackFirearm:stop()
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onRackStop then
        handler.onRackStop(self)
    end

    prevRackStop(self)
end

local prevRackPerform = ISRackFirearm.perform
---@param self ISRackFirearm
function ISRackFirearm:perform()
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onRackPerform then
        handler.onRackPerform(self)
    end

    ReloadRules.afterAction(self)
    prevRackPerform(self)
end

-------------------------------------------------
-- ISReloadWeaponAction (non-magazine reloads: shotgun / revolver / bolt / dbl-barrel / lever)
-------------------------------------------------
-- Only non-mag archetype handlers carry onReload* callbacks, so a magazine gun (its handler
-- has none) and every unregistered gun fall straight through to vanilla. start/animEvent/stop/
-- perform add ONLY the optional off-hand prop and model swaps; the vanilla action keeps full
-- ownership of the shell-by-shell loadFinished/loadAmmo loop. serverStart additionally applies
-- the profile's authored load duration, but only when one is set - a registered gun without
-- durations.load keeps byte-for-byte vanilla timing. The reload rules add their steps in begin
-- (applyRulesOnBegin above) and perform.
--
-- The loadChamber rule step is a load of its own (gunworksReloadStep = "loadChamber"): its single
-- loadFinished puts one round straight into the chamber instead of the magazine, and it ends there.

local prevReloadStart = ISReloadWeaponAction.start
---@param self ISReloadWeaponAction
function ISReloadWeaponAction:start()
    local handler = ReloadAnim.getHandlerForAction(self)
    prevReloadStart(self)
    -- Vanilla start() just set the WeaponReloadType anim variable to the gun's engine reload type
    -- (e.g. "boltactionnomag"), which makes the matching vanilla reload node (LoadRifleNoMag) a
    -- candidate. Our custom node is gated on the separate GunworksReloadAnim variable, so the two
    -- compete - and for some archetypes the vanilla node wins even though ours has a higher
    -- ConditionPriority. Overwrite WeaponReloadType with our animId so NO vanilla reload node
    -- matches and only the custom node plays. Safe: this variable feeds AnimSet node conditions
    -- ONLY - the reload MECHANICS read gun:getWeaponReloadType() directly, never this variable.
    if handler and handler.animId and ReloadAnim.isNonMagArchetype(handler.archetype) then
        self:setAnimVariable("WeaponReloadType", handler.animId)
    end
    if handler and handler.onReloadStart then
        handler.onReloadStart(self)
    end
end

local prevReloadServerStart = ISReloadWeaponAction.serverStart
---@param self ISReloadWeaponAction
function ISReloadWeaponAction:serverStart()
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and self.gunworksReloadStep == ReloadRules.STEP_LOAD_CHAMBER then
        self:initVars()
        self:ejectSpentRounds()
        if not self.bullets then
            self.netAction:forceComplete()
            return
        end
        local chamberSeconds = ReloadAnim.getProfileDuration(self, handler, "loadChamber")
            or ReloadAnim.getProfileDuration(self, handler, "load")
        emulateAnimEventOnce(self.netAction, ReloadAnim.getActionDurationMs(self, chamberSeconds, 1000), "loadFinished", nil)
        return
    end

    local loadSeconds = handler and ReloadAnim.getProfileDuration(self, handler, "load")
    if not handler or not ReloadAnim.isNonMagArchetype(handler.archetype) or loadSeconds == nil then
        return prevReloadServerStart(self)
    end

    self:initVars()
    if isServer() then
        self:ejectSpentRounds()
        if not self.bullets then
            self.netAction:forceComplete()
        end
    end

    -- emulateAnimEvent REPEATS: each loadFinished loads one round, so this is the per-round interval.
    emulateAnimEvent(self.netAction, ReloadAnim.getActionDurationMs(self, loadSeconds, 0), "loadFinished", nil)
end

local prevReloadAnimEvent = ISReloadWeaponAction.animEvent
---@param self ISReloadWeaponAction
---@param event string
---@param parameter string
function ISReloadWeaponAction:animEvent(event, parameter)
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onReloadAnimEvent then
        handler.onReloadAnimEvent(self, event, parameter)
    end

    -- loadChamber: the round goes into the chamber, not through vanilla loadAmmo, and the load ends.
    if event == "loadFinished" and handler and self.gunworksReloadStep == ReloadRules.STEP_LOAD_CHAMBER then
        if not isClient() then
            ReloadAnim.loadRoundIntoChamber(self)
            self.character:clearVariable("isLoading")
            if isServer() then
                self.netAction:forceComplete()
            else
                self:forceComplete()
            end
        end
        return
    end

    -- Always run vanilla: its animEvent owns loadFinished -> loadAmmo (shell-by-shell load)
    -- and rackingFinished. Skipping it would stop ammo from loading.
    prevReloadAnimEvent(self, event, parameter)

    -- Muzzle-loaders (autoRack = false) have no break-action to close. The vanilla double-barrel
    -- reload runs a close/rack "snap-back" stage right after the rounds load (playReloadSound rack ->
    -- rackBullet -> rackingFinished). The rounds are already in by loadFinished, so force-complete the
    -- action here to end it before that stage starts and the snap-back animation plays.
    if event == "loadFinished" and handler and handler.autoRack == false then
        self:forceComplete()
    end
end

local prevReloadStop = ISReloadWeaponAction.stop
---@param self ISReloadWeaponAction
function ISReloadWeaponAction:stop()
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onReloadStop then
        handler.onReloadStop(self)
    end

    prevReloadStop(self)
    if handler then
        ReloadAnim.resetWeaponModel(self, handler)
    end
end

local prevReloadPerform = ISReloadWeaponAction.perform
---@param self ISReloadWeaponAction
function ISReloadWeaponAction:perform()
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onReloadPerform then
        handler.onReloadPerform(self)
    end

    -- Before prev: its perform hands the queue to the next action, after which there is no anchor.
    ReloadRules.afterAction(self)
    prevReloadPerform(self)
    if handler then
        ReloadAnim.resetWeaponModel(self, handler)
    end
end

-------------------------------------------------
-- ISUnloadBulletsFromFirearm (non-magazine unload: shotgun / revolver / bolt / dbl-barrel / lever)
-------------------------------------------------
-- Vanilla start() sets the WeaponReloadType anim variable to the gun's engine reload type
-- (e.g. "doublebarrelshotgun"), exactly like ISReloadWeaponAction did before the override
-- above. A registered non-mag gun's custom Unload AnimSet node is gated on WeaponReloadType
-- == handler.animId (mirroring its Load/Rack nodes), so without this same override that node
-- can never match and a vanilla/unrelated Unload node plays instead - most visibly on
-- break-action guns, whose vanilla node fires changeWeaponSprite to the OPEN vanilla model,
-- silently swapping the held weapon to vanilla's double barrel for the whole unload action.
--
-- Gated on handler.customUnload (opt-in per profile), NOT just animId+isNonMagArchetype.
-- Unlike Load - where every non-mag profile ships a Load*_HB.xml keyed to animId, or the
-- profile wouldn't animate at all - a matching Unload*_HB.xml node is not guaranteed to exist,
-- or to be the ONLY node keyed to that animId's archetype, for every registered profile across
-- every pack on this shared framework. A concrete case: Guns of Marz's lever archetype has TWO
-- parallel Unload node families (UnloadLeverMarz_HB.xml keyed to the animId "lever_reload", and
-- UnloadLeverAction_HB.xml keyed to the gun's real engine value "leveraction", which is what
-- plays today since nothing currently overrides WeaponReloadType at unload) - an unconditional
-- override here would silently switch which one plays, an unverified behavior change nobody
-- asked for. An author sets customUnload = true on a profile only after confirming their pack's
-- Unload*_HB.xml is the one node meant to win once WeaponReloadType == animId during unload.
local prevUnloadStart = ISUnloadBulletsFromFirearm.start
function ISUnloadBulletsFromFirearm:start()
    local handler = ReloadAnim.getHandlerForAction(self)
    prevUnloadStart(self)
    if handler and handler.animId and handler.customUnload and ReloadAnim.isNonMagArchetype(handler.archetype) then
        self:setAnimVariable("WeaponReloadType", handler.animId)
    end
end

local prevUnloadServerStart = ISUnloadBulletsFromFirearm.serverStart
function ISUnloadBulletsFromFirearm:serverStart()
    local handler = ReloadAnim.getHandlerForAction(self)
    local unloadSeconds = handler and ReloadAnim.getProfileDuration(self, handler, "unload")
    if not handler or not ReloadAnim.isNonMagArchetype(handler.archetype) or unloadSeconds == nil then
        return prevUnloadServerStart(self)
    end

    self:initVars()
    self.gunworksTimedUnload = true
    -- Vanilla removes a round every 500 ms regardless of the animation length.
    -- For an authored duration, remove one round/batch at each full clip boundary
    -- and then let vanilla test whether unloading has finished. Keep this repeating
    -- for shell-by-shell guns; insert-all guns empty in a single cycle.
    emulateAnimEvent(self.netAction, ReloadAnim.getActionDurationMs(self, unloadSeconds, 0), "unloadFinished", nil)
end

local prevUnloadAnimEvent = ISUnloadBulletsFromFirearm.animEvent
function ISUnloadBulletsFromFirearm:animEvent(event, parameter)
    if event == "unloadFinished" and self.gunworksTimedUnload and isServer() then
        prevUnloadAnimEvent(self, "playReloadSound", "unload")
    end
    return prevUnloadAnimEvent(self, event, parameter)
end

local prevUnloadPerform = ISUnloadBulletsFromFirearm.perform
function ISUnloadBulletsFromFirearm:perform()
    ReloadRules.afterAction(self)
    return prevUnloadPerform(self)
end

return ReloadAnim
