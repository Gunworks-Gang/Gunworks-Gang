require "TimedActions/ISBaseTimedAction"

-------------------------------------------------
-- Foldable Stock Timed Action
-------------------------------------------------
MWA_AttachBayonetAction = ISBaseTimedAction:derive("MWA_AttachBayonetAction")

function MWA_AttachBayonetAction:isValid()
    return self.character:getPrimaryHandItem() == self.weapon
end

function MWA_AttachBayonetAction:start()
    self:setOverrideHandModels(self.weapon, nil)
    self:setActionAnim(self.animation)
end

function MWA_AttachBayonetAction:update()
end

function MWA_AttachBayonetAction:perform()
    MWA_Utils.ToggleFoldStock(self.weapon)
    ISBaseTimedAction.perform(self)
end

function MWA_AttachBayonetAction:stop()
    ISBaseTimedAction.stop(self)
end

function MWA_AttachBayonetAction:new(character, weapon, anim)
    local o = ISBaseTimedAction.new(self, character)
    o.stopOnWalk = false
    o.stopOnRun = true
    o.maxTime = 30
    o.weapon = weapon
    o.animation = anim
    o.useProgressBar = false
    return o
end

-------------------------------------------------
-- Context Menu Helper
-------------------------------------------------
MWA_AttachBayonetContext = {}

MWA_AttachBayonetContext.callAction = function(player, weapon)
    if not player or not weapon then return end
    if player:getPrimaryHandItem() ~= weapon then
        ISTimedActionQueue.add(ISEquipWeaponAction:new(player, weapon, 50, true, true))
    end
    if weapon:getContainer() == player:getInventory() then
        ISTimedActionQueue.add(MWA_AttachBayonetAction:new(player, weapon, CharacterActionAnims.Craft))
    end
end
