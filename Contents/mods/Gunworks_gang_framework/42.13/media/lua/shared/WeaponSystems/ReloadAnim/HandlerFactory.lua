-- Gunworks reload-animation framework: handler construction + public RegisterWeapon API.
-- Ported from AnimatedReloads' HandlerFactory; the reload-type string is now the
-- gun's animId and registration is keyed on weapon fullType (with an optional
-- matches(gun) predicate), matching the Magazine/RateOfFire registries.

---@class GunworksReloadAnim
local ReloadAnim = require("WeaponSystems/Utils/ReloadAnim")

---@param options table|nil
---@param message string
---@return nil
function ReloadAnim.logInvalidOptions(options, message)
    local id = options and (options.id or options.fullType or options.animId) or "unknown"
    print("[Gunworks/ReloadAnim] Invalid handler options (" .. tostring(id) .. "): " .. message)
end

--- Flatten a public RegisterWeapon profile into the internal handler shape.
---@param fullType string|nil
---@param options table|nil
---@nodiscard
---@return table|nil
function ReloadAnim.normalizeWeaponReloadOptions(fullType, options)
    if not options then
        return nil
    end

    local normalized = {
        id = options.id or fullType or options.animId,
        fullType = fullType,
        animId = options.animId,
        archetype = options.archetype,
        style = options.style,
        magItem = options.magItem,
        shortRackAfterInsert = options.shortRackAfterInsert,
        autoRack = options.autoRack,
        partState = options.partState,
        matches = options.matches,
        -- Extra inventory items required + consumed PER ROUND on top of the valued bullet
        -- (the projectile the gun's AmmoType names). e.g. a paper powder charge + a percussion
        -- cap for a cap-lock. Array of item fullTypes. Consumed server-authoritatively during
        -- the reload; see CustomSystemHooks loadAmmo. Opt-in: nil = vanilla single-item reload.
        consumes = options.consumes,
    }

    -- A non-magazine gun's off-hand prop (a shell/round/speedloader) reuses the same
    -- attach plumbing as the magazine prop, so accept the friendlier profile.prop.item
    -- and fold it into magItem (the field Visuals.lua reads). magItem still wins if both
    -- are given.
    if not normalized.magItem and type(options.prop) == "table" then
        normalized.magItem = options.prop.item
    end

    if type(options.durations) == "table" then
        local durations = options.durations
        normalized.loadDuration = durations.load
        normalized.loadShortDuration = durations.loadShort
        normalized.unloadDuration = durations.unload
        normalized.rackDuration = durations.rack
    end

    if type(options.sprite) == "table" then
        normalized.loadedSprite = options.sprite.loaded
        normalized.unloadedSprite = options.sprite.unloaded
    end

    if type(options.attachments) == "table" then
        local attachments = options.attachments
        normalized.magPart = attachments.magPart
        normalized.parts = attachments.parts
        normalized.states = attachments.states
        normalized.loadedState = attachments.loadedState
        normalized.unloadedState = attachments.unloadedState
    end

    -- Magazine guns default to a whole-sprite swap; non-magazine guns default to no model
    -- swap at all (most pumps/revolvers just animate the arms over the static gun), but may
    -- opt into "sprite"/"attachment" if they have an open/closed or break-action model. A
    -- magazine gun with no separate texture and no part swap can opt OUT of the sprite default
    -- by setting style = "none" explicitly (see createSimpleReloadHandler).
    if not normalized.style then
        normalized.style = ReloadAnim.isNonMagArchetype(normalized.archetype) and "none" or "sprite"
    end
    -- Accept both "attachment" and "attachments" for the part-swap style.
    if normalized.style == "attachment" then
        normalized.style = "attachments"
    end
    -- "simple" is the friendlier spelling of a bare, animation-only magazine profile - the
    -- magazine-archetype counterpart to a non-mag profile's "none" default (see
    -- createSimpleReloadHandler below).
    if normalized.style == "simple" then
        normalized.style = "none"
    end

    -- Part-conditional profile: `whenParts` synthesises a matches(gun) predicate, AND-scoped to
    -- the weapon fullType when one was given, so this profile wins WHILE the listed part(s) are
    -- attached and otherwise falls through to the gun's unconditional profile. It is kept OUT of
    -- the fullType index (normalized.fullType cleared, like the Gunworks facade's RegisterWeapon(nil,
    -- ...) call) so it can never shadow that base profile; the fullType is still captured in the
    -- closure for the gun-identity check. An explicit `matches` always wins over `whenParts`.
    -- Register the most specific condition FIRST - matchers are tried in registration order.
    if options.whenParts and not normalized.matches then
        local condition = ReloadAnim.normalizePartCondition(options.whenParts)
        if not condition then
            ReloadAnim.logInvalidOptions(options,
                "whenParts must be an item/partType string, an array of them, or { all/any/none = {...} }")
            return nil
        end

        local gunType = fullType
        normalized.matches = function(gun)
            if gunType and gun:getFullType() ~= gunType then
                return false
            end
            return ReloadAnim.gunMatchesPartCondition(gun, condition)
        end
        normalized.id = options.id
            or ((fullType or options.animId or "reloadAnim") .. "@" .. ReloadAnim.partConditionKey(condition))
        normalized.fullType = nil
    end

    return normalized
