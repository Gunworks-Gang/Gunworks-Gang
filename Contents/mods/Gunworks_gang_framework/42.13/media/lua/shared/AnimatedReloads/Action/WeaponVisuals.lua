---@class AnimatedReloadsAction
local AnimatedReloadsAction = require("AnimatedReloads/Action/Core")
---@param source AnimatedReloadsPartSpec|string|nil
---@param handler AnimatedReloadsHandler|nil
---@return AnimatedReloadsPartSpec|nil
function AnimatedReloadsAction.resolvePartSpec(source, handler)
    if not source then
        return nil
    end

    if type(source) == "string" then
        if not handler or not handler.parts then
            return nil
        end

        local byId = handler.parts[source]
        if byId then
            return byId
        end

        return nil
    end

    if type(source) == "table" then
        return source
    end

    return nil
end

---@param gun HandWeapon|nil
---@param itemType string|nil
---@return WeaponPart|nil
function AnimatedReloadsAction.getWeaponPartByItemType(gun, itemType)
    if not gun or not itemType or itemType == "" then
        return nil
    end

    local parts = gun:getAllWeaponParts()
    if not parts then
        return nil
    end

    if parts.size and parts.get then
        for i = 0, parts:size() - 1 do
            local part = parts:get(i)
            if part and part:getFullType() == itemType then
                return part
            end
        end
    else
        for i = 1, #parts do
            local part = parts[i]
            if part and part:getFullType() == itemType then
                return part
            end
        end
    end

    return nil
end

---@param action ISBaseTimedAction
---@param gun HandWeapon|nil
---@param spec AnimatedReloadsPartSpec|nil
---@return nil
function AnimatedReloadsAction.attachWeaponPartSpec(action, gun, spec)
    if not action or not gun or not spec or not spec.itemType or spec.itemType == "" then
        return
    end

    if spec.partType and spec.partType ~= "" then
        local currentPart = gun:getWeaponPart(spec.partType)
        if currentPart and currentPart:getFullType() == spec.itemType then
            return
        end
    else
        local existingPart = AnimatedReloadsAction.getWeaponPartByItemType(gun, spec.itemType)
        if existingPart then
            return
        end
    end

    local part = instanceItem(spec.itemType)
    if not part or not instanceof(part, "WeaponPart") then
        return
    end

    gun:attachWeaponPart(action.character, part, spec.doChange == true)
end

---@param action ISBaseTimedAction
---@param gun HandWeapon|nil
---@param spec AnimatedReloadsPartSpec|nil
---@return nil
function AnimatedReloadsAction.detachWeaponPartSpec(action, gun, spec)
    if not action or not gun or not spec then
        return
    end

    local part = nil
    if spec.partType and spec.partType ~= "" then
        part = gun:getWeaponPart(spec.partType)
        if part and spec.itemType and spec.itemType ~= "" and part:getFullType() ~= spec.itemType then
            part = nil
        end
    end

    if not part and spec.itemType and spec.itemType ~= "" then
        part = AnimatedReloadsAction.getWeaponPartByItemType(gun, spec.itemType)
    end

    if not part then
        return
    end

    gun:detachWeaponPart(action.character, part, spec.doChange == true)
end

---@param action ISBaseTimedAction
---@param gun HandWeapon
---@param handler AnimatedReloadsHandler
---@param stateKey string|nil
---@return boolean
function AnimatedReloadsAction.applyWeaponAttachmentState(action, gun, handler, stateKey)
    if not stateKey or stateKey == "" or not handler.states then
        return false
    end

    local state = handler.states[stateKey]
    if not state then
        return false
    end

    if state.detach then
        for i = 1, #state.detach do
            local spec = AnimatedReloadsAction.resolvePartSpec(state.detach[i], handler)
            AnimatedReloadsAction.detachWeaponPartSpec(action, gun, spec)
        end
    end

    if state.attach then
        for i = 1, #state.attach do
            local spec = AnimatedReloadsAction.resolvePartSpec(state.attach[i], handler)
            AnimatedReloadsAction.attachWeaponPartSpec(action, gun, spec)
        end
    end

    return true
end

---@param action ISBaseTimedAction
---@param handler AnimatedReloadsHandler|nil
---@param preferActionGun boolean|nil
---@return HandWeapon|nil
function AnimatedReloadsAction.resolveActionGun(action, handler, preferActionGun)
    if not action then
        return nil
    end

    if preferActionGun and action.gun and instanceof(action.gun, "HandWeapon") then
        return action.gun
    end

    if action.character then
        local item = action.character:getPrimaryHandItem()
        if instanceof(item, "HandWeapon") then
            return item
        end
    end

    if action.gun and instanceof(action.gun, "HandWeapon") then
        return action.gun
    end

    return nil
