local AttachmentsDurability = require("WeaponSystems/Utils/AttachmentsDurability")

local function onShoot(player, weapon)
    if isClient() or not weapon:isRanged() then return end
    AttachmentsDurability.RollConditionLowering(player, weapon)
end

Events.OnWeaponSwingHitPoint.Add(onShoot)
