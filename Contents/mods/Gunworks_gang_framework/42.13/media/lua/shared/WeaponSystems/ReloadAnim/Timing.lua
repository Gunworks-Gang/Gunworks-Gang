-- Gunworks reload-animation framework: duration scaling + reload state variables.
-- Ported from AnimatedReloads' Timing; the per-gun selector now writes the custom
-- GunworksReloadAnim variable (handler.animId) instead of the engine WeaponReloadType.

---@class GunworksReloadAnim
local ReloadAnim = require("WeaponSystems/Utils/ReloadAnim")

---@param action ISBaseTimedAction
---@nodiscard
---@return number
function ReloadAnim.getReloadSpeed(action)
    if not action or not action.character then
        return 1
    end

    local reloadSpeed = action.character:getVariableFloat("ReloadSpeed", 1)
    if reloadSpeed <= 0 then
        return 1
    end

    return reloadSpeed
end

---@param action ISBaseTimedAction
---@param seconds number
---@nodiscard
---@return number
function ReloadAnim.getScaledReloadDelay(action, seconds)
    if seconds <= 0 then
        return seconds
    end

    return seconds / ReloadAnim.getReloadSpeed(action)
end

---@param action ISBaseTimedAction
---@param seconds number|nil
---@param fallbackMs number
---@nodiscard
---@return number
function ReloadAnim.getActionDurationMs(action, seconds, fallbackMs)
    if seconds == nil then
        return fallbackMs
    end

    local scaledSeconds = ReloadAnim.getScaledReloadDelay(action, seconds)
    return math.max(0, math.floor((scaledSeconds * 1000) + 0.5))
end

---@param action ISInsertMagazine
---@nodiscard
---@return boolean
function ReloadAnim.shouldQueueShortRackAfterInsert(action)
    if not action or not action.gun or not action.magazine then
        return false
    end

    if action.gun:isRoundChambered() then
        return false
    end

    local ammoPerShot = action.gun:getAmmoPerShoot()
    return ammoPerShot > 0 and action.magazine:getCurrentAmmoCount() >= ammoPerShot
end

---@param action ISInsertMagazine
---@param handler GunworksReloadAnimHandler|nil
---@nodiscard
---@return boolean
function ReloadAnim.shouldUseShortLoad(action, handler)
    if not action then
        return false
    end

    local shouldShort = action.shouldShortRackAfterInsert
    if shouldShort == nil and handler then
        shouldShort = handler.shortRackAfterInsert
    end

    if not shouldShort then
        return false
    end

    return ReloadAnim.shouldQueueShortRackAfterInsert(action)
end

---@param action ISInsertMagazine
---@param enabled boolean|nil
---@return nil
function ReloadAnim.setShortRackAfterInsert(action, enabled)
    if not action then
        return
    end

    if enabled then
        action.shouldShortRackAfterInsert = true
        if ReloadAnim.shouldQueueShortRackAfterInsert(action) then
            action:setAnimVariable("isLoadingShort", true)
        elseif action.character then
            action.character:clearVariable("isLoadingShort")
        end
    else
        action.shouldShortRackAfterInsert = nil
        if action.character then
            action.character:clearVariable("isLoadingShort")
        end
    end
end

---@param action ISRackFirearm
---@param handler GunworksReloadAnimHandler|nil
---@return boolean
function ReloadAnim.handleShortRackStart(action, handler)
    if not action or not action.useShortRack or not handler then
        return false
    end

    if not ISReloadWeaponAction.canRack(action.gun) then
        action:forceComplete()
        return true
    end

    action:setAnimVariable(ReloadAnim.ANIM_VARIABLE, handler.animId)
    action:setAnimVariable("isRacking", true)

    action:setAnimVariable("RackAiming", action.character:isAiming())
    if action.character:isAiming() then
        action.character:setAimingDelay(action.character:getAimingDelay() + action.gun:getAimingTime() * (0.15 - action.character:getPerkLevel(Perks.Reloading) * 0.01))
    end

    action:setActionAnim(CharacterActionAnims.Reload)
    action.character:reportEvent("EventReloading")

    action:ejectSpentRounds()
    action:initVars()
    return true
end

---@param action ISRackFirearm
---@return nil
function ReloadAnim.handleShortRackStop(action)
    if action and action.useShortRack then
        action.character:clearVariable("isRackingShort")
    end
end

---@param action ISRackFirearm
---@return nil
function ReloadAnim.handleShortRackPerform(action)
    if action and action.useShortRack then
        action.character:clearVariable("isRackingShort")
    end
end

---@param action ISBaseTimedAction
---@return nil
function ReloadAnim.queueGunRackAfter(action)
    local rackAction = ISRackFirearm:new(action.character, action.gun)
    rackAction.useShortRack = true
    ISTimedActionQueue.addAfter(action, rackAction)
end

---@param action ISBaseTimedAction
---@return nil
function ReloadAnim.setShortRackPending(action)
    if not action or not action.gun then
        return
    end

    local modData = action.gun:getModData()
    modData.shortRackAfterInsert = true
end

return ReloadAnim