end

--- Validate the optional persistent-part profile. A malformed one would mis-render silently, so
--- reject the whole registration rather than drop the field.
---@param options table
---@nodiscard
---@return boolean
function ReloadAnim.validatePartStateOptions(options)
    local partState = options.partState
    if not partState then
        return true
    end

    if type(partState) ~= "table" then
        ReloadAnim.logInvalidOptions(options, "partState must be a table")
        return false
    end

    local ammoParts = partState.ammoParts
    if ammoParts then
        if type(ammoParts) ~= "table" then
            ReloadAnim.logInvalidOptions(options, "partState.ammoParts must be an array of {partType, loaded, unloaded}")
            return false
        end
        for i = 1, #ammoParts do
            local spec = ammoParts[i]
            if type(spec) ~= "table" or not spec.partType or not spec.loaded or not spec.unloaded then
                ReloadAnim.logInvalidOptions(options, "partState.ammoParts[" .. i .. "] requires partType, loaded and unloaded")
                return false
            end
        end
    end

    local lists = { ensure = partState.ensure, props = partState.props }
    for name, list in pairs(lists) do
        if type(list) ~= "table" then
            ReloadAnim.logInvalidOptions(options, "partState." .. name .. " must be an array of item fullTypes")
            return false
        end

        for i = 1, #list do
            if type(list[i]) ~= "string" or list[i] == "" then
                ReloadAnim.logInvalidOptions(options, "partState." .. name .. "[" .. i .. "] must be a non-empty item fullType")
                return false
            end
        end
    end

    return true
end

---@param options table|nil
---@nodiscard
---@return boolean
function ReloadAnim.validateReloadOptions(options)
    if not options then
        return false
    end

    if not options.animId or options.animId == "" then
        ReloadAnim.logInvalidOptions(options, "animId is required (it must equal the AnimSet node's GunworksReloadAnim value)")
        return false
    end

    if not options.fullType and not options.matches then
        ReloadAnim.logInvalidOptions(options, "a weapon fullType or a matches(gun) predicate is required")
        return false
    end

    return ReloadAnim.validatePartStateOptions(options)
end

---@param options table|nil
---@nodiscard
---@return boolean
function ReloadAnim.validateSpriteReloadOptions(options)
    if not ReloadAnim.validateReloadOptions(options) then
        return false
    end

    if not options.loadedSprite or options.loadedSprite == "" then
        ReloadAnim.logInvalidOptions(options, "sprite.loaded is required for style = sprite")
        return false
    end

    if not options.unloadedSprite or options.unloadedSprite == "" then
        ReloadAnim.logInvalidOptions(options, "sprite.unloaded is required for style = sprite")
        return false
    end

    if not options.magItem or options.magItem == "" then
        ReloadAnim.logInvalidOptions(options, "magItem is required for style = sprite")
        return false
    end

    return true
end

