require("TimedActions/ISReloadWeaponAction")
require("TimedActions/ISRackFirearm")
require("TimedActions/ISUnloadBulletsFromFirearm")
require("TimedActions/ISInsertMagazine")
require("TimedActions/ISEjectMagazine")

local Animations = require("WeaponSystems/Utils/Animations")

--------------------------------------------------------------------------
--- ISReloadWeaponAction
--------------------------------------------------------------------------
local ISReloadWeaponAction_animEvent = ISReloadWeaponAction.animEvent
function ISReloadWeaponAction:animEvent(event, parameter)
    if event == 'changeWeaponSprite' then
        if parameter and parameter ~= '' then
            local open = parameter ~= 'original'
            Animations.CallAnimationFunction(self.gun, open)
            Animations.CallSyncHandWeaponFields(self.character, self.gun)
        end
    else
        return ISReloadWeaponAction_animEvent(self, event, parameter)
    end
end

local old_ISReloadWeaponAction_onShoot = ISReloadWeaponAction.onShoot
Events.OnWeaponSwingHitPoint.Remove(ISReloadWeaponAction.onShoot)
ISReloadWeaponAction.onShoot = function(player, weapon)
    if Animations.IsWeaponRegistered(weapon:getFullType()) then
        Animations.AmmoCheck(weapon)
        Animations.CallSyncHandWeaponFields(player, weapon)
    end
    Animations.lockActionOpen(player, weapon)
    old_ISReloadWeaponAction_onShoot(player, weapon)
end
Events.OnWeaponSwingHitPoint.Add(ISReloadWeaponAction.onShoot)


--------------------------------------------------------------------------
--- ISRackFirearm
--------------------------------------------------------------------------
local ISRackFirearm_animEvent = ISRackFirearm.animEvent
function ISRackFirearm:animEvent(event, parameter)
    if event == 'rackStart' then
        Animations.rackAction(self.character, self.gun, true)
    end
    if event == 'rackEnd' then
        Animations.rackAction(self.character, self.gun, false)
    end
    if event == 'changeWeaponSprite' then
        if parameter and parameter ~= '' then
            local open = parameter ~= 'original'
            Animations.CallAnimationFunction(self.gun, open)
            Animations.CallSyncHandWeaponFields(self.character, self.gun)
        end
    else
        return ISRackFirearm_animEvent(self, event, parameter)
    end
end

local ISRackFirearm_complete = ISRackFirearm.complete
function ISRackFirearm:complete()
    if Animations.IsWeaponRegistered(self.gun:getFullType()) then
        Animations.AmmoCheck(self.gun)
        Animations.CallSyncHandWeaponFields(self.character, self.gun)
    end
    return ISRackFirearm_complete(self)
end

--------------------------------------------------------------------------
--- ISUnloadBulletsFromFirearm
--------------------------------------------------------------------------
local ISUnloadBulletsFromFirearm_animEvent = ISUnloadBulletsFromFirearm.animEvent
function ISUnloadBulletsFromFirearm:animEvent(event, parameter)
    if event == 'changeWeaponSprite' then
        if parameter and parameter ~= '' then
            local open = parameter ~= 'original'
            Animations.CallAnimationFunction(self.gun, open)
            Animations.CallSyncHandWeaponFields(self.character, self.gun)
        end
    else
        return ISUnloadBulletsFromFirearm_animEvent(self, event, parameter)
    end
end

---------------------------------------------------------------
-- Visual Magazine System
--
-- Driven by a single anim event that modders place in AnimSet XMLs:
--   InsertMag – hand is near the magazine well
--
-- On insert (reload):  attaches the visual Clip part to the weapon.
-- On eject (unload):   detaches the visual Clip part from the weapon.
-- On stop/complete the weapon's visual Clip part is synced to the
-- actual clip state and the weapon is re-synced for MP.
---------------------------------------------------------------

-- Sync the weapon's visual magazine part to its logical clip state.
local function manageMagazineAttachment(weapon, magTypeOverride)
    if not weapon then return end
    local magType = magTypeOverride or weapon:getMagazineType()
    if not magType or magType == "" then return end

    if weapon:isContainsClip() then
        local currentClip = weapon:getWeaponPart("Clip")
        if currentClip and currentClip:getFullType() ~= magType then
            weapon:detachWeaponPart(currentClip)
            currentClip = nil
        end
        if not currentClip then
            local magPart = instanceItem(magType)
            if magPart then
                weapon:attachWeaponPart(magPart, true)
            end
        end
    else
        local clipPart = weapon:getWeaponPart("Clip")
        if clipPart then
            weapon:detachWeaponPart(clipPart)
        end
    end
end

-- Force-attach the visual Clip part on the weapon model (ignores clip state).
local function attachMagazineVisual(weapon, magTypeOverride)
    if not weapon then return end
    local magType = magTypeOverride or weapon:getMagazineType()
    if not magType or magType == "" then return end
    local currentClip = weapon:getWeaponPart("Clip")
    if currentClip and currentClip:getFullType() ~= magType then
        weapon:detachWeaponPart(currentClip)
        currentClip = nil
    end
    if currentClip then return end
    local magPart = instanceItem(magType)
    if magPart then
        weapon:attachWeaponPart(magPart, true)
    end
end

-- Force-detach the visual Clip part from the weapon model (ignores clip state).
local function detachMagazineVisual(weapon)
    if not weapon then return end
    local clipPart = weapon:getWeaponPart("Clip")
    if clipPart then
        weapon:detachWeaponPart(clipPart)
    end
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
        attachMagazineVisual(self.gun, self._actualMagType)
        Animations.CallSyncHandWeaponFields(self.character, self.gun)
    end
    return ISInsertMagazine_animEvent(self, event, parameter)
end

local ISInsertMagazine_stop = ISInsertMagazine.stop
function ISInsertMagazine:stop()
    manageMagazineAttachment(self.gun, self._actualMagType)
    Animations.CallSyncHandWeaponFields(self.character, self.gun)
    return ISInsertMagazine_stop(self)
end

local ISInsertMagazine_complete = ISInsertMagazine.complete
function ISInsertMagazine:complete()
    manageMagazineAttachment(self.gun, self._actualMagType)
    if Animations.IsWeaponRegistered(self.gun:getFullType()) then
        Animations.AmmoCheck(self.gun)
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
        detachMagazineVisual(self.gun)
        Animations.CallSyncHandWeaponFields(self.character, self.gun)
    end
    return ISEjectMagazine_animEvent(self, event, parameter)
end

local ISEjectMagazine_stop = ISEjectMagazine.stop
function ISEjectMagazine:stop()
    manageMagazineAttachment(self.gun)
    Animations.CallSyncHandWeaponFields(self.character, self.gun)
    return ISEjectMagazine_stop(self)
end

local ISEjectMagazine_complete = ISEjectMagazine.complete
function ISEjectMagazine:complete()
    manageMagazineAttachment(self.gun)
    if Animations.IsWeaponRegistered(self.gun:getFullType()) then
        Animations.AmmoCheck(self.gun)
    end
    Animations.CallSyncHandWeaponFields(self.character, self.gun)
    return ISEjectMagazine_complete(self)
end
