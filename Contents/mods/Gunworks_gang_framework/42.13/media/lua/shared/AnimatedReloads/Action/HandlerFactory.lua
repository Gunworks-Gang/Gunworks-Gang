---@class AnimatedReloadsAction
local AnimatedReloadsAction = require("AnimatedReloads/Action/Core")
---@param options table|nil
---@param message string
---@return nil
function AnimatedReloadsAction.logInvalidOptions(options, message)
    local id = options and options.id or options and options.reloadType or "unknown"
    print("[AnimatedReloads] Invalid handler options (" .. tostring(id) .. "): " .. message)
end

---@param options table|nil
---@return table|nil
function AnimatedReloadsAction.normalizeWeaponReloadOptions(options)
    if not options then
        return nil
    end

    local normalized = {
        id = options.id,
        reloadType = options.reloadType,
        style = options.style,
        magItem = options.magItem,
        shortRackAfterInsert = options.shortRackAfterInsert,
        matches = options.matches,
    }

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

    normalized.style = normalized.style or "sprite"

    return normalized
end

---@param options table|nil
---@return boolean
function AnimatedReloadsAction.validateSpriteReloadOptions(options)
    if not options then
        return false
    end

    if not options.loadedSprite or options.loadedSprite == "" then
        AnimatedReloadsAction.logInvalidOptions(options, "sprite.loaded is required for style = sprite")
        return false
    end

    if not options.unloadedSprite or options.unloadedSprite == "" then
        AnimatedReloadsAction.logInvalidOptions(options, "sprite.unloaded is required for style = sprite")
        return false
    end

    if not options.magItem or options.magItem == "" then
        AnimatedReloadsAction.logInvalidOptions(options, "magItem is required for style = sprite")
        return false
    end

    return true
end

---@param options table|nil
---@return boolean
function AnimatedReloadsAction.validateAttachmentReloadOptions(options)
    if not options then
        return false
    end

    if not options.magItem or options.magItem == "" then
        AnimatedReloadsAction.logInvalidOptions(options, "magItem is required for style = attachments")
        return false
    end

    local magPart = options.magPart
    if not magPart then
        AnimatedReloadsAction.logInvalidOptions(options, "attachments.magPart is required for style = attachments")
        return false
    end

    if type(magPart) == "table" then
        if not magPart.itemType or magPart.itemType == "" then
            AnimatedReloadsAction.logInvalidOptions(options, "attachments.magPart.itemType is required")
            return false
        end
    elseif type(magPart) == "string" then
        if not options.parts or not options.parts[magPart] then
            AnimatedReloadsAction.logInvalidOptions(options, "attachments.magPart key must exist in attachments.parts")
            return false
        end
    end

    return true
end

---@param options {id:string|nil,reloadType:string|nil,magItem:string|nil,loadedSprite:string|nil,unloadedSprite:string|nil,shortRackAfterInsert:boolean|nil,loadDuration:number|nil,loadShortDuration:number|nil,unloadDuration:number|nil,rackDuration:number|nil,matches:fun(gun:HandWeapon):boolean|nil}
---@nodiscard
---@return AnimatedReloadsHandler
function AnimatedReloadsAction.createSpriteReloadHandler(options)
    return {
        id = options.id or options.reloadType or "sprite-reload-handler",
        reloadType = options.reloadType,
        style = "sprite",
        loadedSprite = options.loadedSprite,
        unloadedSprite = options.unloadedSprite,
        magItem = options.magItem,
        shortRackAfterInsert = options.shortRackAfterInsert,
        loadDuration = options.loadDuration,
        loadShortDuration = options.loadShortDuration,
        unloadDuration = options.unloadDuration,
        rackDuration = options.rackDuration,
        matches = options.matches,
        onEjectStart = function(action)
            return false
        end,
        onEjectAnimEvent = function(action, event, parameter)
            local handled = AnimatedReloadsAction.handleWeaponSpriteAnimEvent(action, event, parameter)
            if handled then
                local handler = AnimatedReloadsAction.getHandler(action)
                if handler and parameter == handler.unloadedSprite then
                    AnimatedReloadsAction.attachReloadMagazine(action, handler)
                end
            end
            return false
        end,
        onEjectStop = function(action)
            AnimatedReloadsAction.detachReloadMagazine(action)
        end,
        onEjectPerform = function(action)
            AnimatedReloadsAction.detachReloadMagazine(action)
        end,
        onInsertStart = function(action)
            AnimatedReloadsAction.setShortRackAfterInsert(action, options.shortRackAfterInsert)
            AnimatedReloadsAction.attachReloadMagazine(action, AnimatedReloadsAction.getHandler(action))
        end,
        onInsertAnimEvent = function(action, event, parameter)
            local handled = AnimatedReloadsAction.handleWeaponSpriteAnimEvent(action, event, parameter)
            if handled then
                AnimatedReloadsAction.detachReloadMagazine(action)
            end
            return false
        end,
        onInsertStop = function(action)
            AnimatedReloadsAction.detachReloadMagazine(action)
            AnimatedReloadsAction.setShortRackAfterInsert(action, false)
        end,
        onInsertLoadAmmo = function(action)
            if options.shortRackAfterInsert and not isServer() and not isClient() then
                if AnimatedReloadsAction.shouldQueueShortRackAfterInsert(action) then
                    AnimatedReloadsAction.setShortRackPending(action)
                end
            end
        end,
        onInsertPerform = function(action)
            AnimatedReloadsAction.detachReloadMagazine(action)
            AnimatedReloadsAction.setShortRackAfterInsert(action, false)

            if options.shortRackAfterInsert and isClient() then
                if AnimatedReloadsAction.shouldQueueShortRackAfterInsert(action) then
                    AnimatedReloadsAction.setShortRackPending(action)
                end
            end
        end,
        onRackStart = function(action)
            if not options.shortRackAfterInsert then
                return false
            end

            return AnimatedReloadsAction.handleShortRackStart(action, AnimatedReloadsAction.getHandler(action))
        end,
        onRackStop = function(action)
            if options.shortRackAfterInsert then
                AnimatedReloadsAction.handleShortRackStop(action)
            end
        end,
        onRackPerform = function(action)
            if options.shortRackAfterInsert then
                AnimatedReloadsAction.handleShortRackPerform(action)
            end
        end,
    }