---@param options table|nil
---@nodiscard
---@return boolean
function ReloadAnim.validateAttachmentReloadOptions(options)
    if not ReloadAnim.validateReloadOptions(options) then
        return false
    end

    if not options.magItem or options.magItem == "" then
        ReloadAnim.logInvalidOptions(options, "magItem is required for style = attachments")
        return false
    end

    local magPart = options.magPart
    if not magPart then
        ReloadAnim.logInvalidOptions(options, "attachments.magPart is required for style = attachments")
        return false
    end

    if type(magPart) == "table" then
        if not magPart.itemType or magPart.itemType == "" then
            ReloadAnim.logInvalidOptions(options, "attachments.magPart.itemType is required")
            return false
        end
    elseif type(magPart) == "string" then
        if not options.parts or not options.parts[magPart] then
            ReloadAnim.logInvalidOptions(options, "attachments.magPart key must exist in attachments.parts")
            return false
        end
    end

    return true
end

--- Validate a non-magazine (ISReloadWeaponAction-driven) profile. These guns need only an
--- animId + a fullType/matches; a prop or model swap is optional, but if the author opts
--- into a sprite/attachment model swap they must satisfy that style's requirements.
---@param options table|nil
---@nodiscard
---@return boolean
function ReloadAnim.validateNonMagReloadOptions(options)
    if not ReloadAnim.validateReloadOptions(options) then
        return false
    end

    if options.style == "sprite" then
        return ReloadAnim.validateSpriteReloadOptions(options)
    end

    if options.style == "attachments" then
        return ReloadAnim.validateAttachmentReloadOptions(options)
    end

    return true
end

---@param options table
---@nodiscard
---@return GunworksReloadAnimHandler
function ReloadAnim.createSpriteReloadHandler(options)
    return {
        id = options.id,
        fullType = options.fullType,
        animId = options.animId,
        style = "sprite",
        loadedSprite = options.loadedSprite,
        unloadedSprite = options.unloadedSprite,
        magItem = options.magItem,
        shortRackAfterInsert = options.shortRackAfterInsert,
        loadDuration = options.loadDuration,
        loadShortDuration = options.loadShortDuration,
        unloadDuration = options.unloadDuration,
        rackDuration = options.rackDuration,
        partState = options.partState,
        matches = options.matches,
        consumes = options.consumes,
        onEjectStart = function(action)
            return false
        end,
        onEjectAnimEvent = function(action, event, parameter)
            local handled = ReloadAnim.handleWeaponSpriteAnimEvent(action, event, parameter)
            if handled then
                local handler = ReloadAnim.getHandlerForAction(action)
                if handler and parameter == handler.unloadedSprite then
                    ReloadAnim.attachReloadMagazine(action, handler)
                end
            end
            return false
        end,
        onEjectStop = function(action)
            ReloadAnim.detachReloadMagazine(action)
        end,
        onEjectPerform = function(action)
            ReloadAnim.detachReloadMagazine(action)
        end,
        onInsertStart = function(action)
            ReloadAnim.setShortRackAfterInsert(action, options.shortRackAfterInsert)
            ReloadAnim.attachReloadMagazine(action, ReloadAnim.getHandlerForAction(action))
        end,
        onInsertAnimEvent = function(action, event, parameter)
            local handled = ReloadAnim.handleWeaponSpriteAnimEvent(action, event, parameter)
            if handled then
                ReloadAnim.detachReloadMagazine(action)
            end
            return false
        end,
        onInsertStop = function(action)
            ReloadAnim.detachReloadMagazine(action)
            ReloadAnim.setShortRackAfterInsert(action, false)
        end,
        onInsertLoadAmmo = function(action)
            if options.shortRackAfterInsert and not isServer() and not isClient() then
                if ReloadAnim.shouldQueueShortRackAfterInsert(action) then
                    ReloadAnim.setShortRackPending(action)
                end
            end
        end,
        onInsertPerform = function(action)
            ReloadAnim.detachReloadMagazine(action)
            ReloadAnim.setShortRackAfterInsert(action, false)

            if options.shortRackAfterInsert and isClient() then
                if ReloadAnim.shouldQueueShortRackAfterInsert(action) then
                    ReloadAnim.setShortRackPending(action)
                end
            end
        end,
        onRackStart = function(action)
            if not options.shortRackAfterInsert then
                return false
            end

            return ReloadAnim.handleShortRackStart(action, ReloadAnim.getHandlerForAction(action))
        end,
        onRackStop = function(action)
            if options.shortRackAfterInsert then
                ReloadAnim.handleShortRackStop(action)
            end
        end,
        onRackPerform = function(action)
            if options.shortRackAfterInsert then
                ReloadAnim.handleShortRackPerform(action)
            end
        end,
    }
