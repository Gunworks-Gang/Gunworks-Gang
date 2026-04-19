require("TimedActions/ISBaseTimedAction")

local Bayonet             = require("WeaponSystems/Utils/Bayonet")
local Animations          = require("WeaponSystems/Utils/Animations")

-------------------------------------------------
-- Toggle Integrated Bayonet Timed Action
-------------------------------------------------
ISToggleIntegratedBayonet = ISBaseTimedAction:derive("ISToggleIntegratedBayonet")

function ISToggleIntegratedBayonet:isValid()
    if isClient() and self.weapon then
        return self.character:getInventory():containsID(self.weapon:getID())
    end
    return self.character:getPrimaryHandItem() == self.weapon
end

function ISToggleIntegratedBayonet:start()
    if isClient() and self.weapon then
        self.weapon = self.character:getInventory():getItemById(self.weapon:getID())
    end
    Animations.CallSyncHandWeaponFields(self.character, self.weapon)
    self:setActionAnim(self.animation)
end

function ISToggleIntegratedBayonet:update()
end

function ISToggleIntegratedBayonet:perform()
    ISBaseTimedAction.perform(self)
end

function ISToggleIntegratedBayonet:complete()
    Bayonet.ToggleIntegratedBayonet(self.weapon)
    Animations.CallSyncHandWeaponFields(self.character, self.weapon)
    if isClient() then
        sendClientCommand("SWMG", "syncWeapon", {
            onlineID           = self.character:getOnlineID(),
            itemId             = self.weapon:getID(),
            GW_BayonetDeployed = self.weapon:getModData().GW_BayonetDeployed,
        })
    end
    return true
end

function ISToggleIntegratedBayonet:stop()
    ISBaseTimedAction.stop(self)
end

function ISToggleIntegratedBayonet:new(character, weapon, anim)
    local o          = ISBaseTimedAction.new(self, character)
    o.stopOnWalk     = false
    o.stopOnRun      = true
    o.maxTime        = 30
    o.weapon         = weapon
    o.animation      = anim
    o.useProgressBar = false
    return o
end
