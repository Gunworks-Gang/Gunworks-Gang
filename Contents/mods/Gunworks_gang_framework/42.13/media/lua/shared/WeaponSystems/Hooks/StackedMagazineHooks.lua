require("TimedActions/ISReloadWeaponAction")
require("TimedActions/ISInsertMagazine")
require("TimedActions/ISEjectMagazine")
require("WeaponSystems/TimedActions/ISStackedMagazine")

local StackedMagazines = require("WeaponSystems/Utils/StackedMagazines")

local prevInsertStart = ISInsertMagazine.start
function ISInsertMagazine:start()
    prevInsertStart(self)
    local seatedType = self.magazine and StackedMagazines.GetSeatedType(self.magazine)
    if seatedType then
        self._actualMagType = seatedType
    end
end

local prevInsertLoadAmmo = ISInsertMagazine.loadAmmo
function ISInsertMagazine:loadAmmo()
    local magazine = self.magazine
    local pack = magazine and StackedMagazines.ReadPack(magazine)
    if not pack then
        prevInsertLoadAmmo(self)
        StackedMagazines.ForgetGunState(self.gun)
        return
    end

    local undo = StackedMagazines.PresentSide(self.gun, magazine, pack)
    prevInsertLoadAmmo(self)
    if not self.gun:isContainsClip() then
        StackedMagazines.UndoPresentSide(self.gun, magazine, undo)
        return
    end
    StackedMagazines.SeatPack(self.gun, pack)
end

local prevEjectUnloadAmmo = ISEjectMagazine.unloadAmmo
function ISEjectMagazine:unloadAmmo()
    if not StackedMagazines.IsInGun(self.gun) then
        return prevEjectUnloadAmmo(self)
    end
    StackedMagazines.EjectPack(self.character, self.gun)
end

local prevBeginAutomaticReload = ISReloadWeaponAction.BeginAutomaticReload
ISReloadWeaponAction.BeginAutomaticReload = function (playerObj, gun)
    if StackedMagazines.BeginReload(playerObj, gun) then
        return
    end
    return prevBeginAutomaticReload(playerObj, gun)
end
