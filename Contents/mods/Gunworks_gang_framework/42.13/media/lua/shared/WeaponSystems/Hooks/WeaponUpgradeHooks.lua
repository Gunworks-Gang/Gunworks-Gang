require("TimedActions/ISUpgradeWeapon")
require("TimedActions/ISRemoveWeaponUpgrade")

local StatsFactory                      = require("WeaponSystems/Utils/StatsFactory")
local Underbarrel                       = require("WeaponSystems/Utils/Underbarrel")
local RequiredAttachment                = require("WeaponSystems/Utils/RequiredAttachment")

-------------------------------------------------
-- INSTALLATION/REMOVAL VALIDATION
-- Prevent invalid parent/child attachment states
-------------------------------------------------

local _ISUpgradeWeapon_isValid_original = ISUpgradeWeapon.isValid
function ISUpgradeWeapon:isValid()
    if not _ISUpgradeWeapon_isValid_original(self) then
        return false
    end

    if self.weapon and self.part then
        local childType = self.part:getFullType()
        if RequiredAttachment.IsInstallationBlocked(self.weapon, childType) then
            return false
        end
    end

    return true
end

local _ISUpgradeWeapon_canPerformAction_original = ISUpgradeWeapon.canPerformAction
function ISUpgradeWeapon:canPerformAction()
    if not _ISUpgradeWeapon_canPerformAction_original(self) then
        return false
    end

    if self.weapon and self.part then
        local childType = self.part:getFullType()
        if RequiredAttachment.IsInstallationBlocked(self.weapon, childType) then
            return false
        end
    end

    return true
end

local _ISRemoveWeaponUpgrade_isValid_original = ISRemoveWeaponUpgrade.isValid
function ISRemoveWeaponUpgrade:isValid()
    if not _ISRemoveWeaponUpgrade_isValid_original(self) then
        return false
    end

    if self.weapon and self.partType then
        local parentPart = self.weapon:getWeaponPart(self.partType)
        if parentPart then
            local parentType = parentPart:getFullType()
            if RequiredAttachment.IsRemovalBlocked(self.weapon, parentType) then
                return false
            end
        end
    end

    return true
end

local _ISRemoveWeaponUpgrade_canPerformAction_original = ISRemoveWeaponUpgrade.canPerformAction
function ISRemoveWeaponUpgrade:canPerformAction()
    if not _ISRemoveWeaponUpgrade_canPerformAction_original(self) then
        return false
    end

    if self.weapon and self.partType then
        local parentPart = self.weapon:getWeaponPart(self.partType)
        if parentPart then
            local parentType = parentPart:getFullType()
            if RequiredAttachment.IsRemovalBlocked(self.weapon, parentType) then
                return false
            end
        end
    end

    return true
end

-------------------------------------------------
-- After a weapon part is attached or removed via the
-- vanilla upgrade system, reapply all modifier layers
-- so custom-stats attachments take effect immediately.
-- NOTE: Need to double check if I really still needs. We reaply modifiers on equip and unequip, so it might be redundant. will see UPDATE: it's not redundant lmao
-------------------------------------------------

local _ISUpgradeWeapon_complete = ISUpgradeWeapon.complete
function ISUpgradeWeapon:complete()
    _ISUpgradeWeapon_complete(self)
    if self.weapon and instanceof(self.weapon, "HandWeapon") then
        StatsFactory.ReapplyAllModifiers(self.weapon)
    end
end

local _ISRemoveWeaponUpgrade_complete = ISRemoveWeaponUpgrade.complete
function ISRemoveWeaponUpgrade:complete()
    local removedPart = nil
    if self.weapon and instanceof(self.weapon, "HandWeapon") and self.partType then
        removedPart = self.weapon:getWeaponPart(self.partType)
    end

    _ISRemoveWeaponUpgrade_complete(self)

    if self.weapon and instanceof(self.weapon, "HandWeapon") then
        if removedPart then
            Underbarrel.HandleAttachmentRemoval(self.weapon, removedPart, self.character)
        end
        StatsFactory.ReapplyAllModifiers(self.weapon)
    end
end
