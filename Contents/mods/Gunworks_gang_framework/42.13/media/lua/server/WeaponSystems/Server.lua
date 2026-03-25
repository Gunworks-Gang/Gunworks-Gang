local Server = {}

local Ammo = require("WeaponSystems/Utils/AmmoUtils")

function Server.getWeaponById(player, itemId)
    if not player or not itemId then return nil end
    local item = player:getInventory():getItemById(itemId)
    if item and instanceof(item, "HandWeapon") then return item end
    return nil
end

function Server.getItemById(player, itemId)
    if not player or not itemId then return nil end
    return player:getInventory():getItemById(itemId)
end

function Server.OnClientCommand(module, command, player, args)
    if module ~= "MWA" then return end
    if not player or not args then return end

    if command == "ammoProfile" then
        local weapon = Server.getWeaponById(player, args.itemId)
        if not weapon then return end

        local bulletType = args.bulletType
        local ammoEnum = Ammo.GetEnumForBullet(bulletType)
        if not ammoEnum then return end

        if weapon:getAmmoType() == ammoEnum then return end

        Ammo.AmmoAdjustWeaponStats(weapon, bulletType, ammoEnum)

        sendServerCommand(player, "MWA", "applyAmmoProfile", {
            itemId = weapon:getID(),
            bulletType = bulletType
        })
    elseif command == "consumeRound" then
        local weapon = Server.getWeaponById(player, args.itemId)
        if not weapon then return end

        local ammoList = weapon:getModData().AmmoList
        if ammoList and #ammoList > 0 then
            ammoList[#ammoList] = nil
            if #ammoList == 0 then
                weapon:getModData().AmmoList = nil
            end
            sendServerCommand(player, "MWA", "syncAmmoList", {
                itemId = weapon:getID(),
                ammoList = weapon:getModData().AmmoList
            })
        end
    elseif command == "magazineAmmoProfile" then
        local item = Server.getItemById(player, args.itemId)
        if not item then return end

        local bulletType = args.bulletType
        local ammoEnum = Ammo.GetEnumForBullet(bulletType)
        if not ammoEnum then return end

        if item:getAmmoType() == ammoEnum then return end

        item:setAmmoType(ammoEnum)

        sendServerCommand(player, "MWA", "applyMagazineAmmoProfile", {
            itemId = item:getID(),
            bulletType = bulletType
        })
    end
end

Events.OnClientCommand.Add(Server.OnClientCommand)
