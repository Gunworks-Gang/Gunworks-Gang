require "TimedActions/ISBaseTimedAction"

local Bayonet = require "WeaponSystems/Utils/BayonetUtils.lua"

-------------------------------------------------
-- Attach Bayonet Timed Action
-------------------------------------------------
ISBayonetAttach = ISBaseTimedAction:derive("ISBayonetAttach")

function ISBayonetAttach:isValid()
    return self.character:getPrimaryHandItem() == self.weapon and
        self.bayonetKnife and
        self.character:getInventory():contains(self.bayonetKnife)
end

function ISBayonetAttach:start()
    self:setOverrideHandModels(self.weapon, nil)
    self:setActionAnim(CharacterActionAnims.Craft)
end

function ISBayonetAttach:update()
end

function ISBayonetAttach:perform()
    Bayonet.AttachBayonet(self.weapon, self.bayonetKnife, self.character)
    ISBaseTimedAction.perform(self)
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
    return self.character:getPrimaryHandItem() == self.weapon and
        Bayonet.CanRemoveBayonet(self.weapon)
end

function ISBayonetRemove:start()
    self:setOverrideHandModels(self.weapon, nil)
    self:setActionAnim(CharacterActionAnims.Craft)
end

function ISBayonetRemove:update()
end

function ISBayonetRemove:perform()
    Bayonet.RemoveBayonet(self.weapon, self.character)
    ISBaseTimedAction.perform(self)
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
