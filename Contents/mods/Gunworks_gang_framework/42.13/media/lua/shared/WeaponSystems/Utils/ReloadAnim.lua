-- Gunworks reload-animation framework: registry + handler lookup.
--
-- Selects a per-gun reload animation through a Gunworks-owned mechanism instead of
-- the engine's WeaponReloadType enum, which B42.13 froze to a fixed set
-- (WeaponReloadType.java) so mods can no longer add their own reload types. Each
-- registered gun gets a handler carrying an animId; the reload/rack/eject hooks set
-- the custom character anim variable GunworksReloadAnim = animId, and the weapon
-- pack's AnimSet nodes gate on that variable. See ReloadAnim/HandlerFactory.lua for
-- the public RegisterWeapon API; this file is the registry core that other ReloadAnim
-- modules extend (kept dependency-free to avoid a require cycle).

---@class GunworksReloadAnimHandler
---@field id string
---@field fullType string|nil
---@field animId string
---@field archetype string|nil
---@field style string|nil
---@field loadedSprite string|nil
---@field unloadedSprite string|nil
---@field magItem string|nil
---@field magPart GunworksReloadPartSpec|string|nil
---@field parts table<string,GunworksReloadPartSpec>|nil
---@field states table<string,GunworksReloadAttachmentState>|nil
---@field loadedState string|nil
---@field unloadedState string|nil
---@field shortRackAfterInsert boolean|nil
---@field loadDuration number|nil
---@field loadShortDuration number|nil
---@field unloadDuration number|nil
---@field rackDuration number|nil
---@field partState GunworksReloadPartStateProfile|nil
---@field matches fun(gun:HandWeapon):boolean|nil
---@field autoRack boolean|nil
---@field consumes string[]|nil

---@class GunworksReloadPartSpec
---@field partType string|nil
---@field itemType string|nil
---@field doChange boolean|nil

--- Two mutually exclusive part items sharing one PartType, selected by whether the gun is loaded.
--- One spec covers every such part: a flintlock's cocked/uncooked flint, a trapdoor hammer's
--- cocked/uncooked, and so on. `loaded` shows while the gun has ammo, `unloaded` while it is empty.
---@class GunworksReloadAmmoPartSpec
---@field partType string
---@field loaded string
---@field unloaded string

--- Persistent cosmetic part state a gun always carries outside its reload animation. `ammoParts` lists
--- the parts whose variant follows the ammo count (flint, hammer). `props` lists the decorative items
--- its reload markers may place in the off-hand; it doubles as the server's whitelist for a prop change.
---@class GunworksReloadPartStateProfile
---@field ammoParts GunworksReloadAmmoPartSpec[]|nil
---@field ensure string[]|nil
---@field props string[]|nil

---@class GunworksReloadAttachmentState
---@field attach (GunworksReloadPartSpec|string)[]|nil
---@field detach (GunworksReloadPartSpec|string)[]|nil

---@class GunworksReloadAnim
local ReloadAnim = {}

--- Custom character anim variable that drives per-gun reload AnimSet node selection,
--- replacing the non-extensible engine variable "WeaponReloadType". A weapon pack's
--- AnimSet nodes must gate on this name with the gun's animId as the string value.
ReloadAnim.ANIM_VARIABLE = "GunworksReloadAnim"

--- AttachedLocations id for the in-hand reload magazine prop. Registered in
--- ReloadAnim/AttachLocations.lua (attachmentName = the off-hand prop bone Bip01_Prop2, so the
--- magazine model follows the left hand through the reload animation).
ReloadAnim.RELOAD_MAGAZINE_ATTACH_LOCATION = "GunworksReloadMag"

