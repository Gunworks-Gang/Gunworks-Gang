-- Gunworks reload-animation framework: two-stroke racks for guns whose bolt locks back, such as the
-- HK family (MP5, G3). A profile with `splitRack = true` racks in two separate actions, each with its
-- own AnimSet node: an opening stroke that locks the bolt back, then a closing stroke that releases it.
--
--   empty reload (nothing chambered):  open -> eject (if a magazine is in) -> insert -> close
--   reload with a round chambered:      eject -> insert
--   manual rack:                        open -> close
--
-- The opening stroke only animates. The closing stroke is an ordinary rack and keeps all the round
-- handling (vanilla rackBullet, or Hot Brass on ejectCasing), so a manual rack still ejects one round
-- and chambers one. The gun remembers an open bolt in its mod data: the rack the insert queues then
-- only closes, and an interrupted reload resumes with a closing stroke. Every choice is made when an
-- action starts, so the stroke rides the anim snapshot to observers and the constructor argument to
-- the server, like the aim flag. Gate the AnimSet nodes on GunworksRackPhase = "open" / "close".

---@class GunworksReloadAnim
local ReloadAnim = require("WeaponSystems/Utils/ReloadAnim")

ReloadAnim.RACK_PHASE_VARIABLE = "GunworksRackPhase"
ReloadAnim.RACK_PHASE_OPEN = "open"
ReloadAnim.RACK_PHASE_CLOSE = "close"

local BOLT_OPEN_KEY = "gunworksBoltOpen"

---@param handler GunworksReloadAnimHandler|nil
---@nodiscard
---@return boolean
function ReloadAnim.isSplitRackHandler(handler)
    return handler ~= nil and handler.splitRack == true
end

---@param gun HandWeapon|nil
---@nodiscard
---@return boolean
function ReloadAnim.isBoltOpen(gun)
    local modData = gun and gun:getModData()
    return modData ~= nil and modData[BOLT_OPEN_KEY] == true
end

---@param gun HandWeapon|nil
---@param open boolean
---@return nil
function ReloadAnim.setBoltOpen(gun, open)
    local modData = gun and gun:getModData()
    if modData then
        modData[BOLT_OPEN_KEY] = open and true or nil
    end
end

--- Does a reload of this gun start with an opening stroke? True for a split-rack gun with nothing
--- chambered and its bolt still closed, when the reload will queue an eject or an insert: the gun
--- holds a magazine, or there is a magazine to insert.
---@param playerObj IsoPlayer
---@param gun HandWeapon|nil
---@param bestMagazine fun(playerObj:IsoPlayer, gun:HandWeapon):InventoryItem|nil
---@nodiscard
---@return boolean
function ReloadAnim.shouldOpenBoltBeforeReload(playerObj, gun, bestMagazine)
    if not instanceof(gun, "HandWeapon") or not gun:getMagazineType() or not gun:haveChamber() then
        return false
    end
    if gun:isRoundChambered() or ReloadAnim.isBoltOpen(gun) then
        return false
    end
    if not ReloadAnim.isSplitRackHandler(ReloadAnim.GetHandlerForGun(gun)) then
        return false
    end
    return gun:isContainsClip() or bestMagazine(playerObj, gun) ~= nil
end

--- Pick this rack's stroke when its creator did not: close a bolt that is already open; otherwise
--- open it now and queue the closing stroke right after (a full rack). Runs where the action queue
--- lives (client or singleplayer start); the server receives the result as a constructor argument.
---@param action ISRackFirearm
---@return string
function ReloadAnim.chooseRackPhase(action)
    if not action.gunworksRackPhase then
        if ReloadAnim.isBoltOpen(action.gun) then
            action.gunworksRackPhase = ReloadAnim.RACK_PHASE_CLOSE
        else
            action.gunworksRackPhase = ReloadAnim.RACK_PHASE_OPEN
            ISTimedActionQueue.addAfter(action,
                ISRackFirearm:new(action.character, action.gun, ReloadAnim.RACK_PHASE_CLOSE))
        end
    end
    return action.gunworksRackPhase
end

--- Start the opening stroke: vanilla ISRackFirearm:start without its canRack gate (an empty gun can
--- still lock its bolt back) and without ejectSpentRounds (Hot Brass chambers a round there).
---@param action ISRackFirearm
---@return nil
function ReloadAnim.startOpeningStroke(action)
    local character = action.character
    if isClient() then
        action.gun = character:getInventory():getItemById(action.gun:getID())
    end
    action:setAnimVariable("isRacking", true)
    action:setAnimVariable("RackAiming", character:isAiming())
    if character:isAiming() then
        character:setAimingDelay(character:getAimingDelay()
            + action.gun:getAimingTime() * (0.15 - character:getPerkLevel(Perks.Reloading) * 0.01))
    end
    action:setOverrideHandModels(action.gun, nil)
    action:setActionAnim(CharacterActionAnims.Reload)
    character:reportEvent("EventReloading")
    action:initVars()
end

--- Record the bolt position once a stroke has finished.
---@param action ISRackFirearm
---@return boolean opened true when this was an opening stroke
function ReloadAnim.finishRackStroke(action)
    if not action.gunworksRackPhase or not ReloadAnim.isSplitRackHandler(ReloadAnim.getHandlerForAction(action)) then
        return false
    end
    local opened = action.gunworksRackPhase == ReloadAnim.RACK_PHASE_OPEN
    ReloadAnim.setBoltOpen(action.gun, opened)
    return opened
end

return ReloadAnim
