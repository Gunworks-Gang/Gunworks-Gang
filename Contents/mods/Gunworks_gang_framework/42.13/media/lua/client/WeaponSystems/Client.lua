local Ammo = require("WeaponSystems/Utils/AmmoUtils")
local Animations = require("WeaponSystems/Utils/Animations")
local Client = {}

function Client.OnServerCommand(module, command, args)
    if module ~= "SWMG" or not args then return end

    local playerObj = getSpecificPlayer(0)
    if not playerObj then return end

    if command == "applyAmmoProfile" then
        local item = playerObj:getInventory():getItemWithIDRecursiv(args.itemId)
        if item and instanceof(item, "HandWeapon") then
            local bulletType = args.bulletType
            local ammoEnum = Ammo.GetEnumForBullet(bulletType)
            if ammoEnum then
                Ammo.AmmoAdjustWeaponStats(item, bulletType, ammoEnum)
            end
        end
    elseif command == "applyMagazineAmmoProfile" then
        local item = playerObj:getInventory():getItemWithIDRecursiv(args.itemId)
        if item then
            local bulletType = args.bulletType
            local ammoEnum = Ammo.GetEnumForBullet(bulletType)
            if ammoEnum then
                item:setAmmoType(ammoEnum)
            end
        end
    elseif command == "syncAmmoList" then
        local item = playerObj:getInventory():getItemWithIDRecursiv(args.itemId)
        if item then
            item:getModData().AmmoList = args.ammoList
        end
    elseif command == "syncWeapon" then
        local targetPlayer = getPlayerByOnlineID(args.onlineID)
        if not targetPlayer then return end
        local weapon = targetPlayer:getInventory():getItemWithIDRecursiv(args.itemId)
        if not weapon or not instanceof(weapon, "HandWeapon") then return end
        Animations.CallSyncHandWeaponFields(targetPlayer, weapon)
    end
end

Events.OnServerCommand.Add(Client.OnServerCommand)
