local Server = {}

local Ammo = require("WeaponSystems/Utils/Ammo")
local Bayonet = require("WeaponSystems/Utils/Bayonet")
local RateOfFire = require('WeaponSystems/Utils/RateOfFire')
local Underbarrel = require("WeaponSystems/Utils/Underbarrel")
local ReloadAnim = require("WeaponSystems/Utils/ReloadAnim")
require("WeaponSystems/ReloadAnim/Props")
require("WeaponSystems/ReloadAnim/PartSwap")

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
        -- Native packet: syncs all WeaponParts + stats + modData, triggers resetEquippedHandsModels on other clients
        syncHandWeaponFields(player, weapon)
        -- Lua broadcast: needed for models-mode sprite changes not covered by the native packet
        local onlinePlayers = getOnlinePlayers()
        for i = 0, onlinePlayers:size() - 1 do
            sendServerCommand(onlinePlayers:get(i), "SWMG", "syncWeapon", args)
        end
    elseif command == "reloadSprite" then
        -- Reload-animation framework: a client swapped a weapon sprite mid-reload; apply
        -- it on the server (so syncHandWeaponFields broadcasts it) and relay to observers.
        local weapon = player:getInventory():getItemWithIDRecursiv(args.itemId)
        if not weapon or not instanceof(weapon, "HandWeapon") then return end
        if not args.sprite or args.sprite == "" then return end
        weapon:setWeaponSprite(args.sprite)
        player:resetEquippedHandsModels()
        syncHandWeaponFields(player, weapon)
        local onlinePlayers = getOnlinePlayers()
        for i = 0, onlinePlayers:size() - 1 do
            sendServerCommand(onlinePlayers:get(i), "SWMG", "reloadSprite", {
                onlineID = player:getOnlineID(),
                itemId = weapon:getID(),
                sprite = args.sprite,
            })
        end
    elseif command == "reloadProp" then
        -- Reload-animation framework: a reloading client hit a prop / part-transfer marker. The prop
        -- is a real item, so only we may create it; the client is trusted for nothing but the intent.
        if not ReloadAnim.isPropEvent(args.event) then return end

        -- NB: PerformingAction is NOT synced to the dedicated server for a remote player (its
        -- IsoPlayer.update returns before the variable-carrying path), so we cannot gate on an active
        -- reload here. Security instead rests on: the player holds the named registered gun, and the
        -- value is in that gun's whitelist. The props are cosmetic, so "any time while holding the
        -- gun" is an acceptable window.
        if args.event == ReloadAnim.PROP_SET_EVENT and (not args.value or args.value == "") then
            ReloadAnim.applyPropEvent(player, nil, args.event, "")
            -- The engine's attached-item packet is a no-op on the local player, so the reloader must
            -- attach/clear it themselves (the server's item is already synced to their inventory).
            sendServerCommand(player, "SWMG", "attachOwnerProp", {})
            -- Observers attach the off-hand prop via the reloadProp relay (the engine packet is
            -- proximity-limited), so relay the clear to them too or a distant observer keeps it.
            local onlinePlayers = getOnlinePlayers()
            for i = 0, onlinePlayers:size() - 1 do
                sendServerCommand(onlinePlayers:get(i), "SWMG", "reloadProp", {
                    onlineID = player:getOnlineID(),
                    itemId = 0,
                    event = args.event,
                    value = "",
                })
            end
            return
        end

        local gun = player:getPrimaryHandItem()
        if not instanceof(gun, "HandWeapon") then return end
        if args.gunId and gun:getID() ~= args.gunId then return end

        local handler = ReloadAnim.GetHandlerForGun(gun)
        if not handler then return end
        if not ReloadAnim.isAllowedPropValue(handler, args.value) then return end

        ReloadAnim.applyPropEvent(player, gun, args.event, args.value)

        -- The engine's attached-item packet (GameCharacterAttachedItemPacket.processClient) ignores the
        -- local player, so tell the reloader to attach the prop itself; the item the server created is
        -- already synced to their inventory. Resolve the slot the event drove (right-hand vs off-hand).
        local propLocation = (args.event == ReloadAnim.PROP_SET_HAND_EVENT)
            and ReloadAnim.RELOAD_HAND_ATTACH_LOCATION
            or ReloadAnim.RELOAD_MAGAZINE_ATTACH_LOCATION
        local propItem = player:getAttachedItem(propLocation)
        sendServerCommand(player, "SWMG", "attachOwnerProp",
            { itemId = propItem and propItem:getID() or nil, location = propLocation })

        -- syncHandWeaponFields only reaches the weapon's owner, so relay the part side to everyone.
        local onlinePlayers = getOnlinePlayers()
        for i = 0, onlinePlayers:size() - 1 do
            sendServerCommand(onlinePlayers:get(i), "SWMG", "reloadProp", {
                onlineID = player:getOnlineID(),
                itemId = gun:getID(),
                event = args.event,
                value = args.value,
            })
        end
    elseif command == "gwSetPart" then
        -- Reload-animation framework: a reloading client hit a gwSetPart marker (a gun-side cosmetic
        -- part swap). Same trust model as reloadProp: the swap is cosmetic (no item is created), so
        -- security rests on the player holding the named gun and the value resolving to a WeaponPart.
        local gun = player:getPrimaryHandItem()
        if not instanceof(gun, "HandWeapon") then return end
        if args.gunId and gun:getID() ~= args.gunId then return end
        if not ReloadAnim.isAllowedPartValue(gun, args.partType, args.value) then return end

        ReloadAnim.applyPartSwapEvent(player, gun, args.partType, args.value)

        -- syncHandWeaponFields only reaches the weapon's owner, so relay the swap to everyone.
        local onlinePlayers = getOnlinePlayers()
        for i = 0, onlinePlayers:size() - 1 do
            sendServerCommand(onlinePlayers:get(i), "SWMG", "gwSetPart", {
                onlineID = player:getOnlineID(),
                itemId = gun:getID(),
                partType = args.partType,
                value = args.value,
            })
        end
    elseif command == "reconcileParts" then
        -- Reload-animation framework: a client asks the server to reconcile its gun's persistent
        -- cosmetic parts. The dedicated server has no per-player tick to self-reconcile, so the client
        -- is the trigger; the server recomputes the desired parts from its OWN ammo count (never trusts
        -- a client part list), applies them, syncs to the owner, and relays to observers.
        if player:getVariableString("PerformingAction") == "Reload" then return end

        local gun = player:getPrimaryHandItem()
        if not instanceof(gun, "HandWeapon") then return end
        if args.gunId and gun:getID() ~= args.gunId then return end

        local applied = ReloadAnim.reconcileServerParts(player, gun)
        if not applied then return end

        syncHandWeaponFields(player, gun)

        local onlinePlayers = getOnlinePlayers()
        for i = 0, onlinePlayers:size() - 1 do
            sendServerCommand(onlinePlayers:get(i), "SWMG", "syncParts", {
                onlineID = player:getOnlineID(),
                itemId = gun:getID(),
                ammoParts = applied.ammoParts,
                ensure = applied.ensure,
            })
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
