-- Gunworks reload-animation framework: per-tick weapon-part reconciler.
--
-- Nothing else ever attaches a gun's cosmetic parts, so this pass is what first puts them on
-- (including guns already sitting in old saves). It is modelled on Sync.lua: derive the desired
-- part set from synced state every tick rather than setting it at action boundaries, which makes
-- it self-healing, MP-safe, and immune to Core.ResetLua.
--
-- Authority: the server owns weapon parts in MP (they persist on the item and reach observers via
-- SyncHandWeaponFieldsPacket), so a client must never write them - two machines reconciling the
-- same gun is a desync source. isClient() is true only on an MP client, so this guard leaves the
-- pass running on the dedicated server AND in singleplayer (which is neither client nor server).
--
-- While PerformingAction == "Reload" the reload's own anim-event markers own the parts, so the
-- pass stands down; that is what lets the ramrod sit off the gun mid-animation on every machine.

---@class GunworksReloadAnim
local ReloadAnim = require("WeaponSystems/Utils/ReloadAnim")
require("WeaponSystems/ReloadAnim/Visuals")
require("WeaponSystems/ReloadAnim/Props")
local PartReconcile = require("WeaponSystems/Utils/PartReconcile")

--- Reconcile a part whose variant is chosen by whether the gun is loaded (flint cooked/uncooked, hammer
--- cocked/uncocked). One helper for every such spec so flint and hammer stay identical.
---@param gun HandWeapon
---@param character IsoGameCharacter
---@param spec GunworksReloadAmmoPartSpec
---@return boolean
local function reconcileAmmoKeyedPart(gun, character, spec)
    local desired = spec.unloaded
    if gun:getCurrentAmmoCount() > 0 then
        desired = spec.loaded
    end

    local current = gun:getWeaponPart(spec.partType)
    if current and current:getFullType() == desired then
        return false
    end

    -- attachWeaponPart auto-detaches the part already in this PartType, so the swap is one call.
    return ReloadAnim.attachVisualPart(character, gun, desired)
end

--- Reconcile every ammo-keyed part (flint, hammer, ...) the profile declares.
---@param gun HandWeapon
---@param character IsoGameCharacter
---@param list GunworksReloadAmmoPartSpec[]
---@return boolean
local function reconcileAmmoParts(gun, character, list)
    local changed = false
    for i = 1, #list do
        changed = reconcileAmmoKeyedPart(gun, character, list[i]) or changed
    end
    return changed
end

---@param gun HandWeapon
---@param character IsoGameCharacter
---@param ensure string[]
---@return boolean
local function reconcileEnsuredParts(gun, character, ensure)
    local changed = false
    for i = 1, #ensure do
        if ReloadAnim.attachVisualPart(character, gun, ensure[i]) then
            changed = true
        end
    end

    return changed
end

--- Force every ensured part back onto the gun and reconcile the flint from the live ammo count.
--- Called by the reload hooks on interrupt, where the markers may have left a part in the hand.
---@param character IsoGameCharacter|nil
---@param gun HandWeapon|nil
---@return nil
function ReloadAnim.restoreWeaponParts(character, gun)
    if not character or not instanceof(gun, "HandWeapon") then
        return
    end

    local handler = ReloadAnim.GetHandlerForGun(gun)
    local profile = handler and handler.partState
    if not profile then
        return
    end

    -- Both attach/detach helpers are cosmetic model ops (an observer runs them too), so a CLIENT may
    -- restore its OWN gun visual here: without it an interrupt mid-transfer strands the ramrod in the
    -- hand until the server reconcile round-trips back to the reloader. The state is unambiguous (the
    -- reload did not complete, so parts go back to their ammo-derived resting state), so predicting it
    -- locally is safe; the authoritative apply + the observer relay still come from the server.
    local changed = false
    if profile.ensure then
        changed = reconcileEnsuredParts(gun, character, profile.ensure)
    end

    if profile.ammoParts then
        changed = reconcileAmmoParts(gun, character, profile.ammoParts) or changed
    end

    if not changed then
        return
    end

    character:resetEquippedHandsModels()
    if isClient() then
        return
    end
    syncHandWeaponFields(character, gun)
