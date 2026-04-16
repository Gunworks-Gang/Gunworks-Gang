local Ammo = require("WeaponSystems/Utils/AmmoUtils")
local Animations = require("WeaponSystems/Utils/Animations")
local RateOfFire = require('WeaponSystems/Utils/RateOfFire')
local Client = {}

function Client.getFiremodeMenuKey(firemode)
    return firemode:match("^Real(.+)") or firemode
end

function Client.isFiremodeStandard(firemode)
    if firemode == "Auto" or firemode == "Burst" or firemode == "Single" then
        return true
    else
        return false
    end
end

function Client.OnPlayerUpdateFiremode(playerObj, weapon, newfiremode)
    if not isClient() then
        RateOfFire.RecoilDelayAdjuster(playerObj, weapon)
        return
    end

    if not weapon then return end

    sendClientCommand(playerObj, "SWMG", "firemode", {
        itemId = weapon:getID(),
        firemode = newfiremode
    })
end

function Client.FiremodeSwitchCheck(playerObj, weapon)
    if not playerObj or not weapon or not instanceof(weapon, "HandWeapon") or not weapon:isRanged() then return end
    local newfiremode = weapon:getFireMode()
    if Client.isFiremodeStandard(newfiremode) then
        newfiremode = "Real" .. newfiremode
        weapon:setFireMode(newfiremode)
        playerObj:setFireMode(newfiremode)
        Client.OnPlayerUpdateFiremode(playerObj, weapon, newfiremode)
    end
end

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
    elseif command == "applyWeapon" then
        local playerObj = getSpecificPlayer(0)
        if not playerObj then return end

        local item = playerObj:getInventory():getItemWithIDRecursiv(args.itemId)
        if item and instanceof(item, "HandWeapon") then
            if args.firemode then item:setFireMode(args.firemode) end
            if args.recoilDelay then item:setRecoilDelay(args.recoilDelay) end
        end
    end
end

Events.OnServerCommand.Add(Client.OnServerCommand)
Events.OnWeaponSwing.Add(Client.FiremodeSwitchCheck)

return Client
