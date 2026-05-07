require("TimedActions/ISBaseTimedAction")

local Railing     = require("WeaponSystems/Utils/Railing")
local Underbarrel = require("WeaponSystems/Utils/Underbarrel")
local Animations  = require("WeaponSystems/Utils/Animations")

-------------------------------------------------
-- Mount Accessory via Railing – Timed Action
-------------------------------------------------
ISRailingMount    = ISBaseTimedAction:derive("ISRailingMount")

function ISRailingMount:isValid()
    if isClient() and self.weapon and self.accessoryItem then
        return self.character:getInventory():containsID(self.weapon:getID())
            and self.character:getInventory():containsID(self.accessoryItem:getID())
    end
    return self.character:getPrimaryHandItem() == self.weapon
        and self.character:getInventory():contains(self.accessoryItem)
end

function ISRailingMount:start()
    if isClient() then
        if self.weapon then
            self.weapon = self.character:getInventory():getItemById(self.weapon:getID())
        end
        if self.accessoryItem then
            self.accessoryItem = self.character:getInventory():getItemById(self.accessoryItem:getID())
        end
    end
    Animations.CallSyncHandWeaponFields(self.character, self.weapon)
    self:setActionAnim(CharacterActionAnims.Craft)
end

function ISRailingMount:update()
end

function ISRailingMount:perform()
    ISBaseTimedAction.perform(self)
end

function ISRailingMount:complete()
    Railing.MountAccessory(self.weapon, self.accessoryItem, self.character)
    Animations.CallSyncHandWeaponFields(self.character, self.weapon)
    sendRemoveItemFromContainer(self.character:getInventory(), self.accessoryItem)
    return true
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
    if self.weapon and self.accessoryPart and Underbarrel.IsWeaponInUnderbarrelMode(self.weapon) then
        if Underbarrel.UnderbarrelAttachments[self.accessoryPart:getFullType()] then
            return false
        end
    end
    if isClient() and self.weapon then
        return self.character:getInventory():containsID(self.weapon:getID())
    end
    return self.character:getPrimaryHandItem() == self.weapon
end

function ISRailingUnmount:start()
    if isClient() and self.weapon then
        self.weapon = self.character:getInventory():getItemById(self.weapon:getID())
    end
    Animations.CallSyncHandWeaponFields(self.character, self.weapon)
    self:setActionAnim(CharacterActionAnims.Craft)
end

function ISRailingUnmount:update()
end

function ISRailingUnmount:perform()
    ISBaseTimedAction.perform(self)
end

function ISRailingUnmount:complete()
    Underbarrel.HandleAttachmentRemoval(self.weapon, self.accessoryPart, self.character)
    local success, returnedItem = Railing.UnmountAccessory(self.weapon, self.accessoryPart, self.character)
    Animations.CallSyncHandWeaponFields(self.character, self.weapon)
    if returnedItem then
        sendAddItemToContainer(self.character:getInventory(), returnedItem)
    end
    return true
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
