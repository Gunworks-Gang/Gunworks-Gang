require("TimedActions/ISBaseTimedAction")

local FoldingStock = require("WeaponSystems/Utils/FoldingStockUtils")

-------------------------------------------------
-- Foldable Stock Timed Action
-------------------------------------------------
ISFoldStock = ISBaseTimedAction:derive("ISFoldStock")

function ISFoldStock:isValid()
    return self.character:getPrimaryHandItem() == self.weapon
end

function ISFoldStock:start()
    self:setOverrideHandModels(self.weapon, nil)
    self:setActionAnim(self.animation)
end

function ISFoldStock:update()
end

function ISFoldStock:perform()
    FoldingStock.ToggleFoldStock(self.weapon)
    ISBaseTimedAction.perform(self)
end

function ISFoldStock:stop()
    ISBaseTimedAction.stop(self)
end

function ISFoldStock:new(character, weapon, anim)
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
FoldStockContext = {}

FoldStockContext.callAction = function(player, weapon)
    if not player or not weapon then return end
    if player:getPrimaryHandItem() ~= weapon then
        ISTimedActionQueue.add(ISEquipWeaponAction:new(player, weapon, 50, true, true))
    end
    if weapon:getContainer() == player:getInventory() then
        ISTimedActionQueue.add(ISFoldStock:new(player, weapon, CharacterActionAnims.Craft))
    end
end
