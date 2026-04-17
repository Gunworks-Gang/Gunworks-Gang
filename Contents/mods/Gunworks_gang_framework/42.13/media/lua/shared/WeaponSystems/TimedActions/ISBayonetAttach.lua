require("TimedActions/ISBaseTimedAction")

local Bayonet = require("WeaponSystems/Utils/Bayonet")
local Animations = require("WeaponSystems/Utils/Animations")

-------------------------------------------------
-- Attach Bayonet Timed Action
-------------------------------------------------
ISBayonetAttach = ISBaseTimedAction:derive("ISBayonetAttach")

function ISBayonetAttach:isValid()
    if isClient() and self.weapon and self.bayonetKnife then
        return self.character:getInventory():containsID(self.weapon:getID())
            and self.character:getInventory():containsID(self.bayonetKnife:getID())
    end
    return self.character:getPrimaryHandItem() == self.weapon and
        self.bayonetKnife and
        self.character:getInventory():contains(self.bayonetKnife)
end

function ISBayonetAttach:start()
    if isClient() then
        if self.weapon then
            self.weapon = self.character:getInventory():getItemById(self.weapon:getID())
        end
        if self.bayonetKnife then
            self.bayonetKnife = self.character:getInventory():getItemById(self.bayonetKnife:getID())
        end
    end
    Animations.CallSyncHandWeaponFields(self.character, self.weapon)
    self:setActionAnim(CharacterActionAnims.Craft)
end

function ISBayonetAttach:update()
end

function ISBayonetAttach:perform()
    ISBaseTimedAction.perform(self)
end

function ISBayonetAttach:complete()
    Bayonet.AttachBayonet(self.weapon, self.bayonetKnife, self.character)
    Animations.CallSyncHandWeaponFields(self.character, self.weapon)
    sendRemoveItemFromContainer(self.character:getInventory(), self.bayonetKnife)
    return true
end

function ISBayonetAttach:stop()
    ISBaseTimedAction.stop(self)
end

function ISBayonetAttach:new(character, weapon, bayonetKnife)
    local o = ISBaseTimedAction.new(self, character)
    o.stopOnWalk = false
    o.stopOnRun = true
    o.maxTime = 60
    o.weapon = weapon
    o.bayonetKnife = bayonetKnife
    o.useProgressBar = true
    return o
end

-------------------------------------------------
-- Remove Bayonet Timed Action
-------------------------------------------------
ISBayonetRemove = ISBaseTimedAction:derive("ISBayonetRemove")

function ISBayonetRemove:isValid()
    if isClient() and self.weapon then
        return self.character:getInventory():containsID(self.weapon:getID())
    end
    return self.character:getPrimaryHandItem() == self.weapon and
        Bayonet.CanRemoveBayonet(self.weapon)
end

function ISBayonetRemove:start()
    if isClient() and self.weapon then
        self.weapon = self.character:getInventory():getItemById(self.weapon:getID())
    end
    Animations.CallSyncHandWeaponFields(self.character, self.weapon)
    self:setActionAnim(CharacterActionAnims.Craft)
end

function ISBayonetRemove:update()
end

function ISBayonetRemove:perform()
    ISBaseTimedAction.perform(self)
end

function ISBayonetRemove:complete()
    local success, returnedKnife = Bayonet.RemoveBayonet(self.weapon, self.character)
    Animations.CallSyncHandWeaponFields(self.character, self.weapon)
    if returnedKnife then
        sendAddItemToContainer(self.character:getInventory(), returnedKnife)
    end
    return true
end

function ISBayonetRemove:stop()
    ISBaseTimedAction.stop(self)
end

function ISBayonetRemove:new(character, weapon)
    local o = ISBaseTimedAction.new(self, character)
    o.stopOnWalk = false
    o.stopOnRun = true
    o.maxTime = 60
    o.weapon = weapon
    o.useProgressBar = true
    return o
end

-------------------------------------------------
-- Context Menu Helpers
-------------------------------------------------
BayonetAttachmentContext = {}

BayonetAttachmentContext.attachBayonet = function(player, weapon, bayonetKnife)
    if not player or not weapon or not bayonetKnife then return end
    if player:getPrimaryHandItem() ~= weapon then
        ISTimedActionQueue.add(ISEquipWeaponAction:new(player, weapon, 50, true, true))
    end
    ISTimedActionQueue.add(ISBayonetAttach:new(player, weapon, bayonetKnife))
end

BayonetAttachmentContext.removeBayonet = function(player, weapon)
    if not player or not weapon then return end
    if player:getPrimaryHandItem() ~= weapon then
        ISTimedActionQueue.add(ISEquipWeaponAction:new(player, weapon, 50, true, true))
    end
    ISTimedActionQueue.add(ISBayonetRemove:new(player, weapon))
end
