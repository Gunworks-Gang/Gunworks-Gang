require "TimedActions/ISUpgradeWeapon"
require "TimedActions/ISRemoveWeaponUpgrade"

local StatsFactory              = require("WeaponSystems/Utils/StatsFactory")
local Underbarrel               = require("WeaponSystems/Utils/UnderbarrelUtils")

-------------------------------------------------
-- After a weapon part is attached or removed via the
-- vanilla upgrade system, reapply all modifier layers
-- so custom-stats attachments take effect immediately.
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
    -- Capture the part before the vanilla action detaches and pockets it.
    local removedPart = nil
    if self.weapon and instanceof(self.weapon, "HandWeapon") and self.partType then
        removedPart = self.weapon:getWeaponPart(self.partType)
    end

    _ISRemoveWeaponUpgrade_complete(self)

    if self.weapon and instanceof(self.weapon, "HandWeapon") then
        -- Handle underbarrel attachment removal: restore main-weapon mode if active,
        -- return any loaded underbarrel ammo, and clear per-attachment modData state.
        if removedPart then
            Underbarrel.HandleAttachmentRemoval(self.weapon, removedPart, self.character)
        end
        StatsFactory.ReapplyAllModifiers(self.weapon)
    end
end
