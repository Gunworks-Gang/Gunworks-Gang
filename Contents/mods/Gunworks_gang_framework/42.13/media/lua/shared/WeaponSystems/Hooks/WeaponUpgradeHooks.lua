require("TimedActions/ISUpgradeWeapon")
require("TimedActions/ISRemoveWeaponUpgrade")

local StatsFactory              = require("WeaponSystems/Utils/StatsFactory")
local Underbarrel               = require("WeaponSystems/Utils/Underbarrel")

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
