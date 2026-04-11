local Ammo = require("WeaponSystems/Utils/AmmoUtils")
local Animations = require("AnimatedFiring/Utils/Animations")
local FoldingStock = require("WeaponSystems/Utils/FoldingStockUtils")
local FoldingBipod = require("WeaponSystems/Utils/FoldingBipodUtils")
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
        -- Models-mode sprite changes are not covered by the native syncHandWeaponFields packet
        if args.StockFolded ~= nil then
            local entry = FoldingStock.WeaponsWithFoldableStock[weapon:getFullType()]
            if entry and entry.models then
                weapon:setWeaponSprite(args.StockFolded and entry.models.folded or entry.models.unfolded)
            end
        end
        if args.BipodDeployed ~= nil then
            local entry = FoldingBipod.WeaponsWithFoldableBipod[weapon:getFullType()]
            if entry and entry.models then
                weapon:setWeaponSprite(args.BipodDeployed and entry.models.deployed or entry.models.folded)
            end
        end
        targetPlayer:resetEquippedHandsModels()
    elseif command == "slideState" then
        -- Apply slide animation on behalf of another player
        if args.onlineID == playerObj:getOnlineID() then return end
        local targetPlayer = getPlayerByOnlineID(args.onlineID)
        if not targetPlayer then return end
        local weapon = targetPlayer:getPrimaryHandItem()
        if not weapon or not instanceof(weapon, "HandWeapon") then return end
        Animations.CallAnimationFunction(weapon, args.open)
        targetPlayer:resetEquippedHandsModels()
    end
end

Events.OnServerCommand.Add(Client.OnServerCommand)
