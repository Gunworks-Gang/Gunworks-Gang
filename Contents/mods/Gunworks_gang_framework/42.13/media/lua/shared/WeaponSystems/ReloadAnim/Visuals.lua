-- Gunworks reload-animation framework: weapon model/sprite/part swaps + the in-hand
-- magazine prop, driven by AnimSet events. Ported from AnimatedReloads' WeaponVisuals;
-- the only behavioral change is that a client-side sprite swap is relayed through the
-- Gunworks "SWMG" command channel (Server/Client.lua "reloadSprite") so observers see
-- it, instead of AnimatedReloads' separate command module.

---@class GunworksReloadAnim
local ReloadAnim = require("WeaponSystems/Utils/ReloadAnim")

---@param source GunworksReloadPartSpec|string|nil
---@param handler GunworksReloadAnimHandler|nil
---@nodiscard
---@return GunworksReloadPartSpec|nil
function ReloadAnim.resolvePartSpec(source, handler)
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
---@nodiscard
---@return WeaponPart|nil
function ReloadAnim.getWeaponPartByItemType(gun, itemType)
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

--- Attach a part for looks only: doChange = false skips every stat delta and onAttach, and the
--- engine auto-detaches whatever already occupies that PartType.
---@param character IsoGameCharacter
---@param gun HandWeapon
---@param itemType string
---@return boolean
function ReloadAnim.attachVisualPart(character, gun, itemType)
    if ReloadAnim.getWeaponPartByItemType(gun, itemType) then
        return false
    end

    local part = instanceItem(itemType)
    if not part or not instanceof(part, "WeaponPart") then
        return false
    end

    gun:attachWeaponPart(character, part, false)
    return true
end

--- Detach a part for looks only. detachWeaponPart identity-checks against the attached instance,
--- so the part must be fetched off the gun rather than freshly instanced.
---@param character IsoGameCharacter
---@param gun HandWeapon
---@param itemType string
---@return boolean
function ReloadAnim.detachVisualPart(character, gun, itemType)
    local part = ReloadAnim.getWeaponPartByItemType(gun, itemType)
    if not part then
        return false
    end

    gun:detachWeaponPart(character, part, false)
    return true
end

---@param action ISBaseTimedAction
---@param gun HandWeapon|nil
---@param spec GunworksReloadPartSpec|nil
---@return nil
function ReloadAnim.attachWeaponPartSpec(action, gun, spec)
    if not action or not gun or not spec or not spec.itemType or spec.itemType == "" then
        return
    end

    if spec.partType and spec.partType ~= "" then
        local currentPart = gun:getWeaponPart(spec.partType)
        if currentPart and currentPart:getFullType() == spec.itemType then
            return
        end
    else
        local existingPart = ReloadAnim.getWeaponPartByItemType(gun, spec.itemType)
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
---@param spec GunworksReloadPartSpec|nil
---@return nil
function ReloadAnim.detachWeaponPartSpec(action, gun, spec)
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
        part = ReloadAnim.getWeaponPartByItemType(gun, spec.itemType)
    end

    if not part then
        return
    end

    gun:detachWeaponPart(action.character, part, spec.doChange == true)
end

---@param action ISBaseTimedAction
---@param gun HandWeapon
---@param handler GunworksReloadAnimHandler
---@param stateKey string|nil
---@return boolean
function ReloadAnim.applyWeaponAttachmentState(action, gun, handler, stateKey)
    if not stateKey or stateKey == "" or not handler.states then
        return false
    end

    local state = handler.states[stateKey]
    if not state then
        return false
    end

    if state.detach then
        for i = 1, #state.detach do
            local spec = ReloadAnim.resolvePartSpec(state.detach[i], handler)
            ReloadAnim.detachWeaponPartSpec(action, gun, spec)
        end
    end

    if state.attach then
        for i = 1, #state.attach do
            local spec = ReloadAnim.resolvePartSpec(state.attach[i], handler)
            ReloadAnim.attachWeaponPartSpec(action, gun, spec)
        end
    end

    return true
end

---@param action ISBaseTimedAction
---@param handler GunworksReloadAnimHandler|nil
---@param preferActionGun boolean|nil
---@nodiscard
---@return HandWeapon|nil
function ReloadAnim.resolveActionGun(action, handler, preferActionGun)
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
---@param handler GunworksReloadAnimHandler|nil
---@param stateKey string|nil
---@return boolean
function ReloadAnim.setWeaponAttachmentState(action, handler, stateKey)
    if not action or not handler then
        return false
    end

    local gun = ReloadAnim.resolveActionGun(action, handler, true)
    if not gun then
        return false
    end

    local changed = ReloadAnim.applyWeaponAttachmentState(action, gun, handler, stateKey)
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
function ReloadAnim.isEjectAction(action)
    return action and action.Type == "ISEjectMagazine" or false