end

--- Build a handler for a magazine-archetype gun that only needs a custom animation clip: no
--- separate loaded/unloaded texture (style = "sprite") and no part swap (style = "attachments").
--- This is the registry gap those two styles don't cover - both mandate a visual swap
--- (validateSpriteReloadOptions requires loadedSprite/unloadedSprite/magItem;
--- validateAttachmentReloadOptions requires magPart) even for a gun whose pack has no separate
--- open/closed model at all, so a bare "just play this clip" profile was previously rejected by
--- RegisterWeapon (see validateReloadOptions - the baseline this style uses instead).
---
--- A real magazine item is still optional (magItem): if given, the reload-magazine prop shows in
--- the off-hand for the whole eject/insert action (attached at start, detached at stop/perform) -
--- simpler, start-anchored timing than the sprite style's changeWeaponSprite-driven attach, since
--- there is no sprite-swap event to hang it on here. Also wires the gwSetPart/gwSetProp/
--- gwSetHandProp/gwPartToHand/gwPartToGun markers (Props.lua/PartSwap.lua) so a "simple" profile
--- can still opt into a mid-reload part swap or off-hand prop later without switching style.
---@param options table
---@nodiscard
---@return GunworksReloadAnimHandler
function ReloadAnim.createSimpleReloadHandler(options)
    return {
        id = options.id,
        fullType = options.fullType,
        animId = options.animId,
        style = "none",
        magItem = options.magItem,
        shortRackAfterInsert = options.shortRackAfterInsert,
        loadDuration = options.loadDuration,
        loadShortDuration = options.loadShortDuration,
        unloadDuration = options.unloadDuration,
        rackDuration = options.rackDuration,
        partState = options.partState,
        matches = options.matches,
        consumes = options.consumes,
        onEjectStart = function(action)
            ReloadAnim.attachReloadMagazine(action, ReloadAnim.getHandlerForAction(action))
            return false
        end,
        onEjectAnimEvent = function(action, event, parameter)
            local handler = ReloadAnim.getHandlerForAction(action)
            if ReloadAnim.handleGwSetPartAnimEvent(action, handler, event, parameter) then
                return false
            end
            ReloadAnim.handlePropAnimEvent(action, handler, event, parameter)
            return false
        end,
        onEjectStop = function(action)
            ReloadAnim.detachReloadMagazine(action)
        end,
        onEjectPerform = function(action)
            ReloadAnim.detachReloadMagazine(action)
        end,
        onInsertStart = function(action)
            ReloadAnim.setShortRackAfterInsert(action, options.shortRackAfterInsert)
            ReloadAnim.attachReloadMagazine(action, ReloadAnim.getHandlerForAction(action))
        end,
        onInsertAnimEvent = function(action, event, parameter)
            local handler = ReloadAnim.getHandlerForAction(action)
            if ReloadAnim.handleGwSetPartAnimEvent(action, handler, event, parameter) then
                return false
            end
            ReloadAnim.handlePropAnimEvent(action, handler, event, parameter)
            return false
        end,
        onInsertStop = function(action)
            ReloadAnim.detachReloadMagazine(action)
            ReloadAnim.setShortRackAfterInsert(action, false)
        end,
        onInsertLoadAmmo = function(action)
            if options.shortRackAfterInsert and not isServer() and not isClient() then
                if ReloadAnim.shouldQueueShortRackAfterInsert(action) then
                    ReloadAnim.setShortRackPending(action)
                end
            end
        end,
        onInsertPerform = function(action)
            ReloadAnim.detachReloadMagazine(action)
            ReloadAnim.setShortRackAfterInsert(action, false)

            if options.shortRackAfterInsert and isClient() then
                if ReloadAnim.shouldQueueShortRackAfterInsert(action) then
                    ReloadAnim.setShortRackPending(action)
                end
            end
        end,
        onRackStart = function(action)
            if not options.shortRackAfterInsert then
                return false
            end

            return ReloadAnim.handleShortRackStart(action, ReloadAnim.getHandlerForAction(action))
        end,
        onRackStop = function(action)
            if options.shortRackAfterInsert then
                ReloadAnim.handleShortRackStop(action)
            end
        end,
        onRackPerform = function(action)
            if options.shortRackAfterInsert then
                ReloadAnim.handleShortRackPerform(action)
            end
        end,
    }
