require("TimedActions/ISBaseTimedAction")
require("TimedActions/ISReloadWeaponAction")
require("TimedActions/ISRackFirearm")

local StackedMagazines = require("WeaponSystems/Utils/StackedMagazines")
local Magazine = require("WeaponSystems/Utils/Magazine")
local Animations = require("WeaponSystems/Utils/Animations")
---@class GunworksReloadAnim
local ReloadAnim = require("WeaponSystems/Utils/ReloadAnim")
require("WeaponSystems/ReloadAnim/Timing")
require("WeaponSystems/ReloadAnim/Props")
local ReloadRules = require("WeaponSystems/ReloadAnim/Rules")

ISStackedMagazine = ISBaseTimedAction:derive("ISStackedMagazine")

local PHASE_UNLOAD = "unload"
local PHASE_LOAD = "load"

function ISStackedMagazine:isValid()
    if not isClient() and not self.flipped and not StackedMagazines.PeekNextSide(self.gun) then
        return false
    end
    return self.character:getPrimaryHandItem() == self.gun
end

function ISStackedMagazine:start()
    if isClient() then
        self.gun = self.character:getInventory():getItemById(self.gun:getID())
    end

    local nextSide, nextRounds, nextType = StackedMagazines.PeekNextSide(self.gun)
    self.nextMagType = nextType
    self._actualMagType = StackedMagazines.GetWellType(self.gun)
    self.rackAfter = not self.gun:isRoundChambered() and nextRounds >= self.gun:getAmmoPerShoot()
    self.animation = StackedMagazines.GetAnimation(self.gun)
    self.phase = PHASE_UNLOAD

    self:setOverrideHandModels(self.gun, nil)
    self:setAnimVariable(ReloadAnim.AIM_VARIABLE, ReloadAnim.captureReloadAiming(self))
    self:setAnimVariable(StackedMagazines.SIDE_VARIABLE, tostring(nextSide or ""))
    local handler = ReloadAnim.GetHandlerForGun(self.gun)
    if self.animation then
        self:setAnimVariable(StackedMagazines.ANIM_VARIABLE, self.animation)
        self:setAnimVariable("WeaponReloadType", self.animation)
    elseif handler and handler.animId then
        self:setAnimVariable(ReloadAnim.ANIM_VARIABLE, handler.animId)
        self:setAnimVariable("WeaponReloadType", handler.animId)
    else
        self:setAnimVariable("WeaponReloadType", tostring(self.gun:getWeaponReloadType()))
    end
    self:setAnimVariable(ReloadRules.STEP_VARIABLE, "ejectMag")
    self:setAnimVariable("isUnloading", true)
    self:setActionAnim(CharacterActionAnims.Reload)
    self.character:reportEvent("EventReloading")
    self:initVars()
end

function ISStackedMagazine:initVars()
    ISReloadWeaponAction.setReloadSpeed(self.character, false)
end

function ISStackedMagazine:update()
end

--- The unload clip is done: the next side goes in with the load clip.
function ISStackedMagazine:beginLoadPhase()
    self.phase = PHASE_LOAD
    if not self._gwHandProp then
        self._actualMagType = self.nextMagType or self._actualMagType
    end
    if isServer() then
        return
    end
    self:setAnimVariable("isUnloading", false)
    self:setAnimVariable(ReloadRules.STEP_VARIABLE, "insertMag")
    self:setAnimVariable("isLoading", true)
end

function ISStackedMagazine:toggleMagazineModel()
    if self.gun:getWeaponPart("Clip") or self.gun:getWeaponPart("Magazine") then
        Magazine.detachMagazineVisual(self.gun)
    else
        Magazine.attachMagazineVisual(self.gun, self.nextMagType)
    end
    Animations.CallSyncHandWeaponFields(self.character, self.gun)
end

function ISStackedMagazine:playReloadSound(parameter)
    local sound = nil
    if parameter == "load" then
        sound = self.gun:getInsertAmmoSound()
    elseif parameter == "insertAmmoStart" then
        sound = self.gun:getInsertAmmoStartSound()
    elseif parameter == "unload" then
        sound = self.gun:getEjectAmmoSound()
    elseif parameter == "ejectAmmoStart" then
        sound = self.gun:getEjectAmmoStartSound()
    end
    if sound then
        self.character:playSound(sound)
    end
end