end

---@param action ISBaseTimedAction
---@param handler AnimatedReloadsHandler|nil
---@param stateKey string|nil
---@return boolean
function AnimatedReloadsAction.setWeaponAttachmentState(action, handler, stateKey)
    if not action or not handler then
        return false
    end

    local gun = AnimatedReloadsAction.resolveActionGun(action, handler, true)
    if not gun then
        return false
    end

    local changed = AnimatedReloadsAction.applyWeaponAttachmentState(action, gun, handler, stateKey)
    if not changed then
        return false
    end

    if action.character then
        action.character:resetEquippedHandsModels()
        if syncHandWeaponFields then
            syncHandWeaponFields(action.character, gun)
        end
    end

    return true
end

---@param action ISBaseTimedAction|nil
---@nodiscard
---@return boolean
function AnimatedReloadsAction.isEjectAction(action)
    return action and action.Type == "ISEjectMagazine" or false
end

---@param action ISBaseTimedAction|nil
---@nodiscard
---@return boolean
function AnimatedReloadsAction.isInsertAction(action)
    return action and action.Type == "ISInsertMagazine" or false
end

---@param handler AnimatedReloadsHandler|nil
---@param parameter string|nil
---@return AnimatedReloadsPartSpec|nil
function AnimatedReloadsAction.resolveEventPartSpec(handler, parameter)
    if not handler or not parameter or parameter == "" then
        return nil
    end

    local direct = AnimatedReloadsAction.resolvePartSpec(parameter, handler)
    if direct then
        return direct
    end

    if not handler.parts then
        return nil
    end

    local __parts = handler.parts
    for _, spec in pairs(__parts) do
        if spec then
            if spec.partType == parameter then
                return spec
            end
            if spec.itemType == parameter then
                return spec
            end
        end
    end

    return nil
end

---@param gun HandWeapon|nil
---@param spec AnimatedReloadsPartSpec|nil
---@return WeaponPart|nil
function AnimatedReloadsAction.getWeaponPartForSpec(gun, spec)
    if not gun or not spec then
        return nil
    end

    local part = nil
    if spec.partType and spec.partType ~= "" then
        part = gun:getWeaponPart(spec.partType)
        if part and spec.itemType and spec.itemType ~= "" and part:getFullType() ~= spec.itemType then
            part = nil
        end
    end

    if not part and spec.itemType and spec.itemType ~= "" then
        part = AnimatedReloadsAction.getWeaponPartByItemType(gun, spec.itemType)
    end

    return part
end

---@param action ISBaseTimedAction
---@param handler AnimatedReloadsHandler|nil
function AnimatedReloadsAction.attachReloadMagazine(action, handler)
    if not action or not handler or not handler.magItem then
        return
    end

    if action.reloadHandlerMagazineItem then
        return
    end

    local inventory = action.character:getInventory()
    local magazineItem = inventory:AddItem(handler.magItem)
    if not magazineItem then
        return
    end

    action.reloadHandlerMagazineItem = magazineItem
    sendAddItemToContainer(inventory, magazineItem)
    action.character:setAttachedItem("Bip01_Prop2", magazineItem)
end

---@param action ISBaseTimedAction
function AnimatedReloadsAction.detachReloadMagazine(action)
    local magazineItem = action.reloadHandlerMagazineItem
    if not magazineItem then
        return
    end

    action.character:removeAttachedItem(magazineItem)
    action.character:getInventory():Remove(magazineItem)
    sendRemoveItemFromContainer(action.character:getInventory(), magazineItem)
    action.character:resetEquippedHandsModels()
    action.reloadHandlerMagazineItem = nil
end

---@param action ISBaseTimedAction
---@param sprite string|nil
function AnimatedReloadsAction.setWeaponSprite(action, sprite)
    if not action or not action.character or not sprite or sprite == "" then
        return
    end

    local item = action.character:getPrimaryHandItem()
    if not item then
        return
    end

    item:setWeaponSprite(sprite)
    action.character:resetEquippedHandsModels()
    if syncHandWeaponFields and isServer() then
        syncHandWeaponFields(action.character, item)
    end
    local commandModule = AnimatedReloadsAction.getCommandModule()
    if commandModule and sendClientCommand and isClient() then
        sendClientCommand(commandModule, "SetWeaponSprite", { sprite = sprite })
    end
