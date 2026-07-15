require('TimedActions/ISReloadWeaponAction')
require('TimedActions/ISLoadBulletsInMagazine')
require('TimedActions/ISUnloadBulletsFromMagazine')
require("TimedActions/ISInsertMagazine")
require("TimedActions/ISEjectMagazine")
require("TimedActions/ISRackFirearm")

local Magazine = require("WeaponSystems/Utils/Magazine")
local SpeedLoader = require("WeaponSystems/Utils/SpeedLoader")
local Ammo = require("WeaponSystems/Utils/Ammo")
local Bayonet = require("WeaponSystems/Utils/Bayonet")
local Underbarrel = require("WeaponSystems/Utils/Underbarrel")
local OrdnanceFactory = require("ExplosivesSystems/OrdnanceFactory")
local RateOfFire = require("WeaponSystems/Utils/RateOfFire")
local ReloadAnim = require("WeaponSystems/Utils/ReloadAnim")

-------------------------------------------------
-- Multi-item reload: a gun whose reload handler declares `consumes` requires those extra items
-- (a paper powder charge, a percussion cap, ...) once PER ROUND, on top of the valued bullet the
-- gun's AmmoType names. A normal item is destroyed whole; a DRAINABLE (e.g. a tin of percussion
-- caps) is drained one use instead, so one pack lasts many reloads. All consumption is
-- server-authoritative (server/SP only); MP clients never consume here.
-------------------------------------------------
local function gwHasAllConsumeItems(character, consumes)
    local inv = character:getInventory()
    for i = 1, #consumes do
        -- getSomeTypeRecurse returns item instances (a drainable pack is one instance, and a
        -- depleted one has already been removed), so a non-empty result = a usable item on hand.
        local items = inv:getSomeTypeRecurse(consumes[i], 1)
        if not items or items:isEmpty() then
            return false
        end
    end
    return true
end

local function gwConsumeReloadItems(character, consumes)
    local inv = character:getInventory()
    for i = 1, #consumes do
        local items = inv:getSomeTypeRecurse(consumes[i], 1)
        if items and not items:isEmpty() then
            local item = items:get(0)
            if instanceof(item, "DrainableComboItem") then
                -- A tin/pack (e.g. percussion caps): drain a single use rather than destroying the
                -- whole pack. Use() decrements the pack and auto-removes it once depleted.
                item:Use(false, false, isServer())
            else
                inv:Remove(item)
                sendRemoveItemFromContainer(inv, item)
            end
        end
    end
end

-------------------------------------------------
-- BeginAutomaticReload (MagazineProfile + SpeedLoader support)
-------------------------------------------------
local ISReloadWeaponAction_BeginAutomaticReload_Original = ISReloadWeaponAction.BeginAutomaticReload
local function ReloadBestMagazineForGun(playerObj, gun)
    local magazine = gun:getBestMagazine(playerObj)
    local ammoCount = Magazine.reloadMagazine(playerObj, magazine)
    if not magazine or ammoCount == 0 then
        return
    end
    ISTimedActionQueue.add(ISInsertMagazine:new(playerObj, gun, magazine))
end

local function BeginAutomaticSpeedLoaderReload(playerObj, gun)
    if gun:getCurrentAmmoCount() > 0 then
        return false
    end

    if gun:haveChamber() and gun:isRoundChambered() then
        return false
    end

    if gun:isJammed() then
        return false
    end

    local speedLoader = SpeedLoader.GetBestSpeedLoaderForGun(playerObj, gun)

    if not speedLoader then
        return false
    end

    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, speedLoader)
    ISTimedActionQueue.add(ISInsertMagazine:new(playerObj, gun, speedLoader))
    return true
end

