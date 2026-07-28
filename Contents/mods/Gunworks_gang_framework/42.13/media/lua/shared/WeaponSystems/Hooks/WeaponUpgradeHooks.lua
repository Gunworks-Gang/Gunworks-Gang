require("TimedActions/ISUpgradeWeapon")
require("TimedActions/ISRemoveWeaponUpgrade")

local StatsFactory                      = require("WeaponSystems/Utils/StatsFactory")
local Underbarrel                       = require("WeaponSystems/Utils/Underbarrel")
local RequiredAttachment                = require("WeaponSystems/Utils/RequiredAttachment")
local UniversalAttachment               = require("WeaponSystems/Utils/UniversalAttachment")

-------------------------------------------------
-- INSTALLATION/REMOVAL VALIDATION
-- Prevent invalid parent/child attachment states
-------------------------------------------------

local _ISUpgradeWeapon_isValid_original = ISUpgradeWeapon.isValid
function ISUpgradeWeapon:isValid()
    if self.outcomeFullType then
        if not self.weapon or not self.part then return false end
        if not UniversalAttachment.CanInstallOutcome(self.weapon, self.outcomeFullType, self.character) then
            return false
        end

        if isClient() and self.part and self.weapon then
            return self.character:getInventory():containsID(self.part:getID()) and self.character:getInventory():containsID(self.weapon:getID())
        end

        return self.character:getInventory():contains(self.part) and self.character:getInventory():contains(self.weapon)
    end

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

-------------------------------------------------
-- After a weapon part is attached or removed via the
-- vanilla upgrade system, reapply all modifier layers
-- so custom-stats attachments take effect immediately.
-- NOTE: Need to double check if I really still needs. We reaply modifiers on equip and unequip, so it might be redundant. will see UPDATE: it's not redundant lmao
-------------------------------------------------

local _ISUpgradeWeapon_new = ISUpgradeWeapon.new
function ISUpgradeWeapon:new(character, weapon, part, outcomeFullType)
    local o = _ISUpgradeWeapon_new(self, character, weapon, part)
    o.outcomeFullType = outcomeFullType
    return o
end

local _ISUpgradeWeapon_complete = ISUpgradeWeapon.complete
function ISUpgradeWeapon:complete()
    if self.outcomeFullType then
        local outcomePart = instanceItem(self.outcomeFullType)
        if not outcomePart or not instanceof(outcomePart, "WeaponPart") then
            return false
        end

        self.weapon:attachWeaponPart(self.character, outcomePart)
        syncHandWeaponFields(self.character, self.weapon)
        self.character:getInventory():Remove(self.part)
        sendRemoveItemFromContainer(self.character:getInventory(), self.part)
        self.character:setSecondaryHandItem(nil)
    else
        _ISUpgradeWeapon_complete(self)
    end

    if self.weapon and instanceof(self.weapon, "HandWeapon") then
        StatsFactory.ReapplyAllModifiers(self.weapon)
    end

    return true
end

local _ISRemoveWeaponUpgrade_complete = ISRemoveWeaponUpgrade.complete
function ISRemoveWeaponUpgrade:complete()
    local removedPart = nil
    if self.weapon and instanceof(self.weapon, "HandWeapon") and self.partType then
        removedPart = self.weapon:getWeaponPart(self.partType)
    end

    local universalRefundType = nil
    if removedPart and self.weapon and UniversalAttachment.IsRegisteredOutcome(self.weapon, removedPart) then
        universalRefundType = UniversalAttachment.GetGenericItemTypeForOutcome(self.weapon, removedPart)
    end

    if universalRefundType then
        self.weapon:detachWeaponPart(self.character, removedPart)
        syncHandWeaponFields(self.character, self.weapon)

        local refundedItem = self.character:getInventory():AddItem(universalRefundType)
        if refundedItem then
            sendAddItemToContainer(self.character:getInventory(), refundedItem)
        end

        if self.weapon and instanceof(self.weapon, "HandWeapon") then
            if removedPart then
                Underbarrel.HandleAttachmentRemoval(self.weapon, removedPart, self.character)
            end
            StatsFactory.ReapplyAllModifiers(self.weapon)
        end

        return true
    end

    _ISRemoveWeaponUpgrade_complete(self)

    if self.weapon and instanceof(self.weapon, "HandWeapon") then
        if removedPart then
            Underbarrel.HandleAttachmentRemoval(self.weapon, removedPart, self.character)
        end
        StatsFactory.ReapplyAllModifiers(self.weapon)
    end
end