end

---@param options table
---@nodiscard
---@return GunworksReloadAnimHandler
function ReloadAnim.createAttachmentReloadHandler(options)
    local loadedState = options.loadedState or "loaded"
    local unloadedState = options.unloadedState or "unloaded"
    local parts = options.parts or {}

    if type(options.magPart) == "table" then
        parts.mag = options.magPart
    elseif type(options.magPart) == "string" and parts[options.magPart] then
        parts.mag = parts[options.magPart]
    end

    local states = options.states
    if not states then
        states = {
            loaded = { attach = { "mag" } },
            unloaded = { detach = { "mag" } }
        }
    end

    return {
        id = options.id,
        fullType = options.fullType,
        animId = options.animId,
        style = "attachments",
        magItem = options.magItem,
        magPart = options.magPart,
        parts = parts,
        states = states,
        loadedState = loadedState,
        unloadedState = unloadedState,
        shortRackAfterInsert = options.shortRackAfterInsert,
        loadDuration = options.loadDuration,
        loadShortDuration = options.loadShortDuration,
        unloadDuration = options.unloadDuration,
        rackDuration = options.rackDuration,
        partState = options.partState,
        matches = options.matches,
        consumes = options.consumes,
        onEjectStart = function(action)
            return false
        end,
        onEjectAnimEvent = function(action, event, parameter)
            local handler = ReloadAnim.getHandlerForAction(action)
            if ReloadAnim.handleWeaponPartAnimEvent(action, handler, event, parameter) then
                return false
            end

            return ReloadAnim.handleWeaponAttachmentStateAnimEvent(action, handler, event, parameter)
        end,
        onEjectStop = function(action)
            local handler = ReloadAnim.getHandlerForAction(action)
            ReloadAnim.detachReloadMagazine(action)
            ReloadAnim.setWeaponAttachmentState(action, handler, unloadedState)
        end,
        onEjectPerform = function(action)
            local handler = ReloadAnim.getHandlerForAction(action)
            ReloadAnim.detachReloadMagazine(action)
            ReloadAnim.setWeaponAttachmentState(action, handler, unloadedState)
        end,
        onInsertStart = function(action)
            ReloadAnim.setShortRackAfterInsert(action, options.shortRackAfterInsert)
            ReloadAnim.attachReloadMagazine(action, ReloadAnim.getHandlerForAction(action))
        end,
        onInsertAnimEvent = function(action, event, parameter)
            local handler = ReloadAnim.getHandlerForAction(action)
            if ReloadAnim.handleWeaponPartAnimEvent(action, handler, event, parameter) then
                return false
            end

            local handled = ReloadAnim.handleWeaponAttachmentStateAnimEvent(action, handler, event, parameter)
            if handled then
                ReloadAnim.detachReloadMagazine(action)
            end
            return false
        end,
        onInsertStop = function(action)
            local handler = ReloadAnim.getHandlerForAction(action)
            ReloadAnim.detachReloadMagazine(action)
            ReloadAnim.setShortRackAfterInsert(action, false)
            ReloadAnim.setWeaponAttachmentState(action, handler, loadedState)
        end,
        onInsertLoadAmmo = function(action)
            local handler = ReloadAnim.getHandlerForAction(action)
            ReloadAnim.setWeaponAttachmentState(action, handler, loadedState)
            if options.shortRackAfterInsert and not isServer() and not isClient() then
                if ReloadAnim.shouldQueueShortRackAfterInsert(action) then
                    ReloadAnim.setShortRackPending(action)
                end
            end
        end,
        onInsertPerform = function(action)
            local handler = ReloadAnim.getHandlerForAction(action)
            ReloadAnim.detachReloadMagazine(action)
            ReloadAnim.setShortRackAfterInsert(action, false)
            ReloadAnim.setWeaponAttachmentState(action, handler, loadedState)

            if options.shortRackAfterInsert and isClient() then
                if ReloadAnim.shouldQueueShortRackAfterInsert(action) then
                    ReloadAnim.setShortRackPending(action)
                end
            end
        end,
        onRackStart = function(action)
            if not options.shortRackAfterInsert then
                return false
            end

            return ReloadAnim.handleShortRackStart(action, ReloadAnim.getHandlerForAction(action))
        end,
        onRackStop = function(action)
            if options.shortRackAfterInsert then
                ReloadAnim.handleShortRackStop(action)
            end
        end,
        onRackPerform = function(action)
            if options.shortRackAfterInsert then
                ReloadAnim.handleShortRackPerform(action)
            end
        end,
    }