function ISStackedMagazine:animEvent(event, parameter)
    if event == "unloadFinished" then
        if self.phase == PHASE_UNLOAD then
            self:beginLoadPhase()
        end
        return
    end

    if event == "loadFinished" then
        if self.phase ~= PHASE_LOAD or self.flipped then
            return
        end
        self.flipped = true
        if not isClient() then
            local chance = 3
            local xp = 1
            if self.character:getPerkLevel(Perks.Reloading) < 5 then
                chance = 1
                xp = 4
            end
            if ZombRand(chance) == 0 then
                addXp(self.character, Perks.Reloading, xp)
            end
            StackedMagazines.FlipSides(self.character, self.gun)
            self.character:clearVariable("isLoading")
        end
        if isServer() then
            self.netAction:forceComplete()
        elseif not isClient() then
            self:forceComplete()
        end
        return
    end

    if event == "InsertMag" then
        self:toggleMagazineModel()
        return
    end

    if event == "playReloadSound" then
        self:playReloadSound(parameter)
        return
    end

    local handler = ReloadAnim.GetHandlerForGun(self.gun)
    if handler then
        ReloadAnim.handlePropAnimEvent(self, handler, event, parameter)
    end
end

-- Server timing: the group's unload / load durations with its own clips, the gun profile's with the gun's clips.
---@param group GunworksStackedGroup
function ISStackedMagazine:getDurationsMs(group)
    local unloadSeconds, loadSeconds = nil, nil
    if group.animation then
        unloadSeconds, loadSeconds = group.unloadDuration, group.loadDuration
    else
        local handler = ReloadAnim.GetHandlerForGun(self.gun)
        unloadSeconds = handler and ReloadAnim.getProfileDuration(self, handler, "unload")
        loadSeconds = handler and ReloadAnim.getProfileDuration(self, handler, "load")
    end
    local unloadMs = unloadSeconds and ReloadAnim.getActionDurationMs(self, unloadSeconds, 0)
        or ISReloadWeaponAction.getReloadTime(self.character, 1200)
    local loadMs = loadSeconds and ReloadAnim.getActionDurationMs(self, loadSeconds, 0)
        or ISReloadWeaponAction.getReloadTime(self.character, 1500)
    return unloadMs, loadMs
end

function ISStackedMagazine:serverStart()
    self:initVars()
    local _, group = StackedMagazines.GetGunState(self.gun)
    if not group then
        self.netAction:forceComplete()
        return
    end

    local unloadMs, loadMs = self:getDurationsMs(group)
    self.phase = PHASE_UNLOAD
    emulateAnimEventOnce(self.netAction, unloadMs, "unloadFinished", nil)
    emulateAnimEventOnce(self.netAction, unloadMs + loadMs, "loadFinished", nil)
end

function ISStackedMagazine:getDuration()
    return -1
end

function ISStackedMagazine:complete()
    Magazine.manageMagazineAttachment(self.gun)
    if Animations.IsWeaponWithCustomStates(self.gun:getFullType()) then
        Animations.CheckStates(self.gun)
    end
    Animations.CallSyncHandWeaponFields(self.character, self.gun)
    return true
end

function ISStackedMagazine:clearReloadVariables()
    self.gun:setJobDelta(0.0)
    self.character:clearVariable("isLoading")
    self.character:clearVariable("isUnloading")
    self.character:clearVariable("WeaponReloadType")
    ReloadAnim.clearActionHandProp(self)
end

function ISStackedMagazine:stop()
    if self.gun:getInsertAmmoStopSound() then
        self.character:playSound(self.gun:getInsertAmmoStopSound())
    end
    self:clearReloadVariables()
    Magazine.manageMagazineAttachment(self.gun)
    Animations.CallSyncHandWeaponFields(self.character, self.gun)
    ISBaseTimedAction.stop(self)
end

function ISStackedMagazine:perform()
    if self.gun:getInsertAmmoStopSound() then
        self.character:playSound(self.gun:getInsertAmmoStopSound())
    end
    self:clearReloadVariables()

    local rack = self.rackAfter
    if not isClient() then
        rack = not self.gun:isRoundChambered() and self.gun:getCurrentAmmoCount() >= self.gun:getAmmoPerShoot()
    end
    if rack then
        ISTimedActionQueue.addAfter(self, ISRackFirearm:new(self.character, self.gun))
    end

    ISBaseTimedAction.perform(self)
end

function ISStackedMagazine:new(character, gun, gunworksReloadAiming)
    local o = ISBaseTimedAction.new(self, character)
    o.stopOnWalk = false
    o.stopOnRun = true
    o.stopOnAim = false
    o.maxTime = o:getDuration()
    o.useProgressBar = false
    o.gun = gun
    o.gunworksReloadAiming = gunworksReloadAiming
    return o
end
