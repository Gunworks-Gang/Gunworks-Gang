require "TimedActions/ISUpgradeWeapon"
require "TimedActions/ISRemoveWeaponUpgrade"

local StatsFactory = require("WeaponSystems/Utils/StatsFactory")

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
    _ISRemoveWeaponUpgrade_complete(self)
    if self.weapon and instanceof(self.weapon, "HandWeapon") then
        StatsFactory.ReapplyAllModifiers(self.weapon)
    end
end
