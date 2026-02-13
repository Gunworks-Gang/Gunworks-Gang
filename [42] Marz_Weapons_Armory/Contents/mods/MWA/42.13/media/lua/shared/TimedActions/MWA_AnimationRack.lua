require "TimedActions/ISRackFirearm"

local ISRackFirearm_animEvent_old = ISRackFirearm.animEvent
function ISRackFirearm:animEvent(event, parameter)
    if event == 'rackStart' then
        AnimationWeaponAction.rackAction(self.character, self.gun, true)
    end
    if event == 'rackEnd' then
        AnimationWeaponAction.rackAction(self.character, self.gun, false)
    end
    return ISRackFirearm_animEvent_old(self, event, parameter)
end