end

--- Build a handler for a non-magazine archetype (shotgun / revolver / bolt-action-no-mag /
--- double-barrel / lever). These reload through the vanilla ISReloadWeaponAction, so the
--- handler carries onReload* callbacks (not the magazine onEject/onInsert/onRack ones). The
--- callbacks add ONLY the optional off-hand prop and model swaps; the vanilla action keeps
--- full ownership of timing, the shell-by-shell loadFinished/loadAmmo loop, and racking.
---@param options table
---@nodiscard
---@return GunworksReloadAnimHandler
function ReloadAnim.createNonMagReloadHandler(options)
    local loadedState = options.loadedState or "loaded"
    local unloadedState = options.unloadedState or "unloaded"
    local parts = options.parts or {}

    if type(options.magPart) == "table" then
        parts.mag = options.magPart
    elseif type(options.magPart) == "string" and parts[options.magPart] then
        parts.mag = parts[options.magPart]
    end

    return {
        id = options.id,
        fullType = options.fullType,
        animId = options.animId,
        archetype = options.archetype,
        style = options.style,
        loadedSprite = options.loadedSprite,
        unloadedSprite = options.unloadedSprite,
        magItem = options.magItem,
        magPart = options.magPart,
        parts = parts,
        states = options.states,
        loadedState = loadedState,
        unloadedState = unloadedState,
        loadDuration = options.loadDuration,
        loadShortDuration = options.loadShortDuration,
        unloadDuration = options.unloadDuration,
        rackDuration = options.rackDuration,
        partState = options.partState,
        autoRack = options.autoRack,
        matches = options.matches,
        consumes = options.consumes,
        onReloadStart = function(action)
            ReloadAnim.attachReloadMagazine(action, ReloadAnim.getHandlerForAction(action))
        end,
        onReloadAnimEvent = function(action, event, parameter)
            -- Additive only: never block vanilla animEvent (it owns loadFinished/loadAmmo).
            -- A style="none" gun (the common case) has no such events, so this is a no-op.
            local handler = ReloadAnim.getHandlerForAction(action)
            if ReloadAnim.handleGwSetPartAnimEvent(action, handler, event, parameter) then
                return false
            end
            if ReloadAnim.handlePropAnimEvent(action, handler, event, parameter) then
                return false
            end
            if ReloadAnim.handleWeaponSpriteAnimEvent(action, event, parameter) then
                return false
            end
            if ReloadAnim.handleWeaponPartAnimEvent(action, handler, event, parameter) then
                return false
            end
            ReloadAnim.handleWeaponAttachmentStateAnimEvent(action, handler, event, parameter)
            return false
        end,
        onReloadStop = function(action)
            ReloadAnim.detachReloadMagazine(action)
            ReloadAnim.restoreReloadPartState(action)
        end,
        onReloadPerform = function(action)
            ReloadAnim.detachReloadMagazine(action)
            ReloadAnim.restoreReloadPartState(action)
        end,
    }
end

