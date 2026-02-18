require("TimedActions/ISReloadWeaponAction")
require("TimedActions/ISRackFirearm")

local ISReloadWeaponAction_stop_old = ISReloadWeaponAction.stop
function ISReloadWeaponAction:stop()
    MWAOpenModel(self.gun, false)
    self.character:resetEquippedHandsModels()
    return ISReloadWeaponAction_stop_old(self)
end

local ISReloadWeaponAction_animEvent_old = ISReloadWeaponAction.animEvent
function ISReloadWeaponAction:animEvent(event, parameter)
    if event == 'loadFinished' then
        MWAOpenModel(self.gun, false)
        return ISReloadWeaponAction_animEvent_old(self, event, parameter)
    end
    if event == 'changeWeaponSprite' then
        if parameter and parameter ~= '' then
            if parameter == 'open' then
                MWAOpenModel(self.gun, true)
            elseif parameter ~= 'original' then
                self.gun:setWeaponSprite(parameter)
            else
                MWAOpenModel(self.gun, false)
            end
            self.character:resetEquippedHandsModels()
        end
    else
        return ISReloadWeaponAction_animEvent_old(self, event, parameter)
    end
end

local ISRackFirearm_stop_old = ISRackFirearm.stop
function ISRackFirearm:stop()
    MWAOpenModel(self.gun, false)
    self.character:resetEquippedHandsModels()
    return ISRackFirearm_stop_old(self)
end

local ISRackFirearm_animEvent_old = ISRackFirearm.animEvent
function ISRackFirearm:animEvent(event, parameter)
    if event == 'unloadFinished' then
        MWAOpenModel(self.gun, false)
        return ISRackFirearm_animEvent_old(self, event, parameter)
    end
    if event == 'rackingFinished' then
        MWAOpenModel(self.gun, false)
        return ISRackFirearm_animEvent_old(self, event, parameter)
    end
    if event == 'changeWeaponSprite' then
        if parameter and parameter ~= '' then
            if parameter == 'open' then
                MWAOpenModel(self.gun, true)
            elseif parameter ~= 'original' then
                self.gun:setWeaponSprite(parameter)
            else
                MWAOpenModel(self.gun, false)
            end
            self.character:resetEquippedHandsModels()
        end
    else
        return ISRackFirearm_animEvent_old(self, event, parameter)
    end
end

local ISUnloadBulletsFromFirearm_animEvent_old = ISUnloadBulletsFromFirearm.animEvent
function ISUnloadBulletsFromFirearm:animEvent(event, parameter)
    if event == 'unloadFinished' then
        MWAOpenModel(self.gun, false)
        return ISUnloadBulletsFromFirearm_animEvent_old(self, event, parameter)
    end
    if event == 'changeWeaponSprite' then
        if parameter and parameter ~= '' then
            if parameter == 'open' then
                MWAOpenModel(self.gun, true)
            elseif parameter ~= 'original' then
                self.gun:setWeaponSprite(parameter)
            else
                MWAOpenModel(self.gun, false)
            end
            self.character:resetEquippedHandsModels()
        end
    else
        return ISUnloadBulletsFromFirearm_animEvent_old(self, event, parameter)
    end
end

local ISUnloadBulletsFromFirearm_stop_old = ISUnloadBulletsFromFirearm.stop
function ISUnloadBulletsFromFirearm:stop()
    MWAOpenModel(self.gun, false)
    self.character:resetEquippedHandsModels()
    return ISUnloadBulletsFromFirearm_stop_old(self)
end
