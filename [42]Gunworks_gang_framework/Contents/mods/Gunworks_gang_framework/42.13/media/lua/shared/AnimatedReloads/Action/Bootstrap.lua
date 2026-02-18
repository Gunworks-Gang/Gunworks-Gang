---@class AnimatedReloadsAction
local AnimatedReloadsAction = require("AnimatedReloads/Action/Core")

function AnimatedReloadsAction.initializeDurationOptions()
    if AnimatedReloadsAction._durationOptionsInitialized then
        return
    end

    AnimatedReloadsAction._durationOptionsInitialized = true

    local DurationOptions = require("AnimatedReloads/DurationOptions")
    DurationOptions.setHandlersProvider(function()
        return AnimatedReloadsAction.getHandlers()
    end)
    DurationOptions.applyModDataToHandlers()
    DurationOptions.startWatching()
end

function AnimatedReloadsAction.initializeSharedSystems()
    if AnimatedReloadsAction._sharedSystemsInitialized then
        return
    end

    AnimatedReloadsAction._sharedSystemsInitialized = true
    AnimatedReloadsAction.initializeCommandHooks()
    AnimatedReloadsAction.initializeDurationOptions()
end

return AnimatedReloadsAction
