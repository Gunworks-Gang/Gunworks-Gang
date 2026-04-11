require("TimedActions/ISBaseTimedAction")

local DynamicAttachment = require("WeaponSystems/Utils/DynamicAttachmentUtils")

-------------------------------------------------
-- Dynamic Attachment Swap Timed Action
-------------------------------------------------
ISSwapAttachment = ISBaseTimedAction:derive("ISSwapAttachment")

function ISSwapAttachment:isValid()
    if isClient() and self.weapon then
        return self.character:getInventory():containsID(self.weapon:getID())
    end
    return self.character:getPrimaryHandItem() == self.weapon
end

function ISSwapAttachment:start()
    if isClient() and self.weapon then
        self.weapon = self.character:getInventory():getItemById(self.weapon:getID())
    end
    self:setOverrideHandModels(self.weapon, nil)
    self:setActionAnim(self.animation)
end

function ISSwapAttachment:update()
end

function ISSwapAttachment:perform()
    ISBaseTimedAction.perform(self)
end

function ISSwapAttachment:complete()
    DynamicAttachment.SwapAttachment(self.weapon)
    syncHandWeaponFields(self.character, self.weapon)
    return true
end

function ISSwapAttachment:stop()
    ISBaseTimedAction.stop(self)
end

function ISSwapAttachment:new(character, weapon, anim)
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
SwapAttachmentContext = {}

SwapAttachmentContext.callAction = function(player, weapon)
    if not player or not weapon then return end
    if player:getPrimaryHandItem() ~= weapon then
        ISTimedActionQueue.add(ISEquipWeaponAction:new(player, weapon, 50, true, true))
    end
    if weapon:getContainer() == player:getInventory() then
        ISTimedActionQueue.add(ISSwapAttachment:new(player, weapon, CharacterActionAnims.Craft))
    end
end
