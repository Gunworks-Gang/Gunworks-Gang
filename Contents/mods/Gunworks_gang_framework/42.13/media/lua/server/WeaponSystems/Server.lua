local Server = {}

local Ammo = require("WeaponSystems/Utils/Ammo")
local Bayonet = require("WeaponSystems/Utils/Bayonet")
local RateOfFire = require('WeaponSystems/Utils/RateOfFire')
local Underbarrel = require("WeaponSystems/Utils/Underbarrel")

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

function Server.getRecursiveWeaponById(player, itemId)
    if not player or not itemId then return nil end
    local item = player:getInventory():getItemWithIDRecursiv(itemId)
    if item and instanceof(item, "HandWeapon") then return item end
    return nil
end

local function BroadcastWeaponSync(player, weapon)
    if not player or not weapon then return end

    syncHandWeaponFields(player, weapon)

    local syncArgs = {
        onlineID = player:getOnlineID(),
        itemId = weapon:getID(),
    }
    local onlinePlayers = getOnlinePlayers()
    for i = 0, onlinePlayers:size() - 1 do
        sendServerCommand(onlinePlayers:get(i), "SWMG", "syncWeapon", syncArgs)
    end
end

local function SendUnderbarrelResponse(player, itemId, approved, weapon)
    if not player or not itemId then return end

    local state = weapon and Underbarrel.GetModeState(weapon) or {
        isUnderbarrelMode = false,
        underbarrelType = nil,
        modeSource = nil,
    }

    sendServerCommand(player, "SWMG", "applyUnderbarrelMode", {
        onlineID = player:getOnlineID(),
        itemId = itemId,
        approved = approved == true,
        isUnderbarrelMode = state.isUnderbarrelMode == true,
        underbarrelType = state.underbarrelType,
        modeSource = state.modeSource,
    })
end

function Server.OnClientCommand(module, command, player, args)
    if module ~= "SWMG" then return end
    if not player or not args then return end

    if command == "ammoProfile" then
        local weapon = Server.getWeaponById(player, args.itemId)
        if not weapon then return end

        local bulletType = args.bulletType
        local ammoEnum = Ammo.GetEnumForBullet(bulletType)
        if not ammoEnum then return end

        if weapon:getAmmoType() == ammoEnum then return end

        Ammo.AmmoAdjustWeaponStats(weapon, bulletType, ammoEnum)

        sendServerCommand(player, "SWMG", "applyAmmoProfile", {
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
            sendServerCommand(player, "SWMG", "syncAmmoList", {
                itemId = weapon:getID(),
                ammoList = weapon:getModData().AmmoList
            })
        end
    elseif command == "clearAmmoList" then
        local weapon = Server.getWeaponById(player, args.itemId)
        if not weapon then return end
        weapon:getModData().AmmoList = nil
        sendServerCommand(player, "SWMG", "syncAmmoList", {
            itemId = weapon:getID(),
            ammoList = nil
        })
    elseif command == "syncWeapon" then
        local weapon = player:getInventory():getItemWithIDRecursiv(args.itemId)
        if not weapon or not instanceof(weapon, "HandWeapon") then return end
        -- Apply modData server-side so syncHandWeaponFields broadcasts the current state
        local modData = weapon:getModData()
        if args.StockFolded ~= nil then modData.StockFolded = args.StockFolded end
        if args.BipodDeployed ~= nil then modData.BipodDeployed = args.BipodDeployed end
        if args.GW_BayonetDeployed ~= nil then modData.GW_BayonetDeployed = args.GW_BayonetDeployed end
        if args.GW_IntegratedUnderbarrelDeployed ~= nil then modData.GW_IntegratedUnderbarrelDeployed = args.GW_IntegratedUnderbarrelDeployed end
        -- Native packet: syncs all WeaponParts + stats + modData, triggers resetEquippedHandsModels on other clients
        syncHandWeaponFields(player, weapon)
        -- Lua broadcast: needed for models-mode sprite changes not covered by the native packet
        local onlinePlayers = getOnlinePlayers()
        for i = 0, onlinePlayers:size() - 1 do
            sendServerCommand(onlinePlayers:get(i), "SWMG", "syncWeapon", args)
        end
    elseif command == "bayonetHit" then
        local weapon = Server.getRecursiveWeaponById(player, args.itemId)
        if not weapon then return end
        if player:getPrimaryHandItem() ~= weapon and player:getSecondaryHandItem() ~= weapon then return end
        if not Bayonet.IsBayonetDeployed(weapon) then return end

        Bayonet.ProcessMultiplayerHit(player, weapon)
    elseif command == "underbarrelMode" then
        local weapon = Server.getRecursiveWeaponById(player, args.itemId)
        if not weapon then
            SendUnderbarrelResponse(player, args.itemId, false, nil)
            return
        end

        if player:getPrimaryHandItem() ~= weapon then
            SendUnderbarrelResponse(player, args.itemId, false, weapon)
            return
        end

        local approved = false

        if args.action == Underbarrel.ACTION_ENTER_ATTACHMENT then
            local entry = Underbarrel.GetAttachmentEntry(weapon)
            if entry
                and entry.type == args.underbarrelType
                and not Underbarrel.IsWeaponInUnderbarrelMode(weapon) then
                approved = Underbarrel.ReconcileModeState(
                    weapon,
                    player,
                    true,
                    Underbarrel.MODE_SOURCE_ATTACHMENT,
                    entry.type,
                    true
                )
            end
        elseif args.action == Underbarrel.ACTION_ENTER_INTEGRATED then
            local entry = Underbarrel.GetIntegratedEntry(weapon)
            if entry
                and entry.type == args.underbarrelType
                and Underbarrel.CanSwapToIntegratedUnderbarrel(weapon) then
                approved = Underbarrel.ReconcileModeState(
                    weapon,
                    player,
                    true,
                    Underbarrel.MODE_SOURCE_INTEGRATED,
                    entry.type,
                    true
                )
            end
        elseif args.action == Underbarrel.ACTION_RESTORE then
            local state = Underbarrel.GetModeState(weapon)
            if state.isUnderbarrelMode
                and (not args.underbarrelType or state.underbarrelType == args.underbarrelType)
                and (not args.modeSource or state.modeSource == args.modeSource) then
                approved = Underbarrel.ReconcileModeState(weapon, player, false, nil, nil, true)
            end
        end

        SendUnderbarrelResponse(player, args.itemId, approved, weapon)
        if approved then
            BroadcastWeaponSync(player, weapon)
        end
    elseif command == "magazineAmmoProfile" then
        local item = Server.getItemById(player, args.itemId)
        if not item then return end

        local bulletType = args.bulletType
        local ammoEnum = Ammo.GetEnumForBullet(bulletType)
        if not ammoEnum then return end

        if item:getAmmoType() == ammoEnum then return end

        item:setAmmoType(ammoEnum)

        sendServerCommand(player, "SWMG", "applyMagazineAmmoProfile", {
            itemId = item:getID(),
            bulletType = bulletType
        })
    elseif command == "firemode" then
        local weapon = RateOfFire.GetWeaponById(player, args.itemId)
        if not weapon then return end

        if args.firemode then weapon:setFireMode(args.firemode) end
        RateOfFire.RecoilDelayAdjuster(player, weapon)

        sendServerCommand(player, "SWMG", "applyWeapon", {
            itemId = weapon:getID(),
            firemode = weapon:getFireMode(),
            recoilDelay = weapon:getRecoilDelay()
        })
    end
end

Events.OnClientCommand.Add(Server.OnClientCommand)