end

---@param action ISBaseTimedAction|nil
---@nodiscard
---@return boolean
function ReloadAnim.isInsertAction(action)
    return action and action.Type == "ISInsertMagazine" or false
end

---@param handler GunworksReloadAnimHandler|nil
---@param parameter string|nil
---@nodiscard
---@return GunworksReloadPartSpec|nil
function ReloadAnim.resolveEventPartSpec(handler, parameter)
    if not handler or not parameter or parameter == "" then
        return nil
    end

    local direct = ReloadAnim.resolvePartSpec(parameter, handler)
    if direct then
        return direct
    end

    if not handler.parts then
        return nil
    end

    local parts = handler.parts
    for _, spec in pairs(parts) do
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
---@param spec GunworksReloadPartSpec|nil
---@nodiscard
---@return WeaponPart|nil
function ReloadAnim.getWeaponPartForSpec(gun, spec)
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
        part = ReloadAnim.getWeaponPartByItemType(gun, spec.itemType)
    end

    return part
end

-- The in-hand reload magazine prop attaches to ReloadAnim.RELOAD_MAGAZINE_ATTACH_LOCATION
-- (defined in Utils/ReloadAnim.lua, registered in ReloadAnim/AttachLocations.lua).

--- Is an attached-item location id valid for this character's model?
---@param character IsoGameCharacter|nil
---@param location string|nil
---@nodiscard
---@return boolean
function ReloadAnim.hasAttachLocation(character, location)
    if not character or not location then
        return false
    end

    local attached = character:getAttachedItems()
    if not attached then
        return false
    end

    local group = attached:getGroup()
    if not group then
        return false
    end

    return group:indexOf(location) ~= -1
end

--- Which magazine model to show in the reloading hand. A gun may accept several magazine
--- types (standard / extended / drum); the hand must show the one actually being loaded or
--- ejected, not the profile's registered default -- otherwise a gun fed an extended mag
--- shows the default stick mag in-hand while the extended mag snaps onto the gun model.
--- Resolution order:
---   1. action.magazine        -- the real item ISInsertMagazine is inserting (constructor field)
---   2. action._actualMagType  -- the mag type captured off the gun at ISEjectMagazine:start
---   3. gun modData.MagazineType -- the mag type Gunworks last saved on the gun
---   4. handler.magItem         -- the profile default, and the ONLY value for non-mag props
---                                 (shells / rounds / speedloaders, which have no action.magazine)
---@param action ISBaseTimedAction
---@param handler GunworksReloadAnimHandler
---@nodiscard
---@return string|nil
function ReloadAnim.resolveReloadMagItem(action, handler)
    local mag = action.magazine
    if mag then
        local magType = mag:getFullType()
        if magType and magType ~= "" then
            return magType
        end
    end

    local actual = action._actualMagType
    if actual and actual ~= "" then
        return actual
    end

    local gun = ReloadAnim.resolveActionGun(action, handler, true)
    if gun then
        local modData = gun:getModData()
        local saved = modData and modData.MagazineType
        if saved and saved ~= "" then
            return saved
        end
    end

    return handler.magItem
end

---@param action ISBaseTimedAction
---@param handler GunworksReloadAnimHandler|nil
---@return nil
function ReloadAnim.attachReloadMagazine(action, handler)
    if not action or not handler or not handler.magItem then
        return
    end

    if action.reloadHandlerMagazineItem then
        return
    end

    -- Skip the cosmetic prop if this model has no such attachment location (otherwise
    -- setAttachedItem throws and aborts the reload action).
    if not ReloadAnim.hasAttachLocation(action.character, ReloadAnim.RELOAD_MAGAZINE_ATTACH_LOCATION) then
        return
    end

    -- Show the magazine that is actually going on (or coming off) the gun, not the profile
    -- default -- so guns that accept multiple mag types render the correct one in-hand.
    local magItemType = ReloadAnim.resolveReloadMagItem(action, handler)

    local inventory = action.character:getInventory()
    local magazineItem = inventory:AddItem(magItemType)
    if not magazineItem then
        return
    end

    action.reloadHandlerMagazineItem = magazineItem
    sendAddItemToContainer(inventory, magazineItem)
    action.character:setAttachedItem(ReloadAnim.RELOAD_MAGAZINE_ATTACH_LOCATION, magazineItem)
end

