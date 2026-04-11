require('TimedActions/ISReloadWeaponAction')
require('TimedActions/ISLoadBulletsInMagazine')
require('TimedActions/ISUnloadBulletsFromMagazine')
require("TimedActions/ISInsertMagazine")
require("TimedActions/ISEjectMagazine")
require("TimedActions/ISRackFirearm")

local Magazine = require("WeaponSystems/Utils/MagazineUtils")
local Ammo = require("WeaponSystems/Utils/AmmoUtils")
local Bayonet = require("WeaponSystems/Utils/BayonetUtils")
local Underbarrel = require("WeaponSystems/Utils/UnderbarrelUtils")

-------------------------------------------------
-- BeginAutomaticReload (MagazineProfile support)
-------------------------------------------------
local ISReloadWeaponAction_BeginAutomaticReload_Original = ISReloadWeaponAction.BeginAutomaticReload
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
    else
        ISReloadWeaponAction_BeginAutomaticReload_Original(playerObj, gun)
    end
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
    else
        ISRackFirearm_removeBullet_original(self)
    end
end

-------------------------------------------------
-- Insert Magazine: Transfer AmmoList mag -> gun
-------------------------------------------------
local ISInsertMagazine_loadAmmo_original = ISInsertMagazine.loadAmmo
function ISInsertMagazine:loadAmmo()
    if self.gun and Underbarrel.IsWeaponInUnderbarrelMode(self.gun) then
        return ISInsertMagazine_loadAmmo_original(self)
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

            -- Invariant: chambered round is always the last AmmoList entry.
            -- If a chambered round already exists, keep it at tail and place
            -- inserted magazine rounds before it so it fires first.
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
local ISEjectMagazine_unloadAmmo_original = ISEjectMagazine.unloadAmmo
function ISEjectMagazine:unloadAmmo()
    if self.gun and Underbarrel.IsWeaponInUnderbarrelMode(self.gun) then
        return ISEjectMagazine_unloadAmmo_original(self)
    end

    local savedMagType = Magazine.GetMagazineType(self.gun)
    if not savedMagType then
        return ISEjectMagazine_unloadAmmo_original(self)
    end
    local magazineInstance = instanceItem(savedMagType)
    if not magazineInstance then
        return ISEjectMagazine_unloadAmmo_original(self)
    end
    local gunModData = self.gun:getModData()
    local gunList = gunModData.AmmoList

    local ammoListForMag = nil

    if gunList and #gunList > 0 then
        if self.gun:isRoundChambered() and #gunList > 1 then
            -- Keep chambered round on gun as tail entry; magazine receives
            -- every entry before tail.
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

    ISEjectMagazine_unloadAmmo_original(self)

    if ammoListForMag and savedMagType then
        local ejectedMag = self.character:getInventory():getFirstType(savedMagType)
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
local ISLoadBulletsInMagazine_animEvent_Original = ISLoadBulletsInMagazine.animEvent
function ISLoadBulletsInMagazine:animEvent(event, parameter)
    if event == 'InsertBullet' then
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

    return ISLoadBulletsInMagazine_isLoadFinished_Original(self)
end

local ISLoadBulletsInMagazine_new_Original = ISLoadBulletsInMagazine.new
function ISLoadBulletsInMagazine:new(character, magazine, ammoCount, ammoLimit)
    local o = ISLoadBulletsInMagazine_new_Original(self, character, magazine, ammoCount)
    o.ammoLimit = ammoLimit
    return o
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
function ISReloadWeaponAction:new(character, gun, ammoLimit)
    local o = ISReloadWeaponAction_new_Original(self, character, gun)
    o.ammoLimit = ammoLimit
    o.ammoCountStart = gun:getCurrentAmmoCount()
    return o
end

-------------------------------------------------
-- Unload Bullets from Gun: Remove from AmmoList
-------------------------------------------------
local ISUnloadBulletsFromFirearm_animEvent_Original = ISUnloadBulletsFromFirearm.animEvent
function ISUnloadBulletsFromFirearm:animEvent(event, parameter)
    -- 'ejectAmmoStart' is a sound-only cue that returns early in vanilla.
    -- Actual bullet removal fires when parameter ~= 'ejectAmmoStart' (nil on
    -- the server via emulateAnimEvent). Mirror that condition here.
    if event == 'playReloadSound' and parameter ~= 'ejectAmmoStart' then
        if not isClient() then
            local gun = self.gun
            local gunModData = gun:getModData()
            local ammoList = gunModData.AmmoList

            if ammoList and #ammoList > 0 and gun:getCurrentAmmoCount() > 0 then
                local count = 1
                if gun:isInsertAllBulletsReload() then
                    count = gun:getCurrentAmmoCount()
                end
                for _ = 1, count do
                    if #ammoList > 0 then
                        table.remove(ammoList, 1)
                    end
                end

                if #ammoList == 0 then
                    gunModData.AmmoList = nil
                end
            end
            Ammo.SyncAmmoListToClient(self.character, gun)
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
            end

            if ammoList and #ammoList > 0 then
                ammoList[#ammoList] = nil

                if #ammoList == 0 then
                    weapon:getModData().AmmoList = nil
                end

                -- Tell server to consume the round from its AmmoList
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
        local bayonetInstalled = weapon:getWeaponPart("Bayonet")
        if bayonetInstalled then
            Bayonet.BayonetAttack(character, chargeDelta, weapon, Attack_Hook_Original)
        elseif Bayonet.HasIntegratedBayonet(weapon) and Bayonet.IsIntegratedBayonetDeployed(weapon) then
            Bayonet.IntegratedBayonetAttack(character, chargeDelta, weapon, Attack_Hook_Original)
        else
            Attack_Hook_Original(character, chargeDelta, weapon)
        end
    end
end

Hook.Attack.Add(ISReloadWeaponAction.attackHook)
