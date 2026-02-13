require "MWA_Core"

function MWA_Utils.OnServerCommand(module, command, args)
    if module ~= "MWA" or not args then return end

    local playerObj = getSpecificPlayer(0)
    if not playerObj then return end

    if command == "applyAmmoProfile" then
        local item = playerObj:getInventory():getItemWithIDRecursiv(args.itemId)
        if item and instanceof(item, "HandWeapon") then
            local bulletType = args.bulletType
            local ammoEnum = MWA_Utils.ItemFullTypeToAmmoType and MWA_Utils.ItemFullTypeToAmmoType[bulletType]
            if ammoEnum then
                MWA_Utils.AmmoAdjustWeaponStats(item, bulletType, ammoEnum)
            end
        end
    elseif command == "applyMagazineAmmoProfile" then
        local item = playerObj:getInventory():getItemWithIDRecursiv(args.itemId)
        if item then
            local bulletType = args.bulletType
            local ammoEnum = MWA_Utils.ItemFullTypeToAmmoType and MWA_Utils.ItemFullTypeToAmmoType[bulletType]
            if ammoEnum then
                item:setAmmoType(ammoEnum)
            end
        end
    end
end

Events.OnServerCommand.Add(MWA_Utils.OnServerCommand)
