require("TimedActions/ISReloadWeaponAction")
require("TimedActions/ISRackFirearm")

local Animations = require("AnimatedFiring/Utils/Animations")

local ISReloadWeaponAction_stop_old = ISReloadWeaponAction.stop
function ISReloadWeaponAction:stop()
    Animations.CallAnimationFunction(self.gun, false)
    self.character:resetEquippedHandsModels()
    Animations.SyncSlideState(self.character, self.gun, false)
    return ISReloadWeaponAction_stop_old(self)
end

local ISReloadWeaponAction_animEvent_old = ISReloadWeaponAction.animEvent
function ISReloadWeaponAction:animEvent(event, parameter)
    if event == 'loadFinished' then
        Animations.CallAnimationFunction(self.gun, false)
        self.character:resetEquippedHandsModels()
        Animations.SyncSlideState(self.character, self.gun, false)
        return ISReloadWeaponAction_animEvent_old(self, event, parameter)
    end
    if event == 'changeWeaponSprite' then
        if parameter and parameter ~= '' then
            local open = parameter ~= 'original'
            Animations.CallAnimationFunction(self.gun, open)
            self.character:resetEquippedHandsModels()
            Animations.SyncSlideState(self.character, self.gun, open)
        end
    else
        return ISReloadWeaponAction_animEvent_old(self, event, parameter)
    end
end

local ISRackFirearm_stop_old = ISRackFirearm.stop
function ISRackFirearm:stop()
    Animations.CallAnimationFunction(self.gun, false)
    self.character:resetEquippedHandsModels()
    Animations.SyncSlideState(self.character, self.gun, false)
    return ISRackFirearm_stop_old(self)
end

local ISRackFirearm_animEvent_old = ISRackFirearm.animEvent
function ISRackFirearm:animEvent(event, parameter)
    if event == 'unloadFinished' then
        Animations.CallAnimationFunction(self.gun, false)
        self.character:resetEquippedHandsModels()
        Animations.SyncSlideState(self.character, self.gun, false)
        return ISRackFirearm_animEvent_old(self, event, parameter)
    end
    if event == 'rackingFinished' then
        -- Racking is manual pull-and-release — bolt always goes forward.
        -- Slide-lock-on-empty is handled by lockActionOpen/releaseActionLock on fire.
        Animations.CallAnimationFunction(self.gun, false)
        self.character:resetEquippedHandsModels()
        Animations.SyncSlideState(self.character, self.gun, false)
        return ISRackFirearm_animEvent_old(self, event, parameter)
    end
    if event == 'changeWeaponSprite' then
        if parameter and parameter ~= '' then
            local open = parameter ~= 'original'
            Animations.CallAnimationFunction(self.gun, open)
            self.character:resetEquippedHandsModels()
            Animations.SyncSlideState(self.character, self.gun, open)
        end
    else
        return ISRackFirearm_animEvent_old(self, event, parameter)
    end
end

local ISUnloadBulletsFromFirearm_animEvent_old = ISUnloadBulletsFromFirearm.animEvent
function ISUnloadBulletsFromFirearm:animEvent(event, parameter)
    if event == 'unloadFinished' then
        Animations.CallAnimationFunction(self.gun, false)
        self.character:resetEquippedHandsModels()
        return ISUnloadBulletsFromFirearm_animEvent_old(self, event, parameter)
    end
    if event == 'changeWeaponSprite' then
        if parameter and parameter ~= '' then
            local open = parameter ~= 'original'
            Animations.CallAnimationFunction(self.gun, open)
            self.character:resetEquippedHandsModels()
            Animations.SyncSlideState(self.character, self.gun, open)
        end
    else
        return ISUnloadBulletsFromFirearm_animEvent_old(self, event, parameter)
    end
end

local ISUnloadBulletsFromFirearm_stop_old = ISUnloadBulletsFromFirearm.stop
function ISUnloadBulletsFromFirearm:stop()
    Animations.CallAnimationFunction(self.gun, false)
    self.character:resetEquippedHandsModels()
    Animations.SyncSlideState(self.character, self.gun, false)
    return ISUnloadBulletsFromFirearm_stop_old(self)
end
