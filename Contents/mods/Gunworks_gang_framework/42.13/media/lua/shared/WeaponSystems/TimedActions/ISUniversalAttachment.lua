require("TimedActions/ISBaseTimedAction")

local Animations = require("WeaponSystems/Utils/Animations")
local UniversalAttachment = require("WeaponSystems/Utils/UniversalAttachment")

ISUniversalAttachmentInstall = ISBaseTimedAction:derive("ISUniversalAttachmentInstall")
ISUniversalAttachmentRemove = ISBaseTimedAction:derive("ISUniversalAttachmentRemove")

function ISUniversalAttachmentInstall:isValid()
    if not self.weapon or not self.genericPart or not self.outcomeFullType then return false end
    if not UniversalAttachment.CanInstallOutcome(self.weapon, self.outcomeFullType) then return false end

    if isClient() and self.weapon and self.genericPart then
        return self.character:getInventory():containsID(self.weapon:getID())
            and self.character:getInventory():containsID(self.genericPart:getID())
    end

    return self.character:getInventory():contains(self.weapon)
        and self.character:getInventory():contains(self.genericPart)
end

function ISUniversalAttachmentInstall:update()
    self.weapon:setJobDelta(self:getJobDelta())
    self.genericPart:setJobDelta(self:getJobDelta())
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function ISUniversalAttachmentInstall:start()
    if isClient() then
        if self.weapon then
            self.weapon = self.character:getInventory():getItemById(self.weapon:getID())
        end
        if self.genericPart then
            self.genericPart = self.character:getInventory():getItemById(self.genericPart:getID())
        end
    end

    self.weapon:setJobType(getText("ContextMenu_Add_Weapon_Upgrade"))
    self.weapon:setJobDelta(0.0)
    self.genericPart:setJobType(getText("ContextMenu_Add_Weapon_Upgrade"))
    self.genericPart:setJobDelta(0.0)
    self:setActionAnim(CharacterActionAnims.Craft)
end

function ISUniversalAttachmentInstall:stop()
    ISBaseTimedAction.stop(self)
    self.weapon:setJobDelta(0.0)
    self.genericPart:setJobDelta(0.0)
end

function ISUniversalAttachmentInstall:perform()
    self.weapon:setJobDelta(0.0)
    self.genericPart:setJobDelta(0.0)
    ISBaseTimedAction.perform(self)
end

function ISUniversalAttachmentInstall:complete()
    local outcomePart = instanceItem(self.outcomeFullType)
    if not outcomePart or not instanceof(outcomePart, "WeaponPart") then
        return false
    end

    self.weapon:attachWeaponPart(outcomePart, true)
    self.character:getInventory():Remove(self.genericPart)
    sendRemoveItemFromContainer(self.character:getInventory(), self.genericPart)
    Animations.CallSyncHandWeaponFields(self.character, self.weapon)
    return true
end

function ISUniversalAttachmentInstall:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 50
end

function ISUniversalAttachmentInstall:new(character, weapon, genericPart, outcomeFullType)
    local o = ISBaseTimedAction.new(self, character)
    o.weapon = weapon
    o.genericPart = genericPart
    o.outcomeFullType = outcomeFullType
    o.stopOnWalk = false
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    o.useProgressBar = true
    return o
end

function ISUniversalAttachmentRemove:isValid()
    if not self.weapon or not self.partType then return false end

    if isClient() and self.weapon then
        return self.character:getInventory():containsID(self.weapon:getID())
    end

    if not self.character:getInventory():contains(self.weapon) then
        return false
    end

    local installedPart = self.weapon:getWeaponPart(self.partType)
    if not installedPart then return false end

    return UniversalAttachment.CanRemoveInstalledPart(self.weapon, installedPart)
end

function ISUniversalAttachmentRemove:update()
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function ISUniversalAttachmentRemove:start()
    if isClient() and self.weapon then
        self.weapon = self.character:getInventory():getItemById(self.weapon:getID())
    end

    Animations.CallSyncHandWeaponFields(self.character, self.weapon)
    self:setActionAnim(CharacterActionAnims.Craft)
end

function ISUniversalAttachmentRemove:stop()
    ISBaseTimedAction.stop(self)
end

function ISUniversalAttachmentRemove:perform()
    ISBaseTimedAction.perform(self)
end

function ISUniversalAttachmentRemove:complete()
    local installedPart = self.weapon:getWeaponPart(self.partType)
    if not installedPart then
        return false
    end

    if not UniversalAttachment.CanRemoveInstalledPart(self.weapon, installedPart) then
        return false
    end

    local genericItemType = self.genericItemType or UniversalAttachment.GetGenericItemTypeForOutcome(self.weapon, installedPart)
    if not genericItemType then
        return false
    end

    self.weapon:detachWeaponPart(self.character, installedPart)
    local refundedItem = self.character:getInventory():AddItem(genericItemType)
    if refundedItem then
        sendAddItemToContainer(self.character:getInventory(), refundedItem)
    end
    Animations.CallSyncHandWeaponFields(self.character, self.weapon)
    return true
end

function ISUniversalAttachmentRemove:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 50
end

function ISUniversalAttachmentRemove:new(character, weapon, partType, genericItemType)
    local o = ISBaseTimedAction.new(self, character)
    o.weapon = weapon
    o.partType = partType
    o.genericItemType = genericItemType
    o.stopOnWalk = false
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    o.useProgressBar = true
    return o
end