ISReloadWeaponAction.BeginAutomaticReload = function(playerObj, gun)
    if gun and Underbarrel.IsWeaponInUnderbarrelMode(gun) then
        ISReloadWeaponAction_BeginAutomaticReload_Original(playerObj, gun)
        return
    end

    if Magazine.GetProfileForGun(gun) then
        local magazine = Magazine.getBestMagazineForGun(playerObj, gun)
        local hasMagazine = gun:isContainsClip()
        if hasMagazine then
            ISTimedActionQueue.add(ISEjectMagazine:new(playerObj, gun))
            if magazine and magazine:getCurrentAmmoCount() > 0 then
                ISInventoryPaneContextMenu.transferIfNeeded(playerObj, magazine)
                ISTimedActionQueue.add(ISInsertMagazine:new(playerObj, gun, magazine))
                return
            end
            ISTimedActionQueue.queueActions(playerObj, Magazine.ReloadBestMagazineFromList, gun)
            return
        end
        if not magazine then return end
        if magazine:getCurrentAmmoCount() > 0 then
            ISInventoryPaneContextMenu.transferIfNeeded(playerObj, magazine)
            ISTimedActionQueue.add(ISInsertMagazine:new(playerObj, gun, magazine))
            return
        end
        local ammoCount = Magazine.reloadMagazine(playerObj, magazine)
        if ammoCount > 0 or not hasMagazine then
            ISTimedActionQueue.add(ISInsertMagazine:new(playerObj, gun, magazine))
        end
        return
    end

    if SpeedLoader.IsRegisteredGun(gun) and BeginAutomaticSpeedLoaderReload(playerObj, gun) then
        return
    end

    if gun:getMagazineType() then
        local magazine = gun:getBestMagazine(playerObj)
        local hasMagazine = gun:isContainsClip()
        if hasMagazine then
            ISTimedActionQueue.add(ISEjectMagazine:new(playerObj, gun))
            if magazine and magazine:getCurrentAmmoCount() > 0 then
                ISInventoryPaneContextMenu.transferIfNeeded(playerObj, magazine)
                ISTimedActionQueue.add(ISInsertMagazine:new(playerObj, gun, magazine))
                return
            end
            ISTimedActionQueue.queueActions(playerObj, ReloadBestMagazineForGun, gun)
            return
        end
        if not magazine then return end
        if magazine:getCurrentAmmoCount() > 0 then
            ISInventoryPaneContextMenu.transferIfNeeded(playerObj, magazine)
            ISTimedActionQueue.add(ISInsertMagazine:new(playerObj, gun, magazine))
            return
        end
        local ammoCount = Magazine.reloadMagazine(playerObj, magazine)
        if ammoCount > 0 or not hasMagazine then
            ISTimedActionQueue.add(ISInsertMagazine:new(playerObj, gun, magazine))
        end
        return
    end

    -- Multi-item reload: guns that consume extra items per round (powder charge, cap) must run
    -- through the AmmoList override path so per-round consumption + capping happen in loadAmmo.
    -- Route them here regardless of whether the chosen bullet matches the currently-loaded type.
    local gwConsume = ReloadAnim.GetConsumeItemsForGun(gun)
    if gwConsume then
        if gun:getCurrentAmmoCount() >= gun:getMaxAmmo() or gun:isJammed() then
            return
        end
        if not gwHasAllConsumeItems(playerObj, gwConsume) then
            return
        end
        local reloadAmmoType = Ammo.GetAutomaticReloadAmmoType(playerObj, gun)
        if not reloadAmmoType then
            local at = gun:getAmmoType()
            reloadAmmoType = at and at:getItemKey()
        end
        if not reloadAmmoType then
            return
        end
        local ammoCount = ISInventoryPaneContextMenu.transferBullets(
            playerObj, reloadAmmoType, gun:getCurrentAmmoCount(), gun:getMaxAmmo())
        if ammoCount == 0 then
            return
        end
        ISTimedActionQueue.add(ISReloadWeaponAction:new(playerObj, gun, nil, reloadAmmoType))
        return
    end

    local currentAmmoType = gun and gun:getAmmoType()
    local currentItemKey = currentAmmoType and currentAmmoType:getItemKey()
    local reloadAmmoType = Ammo.GetAutomaticReloadAmmoType(playerObj, gun)

    if not reloadAmmoType or reloadAmmoType == currentItemKey then
        ISReloadWeaponAction_BeginAutomaticReload_Original(playerObj, gun)
        return
    end

    if gun:getCurrentAmmoCount() >= gun:getMaxAmmo() then
        return
    end
    if gun:isJammed() then
        return
    end

    local ammoCount = ISInventoryPaneContextMenu.transferBullets(
        playerObj,
        reloadAmmoType,
        gun:getCurrentAmmoCount(),
        gun:getMaxAmmo()
    )
    if ammoCount == 0 then
        return
    end

    ISTimedActionQueue.add(ISReloadWeaponAction:new(playerObj, gun, nil, reloadAmmoType))