end

---@param options {id:string|nil,reloadType:string|nil,magItem:string,magPart:AnimatedReloadsPartSpec|string,parts:table<string,AnimatedReloadsPartSpec>|nil,states:table<string,AnimatedReloadsAttachmentState>|nil,loadedState:string|nil,unloadedState:string|nil,shortRackAfterInsert:boolean|nil,loadDuration:number|nil,loadShortDuration:number|nil,unloadDuration:number|nil,rackDuration:number|nil,matches:fun(gun:HandWeapon):boolean|nil}
---@nodiscard
---@return AnimatedReloadsHandler
function AnimatedReloadsAction.createAttachmentReloadHandler(options)
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
        id = options.id or options.reloadType or "attachment-reload-handler",
        reloadType = options.reloadType,
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
        matches = options.matches,
        onEjectStart = function(action)
            return false
        end,
        onEjectAnimEvent = function(action, event, parameter)
            local handler = AnimatedReloadsAction.getHandler(action)
            if AnimatedReloadsAction.handleWeaponPartAnimEvent(action, handler, event, parameter) then
                return false
            end

            return AnimatedReloadsAction.handleWeaponAttachmentStateAnimEvent(action, handler, event, parameter)
        end,
        onEjectStop = function(action)
            local handler = AnimatedReloadsAction.getHandler(action)
            AnimatedReloadsAction.detachReloadMagazine(action)
            AnimatedReloadsAction.setWeaponAttachmentState(action, handler, unloadedState)
        end,
        onEjectPerform = function(action)
            local handler = AnimatedReloadsAction.getHandler(action)
            AnimatedReloadsAction.detachReloadMagazine(action)
            AnimatedReloadsAction.setWeaponAttachmentState(action, handler, unloadedState)
        end,
        onInsertStart = function(action)
            AnimatedReloadsAction.setShortRackAfterInsert(action, options.shortRackAfterInsert)
            AnimatedReloadsAction.attachReloadMagazine(action, AnimatedReloadsAction.getHandler(action))
        end,
        onInsertAnimEvent = function(action, event, parameter)
            local handler = AnimatedReloadsAction.getHandler(action)
            if AnimatedReloadsAction.handleWeaponPartAnimEvent(action, handler, event, parameter) then
                return false
            end

            local handled = AnimatedReloadsAction.handleWeaponAttachmentStateAnimEvent(action, handler, event, parameter)
            if handled then
                AnimatedReloadsAction.detachReloadMagazine(action)
            end
            return false
        end,
        onInsertStop = function(action)
            local handler = AnimatedReloadsAction.getHandler(action)
            AnimatedReloadsAction.detachReloadMagazine(action)
            AnimatedReloadsAction.setShortRackAfterInsert(action, false)
            AnimatedReloadsAction.setWeaponAttachmentState(action, handler, loadedState)
        end,
        onInsertLoadAmmo = function(action)
            local handler = AnimatedReloadsAction.getHandler(action)
            AnimatedReloadsAction.setWeaponAttachmentState(action, handler, loadedState)
            if options.shortRackAfterInsert and not isServer() and not isClient() then
                if AnimatedReloadsAction.shouldQueueShortRackAfterInsert(action) then
                    AnimatedReloadsAction.setShortRackPending(action)
                end
            end
        end,
        onInsertPerform = function(action)
            local handler = AnimatedReloadsAction.getHandler(action)
            AnimatedReloadsAction.detachReloadMagazine(action)
            AnimatedReloadsAction.setShortRackAfterInsert(action, false)
            AnimatedReloadsAction.setWeaponAttachmentState(action, handler, loadedState)

            if options.shortRackAfterInsert and isClient() then
                if AnimatedReloadsAction.shouldQueueShortRackAfterInsert(action) then
                    AnimatedReloadsAction.setShortRackPending(action)
                end
            end
        end,
        onRackStart = function(action)
            if not options.shortRackAfterInsert then
                return false
            end

            return AnimatedReloadsAction.handleShortRackStart(action, AnimatedReloadsAction.getHandler(action))
        end,
        onRackStop = function(action)
            if options.shortRackAfterInsert then
                AnimatedReloadsAction.handleShortRackStop(action)
            end
        end,
        onRackPerform = function(action)
            if options.shortRackAfterInsert then
                AnimatedReloadsAction.handleShortRackPerform(action)
            end
        end,
    }
end

---@param options table|nil
function AnimatedReloadsAction.registerWeaponReloadHandler(options)
    local normalized = AnimatedReloadsAction.normalizeWeaponReloadOptions(options)
    if not normalized then
        return
    end

    local handler = nil
    if normalized.style == "attachments" then
        if not AnimatedReloadsAction.validateAttachmentReloadOptions(normalized) then
            return
        end
        handler = AnimatedReloadsAction.createAttachmentReloadHandler(normalized)
    else
        if not AnimatedReloadsAction.validateSpriteReloadOptions(normalized) then
            return
        end
        handler = AnimatedReloadsAction.createSpriteReloadHandler(normalized)
    end

    if not handler then
        return
    end

AnimatedReloadsAction.registerReloadHandler(handler)
end

return AnimatedReloadsAction
