require "TimedActions/ISBaseTimedAction"

-------------------------------------------------
-- Foldable Stock Timed Action
-------------------------------------------------
MWA_FoldStockAction = ISBaseTimedAction:derive("MWA_FoldStockAction")

function MWA_FoldStockAction:isValid()
    return self.character:getPrimaryHandItem() == self.weapon
end

function MWA_FoldStockAction:start()
    self:setOverrideHandModels(self.weapon, nil)
    self:setActionAnim(self.animation)
end

function MWA_FoldStockAction:update()
end

function MWA_FoldStockAction:perform()
    MWA_Utils.ToggleFoldStock(self.weapon)
    ISBaseTimedAction.perform(self)
end

function MWA_FoldStockAction:stop()
    ISBaseTimedAction.stop(self)
end

function MWA_FoldStockAction:new(character, weapon, anim)
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
MWA_FoldStockContext = {}

MWA_FoldStockContext.callAction = function(player, weapon)
    if not player or not weapon then return end
    if player:getPrimaryHandItem() ~= weapon then
        ISTimedActionQueue.add(ISEquipWeaponAction:new(player, weapon, 50, true, true))
    end
    if weapon:getContainer() == player:getInventory() then
        ISTimedActionQueue.add(MWA_FoldStockAction:new(player, weapon, CharacterActionAnims.Craft))
    end
end
