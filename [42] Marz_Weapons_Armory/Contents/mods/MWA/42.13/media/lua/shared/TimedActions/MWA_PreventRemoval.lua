require "TimedActions/ISRemoveWeaponUpgrade"

local ISRemoveWeaponUpgrade_completeHook = ISRemoveWeaponUpgrade.complete
function ISRemoveWeaponUpgrade:complete()
    local part = self.weapon:getWeaponPart(self.partType)
    if part:getPartType() == "Clip" then return end
    ISRemoveWeaponUpgrade_completeHook(self)
end
