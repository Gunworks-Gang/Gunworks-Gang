local MWA_Client = {}

local SWMG_Ammo = require "Utils/MWA_AmmoUtils.lua"

function MWA_Client.OnServerCommand(module, command, args)
    if module ~= "MWA" or not args then return end

    local playerObj = getSpecificPlayer(0)
    if not playerObj then return end

    if command == "applyAmmoProfile" then
        local item = playerObj:getInventory():getItemWithIDRecursiv(args.itemId)
        if item and instanceof(item, "HandWeapon") then
            local bulletType = args.bulletType
            local ammoEnum = SWMG_Ammo.ItemFullTypeToAmmoType and SWMG_Ammo.ItemFullTypeToAmmoType[bulletType]
            if ammoEnum then
                SWMG_Ammo.AmmoAdjustWeaponStats(item, bulletType, ammoEnum)
            end
        end
    elseif command == "applyMagazineAmmoProfile" then
        local item = playerObj:getInventory():getItemWithIDRecursiv(args.itemId)
        if item then
            local bulletType = args.bulletType
            local ammoEnum = SWMG_Ammo.ItemFullTypeToAmmoType and SWMG_Ammo.ItemFullTypeToAmmoType[bulletType]
            if ammoEnum then
                item:setAmmoType(ammoEnum)
            end
        end
    end
end

Events.OnServerCommand.Add(MWA_Client.OnServerCommand)