--- Public API: register a per-gun reload animation profile.
--- Magazine guns (no archetype, or archetype "magazine") use the eject/insert/rack chain.
--- Set archetype to a non-mag value ("shotgun"/"revolver"/"boltactionnomag"/"doublebarrel"/
--- "lever") for guns that reload through ISReloadWeaponAction; those need only animId + a
--- fullType/matches, with an optional off-hand prop (profile.prop.item) and model swap.
--- Non-mag guns that have no break-action to close (e.g. muzzle-loaders) can set autoRack = false to
--- skip the vanilla close/rack finish stage: the reload force-completes the instant the rounds load
--- (on loadFinished), so the "snap the action shut" animation that stage plays never runs. The load
--- clip still plays in full, so keep the node's loadFinished event at m_Time = End.
--- Magazine guns default to style = "sprite" (a real loaded/unloaded texture is required). Set
--- style = "none" (alias "simple") for a magazine gun that has no separate texture and no part
--- swap - just a custom animId, exactly like a non-mag profile's default. See
--- createSimpleReloadHandler; magItem is still accepted there for an optional off-hand prop.
---
--- Installed-part conditions: set `whenParts` to swap the reload animation based on what is
--- currently attached to the gun rather than which gun it is. The value is an item fullType OR a
--- partType slot, an array of them (all must be attached), or { all = {...}, any = {...},
--- none = {...} }. A whenParts profile is AND-scoped to `fullType` when one is given (pass nil for
--- "any gun carrying this part"); it wins while its condition holds and otherwise falls through to
--- the gun's plain profile. Give each variant its own `whenParts` (or `id`); register the most
--- specific one first, matchers are tried in registration order. `profile` may also be an ARRAY of
--- profiles for one fullType (a base plus whenParts variants).
---@param fullType string|nil  weapon fullType key, e.g. "MyPack.M249Rifle" (nil only if profile.matches or profile.whenParts is set)
---@param profile {animId:string,archetype:string|nil,style:string|nil,magItem:string|nil,prop:{item:string|nil}|nil,sprite:{loaded:string|nil,unloaded:string|nil}|nil,attachments:table|nil,durations:{load:number|nil,loadShort:number|nil,unload:number|nil,rack:number|nil}|nil,shortRackAfterInsert:boolean|nil,matches:fun(gun:HandWeapon):boolean|nil,whenParts:string|string[]|table|nil,id:string|nil}|table[]
---@return nil
function ReloadAnim.RegisterWeapon(fullType, profile)
    -- An array of profiles for one gun (base + whenParts variants). Each entry carries its own
    -- animId, so recursion bottoms out on the first pass.
    if type(profile) == "table" and not profile.animId and profile[1] then
        for i = 1, #profile do
            ReloadAnim.RegisterWeapon(fullType, profile[i])
        end
        return
    end

    local normalized = ReloadAnim.normalizeWeaponReloadOptions(fullType, profile)
    if not normalized then
        return
    end

    local handler = nil
    if ReloadAnim.isNonMagArchetype(normalized.archetype) then
        if not ReloadAnim.validateNonMagReloadOptions(normalized) then
            return
        end
        handler = ReloadAnim.createNonMagReloadHandler(normalized)
    elseif normalized.style == "attachments" then
        if not ReloadAnim.validateAttachmentReloadOptions(normalized) then
            return
        end
        handler = ReloadAnim.createAttachmentReloadHandler(normalized)
    elseif normalized.style == "none" then
        -- Bare magazine profile: same minimum bar as a non-mag one (animId + fullType/matches),
        -- no sprite/magPart required.
        if not ReloadAnim.validateReloadOptions(normalized) then
            return
        end
        handler = ReloadAnim.createSimpleReloadHandler(normalized)
    else
        if not ReloadAnim.validateSpriteReloadOptions(normalized) then
            return
        end
        handler = ReloadAnim.createSpriteReloadHandler(normalized)
    end

    if not handler then
        return
    end

    ReloadAnim.registerHandler(handler)
end

--- Public API: register many guns at once. Keys are weapon fullTypes; each value is a single
--- profile or an array of profiles (a base plus whenParts variants for that gun).
---@param entries table<string,table|table[]>
---@return nil
function ReloadAnim.RegisterMultipleWeapons(entries)
    if not entries then
        return
    end

    for fullType, profile in pairs(entries) do
        ReloadAnim.RegisterWeapon(fullType, profile)
    end
end

return ReloadAnim