end

--- The reload ended, finished or interrupted: empty the off-hand and force every ensured part back
--- onto the gun, so an interrupt mid-transfer can never strand the ramrod in the hand.
---@param action ISBaseTimedAction
---@return nil
function ReloadAnim.restoreReloadPartState(action)
    if not action or not action.character then
        return
    end

    local character = action.character

    -- On a client, immediately drop this player's OWN off-hand/hand prop attachments so an interrupt
    -- can't leave the ramrod (or a prop) stranded in the hand until the server round-trips the clear
    -- back. removeAttachedItem re-broadcasts for the local player, so the server + observers clear too;
    -- clearOffHandProp below still runs for the authoritative inventory-item removal.
    if isClient() then
        local locations = { ReloadAnim.RELOAD_MAGAZINE_ATTACH_LOCATION, ReloadAnim.RELOAD_HAND_ATTACH_LOCATION }
        local dropped = false
        for i = 1, #locations do
            local held = character:getAttachedItem(locations[i])
            if held then
                character:removeAttachedItem(held)
                dropped = true
            end
        end
        if dropped then
            character:resetEquippedHandsModels()
        end
    end

    ReloadAnim.clearOffHandProp(character)

    local handler = ReloadAnim.getHandlerForAction(action)
    ReloadAnim.restoreWeaponParts(character, ReloadAnim.resolveActionGun(action, handler, true))
end

--- The desired variant for an ammo-keyed part (flint or hammer), from the gun's live ammo count.
---@param gun HandWeapon
---@param spec GunworksReloadAmmoPartSpec
---@nodiscard
---@return string
local function desiredAmmoKeyedPart(gun, spec)
    if gun:getCurrentAmmoCount() > 0 then
        return spec.loaded
    end
    return spec.unloaded
end

--- The desired fullType of every ammo-keyed part, in profile order, for the observer relay.
---@param gun HandWeapon
---@param list GunworksReloadAmmoPartSpec[]
---@nodiscard
---@return string[]
local function desiredAmmoParts(gun, list)
    local desired = {}
    for i = 1, #list do
        desired[i] = desiredAmmoKeyedPart(gun, list[i])
    end
    return desired
end

--- Read-only: does this gun's part set differ from its profile's desired state? The MP client uses
--- this to decide whether to nudge the server WITHOUT mutating locally - predicting locally would
--- stop the nudge after one tick and lose it if it raced ahead of the equip-sync to the server.
---@param gun HandWeapon
---@param profile GunworksReloadPartStateProfile
---@nodiscard
---@return boolean
local function needsReconcile(gun, profile)
    if profile.ammoParts then
        for i = 1, #profile.ammoParts do
            local spec = profile.ammoParts[i]
            local current = gun:getWeaponPart(spec.partType)
            if not current or current:getFullType() ~= desiredAmmoKeyedPart(gun, spec) then
                return true
            end
        end
    end

    if profile.ensure then
        for i = 1, #profile.ensure do
            if not ReloadAnim.getWeaponPartByItemType(gun, profile.ensure[i]) then
                return true
            end
        end
    end

    return false
end