end

---@param action ISBaseTimedAction
---@param event string
---@param parameter string
---@return boolean
function AnimatedReloadsAction.handleWeaponSpriteAnimEvent(action, event, parameter)
    if event ~= "changeWeaponSprite" then
        return false
    end

    if not parameter or parameter == "" then
        return false
    end

    AnimatedReloadsAction.setWeaponSprite(action, parameter)
    local handler = AnimatedReloadsAction.getHandler(action)
    if handler and handler.loadedSprite and parameter == handler.loadedSprite then
        AnimatedReloadsAction.detachReloadMagazine(action)
    end
    return true
end

---@param action ISBaseTimedAction
---@param handler AnimatedReloadsHandler|nil
---@param event string
---@param parameter string
---@return boolean
function AnimatedReloadsAction.handleWeaponAttachmentStateAnimEvent(action, handler, event, parameter)
    if event ~= "changeWeaponAttachmentState" then
        return false
    end

    if not parameter or parameter == "" then
        return false
    end

    return AnimatedReloadsAction.setWeaponAttachmentState(action, handler, parameter)
end

---@param action ISBaseTimedAction
---@param handler AnimatedReloadsHandler|nil
---@param event string
---@param parameter string
---@return boolean
function AnimatedReloadsAction.handleWeaponPartAnimEvent(action, handler, event, parameter)
    if event ~= "changeWeaponPart" then
        return false
    end

    local spec = AnimatedReloadsAction.resolveEventPartSpec(handler, parameter)
    if not spec then
        return false
    end

    local gun = AnimatedReloadsAction.resolveActionGun(action, handler, true)
    if not gun then
        return false
    end

    local currentPart = AnimatedReloadsAction.getWeaponPartForSpec(gun, spec)
    if AnimatedReloadsAction.isEjectAction(action) then
        if currentPart then
            AnimatedReloadsAction.detachWeaponPartSpec(action, gun, spec)
            AnimatedReloadsAction.attachReloadMagazine(action, handler)
        end
    elseif AnimatedReloadsAction.isInsertAction(action) then
        if not currentPart then
            AnimatedReloadsAction.attachWeaponPartSpec(action, gun, spec)
            AnimatedReloadsAction.detachReloadMagazine(action)
        end
    else
        if currentPart then
            AnimatedReloadsAction.detachWeaponPartSpec(action, gun, spec)
            AnimatedReloadsAction.attachReloadMagazine(action, handler)
        else
            AnimatedReloadsAction.attachWeaponPartSpec(action, gun, spec)
            AnimatedReloadsAction.detachReloadMagazine(action)
        end
    end

    if action.character then
        action.character:resetEquippedHandsModels()
        if syncHandWeaponFields then
            syncHandWeaponFields(action.character, gun)
        end
    end

    return true
end

---@param action ISBaseTimedAction
---@param handler AnimatedReloadsHandler|nil
function AnimatedReloadsAction.setNoMagazineModel(action, handler)
    if not handler then
        return
    end

    if handler.style == "attachments" then
        AnimatedReloadsAction.setWeaponAttachmentState(action, handler, handler.unloadedState or "unloaded")
        return
    end

    AnimatedReloadsAction.setWeaponSprite(action, handler.unloadedSprite)
end

---@param action ISBaseTimedAction
---@param handler AnimatedReloadsHandler|nil
function AnimatedReloadsAction.resetWeaponModel(action, handler)
    if not handler or not action or not action.character then
        return
    end

    local item = action.gun
    if not instanceof(item, "HandWeapon") then
        item = action.character:getPrimaryHandItem()
    end

    if not instanceof(item, "HandWeapon") then
        return
    end

    if handler.style == "attachments" then
        if item:isContainsClip() then
            AnimatedReloadsAction.setWeaponAttachmentState(action, handler, handler.loadedState or "loaded")
            return
        end

        AnimatedReloadsAction.setWeaponAttachmentState(action, handler, handler.unloadedState or "unloaded")
        return
    end

    if item:isContainsClip() then
        AnimatedReloadsAction.setWeaponSprite(action, handler.loadedSprite or handler.unloadedSprite)
        return
    end

AnimatedReloadsAction.setNoMagazineModel(action, handler)
end

return AnimatedReloadsAction
