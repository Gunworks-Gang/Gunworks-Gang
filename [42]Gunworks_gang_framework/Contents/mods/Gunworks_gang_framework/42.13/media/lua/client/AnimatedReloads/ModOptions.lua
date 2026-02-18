local DurationOptions = require("AnimatedReloads/DurationOptions")

---@class AnimatedReloadsModOptions
local AnimatedReloadsModOptions = {}

---@return nil
function AnimatedReloadsModOptions.boot()
    if PZAPI and PZAPI.ModOptions then
        DurationOptions.ensureOptions()
        PZAPI.ModOptions:load()
    end

    DurationOptions.applyModDataToHandlers()
end

if Events and Events.OnGameBoot then
    Events.OnGameBoot.Add(AnimatedReloadsModOptions.boot)
else
    AnimatedReloadsModOptions.boot()
end


return AnimatedReloadsModOptions