end

-------------------------------------------------
-- Rack: remove AmmoList[#], set ammo type from new last
-------------------------------------------------
local ISRackFirearm_removeBullet_original = ISRackFirearm.removeBullet
function ISRackFirearm:removeBullet()
    local ammoList = self.gun:getModData().AmmoList
    if ammoList and #ammoList > 0 then
        local bulletType = ammoList[#ammoList]
        local newBullet = instanceItem(bulletType)
        self.character:getInventory():AddItem(newBullet)
        sendAddItemToContainer(self.character:getInventory(), newBullet)
        ammoList[#ammoList] = nil
        if #ammoList == 0 then
            self.gun:getModData().AmmoList = nil
        end
        Ammo.SyncAmmoListToClient(self.character, self.gun)
    elseif self.gun:getAmmoType() then
        ISRackFirearm_removeBullet_original(self)
    end
    -- else: no AmmoList and no current ammo type. Vanilla removeBullet dereferences
    -- self.gun:getAmmoType():getItemKey(), so calling it with a nil ammo type (e.g. a
    -- chamber-less belt-fed gun racking right after a reload, before the ammo type is set)
    -- throws and aborts the rack mid-animEvent, leaving the character stuck in the raised-arms
    -- fallback pose. Skipping the give-back when there is no ammo type avoids that crash.
end

-------------------------------------------------
-- Insert Magazine: Transfer AmmoList mag -> gun
-------------------------------------------------
local ISInsertMagazine_start_original = ISInsertMagazine.start
function ISInsertMagazine:start()
    ISInsertMagazine_start_original(self)

    if self.magazine and SpeedLoader.IsCompatibleTypeForGun(self.magazine:getFullType(), self.gun) then
        ISReloadWeaponAction.ejectSpentRounds(self)
    end
end

local ISInsertMagazine_serverStart_original = ISInsertMagazine.serverStart
function ISInsertMagazine:serverStart()
    ISInsertMagazine_serverStart_original(self)

    if self.magazine and SpeedLoader.IsCompatibleTypeForGun(self.magazine:getFullType(), self.gun) then
        ISReloadWeaponAction.ejectSpentRounds(self)
    end
end

local ISInsertMagazine_loadAmmo_original = ISInsertMagazine.loadAmmo
function ISInsertMagazine:loadAmmo()
    if self.gun and Underbarrel.IsWeaponInUnderbarrelMode(self.gun) then
        return ISInsertMagazine_loadAmmo_original(self)
    end

    if self.magazine and SpeedLoader.IsCompatibleTypeForGun(self.magazine:getFullType(), self.gun) then
        local transferredCount = SpeedLoader.TransferAmmoToGun(self.gun, self.magazine)
        self.character:clearVariable("isLoading")

        if transferredCount > 0 then
            syncItemFields(self.character, self.magazine)
            syncHandWeaponFields(self.character, self.gun)
            Ammo.SyncAmmoListToClient(self.character, self.magazine)
            Ammo.SyncAmmoListToClient(self.character, self.gun)

            if not isServer() and not isClient()
                and self.gun:isRackAfterShoot()
                and not self.gun:isRoundChambered()
                and self.gun:getCurrentAmmoCount() >= self.gun:getAmmoPerShoot() then
                ISTimedActionQueue.addAfter(self, ISRackFirearm:new(self.character, self.gun))
            end
        end

        return
    end

    local magazineInstance = instanceItem(self.magazine:getFullType())
    if self.magazine then
        if self.gun.setMagazineType then
            self.gun:setMagazineType(self.magazine:getFullType())
            self.gun:setMaxAmmo(magazineInstance:getMaxAmmo())
        end
        Magazine.SaveMagazineType(self.gun, self.magazine:getFullType())

        local magList = self.magazine:getModData().AmmoList
        if magList and #magList > 0 then
            local gunModData = self.gun:getModData()

            if self.gun:isRoundChambered() and gunModData.AmmoList and #gunModData.AmmoList > 0 then
                local chamberedType = gunModData.AmmoList[#gunModData.AmmoList]
                local merged = Ammo.CopyAmmoList(magList)
                merged[#merged + 1] = chamberedType
                gunModData.AmmoList = merged
            else
                gunModData.AmmoList = Ammo.CopyAmmoList(magList)
            end

            self.magazine:getModData().AmmoList = nil
        end
        Ammo.SyncAmmoListToClient(self.character, self.gun)
    end
    return ISInsertMagazine_loadAmmo_original(self)
end

-------------------------------------------------
-- Eject Magazine: Transfer AmmoList gun -> mag
-------------------------------------------------
local function getInventoryItemIdsByType(inventory, itemType)
    local ids = {}
    if not inventory or not itemType then
        return ids
    end

    local items = inventory:getAllTypeRecurse(itemType)
    if not items then
        return ids
    end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            ids[item:getID()] = true
        end
    end

    return ids
end

local function getNewInventoryItemByType(inventory, itemType, knownIds)
    if not inventory or not itemType then
        return nil
    end

    local items = inventory:getAllTypeRecurse(itemType)
    if not items then
        return nil
    end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and not knownIds[item:getID()] then
            return item
        end
    end

    return nil
end

local ISEjectMagazine_unloadAmmo_original = ISEjectMagazine.unloadAmmo
function ISEjectMagazine:unloadAmmo()
    if self.gun and Underbarrel.IsWeaponInUnderbarrelMode(self.gun) then
        return ISEjectMagazine_unloadAmmo_original(self)
    end

    local savedMagType = self._actualMagType or Magazine.GetMagazineType(self.gun)
    if not savedMagType then
        return ISEjectMagazine_unloadAmmo_original(self)
    end
    local magazineInstance = instanceItem(savedMagType)
    if not magazineInstance then
        return ISEjectMagazine_unloadAmmo_original(self)
    end
    local inventory = self.character and self.character:getInventory()
    local gunModData = self.gun:getModData()
    local gunList = gunModData.AmmoList

    local ammoListForMag = nil

    if gunList and #gunList > 0 then
        if self.gun:isRoundChambered() and #gunList > 1 then
            ammoListForMag = {}
            for i = 1, #gunList - 1 do
                ammoListForMag[#ammoListForMag + 1] = gunList[i]
            end
            gunModData.AmmoList = { gunList[#gunList] }
        elseif self.gun:isRoundChambered() and #gunList == 1 then
            gunModData.AmmoList = { gunList[#gunList] }
        else
            ammoListForMag = {}
            for i = 1, #gunList do
                ammoListForMag[i] = gunList[i]
            end
            gunModData.AmmoList = nil
        end
    else
        gunModData.AmmoList = nil
    end

    if self.gun:isContainsClip() and savedMagType then
        self.gun:setMagazineType(savedMagType)
        self.gun:setMaxAmmo(magazineInstance:getMaxAmmo())
    end

    local knownMagazineIds = nil
    if ammoListForMag and inventory then
        knownMagazineIds = getInventoryItemIdsByType(inventory, savedMagType)
    end

    ISEjectMagazine_unloadAmmo_original(self)

    if ammoListForMag and knownMagazineIds and inventory then
        local ejectedMag = getNewInventoryItemByType(inventory, savedMagType, knownMagazineIds)
        if ejectedMag then
            ejectedMag:getModData().AmmoList = ammoListForMag
            Ammo.SyncAmmoListToClient(self.character, ejectedMag)
        end
    end

    Ammo.SyncAmmoListToClient(self.character, self.gun)

    Magazine.ClearMagazineType(self.gun)
end

-------------------------------------------------
-- Load and Unload Bullets from Magazine update AmmoList
-------------------------------------------------

local ISLoadBulletsInMagazine_start_Original = ISLoadBulletsInMagazine.start
function ISLoadBulletsInMagazine:start()
    if not self.ammoTypeOverride then
        return ISLoadBulletsInMagazine_start_Original(self)
    end

    if not self.character:getInventory():containsWithModule(self.ammoTypeOverride) then
        self:forceStop()
        return
    end

    self.ammoCountStart = self.magazine:getCurrentAmmoCount()
    self.magazine:setJobDelta(0.0)
    self:setOverrideHandModels(nil, "GunMagazine")
    self:setActionAnim(CharacterActionAnims.InsertBullets)
    self:initVars()
    self.loadedThisLoop = false
    self.updateLoadBulletsTime = 0.0
    self.character:setVariable("UpdateLoadBulletsTime", 0.0)
end

local ISLoadBulletsInMagazine_animEvent_Original = ISLoadBulletsInMagazine.animEvent
function ISLoadBulletsInMagazine:animEvent(event, parameter)
    if event == 'InsertBullet' then
        if self.ammoTypeOverride then
            if self:isLoadFinished() then
                return
            end
            if self:isLocal() and self.loadedThisLoop then
                return
            end

            self.loadedThisLoop = true

            if not isClient() then
                local chance = 5
                local xp = 1
                if self.character:getPerkLevel(Perks.Reloading) < 5 then
                    chance = 2
                    xp = 4
                end
                if ZombRand(chance) == 0 then
                    addXp(self.character, Perks.Reloading, xp)
                end

                local removedBullet = self.character:getInventory():RemoveOneOf(self.ammoTypeOverride, true)
                if not removedBullet then
                    return
                end

                self.magazine:setCurrentAmmoCount(self.magazine:getCurrentAmmoCount() + 1)
                sendRemoveItemFromContainer(self.character:getInventory(), removedBullet)
                syncItemFields(self.character, self.magazine)

                local modData = self.magazine:getModData()
                modData.AmmoList = modData.AmmoList or {}
                modData.AmmoList[#modData.AmmoList + 1] = self.ammoTypeOverride
                Ammo.SyncAmmoListToClient(self.character, self.magazine)
            end

            return
        end

        if self:isLoadFinished() then
            return ISLoadBulletsInMagazine_animEvent_Original(self, event, parameter)
        end
        if self:isLocal() and self.loadedThisLoop then
            return ISLoadBulletsInMagazine_animEvent_Original(self, event, parameter)
        end

        if not isClient() then
            local modData = self.magazine:getModData()
            modData.AmmoList = modData.AmmoList or {}

            local bulletType =
                (self.ammo and self.ammo.getFullType and self.ammo:getFullType())
                or (self.magazine:getAmmoType() and self.magazine:getAmmoType():getItemKey())

            modData.AmmoList[#modData.AmmoList + 1] = bulletType
            Ammo.SyncAmmoListToClient(self.character, self.magazine)
        end
    end
    ISLoadBulletsInMagazine_animEvent_Original(self, event, parameter)
end

local ISUnloadBulletsFromMagazine_animEvent_Original = ISUnloadBulletsFromMagazine.animEvent
function ISUnloadBulletsFromMagazine:animEvent(event, parameter)
    if event == "RemoveBullet" or event == "removeBullet" then
        local mag = self.magazine
        if mag and not isClient() then
            local ammoList = mag:getModData().AmmoList
            if ammoList and #ammoList > 0 and mag:getCurrentAmmoCount() > 0 then
                local bulletType = ammoList[#ammoList]
                ammoList[#ammoList] = nil

                if not bulletType then
                    bulletType = mag:getAmmoType() and mag:getAmmoType():getItemKey()
                end

                local newBullet = instanceItem(bulletType)
                self.character:getInventory():AddItem(newBullet)
                mag:setCurrentAmmoCount(mag:getCurrentAmmoCount() - 1)
                sendAddItemToContainer(self.character:getInventory(), newBullet)

                if #ammoList == 0 then
                    mag:getModData().AmmoList = nil
                end
                Ammo.SyncAmmoListToClient(self.character, mag)
                return
            end
        end
    end

    ISUnloadBulletsFromMagazine_animEvent_Original(self, event, parameter)
end

local ISLoadBulletsInMagazine_isLoadFinished_Original = ISLoadBulletsInMagazine.isLoadFinished
function ISLoadBulletsInMagazine:isLoadFinished()
    local loadedThisSession = self.magazine:getCurrentAmmoCount() - (self.ammoCountStart or 0)

    if self.ammoLimit and loadedThisSession >= self.ammoLimit then
        return true
    end

    if self.ammoTypeOverride then
        return self.magazine:getCurrentAmmoCount() >= self.magazine:getMaxAmmo()
            or not self.character:getInventory():containsWithModule(self.ammoTypeOverride)
    end

    return ISLoadBulletsInMagazine_isLoadFinished_Original(self)
end

local ISLoadBulletsInMagazine_new_Original = ISLoadBulletsInMagazine.new
function ISLoadBulletsInMagazine:new(character, magazine, ammoCount, ammoLimit, ammoTypeOverride)
    local o = ISLoadBulletsInMagazine_new_Original(self, character, magazine, ammoCount)
    o.ammoLimit = ammoLimit
    o.ammoTypeOverride = ammoTypeOverride
    if ammoTypeOverride then
        o.ammo = instanceItem(ammoTypeOverride)
    end
    return o
end

local ISReloadWeaponAction_initVars_Original = ISReloadWeaponAction.initVars
function ISReloadWeaponAction:initVars()
    if not self.ammoTypeOverride then
        return ISReloadWeaponAction_initVars_Original(self)
    end

    ISReloadWeaponAction.setReloadSpeed(self.character, false)

    local ammoCount = self.character:getInventory():getItemCountRecurse(self.ammoTypeOverride)
    ammoCount = math.min(ammoCount, self.gun:getMaxAmmo() - self.gun:getCurrentAmmoCount())
    if ammoCount <= 0 then
        return
    end

    local bullets = self.character:getInventory():getSomeTypeRecurse(self.ammoTypeOverride, ammoCount)
    if bullets and not bullets:isEmpty() then
        self.bullets = bullets
        self.ammoCount = ammoCount
    end
end

-------------------------------------------------
-- Bullet reload with no magazine: add to AmmoList
-------------------------------------------------
local ISReloadWeaponAction_loadAmmo_Original = ISReloadWeaponAction.loadAmmo
function ISReloadWeaponAction:loadAmmo()
    if not self.bullets then
        return ISReloadWeaponAction_loadAmmo_Original(self)
    end

    local loadedThisSession = self.gun:getCurrentAmmoCount() - (self.ammoCountStart or 0)

    if self.ammoLimit and loadedThisSession >= self.ammoLimit then
        self.character:clearVariable("isLoading")
        if not isServer() then
            if self.gun:haveChamber() and not self.gun:isRoundChambered() then
                ISTimedActionQueue.addAfter(self, ISRackFirearm:new(self.character, self.gun))
            end
            if self.gun:needToBeClosedOnceReload() then
                self:setAnimVariable("isLoading", false)
                self:setAnimVariable("isRacking", true)
                return
            end
        end
        if isServer() then
            self.netAction:forceComplete()
        else
            self:forceComplete()
        end
        return
    end

    -- Multi-item reload: gate this round on the extra items (powder charge / percussion cap) the
    -- gun's reload handler declares. When they run out, emptying self.bullets makes the termination
    -- block below finish the reload, so the round count can never exceed the powder/caps loaded.
    local gwConsume = ReloadAnim.GetConsumeItemsForGun(self.gun)
    if gwConsume and (not isClient()) and not gwHasAllConsumeItems(self.character, gwConsume) then
        self.bullets:clear()
    end

    if not self.bullets:isEmpty() and self.gun:getCurrentAmmoCount() < self.gun:getMaxAmmo() then
        local bullet = self.bullets:get(0)
        self.bullets:remove(bullet)
        self.character:getInventory():Remove(bullet)

        local gunModData = self.gun:getModData()
        gunModData.AmmoList = gunModData.AmmoList or {}
        local ammoList = gunModData.AmmoList

        local bulletType = (bullet and bullet.getFullType and bullet:getFullType())
            or (self.gun:getAmmoType() and self.gun:getAmmoType():getItemKey())

        if self.gun:isRoundChambered() and #ammoList > 0 then
            local chamberedType = ammoList[#ammoList]
            ammoList[#ammoList] = bulletType
            ammoList[#ammoList + 1] = chamberedType
        else
            ammoList[#ammoList + 1] = bulletType
        end

        self.gun:setCurrentAmmoCount(self.gun:getCurrentAmmoCount() + 1)
        if gwConsume and (not isClient()) then
            gwConsumeReloadItems(self.character, gwConsume)
        end
        sendRemoveItemFromContainer(self.character:getInventory(), bullet)
        syncHandWeaponFields(self.character, self.gun)
        Ammo.SyncAmmoListToClient(self.character, self.gun)
    end

    if self.bullets:isEmpty() or self.gun:getCurrentAmmoCount() >= self.gun:getMaxAmmo() then
        self.character:clearVariable("isLoading")
        if not isServer() then
            if self.gun:haveChamber() and not self.gun:isRoundChambered() then
                ISTimedActionQueue.addAfter(self, ISRackFirearm:new(self.character, self.gun))
            end
            if self.gun:needToBeClosedOnceReload() then
                self:setAnimVariable("isLoading", false)
                self:setAnimVariable("isRacking", true)
                return
            end
        end
        if isServer() then
            self.netAction:forceComplete()
        else
            self:forceComplete()
        end
    elseif self.gun:isInsertAllBulletsReload() then
        self:loadAmmo()
    end
end

local ISReloadWeaponAction_new_Original = ISReloadWeaponAction.new
function ISReloadWeaponAction:new(character, gun, ammoLimit, ammoTypeOverride)
    local o = ISReloadWeaponAction_new_Original(self, character, gun)
    o.ammoLimit = ammoLimit
    o.ammoCountStart = gun:getCurrentAmmoCount()
    o.ammoTypeOverride = ammoTypeOverride
    return o
end

-------------------------------------------------
-- Unload Bullets from Gun: Remove from AmmoList
-------------------------------------------------
local ISUnloadBulletsFromFirearm_animEvent_Original = ISUnloadBulletsFromFirearm.animEvent
function ISUnloadBulletsFromFirearm:animEvent(event, parameter)
    if event == 'playReloadSound' then
        if parameter == 'ejectAmmoStart' then
            return ISUnloadBulletsFromFirearm_animEvent_Original(self, event, parameter)
        end

        local gun = self.gun
        local gunModData = gun:getModData()
        local ammoList = gunModData.AmmoList

        if ammoList and #ammoList > 0 and gun:getCurrentAmmoCount() > 0 then
            if gun:getEjectAmmoSound() then
                self.character:playSound(gun:getEjectAmmoSound())
            end

            local count = 1
            if gun:isInsertAllBulletsReload() then
                count = gun:getCurrentAmmoCount()
            end

            if not isClient() then
                while gun:getCurrentAmmoCount() > 0 and count > 0 and #ammoList > 0 do
                    local bulletType = table.remove(ammoList, 1)
                    local newBullet = instanceItem(bulletType)
                    self.character:getInventory():AddItem(newBullet)
                    gun:setCurrentAmmoCount(gun:getCurrentAmmoCount() - 1)
                    sendAddItemToContainer(self.character:getInventory(), newBullet)
                    syncHandWeaponFields(self.character, gun)
                    count = count - 1
                end

                if #ammoList == 0 then
                    gunModData.AmmoList = nil
                end
                Ammo.SyncAmmoListToClient(self.character, gun)
            end

            self.unloadFinished = false
            return
        end
    end

    ISUnloadBulletsFromFirearm_animEvent_Original(self, event, parameter)
end

------------------------------------------------
-- Attack_Hook: set ammo type BEFORE original, then remove from AmmoList array and handle bayonet attack case
-------------------------------------------------
local Attack_Hook_Original = ISReloadWeaponAction.attackHook
Hook.Attack.Remove(ISReloadWeaponAction.attackHook)
ISReloadWeaponAction.attackHook = function(character, chargeDelta, weapon)
    if weapon:isRanged() and not character:isDoShove() then
        if ISReloadWeaponAction.canShoot(character, weapon) then
            local ammoList = weapon:getModData().AmmoList
            if ammoList and #ammoList > 0 then
                local bulletType = ammoList[#ammoList]
                Ammo.AmmoProfileSetter(weapon, bulletType)

                if OrdnanceFactory.IsAmmoRegistered(bulletType) then
                    weapon:getModData().GWG_FiringExplosiveAmmo = bulletType
                else
                    weapon:getModData().GWG_FiringExplosiveAmmo = nil
                end
            end

            if ammoList and #ammoList > 0 then
                ammoList[#ammoList] = nil

                if #ammoList == 0 then
                    weapon:getModData().AmmoList = nil
                end

                if isClient() then
                    sendClientCommand(character, "SWMG", "consumeRound", {
                        itemId = weapon:getID()
                    })
                end
            end
        else
            if weapon:getCurrentAmmoCount() <= 0 then
                weapon:getModData().AmmoList = nil
                if isClient() then
                    sendClientCommand(character, "SWMG", "clearAmmoList", {
                        itemId = weapon:getID()
                    })
                end
            end
        end
        Attack_Hook_Original(character, chargeDelta, weapon)
    elseif (not character:getVehicle() or character:isDoShove()) then
        local isBayonetDeployed = Bayonet.IsBayonetDeployed(weapon)
        if isBayonetDeployed then
            Bayonet.BayonetAttack(character, chargeDelta, weapon, Attack_Hook_Original)
        else
            Attack_Hook_Original(character, chargeDelta, weapon)
        end
    end
end

Hook.Attack.Add(ISReloadWeaponAction.attackHook)

------------------------------------------------
-- RAF_Hook: Right on game start ensure the hook takes over after picking all attack hooks
-------------------------------------------------
Events.OnGameStart.Add(function()
    local Original_Attack_Hook = ISReloadWeaponAction.attackHook

    ISReloadWeaponAction.RAFattackHook = function(character, chargeDelta, weapon)
        if weapon:isRanged() and not character:isDoShove() then
            local canFire, intervalMs = RateOfFire.canFire(character, weapon)
            if not canFire then return end

            RateOfFire.applySpreadOnShot(character, weapon, intervalMs)

            if weapon:getFireMode() == "RealBurst" then
                if RateOfFire.burstState[character:getPlayerNum()] then return end
                if not RateOfFire.canStartBurst(character) then return end

                local result = Original_Attack_Hook(character, chargeDelta, weapon)
                RateOfFire.startBurst(character, weapon, intervalMs, Original_Attack_Hook, chargeDelta)
                return result
            end
        end

        return Original_Attack_Hook(character, chargeDelta, weapon)
    end

    Hook.Attack.Remove(ISReloadWeaponAction.attackHook)
    Hook.Attack.Add(ISReloadWeaponAction.RAFattackHook)
    Events.OnTick.Add(RateOfFire.burstTickHandler)
    Events.OnTick.Add(RateOfFire.decaySpreadTick)
end)
