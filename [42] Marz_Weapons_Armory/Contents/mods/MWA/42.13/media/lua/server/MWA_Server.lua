require "MWA_Core"

function MWA_Utils.getWeaponById(player, itemId)
    if not player or not itemId then return nil end
    local item = player:getInventory():getItemById(itemId)
    if item and instanceof(item, "HandWeapon") then return item end
    return nil
end

function MWA_Utils.getItemById(player, itemId)
    if not player or not itemId then return nil end
    return player:getInventory():getItemById(itemId)
end

function MWA_Utils.OnClientCommand(module, command, player, args)
    if module ~= "MWA" then return end
    if not player or not args then return end

    if command == "ammoProfile" then
        local weapon = MWA_Utils.getWeaponById(player, args.itemId)
        if not weapon then return end

        local bulletType = args.bulletType
        local ammoEnum = MWA_Utils.ItemFullTypeToAmmoType and MWA_Utils.ItemFullTypeToAmmoType[bulletType]
        if not ammoEnum then return end

        if weapon:getAmmoType() == ammoEnum then return end

        MWA_Utils.AmmoAdjustWeaponStats(weapon, bulletType, ammoEnum)

        sendServerCommand(player, "MWA", "applyAmmoProfile", {
            itemId = weapon:getID(),
            bulletType = bulletType
        })
    elseif command == "magazineAmmoProfile" then
        local item = MWA_Utils.getItemById(player, args.itemId)
        if not item then return end

        local bulletType = args.bulletType
        local ammoEnum = MWA_Utils.ItemFullTypeToAmmoType and MWA_Utils.ItemFullTypeToAmmoType[bulletType]
        if not ammoEnum then return end

        if item:getAmmoType() == ammoEnum then return end

        item:setAmmoType(ammoEnum)

        sendServerCommand(player, "MWA", "applyMagazineAmmoProfile", {
            itemId = item:getID(),
            bulletType = bulletType
        })
    end
end

Events.OnClientCommand.Add(MWA_Utils.OnClientCommand)