--- AttachedLocations id for a prop held in the RIGHT hand during a reload. Its attachmentName is the
--- "GunworksReloadHand" ModelAttachment we add to the body ModelScripts (client/.../HandAttachment.lua),
--- bound to Bip01_R_Hand. It cannot reuse Bip01_Prop1 (the engine puts the primary weapon model there,
--- AnimatedModel:625) or Bip01_Prop2 (the off-hand ramrod's slot), so it needs its own attachment. A
--- second, independent slot from the off-hand one above, so a reload can show a hand-held consumable
--- (e.g. a musket's paper cartridge / ball) tracking the right hand while a gun part (e.g. the ramrod)
--- tracks Bip01_Prop2 at the same time. Because a runtime attachment only resolves on a client that
--- actually registered it, HandAttachment.lua registers it with a bounded retry so a joining observer
--- has it too. Fed by the `gwSetHandProp` marker. (The id string here is the same as the attachment
--- name only by coincidence; it is just an opaque slot key like RELOAD_MAGAZINE_ATTACH_LOCATION's
--- "GunworksReloadMag".)
ReloadAnim.RELOAD_HAND_ATTACH_LOCATION = "GunworksReloadHand"

--- Recognised non-magazine reload archetypes. These guns reload through the vanilla
--- ISReloadWeaponAction (round/shell-by-shell) rather than the magazine eject/insert/rack
--- chain, so they take a different set of hooks and AnimSet stage nodes. The string values
--- match the engine WeaponReloadType the gun's item script must still declare; Gunworks only
--- swaps the animation on top, the reload MECHANICS stay 100% vanilla.
---@type table<string,boolean>
ReloadAnim.NON_MAG_ARCHETYPES = {
    shotgun = true,
    revolver = true,
    boltactionnomag = true,
    doublebarrel = true,
    lever = true,
}

--- Is this archetype one of the non-magazine (ISReloadWeaponAction-driven) reloads?
---@param archetype string|nil
---@nodiscard
---@return boolean
function ReloadAnim.isNonMagArchetype(archetype)
    if not archetype then
        return false
    end

    return ReloadAnim.NON_MAG_ARCHETYPES[archetype] == true
end

--- Flat list of every registered handler (registration order; used for introspection).
---@type GunworksReloadAnimHandler[]
ReloadAnim.handlers = {}

--- O(1) lookup index: weapon fullType -> handler.
---@type table<string,GunworksReloadAnimHandler>
ReloadAnim.byFullType = {}

--- Predicate-based handlers (handler.matches(gun)); checked before the fullType index.
---@type GunworksReloadAnimHandler[]
ReloadAnim.matchers = {}

--- Rebuild the lookup indexes from the flat handler list.
---@return nil
function ReloadAnim.reindex()
    local byFullType = {}
    local matchers = {}
    local list = ReloadAnim.handlers
    for i = 1, #list do
        local handler = list[i]
        if handler.matches then
            matchers[#matchers + 1] = handler
        end
        if handler.fullType then
            byFullType[handler.fullType] = handler
        end
    end
    ReloadAnim.byFullType = byFullType
    ReloadAnim.matchers = matchers
end

--- Register (or replace, by id) a fully-built handler. Prefer the higher-level
--- RegisterWeapon (ReloadAnim/HandlerFactory.lua) over calling this directly.
---@param handler GunworksReloadAnimHandler
---@return nil
function ReloadAnim.registerHandler(handler)
    if not handler or not handler.id then
        return
    end

    local list = ReloadAnim.handlers
    for i = 1, #list do
        if list[i].id == handler.id then
            list[i] = handler
            ReloadAnim.reindex()
            return
        end
    end

    list[#list + 1] = handler
    ReloadAnim.reindex()
end

--- Remove a handler by id.
---@param handlerId string|nil
---@return nil
function ReloadAnim.unregisterHandler(handlerId)
    if not handlerId then
        return
    end

    local list = ReloadAnim.handlers
    for i = #list, 1, -1 do
        if list[i].id == handlerId then
            table.remove(list, i)
        end
    end
    ReloadAnim.reindex()
end

---@nodiscard
---@return GunworksReloadAnimHandler[]
function ReloadAnim.getHandlers()
    return ReloadAnim.handlers
end

--- Resolve the handler for a gun: predicate matchers first, then the fullType index.
---@param gun HandWeapon|nil
---@nodiscard
---@return GunworksReloadAnimHandler|nil
function ReloadAnim.GetHandlerForGun(gun)
    if not instanceof(gun, "HandWeapon") then
        return nil
    end

    local matchers = ReloadAnim.matchers
    for i = 1, #matchers do
        local handler = matchers[i]
        if handler.matches(gun) then
            return handler
        end
    end

    return ReloadAnim.byFullType[gun:getFullType()]
end

--- Alias matching the Magazine/RateOfFire registry naming (returns the same handler).
---@param gun HandWeapon|nil
---@nodiscard
---@return GunworksReloadAnimHandler|nil
function ReloadAnim.GetProfileForGun(gun)
    return ReloadAnim.GetHandlerForGun(gun)
end

-- Standalone per-round consume registry, keyed on weapon fullType. Lets a gun declare multi-item
-- reload costs WITHOUT a full anim handler (e.g. a revolver on the vanilla reload animation), and
-- keeps the ammo/consume config independent of the reload-animation profile.
ReloadAnim.consumesByFullType = ReloadAnim.consumesByFullType or {}

--- Register the extra items a gun consumes per round (on top of its valued bullet). Opt-in.
---@param fullType string
---@param items string[]
---@return nil
function ReloadAnim.RegisterConsumes(fullType, items)
    ReloadAnim.consumesByFullType[fullType] = items
end

--- The extra per-round reload items this gun requires + consumes (on top of the valued bullet),
--- or nil if it reloads the vanilla single-item way. Checks the reload handler's `consumes` first,
--- then the standalone registry. See CustomSystemHooks loadAmmo.
---@param gun HandWeapon|nil
---@nodiscard
---@return string[]|nil
function ReloadAnim.GetConsumeItemsForGun(gun)
    if not instanceof(gun, "HandWeapon") then
        return nil
    end
    local handler = ReloadAnim.GetHandlerForGun(gun)
    local consumes = handler and handler.consumes
    if not consumes then
        consumes = ReloadAnim.consumesByFullType[gun:getFullType()]
    end
    if type(consumes) ~= "table" or #consumes == 0 then
        return nil
    end
    return consumes
end

--- Resolve the handler for a timed action via its .gun field.
---@param action ISBaseTimedAction|nil
---@nodiscard
---@return GunworksReloadAnimHandler|nil
function ReloadAnim.getHandlerForAction(action)
    if not action or not action.gun then
        return nil
    end

    return ReloadAnim.GetHandlerForGun(action.gun)
end

return ReloadAnim
