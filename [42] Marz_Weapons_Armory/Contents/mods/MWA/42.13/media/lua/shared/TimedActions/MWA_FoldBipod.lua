require "TimedActions/ISBaseTimedAction"

-------------------------------------------------
-- Foldable Bipod Timed Action
-------------------------------------------------
MWA_FoldBipodAction = ISBaseTimedAction:derive("MWA_FoldBipodAction")

function MWA_FoldBipodAction:isValid()
    return self.character:getPrimaryHandItem() == self.weapon
end

function MWA_FoldBipodAction:start()
    self:setOverrideHandModels(self.weapon, nil)
    self:setActionAnim(self.animation)
end

function MWA_FoldBipodAction:update()
end

function MWA_FoldBipodAction:perform()
    MWA_Utils.ToggleDeployBipod(self.weapon)
    ISBaseTimedAction.perform(self)
end

function MWA_FoldBipodAction:stop()
    ISBaseTimedAction.stop(self)
end

function MWA_FoldBipodAction:new(character, weapon, anim)
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
MWA_FoldBipodContext = {}

MWA_FoldBipodContext.callAction = function(player, weapon)
    if not player or not weapon then return end
    if player:getPrimaryHandItem() ~= weapon then
        ISTimedActionQueue.add(ISEquipWeaponAction:new(player, weapon, 50, true, true))
    end
    if weapon:getContainer() == player:getInventory() then
        ISTimedActionQueue.add(MWA_FoldBipodAction:new(player, weapon, CharacterActionAnims.Craft))
    end
end
