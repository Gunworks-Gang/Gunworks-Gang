-- Gunworks reload-animation framework: off-hand props and mid-reload part transfers.
--
-- Three additive anim events, authored as timeline markers on the reload clip. Vanilla never sees
-- an unknown event name, so they cost nothing on guns that do not use them.
--
--   gwSetProp     value = item fullType, or "" -> put that item in the off-hand, or empty the hand
--   gwPartToHand  value = part item fullType   -> take the part off the gun AND into the off-hand
--   gwPartToGun   value = part item fullType   -> empty the off-hand AND put the part back on the gun
--
-- The two transfer events are deliberately one marker each rather than a pair, so the gun side and
-- the hand side can never drift apart. There is exactly one off-hand slot, so a prop must be cleared
-- before the next one arrives.
--
-- Authority in MP. Lua animEvent only fires for the LOCAL action (LuaTimedActionNew.java:208), so
-- these markers run on the reloading client, never on observers. The client therefore asks the
-- server to make the change:
--   * the prop is a REAL item in a container (GameCharacterAttachedItemPacket resolves it by
--     containerId), so only the server may create it;
--   * setAttachedItem does NOT broadcast from the server - the server-only sendAttachedItem global
--     does (sendToRelative, LuaManager.java:10281);
--   * syncHandWeaponFields unicasts to the weapon's OWNER only (INetworkPacket.send(IsoPlayer,...)),
--     so observers are updated by relaying the marker to every client, exactly as reloadSprite does.

---@class GunworksReloadAnim
local ReloadAnim = require("WeaponSystems/Utils/ReloadAnim")
require("WeaponSystems/ReloadAnim/Visuals")

ReloadAnim.PROP_SET_EVENT = "gwSetProp"          -- item -> off-hand slot (Bip01_Prop2)
ReloadAnim.PROP_SET_HAND_EVENT = "gwSetHandProp" -- item -> right-hand slot (Bip01_R_Hand)
ReloadAnim.PART_TO_HAND_EVENT = "gwPartToHand"
ReloadAnim.PART_TO_GUN_EVENT = "gwPartToGun"

---@type table<string,boolean>
local PROP_EVENTS = {
    [ReloadAnim.PROP_SET_EVENT] = true,
    [ReloadAnim.PROP_SET_HAND_EVENT] = true,
    [ReloadAnim.PART_TO_HAND_EVENT] = true,
    [ReloadAnim.PART_TO_GUN_EVENT] = true,
}

--- The attachment slot a gwSetProp/gwSetHandProp event drives (they are independent, so a hand prop
--- and an off-hand part can be shown at once).
---@param event string
---@return string
local function slotForEvent(event)
    if event == ReloadAnim.PROP_SET_HAND_EVENT then
        return ReloadAnim.RELOAD_HAND_ATTACH_LOCATION
    end
    return ReloadAnim.RELOAD_MAGAZINE_ATTACH_LOCATION
end

---@param event string|nil
---@nodiscard
---@return boolean
function ReloadAnim.isPropEvent(event)
    return event ~= nil and PROP_EVENTS[event] == true
end

--- Is this an item the gun's profile is allowed to put in the off-hand? The value arrives from a
--- client command, so an unvalidated one would let a client spawn any item into its inventory.
---@param handler GunworksReloadAnimHandler|nil
---@param itemType string|nil
---@nodiscard
---@return boolean
function ReloadAnim.isAllowedPropValue(handler, itemType)
    if not itemType or itemType == "" then
        return true
    end

    local profile = handler and handler.partState
    if not profile then
        return false
    end

    if profile.ammoParts then
        for i = 1, #profile.ammoParts do
            local spec = profile.ammoParts[i]
            if itemType == spec.loaded or itemType == spec.unloaded then
                return true
            end
        end
    end

    if profile.ensure then
        for i = 1, #profile.ensure do
            if profile.ensure[i] == itemType then
                return true
            end
        end
    end

    if profile.props then
        for i = 1, #profile.props do
            if profile.props[i] == itemType then
                return true
            end
        end
    end

    return false
end

