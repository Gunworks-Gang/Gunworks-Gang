require("TimedActions/ISBaseTimedAction")

local FoldingStock = require("WeaponSystems/Utils/FoldingStockUtils")

-------------------------------------------------
-- Foldable Stock Timed Action
-------------------------------------------------
ISFoldStock = ISBaseTimedAction:derive("ISFoldStock")

function ISFoldStock:isValid()
    if isClient() and self.weapon then
        return self.character:getInventory():containsID(self.weapon:getID())
    end
    return self.character:getPrimaryHandItem() == self.weapon
end

function ISFoldStock:start()
    if isClient() and self.weapon then
        self.weapon = self.character:getInventory():getItemById(self.weapon:getID())
    end
    self:setOverrideHandModels(self.weapon, nil)
    self:setActionAnim(self.animation)
end

function ISFoldStock:update()
end

function ISFoldStock:perform()
    ISBaseTimedAction.perform(self)
end

function ISFoldStock:complete()
    FoldingStock.ToggleFoldStock(self.weapon)
    syncHandWeaponFields(self.character, self.weapon)
    -- Broadcast sprite changes for models-mode (not covered by native sync packet)
    local entry = FoldingStock.WeaponsWithFoldableStock[self.weapon:getFullType()]
    if entry and entry.models then
        local onlinePlayers = getOnlinePlayers()
        if onlinePlayers then
            for i = 0, onlinePlayers:size() - 1 do
                sendServerCommand(onlinePlayers:get(i), "SWMG", "syncWeapon", {
                    onlineID    = self.character:getOnlineID(),
                    itemId      = self.weapon:getID(),
                    StockFolded = self.weapon:getModData().StockFolded,
                })
            end
        end
    end
    return true
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
