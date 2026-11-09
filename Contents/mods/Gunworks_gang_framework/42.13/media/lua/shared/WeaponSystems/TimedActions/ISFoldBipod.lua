require("TimedActions/ISBaseTimedAction")

local FoldingBipod = require("WeaponSystems/Utils/FoldingBipod")
local Animations = require("WeaponSystems/Utils/Animations")

-------------------------------------------------
-- Foldable Bipod Timed Action
-------------------------------------------------
ISFoldBipod = ISBaseTimedAction:derive("ISFoldBipod")

function ISFoldBipod:isValid()
    if isClient() and self.weapon then
        return self.character:getInventory():containsID(self.weapon:getID())
    end
    return self.character:getPrimaryHandItem() == self.weapon
end

function ISFoldBipod:start()
    if isClient() and self.weapon then
        self.weapon = self.character:getInventory():getItemById(self.weapon:getID())
    end
    Animations.CallSyncHandWeaponFields(self.character, self.weapon)
    -- Choose at start so queued toggles use the current bipod state.
    local animation = FoldingBipod.IsBipodDeployed(self.weapon) and "GW_BipodFold" or "GW_BipodUnfold"
    self:setActionAnim(animation)
    self:setOverrideHandModels(self.weapon, nil)
end

function ISFoldBipod:serverStart()
    local duration = FoldingBipod.IsBipodDeployed(self.weapon) and 2056 or 2139
    emulateAnimEventOnce(self.netAction, duration, "GW_BipodFinished", nil)
end

function ISFoldBipod:getDuration()
    return -1
end

function ISFoldBipod:animEvent(event, parameter)
    if event == "GW_BipodFinished" then
        if isServer() then
            self.netAction:forceComplete()
        else
            self:forceComplete()
        end
    end
end

function ISFoldBipod:update()
end

function ISFoldBipod:perform()
    ISBaseTimedAction.perform(self)
end

function ISFoldBipod:complete()
    FoldingBipod.ToggleDeployBipod(self.weapon)
    Animations.CallSyncHandWeaponFields(self.character, self.weapon)
    return true
end

function ISFoldBipod:stop()
    ISBaseTimedAction.stop(self)
end

function ISFoldBipod:new(character, weapon)
    local o = ISBaseTimedAction.new(self, character)
    o.stopOnWalk = false
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    o.weapon = weapon
    o.useProgressBar = false
    return o
end

-------------------------------------------------
-- Context Menu Helper
-------------------------------------------------
FoldBipodContext = {}

FoldBipodContext.callAction = function (player, weapon)
    if not player or not weapon then return end
    if player:getPrimaryHandItem() ~= weapon then
        ISTimedActionQueue.add(ISEquipWeaponAction:new(player, weapon, 50, true, true))
    end
    if weapon:getContainer() == player:getInventory() then
        ISTimedActionQueue.add(ISFoldBipod:new(player, weapon))
    end
end
