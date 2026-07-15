-- Gunworks reload-animation framework: mid-reload gun-part swaps (the gwSetPart marker).
--
-- One additive anim event, authored as a timeline marker on the reload clip. It sets which WeaponPart
-- shows at an attachment location (a PartType) on the gun:
--
--   gwSetPart  value = "<PartType>=<partFullType>"  -> attach/replace the part at that PartType
--              value = "<PartType>="                -> detach whatever occupies that PartType
--
-- Unlike gwPartToHand/gwPartToGun (Props.lua), which move a gun part into/out of the off-hand slot,
-- gwSetPart is gun-side only: it swaps the cosmetic part model shown at a location (a trapdoor breech
-- closed<->open, a hammer uncocked<->cocked). Purely cosmetic (attachVisualPart uses doChange=false),
-- and PartState.lua reconciles the steady state back after the reload.
--
-- Authority in MP mirrors reloadProp (Props.lua): a Lua animEvent fires only for the LOCAL reloading
-- client (LuaTimedActionNew.java), so on an MP client we ask the server to apply + relay to observers;
-- in singleplayer / on the server we apply directly.

---@class GunworksReloadAnim
local ReloadAnim = require("WeaponSystems/Utils/ReloadAnim")
require("WeaponSystems/ReloadAnim/Visuals")

ReloadAnim.PART_SWAP_EVENT = "gwSetPart"

--- Split a gwSetPart value "PartType=fullType" into its parts. An empty fullType means "detach whatever
--- is at this location". Returns nil partType for a malformed value.
---@param value string|nil
---@nodiscard
---@return string|nil partType, string fullType
function ReloadAnim.parsePartSwapValue(value)
    if not value or value == "" then
        return nil, ""
    end

    local eq = string.find(value, "=", 1, true)
    if not eq then
        return nil, ""
    end

    local partType = string.sub(value, 1, eq - 1)
    if partType == "" then
        return nil, ""
    end

    return partType, string.sub(value, eq + 1)
end

---@param event string|nil
---@nodiscard
---@return boolean
function ReloadAnim.isPartSwapEvent(event)
    return event == ReloadAnim.PART_SWAP_EVENT
end

--- Validate a gwSetPart request. The value arrives from a client command, so the server must not
--- trust it blindly. A detach (empty fullType) is always safe. For an attach, the item must resolve to
--- a WeaponPart -- the swap is cosmetic (doChange=false) and PartState reconciles it away if it is
--- wrong, so a WeaponPart check is a sufficient bar without a full MountOn scan.
---@param gun HandWeapon|nil
---@param partType string|nil
---@param fullType string|nil
---@nodiscard
---@return boolean
function ReloadAnim.isAllowedPartValue(gun, partType, fullType)
    if not instanceof(gun, "HandWeapon") or not partType or partType == "" then
        return false
    end

    if not fullType or fullType == "" then
        return true
    end

    local part = instanceItem(fullType)
    return part ~= nil and instanceof(part, "WeaponPart")
end

--- Apply one gwSetPart marker authoritatively (singleplayer, or the server acting for a client). An
--- empty fullType detaches whatever is at `partType`; a non-empty one attaches it, and attachVisualPart
--- auto-detaches the part already sharing that PartType, so a replace is one call.
---@param character IsoGameCharacter|nil
---@param gun HandWeapon|nil
---@param partType string|nil
---@param fullType string|nil
---@return nil
function ReloadAnim.applyPartSwapEvent(character, gun, partType, fullType)
    if not character or not instanceof(gun, "HandWeapon") or not partType or partType == "" then
        return
    end

    local changed = false
    if fullType and fullType ~= "" then
        changed = ReloadAnim.attachVisualPart(character, gun, fullType)
    else
        local current = gun:getWeaponPart(partType)
        if current then
            changed = ReloadAnim.detachVisualPart(character, gun, current:getFullType())
        end
    end

    if not changed then
        return
    end

    character:resetEquippedHandsModels()
    syncHandWeaponFields(character, gun)
end

--- Apply a relayed gwSetPart marker on an observer client. Gun-side only and no re-broadcast: the part
--- change reaches the observer's copy of the weapon, syncHandWeaponFields stays with the server.
---@param character IsoGameCharacter|nil
---@param gun HandWeapon|nil
---@param partType string|nil
---@param fullType string|nil
---@return nil
function ReloadAnim.applyRemotePartSwapEvent(character, gun, partType, fullType)
    if not character or not instanceof(gun, "HandWeapon") or not partType or partType == "" then
        return
    end

    local changed = false
    if fullType and fullType ~= "" then
        changed = ReloadAnim.attachVisualPart(character, gun, fullType)
    else
        local current = gun:getWeaponPart(partType)
        if current then
            changed = ReloadAnim.detachVisualPart(character, gun, current:getFullType())
        end
    end

    if changed then
        character:resetEquippedHandsModels()
    end
end

--- Timed-action entry point: handle a gwSetPart marker fired by the reload clip. Additive -- returns
--- false for every other event so the normal dispatch continues.
---@param action ISBaseTimedAction
---@param handler GunworksReloadAnimHandler|nil
---@param event string
---@param parameter string
---@nodiscard
---@return boolean
function ReloadAnim.handleGwSetPartAnimEvent(action, handler, event, parameter)
    if event ~= ReloadAnim.PART_SWAP_EVENT then
        return false
    end

    local character = action.character
    if not character then
        return false
    end

    local partType, fullType = ReloadAnim.parsePartSwapValue(parameter)
    if not partType then
        return true
    end

    local gun = ReloadAnim.resolveActionGun(action, handler, true)
    if isClient() then
        sendClientCommand(character, "SWMG", "gwSetPart", {
            gunId = gun and gun:getID(),
            partType = partType,
            value = fullType,
        })
        return true
    end

    ReloadAnim.applyPartSwapEvent(character, gun, partType, fullType)
    return true
end

return ReloadAnim
