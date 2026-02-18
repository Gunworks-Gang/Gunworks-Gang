---@class AnimatedReloadsUtils
local AnimatedReloadsUtils = {}

---@param seconds number
---@param callback fun()
---@return fun
AnimatedReloadsUtils.runAfter = function(seconds, callback)
    local elapsed = 0

    ---@return nil
    local function tick()
        elapsed = elapsed + GameTime.getInstance():getTimeDelta()
        if elapsed < seconds then
            return
        end

        Events.OnTick.Remove(tick)
        callback()
    end

    Events.OnTick.Add(tick)

    return function()
        Events.OnTick.Remove(tick)
    end
end


return AnimatedReloadsUtils