-- The exact prop item created per (character, location). removeProp needs this because in MP the
-- server applies the prop markers from ASYNC client commands, and the getAttachedItem reference does
-- NOT reliably survive between them -- so a getAttachedItem-only removeProp finds nothing and leaks
-- the created prop item into the inventory. As the prop items are real ammo/cartridge types, each
-- leaked duplicate cancels the reload's consume/load, producing a net-zero (infinite-ammo) reload.
-- Keyed by the character (same server-side IsoPlayer instance across one reload's markers).
local trackedProps = {}

--- Free whatever currently occupies `location`. The send* globals self-guard on GameServer.server,
--- so this is a plain local mutation in singleplayer.
---@param character IsoGameCharacter
---@param location string
---@return boolean
local function removeProp(character, location)
    local attached = character:getAttachedItem(location)
    local byChar = trackedProps[character]
    -- Prefer the still-attached item; fall back to the one we created (MP leak recovery).
    local item = attached or (byChar and byChar[location])
    if not item then
        return false
    end

    if attached then
        character:removeAttachedItem(attached)
    end
    sendAttachedItem(character, location, nil)

    local inventory = character:getInventory()
    inventory:Remove(item)
    sendRemoveItemFromContainer(inventory, item)

    if byChar then
        byChar[location] = nil
    end
    return true
end

--- Set (or clear, with an empty itemType) the prop in `location`. Server / singleplayer only: a
--- client creating the item locally would leave a phantom that no packet can reconcile.
---@param character IsoGameCharacter
---@param location string
---@param itemType string|nil
---@return boolean
local function applyProp(character, location, itemType)
    if not ReloadAnim.hasAttachLocation(character, location) then
        return false
    end

    local changed = removeProp(character, location)
    if not itemType or itemType == "" then
        if changed then
            character:resetEquippedHandsModels()
        end
        return changed
    end

    local inventory = character:getInventory()
    local item = inventory:AddItem(itemType)
    if not item then
        return changed
    end

    -- Remember the exact item so the NEXT removeProp deletes it even if getAttachedItem later returns
    -- nil (MP async markers) -- otherwise the prop leaks and cancels the reload's ammo consumption.
    local byChar = trackedProps[character]
    if not byChar then
        byChar = {}
        trackedProps[character] = byChar
    end
    byChar[location] = item

    sendAddItemToContainer(inventory, item)
    character:setAttachedItem(location, item)
    sendAttachedItem(character, location, item)
    character:resetEquippedHandsModels()
    return true
end

--- Clear the off-hand prop wherever authority for it lives. Used on reload interrupt.
---@param character IsoGameCharacter|nil
---@return nil
function ReloadAnim.clearOffHandProp(character)
    if not character then
        return
    end

    if isClient() then
        -- clear both the off-hand and the right-hand slot
        sendClientCommand(character, "SWMG", "reloadProp", { event = ReloadAnim.PROP_SET_EVENT, value = "" })
        sendClientCommand(character, "SWMG", "reloadProp", { event = ReloadAnim.PROP_SET_HAND_EVENT, value = "" })
        return
    end

    applyProp(character, ReloadAnim.RELOAD_MAGAZINE_ATTACH_LOCATION, "")
    applyProp(character, ReloadAnim.RELOAD_HAND_ATTACH_LOCATION, "")
end

--- Apply one marker authoritatively (singleplayer, or the server acting on a client's request).
---@param character IsoGameCharacter
---@param gun HandWeapon|nil
---@param event string
---@param value string|nil
---@return nil
function ReloadAnim.applyPropEvent(character, gun, event, value)
    -- gwSetProp -> off-hand (Prop2) slot; gwSetHandProp -> right-hand slot. Independent slots.
    if event == ReloadAnim.PROP_SET_EVENT or event == ReloadAnim.PROP_SET_HAND_EVENT then
        applyProp(character, slotForEvent(event), value)
        return
    end

    if not instanceof(gun, "HandWeapon") or not value or value == "" then
        return
    end

    -- Part transfers move a gun part into/out of the off-hand (Prop2) slot (e.g. the ramrod).
    local offHand = ReloadAnim.RELOAD_MAGAZINE_ATTACH_LOCATION
    local changed = false
    if event == ReloadAnim.PART_TO_HAND_EVENT then
        changed = ReloadAnim.detachVisualPart(character, gun, value)
        applyProp(character, offHand, value)
    elseif event == ReloadAnim.PART_TO_GUN_EVENT then
        applyProp(character, offHand, "")
        changed = ReloadAnim.attachVisualPart(character, gun, value)
    else
        return
    end

    if not changed then
        return
    end

    character:resetEquippedHandsModels()
    syncHandWeaponFields(character, gun)
end

--- Apply a relayed marker on an observer client. Only the gun-side part moves here; the prop item
--- and its attachment arrive from the server as engine packets.
---@param character IsoGameCharacter|nil
---@param gun HandWeapon|nil
---@param event string
---@param value string|nil
---@return nil
function ReloadAnim.applyRemotePropEvent(character, gun, event, value)
    if not character then
        return
    end

    -- Pure hand/off-hand ITEM props (gwSetProp / gwSetHandProp). These reach nearby observers as the
    -- reloader's REAL attached item through the server's sendAttachedItem engine packet -- the very same
    -- path the ramrod's off-hand item rides -- and render correctly here once GunworksReloadHand is
    -- registered on the body models.
    --
    -- DO NOT re-attach it ourselves. The previous version removed that engine-delivered item and set a
    -- fresh client-side instanceItem in its place; a bare instance attached to a REMOTE character does
    -- NOT render, so clobbering the good item made the prop VANISH on observers entirely (rendered as
    -- nothing -- not even at the model root, which is what an unresolved attachment would show). That is
    -- exactly why the ramrod (engine item, left untouched) appeared on observers and the hand cartridge
    -- did not. So on SET we leave the engine-delivered item alone. On CLEAR we drop whatever is attached
    -- -- the engine packet clears it too, but this is a cheap safety net. An observer beyond
    -- sendToRelative range never gets the prop, exactly as it never gets the ramrod: an accepted
    -- proximity limit, not a per-client render bug.
    if event == ReloadAnim.PROP_SET_EVENT or event == ReloadAnim.PROP_SET_HAND_EVENT then
        if value and value ~= "" then
            return
        end

        local location = (event == ReloadAnim.PROP_SET_HAND_EVENT)
            and ReloadAnim.RELOAD_HAND_ATTACH_LOCATION
            or ReloadAnim.RELOAD_MAGAZINE_ATTACH_LOCATION

        local current = character:getAttachedItem(location)
        if current then
            character:removeAttachedItem(current)
            character:resetEquippedHandsModels()
        end
        return
    end

    -- Gun-side part transfers (e.g. the ramrod): only the gun part moves on an observer; the item is
    -- already the remote player's and rides the part swap.
    if not instanceof(gun, "HandWeapon") or not value or value == "" then
        return
    end

    local changed = false
    if event == ReloadAnim.PART_TO_HAND_EVENT then
        changed = ReloadAnim.detachVisualPart(character, gun, value)
    elseif event == ReloadAnim.PART_TO_GUN_EVENT then
        changed = ReloadAnim.attachVisualPart(character, gun, value)
    end

    if changed then
        character:resetEquippedHandsModels()
    end
end

--- The reloader attaches (or clears) its OWN off-hand prop. The server created the prop item, synced
--- it into this player's inventory, and attached it server-side -- but GameCharacterAttachedItemPacket
--- ignores the LOCAL player, so the owner never sees its own prop until it attaches the synced item
--- itself. A nil itemId means clear the slot (the server already removed the item + broadcast the
--- detach; only our local attachment is left to drop).
---@param character IsoGameCharacter|nil
---@param itemId number|nil
---@param location string|nil
---@return nil
function ReloadAnim.applyOwnerProp(character, itemId, location)
    if not character then
        return
    end

    location = location or ReloadAnim.RELOAD_MAGAZINE_ATTACH_LOCATION

    if not itemId then
        local current = character:getAttachedItem(location)
        if current then
            character:removeAttachedItem(current)
            character:resetEquippedHandsModels()
        end
        return
    end

    local item = character:getInventory():getItemWithIDRecursiv(itemId)
    if not item then
        return
    end

    character:setAttachedItem(location, item)
    character:resetEquippedHandsModels()
end

--- Timed-action entry point: handle a prop/transfer marker fired by the reload clip.
---@param action ISBaseTimedAction
---@param handler GunworksReloadAnimHandler|nil
---@param event string
---@param parameter string
---@return boolean
function ReloadAnim.handlePropAnimEvent(action, handler, event, parameter)
    if not PROP_EVENTS[event] then
        return false
    end

    local character = action.character
    if not character then
        return false
    end

    local gun = ReloadAnim.resolveActionGun(action, handler, true)
    if isClient() then
        sendClientCommand(character, "SWMG", "reloadProp", {
            gunId = gun and gun:getID(),
            event = event,
            value = parameter or "",
        })
        return true
    end

    ReloadAnim.applyPropEvent(character, gun, event, parameter)
    return true
end

return ReloadAnim
