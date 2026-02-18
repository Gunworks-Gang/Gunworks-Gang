local MWA_Server = {}

local SWMG_Ammo = require "Utils/MWA_AmmoUtils.lua"

function MWA_Server.getWeaponById(player, itemId)
    if not player or not itemId then return nil end
    local item = player:getInventory():getItemById(itemId)
    if item and instanceof(item, "HandWeapon") then return item end
    return nil
end

function MWA_Server.getItemById(player, itemId)
    if not player or not itemId then return nil end
    return player:getInventory():getItemById(itemId)
end

function MWA_Server.OnClientCommand(module, command, player, args)
    if module ~= "MWA" then return end
    if not player or not args then return end

    if command == "ammoProfile" then
        local weapon = MWA_Server.getWeaponById(player, args.itemId)
        if not weapon then return end

        local bulletType = args.bulletType
        local ammoEnum = SWMG_Ammo.ItemFullTypeToAmmoType and SWMG_Ammo.ItemFullTypeToAmmoType[bulletType]
        if not ammoEnum then return end

        if weapon:getAmmoType() == ammoEnum then return end

        SWMG_Ammo.AmmoAdjustWeaponStats(weapon, bulletType, ammoEnum)

        sendServerCommand(player, "MWA", "applyAmmoProfile", {
            itemId = weapon:getID(),
            bulletType = bulletType
        })
    elseif command == "magazineAmmoProfile" then
        local item = MWA_Server.getItemById(player, args.itemId)
        if not item then return end

        local bulletType = args.bulletType
        local ammoEnum = SWMG_Ammo.ItemFullTypeToAmmoType and SWMG_Ammo.ItemFullTypeToAmmoType[bulletType]
        if not ammoEnum then return end

        if item:getAmmoType() == ammoEnum then return end

        item:setAmmoType(ammoEnum)

        sendServerCommand(player, "MWA", "applyMagazineAmmoProfile", {
            itemId = item:getID(),
            bulletType = bulletType
        })
    end
end

Events.OnClientCommand.Add(MWA_Server.OnClientCommand)
