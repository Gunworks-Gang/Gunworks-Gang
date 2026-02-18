---@class AnimatedReloadsAction
local AnimatedReloadsAction = require("AnimatedReloads/Action/Core")
AnimatedReloadsAction.handlers = {}
AnimatedReloadsAction.commandModule = AnimatedReloadsAction.commandModule or "AnimatedReloads"

---@nodiscard
---@return string
function AnimatedReloadsAction.getCommandModule()
    return AnimatedReloadsAction.commandModule
end

---@param moduleName string|nil
function AnimatedReloadsAction.setCommandModule(moduleName)
    if moduleName and moduleName ~= "" then
        AnimatedReloadsAction.commandModule = moduleName
    else
        AnimatedReloadsAction.commandModule = "AnimatedReloads"
    end
end

---@nodiscard
---@return AnimatedReloadsHandler[]
function AnimatedReloadsAction.getHandlers()
    return AnimatedReloadsAction.handlers
end

---@param handler AnimatedReloadsHandler
function AnimatedReloadsAction.registerReloadHandler(handler)
    if not handler or not handler.id then
        return
    end

    local __list = AnimatedReloadsAction.handlers
    for i = 1, #__list do
        local existing = __list[i]
        if existing.id == handler.id then
            __list[i] = handler
            return
        end
    end

    table.insert(AnimatedReloadsAction.handlers, handler)
end

---@param handlerId string|nil
function AnimatedReloadsAction.unregisterReloadHandler(handlerId)
    if not handlerId then
        return
    end

    local __list = AnimatedReloadsAction.handlers
    for i = #__list, 1, -1 do
        if __list[i].id == handlerId then
            table.remove(__list, i)
        end
    end
end

---@return nil
function AnimatedReloadsAction.clearReloadHandlers()
    AnimatedReloadsAction.handlers = {}
end

---@param gun HandWeapon|nil
---@nodiscard
---@return AnimatedReloadsHandler|nil
function AnimatedReloadsAction.getHandlerForGun(gun)
    if not instanceof(gun, "HandWeapon") then
        return nil
    end

    local __list = AnimatedReloadsAction.handlers
    for i = 1, #__list do
        local handler = __list[i]
        if handler.matches then
            if handler.matches(gun) then
                return handler
            end
        elseif handler.reloadType and gun and gun:getWeaponReloadType() == handler.reloadType then
            return handler
        end
    end

    return nil
end

---@param reloadType string|nil
---@nodiscard
---@return AnimatedReloadsHandler|nil
function AnimatedReloadsAction.getHandlerForReloadType(reloadType)
    if not reloadType then
        return nil
    end

    local __list = AnimatedReloadsAction.handlers
    for i = 1, #__list do
        local handler = __list[i]
        if handler.reloadType == reloadType then
            return handler
        end
    end

    return nil
end

---@param action ISBaseTimedAction
---@nodiscard
---@return AnimatedReloadsHandler|nil
function AnimatedReloadsAction.getHandler(action)
    if not action or not action.gun then
        return nil
    end

return AnimatedReloadsAction.getHandlerForGun(action.gun)
end

return AnimatedReloadsAction
