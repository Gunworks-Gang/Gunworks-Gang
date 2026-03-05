require("TimedActions/ISRackFirearm")

local Animations = require("AnimatedFiring/Utils/Animations")

local ISRackFirearm_animEvent_old = ISRackFirearm.animEvent
function ISRackFirearm:animEvent(event, parameter)
    if event == 'rackStart' then
        Animations.rackAction(self.character, self.gun, true)
    end
    if event == 'rackEnd' then
        Animations.rackAction(self.character, self.gun, false)
    end
    return ISRackFirearm_animEvent_old(self, event, parameter)
end
