require("TimedActions/ISBaseTimedAction")

local FoldingBipod = require("WeaponSystems/Utils/FoldingBipodUtils")

-------------------------------------------------
-- Foldable Bipod Timed Action
-------------------------------------------------
ISFoldBipod = ISBaseTimedAction:derive("ISFoldBipod")

function ISFoldBipod:isValid()
    return self.character:getPrimaryHandItem() == self.weapon
end

function ISFoldBipod:start()
    self:setOverrideHandModels(self.weapon, nil)
    self:setActionAnim(self.animation)
end

function ISFoldBipod:update()
end

function ISFoldBipod:perform()
    FoldingBipod.ToggleDeployBipod(self.weapon)
    ISBaseTimedAction.perform(self)
end

function ISFoldBipod:stop()
    ISBaseTimedAction.stop(self)
end

function ISFoldBipod:new(character, weapon, anim)
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
FoldBipodContext = {}

FoldBipodContext.callAction = function(player, weapon)
    if not player or not weapon then return end
    if player:getPrimaryHandItem() ~= weapon then
        ISTimedActionQueue.add(ISEquipWeaponAction:new(player, weapon, 50, true, true))
    end
    if weapon:getContainer() == player:getInventory() then
        ISTimedActionQueue.add(ISFoldBipod:new(player, weapon, CharacterActionAnims.Craft))
    end
end
