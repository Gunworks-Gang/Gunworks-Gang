require('TimedActions/ISReloadWeaponAction')
require('TimedActions/ISLoadBulletsInMagazine')
require('TimedActions/ISUnloadBulletsFromMagazine')
require("TimedActions/ISInsertMagazine")
require("TimedActions/ISEjectMagazine")
require("TimedActions/ISRackFirearm")

local Magazine = require("WeaponSystems/Utils/MagazineUtils")
local Ammo = require("WeaponSystems/Utils/AmmoUtils")
local Bayonet = require("WeaponSystems/Utils/BayonetUtils")

-------------------------------------------------
-- BeginAutomaticReload (MagazineProfile support)
-------------------------------------------------
local ISReloadWeaponAction_BeginAutomaticReload_Original = ISReloadWeaponAction.BeginAutomaticReload
ISReloadWeaponAction.BeginAutomaticReload = function(playerObj, gun)
    if Magazine.WeaponMagazineProfile[gun:getFullType()] then
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
        if SpentCasingPhysics and not self.gun:isManuallyRemoveSpentRounds() then
            self.emptyRack = false
            Ammo.AmmoProfileSetter(self.gun, bulletType)
        else
            local newBullet = instanceItem(bulletType)
            self.character:getInventory():AddItem(newBullet)
        end
        ammoList[#ammoList] = nil
    else
        ISRackFirearm_removeBullet_original(self)
    end
end

-------------------------------------------------
-- Insert Magazine: Transfer AmmoList mag -> gun
-------------------------------------------------
local ISInsertMagazine_loadAmmo_original = ISInsertMagazine.loadAmmo
function ISInsertMagazine:loadAmmo()
    if self.magazine then
        if self.gun.setMagazineType then
            self.gun:setMagazineType(self.magazine:getFullType())
        end
        Magazine.SaveMagazineType(self.gun, self.magazine:getFullType())

        local magList = self.magazine:getModData().AmmoList
        if magList and #magList > 0 then
            local gunModData = self.gun:getModData()
            gunModData.AmmoList = magList
            self.magazine:getModData().AmmoList = nil
        end
    end
    return ISInsertMagazine_loadAmmo_original(self)
end

-------------------------------------------------
-- Eject Magazine: Transfer AmmoList gun -> mag
-------------------------------------------------
local ISEjectMagazine_unloadAmmo_original = ISEjectMagazine.unloadAmmo
function ISEjectMagazine:unloadAmmo()
    local savedMagType = Magazine.GetMagazineType(self.gun)
    local gunModData = self.gun:getModData()
    local gunList = gunModData.AmmoList

    local ammoListForMag = nil

    if gunList and #gunList > 0 then
        if self.gun:isRoundChambered() and #gunList > 1 then
            ammoListForMag = {}
            for i = 2, #gunList do
                ammoListForMag[#ammoListForMag + 1] = gunList[i]
            end
            gunModData.AmmoList = { gunList[1] }
        elseif self.gun:isRoundChambered() and #gunList == 1 then
            gunModData.AmmoList = { gunList[1] }
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
    end

    ISEjectMagazine_unloadAmmo_original(self)

    if ammoListForMag and savedMagType then
        local ejectedMag = self.character:getInventory():getFirstType(savedMagType)
        if ejectedMag then
            ejectedMag:getModData().AmmoList = ammoListForMag
        end
    end

    Magazine.ClearMagazineType(self.gun)
end

-------------------------------------------------
-- Load and Unload Bullets from Magazine update AmmoList
-------------------------------------------------
local ISLoadBulletsInMagazine_animEvent_Original = ISLoadBulletsInMagazine.animEvent
function ISLoadBulletsInMagazine:animEvent(event, parameter)
    if event == 'InsertBullet' then
        local modData = self.magazine:getModData()
        modData.AmmoList = modData.AmmoList or {}

        local bulletType =
            (self.ammo and self.ammo.getFullType and self.ammo:getFullType())
            or (self.magazine:getAmmoType() and self.magazine:getAmmoType():getItemKey())

        modData.AmmoList[#modData.AmmoList + 1] = bulletType
    end
    ISLoadBulletsInMagazine_animEvent_Original(self, event, parameter)
end

local ISUnloadBulletsFromMagazine_animEvent_Original = ISUnloadBulletsFromMagazine.animEvent
function ISUnloadBulletsFromMagazine:animEvent(event, parameter)
    if event == "RemoveBullet" or event == "removeBullet" then
        local mag = self.magazine
        if mag then
            local ammoList = mag:getModData().AmmoList
            if ammoList and #ammoList > 0 and mag:getCurrentAmmoCount() > 0 then
                local bulletType = ammoList[#ammoList]
                ammoList[#ammoList] = nil

                if not bulletType then
                    bulletType = mag:getAmmoType() and mag:getAmmoType():getItemKey()
                end

                if not isClient() then
                    local newBullet = instanceItem(bulletType)
                    self.character:getInventory():AddItem(newBullet)
                    mag:setCurrentAmmoCount(mag:getCurrentAmmoCount() - 1)
                    sendAddItemToContainer(self.character:getInventory(), newBullet)
                else
                    mag:setCurrentAmmoCount(mag:getCurrentAmmoCount() - 1)
                end

                if #ammoList == 0 then
                    mag:getModData().AmmoList = nil
                end
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
    if event == 'playReloadSound' and parameter == 'ejectAmmoStart' then
        local gun = self.gun
        local gunModData = gun:getModData()
        local ammoList = gunModData.AmmoList

        if ammoList and #ammoList > 0 and gun:getCurrentAmmoCount() > 0 then
            if gun:isInsertAllBulletsReload() then
                local count = gun:getCurrentAmmoCount()
                for i = 1, count do
                    if #ammoList > 0 then
                        table.remove(ammoList, 1)
                    end
                end
            else
                table.remove(ammoList, 1)
            end

            if #ammoList == 0 then
                gunModData.AmmoList = nil
            end
        end
    end

    ISUnloadBulletsFromFirearm_animEvent_Original(self, event, parameter)
end

------------------------------------------------
-- EjectSpentRounds for manuallyRemoveSpentRounds firearms
-------------------------------------------------
local ISReloadWeaponAction_ejectSpentRounds_Original = ISReloadWeaponAction.ejectSpentRounds
function ISReloadWeaponAction:ejectSpentRounds()
    if SpentCasingPhysics and self.gun:getModData().SpentAmmoList then
        for _, bulletType in ipairs(self.gun:getModData().SpentAmmoList) do
            Ammo.AmmoProfileSetter(self.gun, bulletType)
            SpentCasingPhysics.rackCasing(self.character, self.gun, false)
        end
        self.gun:getModData().SpentAmmoList = nil
        self.gun:setSpentRoundCount(0)
        syncHandWeaponFields(self.character, self.gun)
    else
        ISReloadWeaponAction_ejectSpentRounds_Original(self)
    end
end

local ISRackFirearm_ejectSpentRounds_Original = ISRackFirearm.ejectSpentRounds
function ISRackFirearm:ejectSpentRounds()
    if SpentCasingPhysics and self.gun:getModData().SpentAmmoList then
        for _, bulletType in ipairs(self.gun:getModData().SpentAmmoList) do
            Ammo.AmmoProfileSetter(self.gun, bulletType)
            SpentCasingPhysics.rackCasing(self.character, self.gun, false)
        end
        self.gun:getModData().SpentAmmoList = nil
        self.gun:setSpentRoundCount(0)
        syncHandWeaponFields(self.character, self.gun)
    else
        ISRackFirearm_ejectSpentRounds_Original(self)
    end
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

            if weapon:isManuallyRemoveSpentRounds() then
                if ammoList and #ammoList > 0 then
                    local bulletType = ammoList[#ammoList]
                    if weapon:getModData().SpentAmmoList == nil then
                        weapon:getModData().SpentAmmoList = { bulletType }
                    else
                        weapon:getModData().SpentAmmoList[#weapon:getModData().SpentAmmoList + 1] = bulletType
                    end
                end
            end

            if ammoList and #ammoList > 0 then
                ammoList[#ammoList] = nil

                if #ammoList == 0 then
                    weapon:getModData().AmmoList = nil
                end
            end
        else
            if weapon:getCurrentAmmoCount() <= 0 then
                weapon:getModData().AmmoList = nil
            end
        end
        Attack_Hook_Original(character, chargeDelta, weapon)
    elseif (not character:getVehicle() or character:isDoShove()) then
        local bayonetInstalled = weapon:getWeaponPart("Bayonet")
        if bayonetInstalled then
            Bayonet.BayonetAttack(character, chargeDelta, weapon, Attack_Hook_Original)
        else
            Attack_Hook_Original(character, chargeDelta, weapon)
        end
    end
end

Hook.Attack.Add(ISReloadWeaponAction.attackHook)
