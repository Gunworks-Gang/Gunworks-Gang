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
    StackedMagazines.debug(
        "insert loadAmmo:", magazine and magazine:getFullType(), magazine and magazine:getCurrentAmmoCount(), "pack",
        pack ~= nil, pack and pack.side, pack and pack.rounds[1], pack and pack.rounds[2]
    )
    if not pack then
        prevInsertLoadAmmo(self)
        StackedMagazines.ForgetGunState(self.gun)
        return
    end

    local undo = StackedMagazines.PresentSide(self.gun, magazine, pack)
    prevInsertLoadAmmo(self)
    if not self.gun:isContainsClip() then
        StackedMagazines.debug("  -> the chain did not load the magazine: undone")
        StackedMagazines.UndoPresentSide(self.gun, magazine, undo)
        return
    end
    StackedMagazines.SeatPack(self.gun, pack)
    StackedMagazines.debug(
        "  -> seated: magType", self.gun:getMagazineType(), "count", self.gun:getCurrentAmmoCount(), "maxAmmo",
        self.gun:getMaxAmmo(), "state", StackedMagazines.GetGunState(self.gun) ~= nil
    )
end

local prevEjectUnloadAmmo = ISEjectMagazine.unloadAmmo
function ISEjectMagazine:unloadAmmo()
    StackedMagazines.debug(
        "eject unloadAmmo:", self.gun:getMagazineType(), "pack in gun", StackedMagazines.IsInGun(self.gun)
    )
    if not StackedMagazines.IsInGun(self.gun) then
        return prevEjectUnloadAmmo(self)
    end
    StackedMagazines.EjectPack(self.character, self.gun)
end

local prevBeginAutomaticReload = ISReloadWeaponAction.BeginAutomaticReload
ISReloadWeaponAction.BeginAutomaticReload = function (playerObj, gun)
    StackedMagazines.debug("BeginAutomaticReload (stacked wrapper)")
    if StackedMagazines.BeginReload(playerObj, gun) then
        return
    end
    return prevBeginAutomaticReload(playerObj, gun)
end

StackedMagazines.debug("hooks loaded")
