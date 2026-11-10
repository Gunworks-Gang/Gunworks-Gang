require("TimedActions/ISReloadWeaponAction")
require("TimedActions/ISRackFirearm")
require("TimedActions/ISUnloadBulletsFromFirearm")
require("TimedActions/ISInsertMagazine")
require("TimedActions/ISEjectMagazine")

local Animations = require("WeaponSystems/Utils/Animations")
local Magazine = require("WeaponSystems/Utils/Magazine")
local ReloadRules = require("WeaponSystems/ReloadAnim/Rules")

--------------------------------------------------------------------------
--- ISReloadWeaponAction
--------------------------------------------------------------------------
local ISReloadWeaponAction_animEvent = ISReloadWeaponAction.animEvent
function ISReloadWeaponAction:animEvent(event, parameter)
    if event == "openWeapon" then
        Animations.CallAnimate(self.character, self.gun, true, nil, "reload")
    end
    if event == "closeWeapon" then
        Animations.CallAnimate(self.character, self.gun, false, nil, "reload")
    end
    ISReloadWeaponAction_animEvent(self, event, parameter)
end

local ISReloadWeaponAction_complete = ISReloadWeaponAction.complete
function ISReloadWeaponAction:complete()
    if Animations.IsWeaponWithCustomStates(self.gun:getFullType()) then
        Animations.CheckStates(self.gun)
    end
    if not self.gun:haveChamber() and not ReloadRules.gunHasRules(self.gun) then
        Animations.CallAnimate(self.character, self.gun, false, nil, "reload")
    end
    return ISReloadWeaponAction_complete(self)
end

local function isTriggerBlocked(weapon)
    return weapon:getFireMode() == "Safe" or weapon:getModData().gunworksBoltOpen == true
end

local ISReloadWeaponAction_canShoot = ISReloadWeaponAction.canShoot
ISReloadWeaponAction.canShoot = function (player, weapon)
    if isTriggerBlocked(weapon) then return false end
    return ISReloadWeaponAction_canShoot(player, weapon)
end

-- I really want my revolvers clicking. A dry fire plays the Empty anim, which has no AttackCollisionCheck,
-- so onShoot never runs, OnWeaponSwing fires once per trigger pull instead. should be better for MP
local function onWeaponSwing(player, weapon)
    if not player:isLocalPlayer() or not weapon or not weapon:isRanged() or player:isDoShove() then return end
    if isTriggerBlocked(weapon) or ISReloadWeaponAction.canShoot(player, weapon) then return end
    Animations.dryFireAction(player, weapon)
end
Events.OnWeaponSwing.Add(onWeaponSwing)

local ISReloadWeaponAction_onShoot = ISReloadWeaponAction.onShoot
Events.OnWeaponSwingHitPoint.Remove(ISReloadWeaponAction.onShoot)
ISReloadWeaponAction.onShoot = function (player, weapon)
    if Animations.IsWeaponWithCustomStates(weapon:getFullType()) then
        Animations.CheckStates(weapon)
        Animations.CallSyncHandWeaponFields(player, weapon)
    end
    Animations.lockActionOpen(player, weapon)
    ISReloadWeaponAction_onShoot(player, weapon)
end
Events.OnWeaponSwingHitPoint.Add(ISReloadWeaponAction.onShoot)

--------------------------------------------------------------------------
--- ISRackFirearm
--------------------------------------------------------------------------
local ISRackFirearm_animEvent = ISRackFirearm.animEvent
function ISRackFirearm:animEvent(event, parameter)
    if event == "rackStart" then
        Animations.rackAction(self.character, self.gun, true, self.gunworksRackPhase)
    end
    if event == "rackEnd" then
        Animations.rackAction(self.character, self.gun, false, self.gunworksRackPhase)
    end
    if event == "openWeapon" then
        Animations.CallAnimate(self.character, self.gun, true, nil, "reload", self.gunworksRackPhase)
    end
    if event == "closeWeapon" then
        Animations.CallAnimate(self.character, self.gun, false, nil, "reload", self.gunworksRackPhase)
    end
    ISRackFirearm_animEvent(self, event, parameter)
end

local ISRackFirearm_complete = ISRackFirearm.complete
function ISRackFirearm:complete()
    if Animations.IsWeaponWithCustomStates(self.gun:getFullType()) then
        Animations.CheckStates(self.gun)
    end
    if not self.gun:haveChamber() and self.gunworksRackPhase ~= "open" then
        Animations.CallAnimate(self.character, self.gun, false, nil, "reload", self.gunworksRackPhase)
    end
    return ISRackFirearm_complete(self)
