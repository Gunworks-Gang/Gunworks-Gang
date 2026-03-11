require("TimedActions/ISBaseTimedAction")

local Railing = require("WeaponSystems/Utils/RailingUtils")

-------------------------------------------------
-- Mount Accessory via Railing – Timed Action
-------------------------------------------------
ISRailingMount = ISBaseTimedAction:derive("ISRailingMount")

function ISRailingMount:isValid()
    return self.character:getPrimaryHandItem() == self.weapon
        and self.character:getInventory():contains(self.accessoryItem)
end

function ISRailingMount:start()
    self:setOverrideHandModels(self.weapon, nil)
    self:setActionAnim(CharacterActionAnims.Craft)
end

function ISRailingMount:update()
end

function ISRailingMount:perform()
    Railing.MountAccessory(self.weapon, self.accessoryItem, self.character)
    ISBaseTimedAction.perform(self)
end

function ISRailingMount:stop()
    ISBaseTimedAction.stop(self)
end

function ISRailingMount:new(character, weapon, accessoryItem)
    local o = ISBaseTimedAction.new(self, character)
    o.stopOnWalk = false
    o.stopOnRun = true
    o.maxTime = 60
    o.weapon = weapon
    o.accessoryItem = accessoryItem
    o.useProgressBar = true
    return o
end

-------------------------------------------------
-- Unmount Accessory from Railing – Timed Action
-------------------------------------------------
ISRailingUnmount = ISBaseTimedAction:derive("ISRailingUnmount")

function ISRailingUnmount:isValid()
    return self.character:getPrimaryHandItem() == self.weapon
end

function ISRailingUnmount:start()
    self:setOverrideHandModels(self.weapon, nil)
    self:setActionAnim(CharacterActionAnims.Craft)
end

function ISRailingUnmount:update()
end

function ISRailingUnmount:perform()
    Railing.UnmountAccessory(self.weapon, self.accessoryPart, self.character)
    ISBaseTimedAction.perform(self)
end

function ISRailingUnmount:stop()
    ISBaseTimedAction.stop(self)
end

function ISRailingUnmount:new(character, weapon, accessoryPart)
    local o = ISBaseTimedAction.new(self, character)
    o.stopOnWalk = false
    o.stopOnRun = true
    o.maxTime = 60
    o.weapon = weapon
    o.accessoryPart = accessoryPart
    o.useProgressBar = true
    return o
end

-------------------------------------------------
-- Context Menu Helpers
-------------------------------------------------
RailingContext = {}

RailingContext.mountAccessory = function(player, weapon, accessoryItem)
    if not player or not weapon or not accessoryItem then return end
    if player:getPrimaryHandItem() ~= weapon then
        ISTimedActionQueue.add(ISEquipWeaponAction:new(player, weapon, 50, true, true))
    end
    ISTimedActionQueue.add(ISRailingMount:new(player, weapon, accessoryItem))
end

RailingContext.unmountAccessory = function(player, weapon, accessoryPart)
    if not player or not weapon or not accessoryPart then return end
    if player:getPrimaryHandItem() ~= weapon then
        ISTimedActionQueue.add(ISEquipWeaponAction:new(player, weapon, 50, true, true))
    end
    ISTimedActionQueue.add(ISRailingUnmount:new(player, weapon, accessoryPart))
end
