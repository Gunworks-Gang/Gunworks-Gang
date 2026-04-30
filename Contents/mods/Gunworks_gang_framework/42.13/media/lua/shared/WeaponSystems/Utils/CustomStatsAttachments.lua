local CustomStatsAttachments = {}
local StatsFactory = require("WeaponSystems/Utils/StatsFactory")

-------------------------------------------------
-- Registry: partFullType -> { modifiers = { ... } }
-- Each entry maps an attachment item to an array of
-- StatsFactory modifier functions applied while that
-- attachment is physically present on the weapon.
-------------------------------------------------
CustomStatsAttachments.RegisteredParts = {}

-------------------------------------------------
-- Restore Stats: union of all stat names that registered
-- attachment modifiers may touch.  Content mods populate
-- this via CustomStatsAttachments.RegisterRestoreStats.
-------------------------------------------------
CustomStatsAttachments.RestoreStats = {}

-------------------------------------------------
-- Registration API
-------------------------------------------------

--- Declare which stats custom-attachment modifiers may modify.
--- Call once from your content mod before any RegisterPart calls.
---@param statNames string[]  e.g. { "SoundRadius", "SoundVolume" }
function CustomStatsAttachments.RegisterRestoreStats(statNames)
    for _, name in ipairs(statNames) do
        CustomStatsAttachments.RestoreStats[name] = true
    end
end

--- Register an attachment that carries custom stat modifiers.
---@param partFullType string   e.g. "MWA.Suppressor_556"
---@param modifiers    table    array of StatsFactory modifier fns
function CustomStatsAttachments.RegisterPart(partFullType, modifiers)
    CustomStatsAttachments.RegisteredParts[partFullType] = {
        modifiers = modifiers,
    }
end

function CustomStatsAttachments.RegisterMultipleParts(partsTable)
    if not partsTable then return end

    for partFullType, modifiers in pairs(partsTable) do
        CustomStatsAttachments.RegisterPart(partFullType, modifiers)
    end
end

-------------------------------------------------
-- Modifier layer callback
-------------------------------------------------

--- Collect modifiers from every currently-attached registered part.
--- Returns nil when no registered parts are present (layer inactive).
local function getModifiers(weapon)
    local parts = weapon:getAllWeaponParts()
    if not parts then return nil end

    local combined = nil
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part then
            local entry = CustomStatsAttachments.RegisteredParts[part:getFullType()]
            if entry and entry.modifiers then
                if not combined then combined = {} end
                for _, mod in ipairs(entry.modifiers) do
                    combined[#combined + 1] = mod
                end
            end
        end
    end
    return combined
end

-------------------------------------------------
-- Register with StatsFactory
-------------------------------------------------
StatsFactory.RegisterModifierLayer(
    "CustomStatsAttachments",
    getModifiers,
    CustomStatsAttachments.RestoreStats
)

return CustomStatsAttachments
