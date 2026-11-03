-- Gunworks reload-animation framework: the opening and closing strokes, and the round loaded by hand.
--
-- A gun whose reload rules (ReloadAnim/Rules.lua) use the `open` and `close` steps racks in two separate
-- ISRackFirearm actions, each with its own AnimSet node gated on GunworksRackPhase = "open" / "close". The
-- stroke is a constructor argument, so the server times the same stroke the owner plays.
--
-- The opening stroke only animates: it starts on an empty gun (no canRack gate) and handles no rounds
-- itself; with Hot Brass its ejectCasing event ejects the chambered round. The closing stroke is an ordinary
-- rack: vanilla rackBullet, or Hot Brass chamberRound, chambers the next round (and, without Hot Brass,
-- ejects the round the opening left in).
--
-- The exception is a round put straight into the open chamber (the loadChamber step, used by pump actions
-- loaded from empty). The gun is marked, and the closing stroke that follows closes over that round and
-- leaves the rounds alone. The mark lives where rounds are handled (server, singleplayer) and any rack
-- clears it when it completes.
--
-- The bolt flag (gunworksBoltOpen) is recorded by the strokes' rackStart / rackEnd events (Animations.lua).
-- Those events play only on the owner's client, so the multiplayer server records each stroke's bolt state
-- itself when the stroke starts (recordStrokeOnServer).

---@class GunworksReloadAnim
local ReloadAnim = require("WeaponSystems/Utils/ReloadAnim")
local Ammo = require("WeaponSystems/Utils/Ammo")
local Animations = require("WeaponSystems/Utils/Animations")

ReloadAnim.RACK_PHASE_VARIABLE = "GunworksRackPhase"
ReloadAnim.RACK_PHASE_OPEN = "open"
ReloadAnim.RACK_PHASE_CLOSE = "close"

local BOLT_OPEN_KEY = "gunworksBoltOpen"
local HAND_CHAMBERED_KEY = "gunworksHandChambered"

-- Round events of a rack, skipped by a closing stroke that closes over a round loaded by hand.
local ROUND_EVENTS = {
    rackBullet = true,
    ejectCasing = true,
    chamberRound = true,
}

---@param gun HandWeapon|nil
---@nodiscard
---@return boolean
function ReloadAnim.isBoltOpen(gun)
    local modData = gun and gun:getModData()
    return modData ~= nil and modData[BOLT_OPEN_KEY] == true
end

--- Multiplayer server, when a rack starts: the bolt state the stroke leaves. Without it the server keeps a
--- closed bolt, and its next weapon sync (a loaded round, an ejected magazine) closes the bolt on the client in
--- the middle of the reload. An opening stroke leaves the bolt open; any other rack leaves it closed, recorded
--- before the rack's own round syncs go out. Nothing is sent: the client's rackStart / rackEnd keep the timing.
---@param action ISRackFirearm
---@return nil
function ReloadAnim.recordStrokeOnServer(action)
    local open = action.gunworksRackPhase == ReloadAnim.RACK_PHASE_OPEN
    if open ~= ReloadAnim.isBoltOpen(action.gun) then
        Animations.SetBoltStateServer(action.gun, open, "reload")
    end
end

--- Does this closing stroke only close the action? A gun without a chamber (revolver) gets its rounds from the
--- load, so its closing stroke handles none: no ejectSpentRounds or rackBullet, which on such a gun take a round
--- out of the cylinder. Its rack complete closes the action visual (AnimationsHooks).
---@param action ISRackFirearm
---@nodiscard
---@return boolean
function ReloadAnim.closesWithoutChamber(action)
    return action.gunworksRackPhase == ReloadAnim.RACK_PHASE_CLOSE and not action.gun:haveChamber()
end

--- Start a stroke that handles no rounds: the opening stroke, or the closing stroke of a gun without a chamber.
--- Vanilla ISRackFirearm:start without its canRack gate (an empty gun can still lock its bolt back) and without
--- ejectSpentRounds (Hot Brass chambers a round there).
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

--- Was the chambered round put in by hand while the action was open? Server and singleplayer only.
---@param gun HandWeapon|nil
---@nodiscard
---@return boolean
function ReloadAnim.isHandChambered(gun)
    local modData = gun and gun:getModData()
    return modData ~= nil and modData[HAND_CHAMBERED_KEY] == true
end

---@param gun HandWeapon|nil
---@param value boolean
---@return nil
function ReloadAnim.setHandChambered(gun, value)
    if not gun then
        return
    end
    gun:getModData()[HAND_CHAMBERED_KEY] = value and true or nil
end

--- Does this closing stroke close over a round loaded by hand? Decided once, where rounds are handled.
---@param action ISRackFirearm
---@nodiscard
---@return boolean
function ReloadAnim.closesOverHandRound(action)
    return not isClient()
        and action.gunworksRackPhase == ReloadAnim.RACK_PHASE_CLOSE
        and ReloadAnim.isHandChambered(action.gun)
end

---@param event string
---@nodiscard
---@return boolean
function ReloadAnim.isRoundEvent(event)
    return ROUND_EVENTS[event] == true
end

--- The loadChamber step: put one of the action's rounds straight into the empty chamber. Server and
--- singleplayer, on the load's loadFinished. The chambered round is the last AmmoList entry, as everywhere.
---@param action ISReloadWeaponAction
---@return boolean true when a round went in
function ReloadAnim.loadRoundIntoChamber(action)
    if isClient() then
        return false
    end
    local gun = action.gun
    local bullets = action.bullets
    if not gun:haveChamber() or gun:isRoundChambered() or not bullets or bullets:isEmpty() then
        return false
    end

    local bullet = bullets:get(0)
    bullets:remove(bullet)
    local inventory = action.character:getInventory()
    inventory:Remove(bullet)

    local modData = gun:getModData()
    local ammoList = modData.AmmoList or {}
    modData.AmmoList = ammoList
    ammoList[#ammoList + 1] = bullet:getFullType()

    gun:setRoundChambered(true)
    ReloadAnim.setHandChambered(gun, true)
    sendRemoveItemFromContainer(inventory, bullet)
    syncHandWeaponFields(action.character, gun)
    Ammo.SyncAmmoListToClient(action.character, gun)
    return true
end

return ReloadAnim