-- The dedicated server fires NO per-player tick event (IsoPlayer.update returns via
-- updateRemotePlayer before the OnPlayerUpdate trigger, guarded by assert !GameServer.server; OnTick
-- lives in the client's IngameState), so a server can't self-reconcile on a tick. Instead each
-- client reconciles its OWN player (OnPlayerUpdate fires for the local player in SP and on a client)
-- and, in MP, nudges the server to reconcile authoritatively + relay to observers. The client is only
-- the TRIGGER; the server recomputes the desired parts from its own authoritative ammo count and
-- never trusts a client-supplied part list.

---@param player IsoPlayer|nil
---@return nil
local function reconcilePartsForPlayer(player)
    if not player then
        return
    end

    local gun = player:getPrimaryHandItem()
    if not instanceof(gun, "HandWeapon") then
        return
    end

    local handler = ReloadAnim.GetHandlerForGun(gun)
    local profile = handler and handler.partState
    if not profile then
        return
    end

    if player:getVariableString("PerformingAction") == "Reload" then
        return
    end

    -- Outside a reload the off-hand slot is always stale. Sweeping it here frees the prop item when
    -- the reload's own restore never ran: a disconnect mid-reload, or an action killed without stop.
    ReloadAnim.clearOffHandProp(player)

    if isClient() then
        -- The client owns only the TRIGGER: nudge the server every tick the parts are wrong (never
        -- predict locally), so the nudge repeats until the server has the equip AND syncs the parts
        -- back. Predicting locally would clear the mismatch after one tick and lose a nudge that
        -- raced ahead of the equip-sync.
        if needsReconcile(gun, profile) then
            sendClientCommand(player, "SWMG", "reconcileParts", { gunId = gun:getID() })
        end
        return
    end

    -- Singleplayer: this machine is authoritative, apply directly.
    local changed = false
    if profile.ammoParts then
        changed = reconcileAmmoParts(gun, player, profile.ammoParts)
    end

    if profile.ensure then
        changed = reconcileEnsuredParts(gun, player, profile.ensure) or changed
    end

    if not changed then
        return
    end

    player:resetEquippedHandsModels()
    syncHandWeaponFields(player, gun)
end

--- Server-authoritative reconcile of one player's gun, computed from the SERVER's own ammo count and
--- profile (never from client input). Returns the desired {ammoParts, ensure} it applied, for the
--- observer relay, or nil if the gun carries no partState profile.
---@param player IsoPlayer
---@param gun HandWeapon|nil
---@nodiscard
---@return { ammoParts: string[]|nil, ensure: string[]|nil }|nil
function ReloadAnim.reconcileServerParts(player, gun)
    if not instanceof(gun, "HandWeapon") then
        return nil
    end

    local handler = ReloadAnim.GetHandlerForGun(gun)
    local profile = handler and handler.partState
    if not profile then
        return nil
    end

    if profile.ammoParts then
        reconcileAmmoParts(gun, player, profile.ammoParts)
    end
    if profile.ensure then
        reconcileEnsuredParts(gun, player, profile.ensure)
    end

    player:resetEquippedHandsModels()

    return {
        ammoParts = profile.ammoParts and desiredAmmoParts(gun, profile.ammoParts) or nil,
        ensure = profile.ensure,
    }
end

--- Apply a relayed steady-state part set on an observer client (or the reloader mirroring the
--- server). Idempotent: attachVisualPart skips a part already present, and swapping an ammo-keyed
--- part auto-detaches the previous one (same PartType).
---@param character IsoGameCharacter|nil
---@param gun HandWeapon|nil
---@param ammoParts string[]|nil
---@param ensure string[]|nil
---@return nil
function ReloadAnim.applyRemotePartState(character, gun, ammoParts, ensure)
    if not character or not instanceof(gun, "HandWeapon") then
        return
    end

    local changed = false
    if ammoParts then
        for i = 1, #ammoParts do
            if ammoParts[i] and ammoParts[i] ~= "" then
                changed = ReloadAnim.attachVisualPart(character, gun, ammoParts[i]) or changed
            end
        end
    end

    if ensure then
        for i = 1, #ensure do
            changed = ReloadAnim.attachVisualPart(character, gun, ensure[i]) or changed
        end
    end

    if changed then
        character:resetEquippedHandsModels()
    end
end

-- Register with the shared per-tick scheduler instead of adding our own OnPlayerUpdate handler, so every
-- weapon-part reconciler runs in one defined order. The scheduler guards its own OnPlayerUpdate on
-- isServer, so behaviour is unchanged: the pass runs for the local player in singleplayer + on an MP
-- client, never on the dedicated server (which reconciles reactively via the reconcileParts command).
-- Order 10 keeps reload first, ahead of downstream part providers.
PartReconcile.register("reload-parts", 10, reconcilePartsForPlayer)

return ReloadAnim