end

--------------------------------------------------------------------------
--- ISUnloadBulletsFromFirearm
--------------------------------------------------------------------------
local ISUnloadBulletsFromFirearm_animEvent = ISUnloadBulletsFromFirearm.animEvent
function ISUnloadBulletsFromFirearm:animEvent(event, parameter)
    if event == "openWeapon" then
        Animations.CallAnimate(self.character, self.gun, true, nil, "reload")
    end
    if event == "closeWeapon" then
        Animations.CallAnimate(self.character, self.gun, false, nil, "reload")
    end
    ISUnloadBulletsFromFirearm_animEvent(self, event, parameter)
end

local ISUnloadBulletsFromFirearm_complete = ISUnloadBulletsFromFirearm.complete
function ISUnloadBulletsFromFirearm:complete()
    if not self.gun:haveChamber() and not ReloadRules.gunHasRules(self.gun) then
        Animations.CallAnimate(self.character, self.gun, false, nil, "reload")
    end
    return ISUnloadBulletsFromFirearm_complete(self)
end

---------------------------------------------------------------
-- ISInsertMagazine hooks
---------------------------------------------------------------
local ISInsertMagazine_start = ISInsertMagazine.start
function ISInsertMagazine:start()
    self._actualMagType = self.magazine and self.magazine:getFullType() or nil
    return ISInsertMagazine_start(self)
end

local ISInsertMagazine_animEvent = ISInsertMagazine.animEvent
function ISInsertMagazine:animEvent(event, parameter)
    if event == "InsertMag" then
        Magazine.attachMagazineVisual(self.gun, self._actualMagType)
        Animations.CallSyncHandWeaponFields(self.character, self.gun)
    end
    ISInsertMagazine_animEvent(self, event, parameter)
end

local ISInsertMagazine_stop = ISInsertMagazine.stop
function ISInsertMagazine:stop()
    Magazine.manageMagazineAttachment(self.gun, self._actualMagType)
    Animations.CallSyncHandWeaponFields(self.character, self.gun)
    return ISInsertMagazine_stop(self)
end

local ISInsertMagazine_complete = ISInsertMagazine.complete
function ISInsertMagazine:complete()
    Magazine.manageMagazineAttachment(self.gun, self._actualMagType)
    if Animations.IsWeaponWithCustomStates(self.gun:getFullType()) then
        Animations.CheckStates(self.gun)
    end
    Animations.CallSyncHandWeaponFields(self.character, self.gun)
    return ISInsertMagazine_complete(self)
end

---------------------------------------------------------------
-- ISEjectMagazine hooks
---------------------------------------------------------------
local ISEjectMagazine_start = ISEjectMagazine.start
function ISEjectMagazine:start()
    local clipPart = self.gun and self.gun:getWeaponPart("Clip")
    self._actualMagType = clipPart and clipPart:getFullType() or nil
    return ISEjectMagazine_start(self)
end

local ISEjectMagazine_animEvent = ISEjectMagazine.animEvent
function ISEjectMagazine:animEvent(event, parameter)
    if event == "InsertMag" then
        Magazine.detachMagazineVisual(self.gun)
        return Animations.CallSyncHandWeaponFields(self.character, self.gun)
    end
    ISEjectMagazine_animEvent(self, event, parameter)
end

local ISEjectMagazine_stop = ISEjectMagazine.stop
function ISEjectMagazine:stop()
    Magazine.manageMagazineAttachment(self.gun)
    Animations.CallSyncHandWeaponFields(self.character, self.gun)
    return ISEjectMagazine_stop(self)
end

local ISEjectMagazine_complete = ISEjectMagazine.complete
function ISEjectMagazine:complete()
    Magazine.manageMagazineAttachment(self.gun)
    if Animations.IsWeaponWithCustomStates(self.gun:getFullType()) then
        Animations.CheckStates(self.gun)
    end
    Animations.CallSyncHandWeaponFields(self.character, self.gun)
    return ISEjectMagazine_complete(self)
end

local function checkWeaponStateOnEquip(playerObj, weapon)
    if not playerObj or not weapon then return end
    if instanceof(weapon, "HandWeapon") and weapon:isRanged() then
        if Animations.IsWeaponWithCustomStates(weapon:getFullType()) then
            Animations.CheckStates(weapon)
        end
    end
end

Events.OnEquipPrimary.Add(checkWeaponStateOnEquip)
Events.OnEquipSecondary.Add(checkWeaponStateOnEquip)