---@param action ISBaseTimedAction
---@return nil
function ReloadAnim.detachReloadMagazine(action)
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
---@return nil
function ReloadAnim.setWeaponSprite(action, sprite)
    if not action or not action.character or not sprite or sprite == "" then
        return
    end

    local item = action.character:getPrimaryHandItem()
    if not item then
        return
    end

    item:setWeaponSprite(sprite)
    action.character:resetEquippedHandsModels()
    if isServer() then
        if syncHandWeaponFields then
            syncHandWeaponFields(action.character, item)
        end
    elseif isClient() then
        sendClientCommand(action.character, "SWMG", "reloadSprite", {
            itemId = item:getID(),
            sprite = sprite,
        })
    end
end

---@param action ISBaseTimedAction
---@param event string
---@param parameter string
---@return boolean
function ReloadAnim.handleWeaponSpriteAnimEvent(action, event, parameter)
    if event ~= "changeWeaponSprite" then
        return false
    end

    if not parameter or parameter == "" then
        return false
    end

    -- Only guns registered with a reload sprite have a WeaponSprite to swap. A model/part-based gun
    -- (e.g. the flintlock double-barrel, whose visual state lives in its lock/part models) defines no
    -- reload sprite, so the vanilla reload's changeWeaponSprite("original") revert would set its
    -- WeaponSprite to a non-existent "original" mesh and render the gun invisible (MeshAssetManager
    -- fails to load AssetPath "original"). Skip such guns and leave their model untouched.
    local handler = ReloadAnim.getHandlerForAction(action)
    if not handler or not (handler.loadedSprite or handler.unloadedSprite) then
        return false
    end

    ReloadAnim.setWeaponSprite(action, parameter)
    if handler.loadedSprite and parameter == handler.loadedSprite then
        ReloadAnim.detachReloadMagazine(action)
    end
    return true
end

---@param action ISBaseTimedAction
---@param handler GunworksReloadAnimHandler|nil
---@param event string
---@param parameter string
---@return boolean
function ReloadAnim.handleWeaponAttachmentStateAnimEvent(action, handler, event, parameter)
    if event ~= "changeWeaponAttachmentState" then
        return false
    end

    if not parameter or parameter == "" then
        return false
    end

    return ReloadAnim.setWeaponAttachmentState(action, handler, parameter)
end

---@param action ISBaseTimedAction
---@param handler GunworksReloadAnimHandler|nil
---@param event string
---@param parameter string
---@return boolean
function ReloadAnim.handleWeaponPartAnimEvent(action, handler, event, parameter)
    if event ~= "changeWeaponPart" then
        return false
    end

    local spec = ReloadAnim.resolveEventPartSpec(handler, parameter)
    if not spec then
        return false
    end

    local gun = ReloadAnim.resolveActionGun(action, handler, true)
    if not gun then
        return false
    end

    local currentPart = ReloadAnim.getWeaponPartForSpec(gun, spec)
    if ReloadAnim.isEjectAction(action) then
        if currentPart then
            ReloadAnim.detachWeaponPartSpec(action, gun, spec)
            ReloadAnim.attachReloadMagazine(action, handler)
        end
    elseif ReloadAnim.isInsertAction(action) then
        if not currentPart then
            ReloadAnim.attachWeaponPartSpec(action, gun, spec)
            ReloadAnim.detachReloadMagazine(action)
        end
    else
        if currentPart then
            ReloadAnim.detachWeaponPartSpec(action, gun, spec)
            ReloadAnim.attachReloadMagazine(action, handler)
        else
            ReloadAnim.attachWeaponPartSpec(action, gun, spec)
            ReloadAnim.detachReloadMagazine(action)
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
---@param handler GunworksReloadAnimHandler|nil
---@return nil
function ReloadAnim.setNoMagazineModel(action, handler)
    if not handler then
        return
    end

    if handler.style == "attachments" then
        ReloadAnim.setWeaponAttachmentState(action, handler, handler.unloadedState or "unloaded")
        return
    end

    ReloadAnim.setWeaponSprite(action, handler.unloadedSprite)
end

---@param action ISBaseTimedAction
---@param handler GunworksReloadAnimHandler|nil
---@return nil
function ReloadAnim.resetWeaponModel(action, handler)
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
            ReloadAnim.setWeaponAttachmentState(action, handler, handler.loadedState or "loaded")
            return
        end

        ReloadAnim.setWeaponAttachmentState(action, handler, handler.unloadedState or "unloaded")
        return
    end

    if item:isContainsClip() then
        ReloadAnim.setWeaponSprite(action, handler.loadedSprite or handler.unloadedSprite)
        return
    end

    ReloadAnim.setNoMagazineModel(action, handler)
end

return ReloadAnim
