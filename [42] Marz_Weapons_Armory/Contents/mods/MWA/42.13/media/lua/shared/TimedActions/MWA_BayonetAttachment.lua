require "TimedActions/ISBaseTimedAction"

local SWMG_Bayonet = require "Utils/MWA_BayonetUtils"

-------------------------------------------------
-- Attach Bayonet Timed Action
-------------------------------------------------
MWA_AttachBayonetAction = ISBaseTimedAction:derive("MWA_AttachBayonetAction")

function MWA_AttachBayonetAction:isValid()
    return self.character:getPrimaryHandItem() == self.weapon and
        self.bayonetKnife and
        self.character:getInventory():contains(self.bayonetKnife)
end

function MWA_AttachBayonetAction:start()
    self:setOverrideHandModels(self.weapon, nil)
    self:setActionAnim(CharacterActionAnims.Craft)
end

function MWA_AttachBayonetAction:update()
end

function MWA_AttachBayonetAction:perform()
    SWMG_Bayonet.AttachBayonet(self.weapon, self.bayonetKnife, self.character)
    ISBaseTimedAction.perform(self)
end

function MWA_AttachBayonetAction:stop()
    ISBaseTimedAction.stop(self)
end

function MWA_AttachBayonetAction:new(character, weapon, bayonetKnife)
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
MWA_RemoveBayonetAction = ISBaseTimedAction:derive("MWA_RemoveBayonetAction")

function MWA_RemoveBayonetAction:isValid()
    return self.character:getPrimaryHandItem() == self.weapon and
        SWMG_Bayonet.CanRemoveBayonet(self.weapon)
end

function MWA_RemoveBayonetAction:start()
    self:setOverrideHandModels(self.weapon, nil)
    self:setActionAnim(CharacterActionAnims.Craft)
end

function MWA_RemoveBayonetAction:update()
end

function MWA_RemoveBayonetAction:perform()
    SWMG_Bayonet.RemoveBayonet(self.weapon, self.character)
    ISBaseTimedAction.perform(self)
end

function MWA_RemoveBayonetAction:stop()
    ISBaseTimedAction.stop(self)
end

function MWA_RemoveBayonetAction:new(character, weapon)
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
MWA_BayonetAttachmentContext = {}

MWA_BayonetAttachmentContext.attachBayonet = function(player, weapon, bayonetKnife)
    if not player or not weapon or not bayonetKnife then return end
    if player:getPrimaryHandItem() ~= weapon then
        ISTimedActionQueue.add(ISEquipWeaponAction:new(player, weapon, 50, true, true))
    end
    ISTimedActionQueue.add(MWA_AttachBayonetAction:new(player, weapon, bayonetKnife))
end

MWA_BayonetAttachmentContext.removeBayonet = function(player, weapon)
    if not player or not weapon then return end
    if player:getPrimaryHandItem() ~= weapon then
        ISTimedActionQueue.add(ISEquipWeaponAction:new(player, weapon, 50, true, true))
    end
    ISTimedActionQueue.add(MWA_RemoveBayonetAction:new(player, weapon))
end
