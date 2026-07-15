local Ammo = require("WeaponSystems/Utils/Ammo")
local Animations = require("WeaponSystems/Utils/Animations")
local RateOfFire = require('WeaponSystems/Utils/RateOfFire')
local Underbarrel = require("WeaponSystems/Utils/Underbarrel")
local ReloadAnim = require("WeaponSystems/Utils/ReloadAnim")
require("WeaponSystems/ReloadAnim/Props")
require("WeaponSystems/ReloadAnim/PartSwap")
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
    elseif command == "applyUnderbarrelMode" then
        local item = playerObj:getInventory():getItemWithIDRecursiv(args.itemId)
        if item and instanceof(item, "HandWeapon") then
            local currentState = Underbarrel.GetModeState(item)
            local targetIsUnderbarrel = args.isUnderbarrelMode == true
            if currentState.isUnderbarrelMode ~= targetIsUnderbarrel
                or currentState.underbarrelType ~= args.underbarrelType
                or currentState.modeSource ~= args.modeSource then
                Underbarrel.ReconcileModeState(
                    item,
                    playerObj,
                    targetIsUnderbarrel,
                    args.modeSource,
                    args.underbarrelType,
                    true
                )
            end
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
    elseif command == "reloadSprite" then
        -- Reload-animation framework: apply a reloading player's mid-reload sprite swap
        -- on this observer client.
        local targetPlayer = getPlayerByOnlineID(args.onlineID)
        if not targetPlayer then return end
        local weapon = targetPlayer:getInventory():getItemWithIDRecursiv(args.itemId)
        if not weapon or not instanceof(weapon, "HandWeapon") then return end
        if not args.sprite or args.sprite == "" then return end
        weapon:setWeaponSprite(args.sprite)
        targetPlayer:resetEquippedHandsModels()
    elseif command == "reloadProp" then
        -- Reload-animation framework: mirror a reloading player's mid-reload prop / part transfer on
        -- this observer. The hand/off-hand ITEM props are attached here too (not just via the engine
        -- packet), because that packet is proximity-limited and a distant observer never gets it.
        local targetPlayer = getPlayerByOnlineID(args.onlineID)
        if not targetPlayer then return end
        -- An observer has the remote player's EQUIPPED weapon but not necessarily their whole
        -- inventory, so prefer the primary hand item and fall back to a recursive lookup. Item props
        -- don't need the weapon (they attach to the character), so a nil weapon is fine for those;
        -- part transfers require it and applyRemotePropEvent guards on that.
        local weapon = targetPlayer:getPrimaryHandItem()
        if not instanceof(weapon, "HandWeapon") or weapon:getID() ~= args.itemId then
            weapon = targetPlayer:getInventory():getItemWithIDRecursiv(args.itemId)
        end
        if not instanceof(weapon, "HandWeapon") then
            weapon = nil
        end
        ReloadAnim.applyRemotePropEvent(targetPlayer, weapon, args.event, args.value)
    elseif command == "gwSetPart" then
        -- Reload-animation framework: mirror a reloading player's mid-reload gun-part swap on this
        -- observer client (gun-side only; no item involved).
        local targetPlayer = getPlayerByOnlineID(args.onlineID)
        if not targetPlayer then return end
        local weapon = targetPlayer:getPrimaryHandItem()
        if not instanceof(weapon, "HandWeapon") or weapon:getID() ~= args.itemId then
            weapon = targetPlayer:getInventory():getItemWithIDRecursiv(args.itemId)
        end
        if not weapon or not instanceof(weapon, "HandWeapon") then return end
        ReloadAnim.applyRemotePartSwapEvent(targetPlayer, weapon, args.partType, args.value)
    elseif command == "syncParts" then
        -- Reload-animation framework: mirror a player's reconciled steady-state parts (ensured parts
        -- like the ramrod + the ammo-keyed parts like flint/hammer) on this machine's copy of them.
        -- Reaches observers and the reloader alike.
        local targetPlayer = getPlayerByOnlineID(args.onlineID)
        if not targetPlayer then return end
        local weapon = targetPlayer:getPrimaryHandItem()
        if not instanceof(weapon, "HandWeapon") or weapon:getID() ~= args.itemId then
            weapon = targetPlayer:getInventory():getItemWithIDRecursiv(args.itemId)
        end
        if not weapon or not instanceof(weapon, "HandWeapon") then return end
        ReloadAnim.applyRemotePartState(targetPlayer, weapon, args.ammoParts, args.ensure)
    elseif command == "attachOwnerProp" then
        -- Reload-animation framework: the reloader attaches its own off-hand prop. The server cannot
        -- push an attached item to the local player, so it created + synced the item and told us its id.
        local playerObj = getSpecificPlayer(0)
        if not playerObj then return end
        ReloadAnim.applyOwnerProp(playerObj, args.itemId, args.location)
    end
end

Events.OnServerCommand.Add(Client.OnServerCommand)
Events.OnWeaponSwing.Add(Client.FiremodeSwitchCheck)

return Client
