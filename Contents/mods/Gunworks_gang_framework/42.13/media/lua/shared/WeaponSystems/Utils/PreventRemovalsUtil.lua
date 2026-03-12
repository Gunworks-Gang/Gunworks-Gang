local PreventRemoval = {}

-------------------------------------------------
-- Registry: fullType -> true
-- Parts registered here will be excluded from the
-- vanilla "Remove Weapon Upgrade" submenu.
-------------------------------------------------
PreventRemoval.KnownParts = {}

--- Register one or more weapon part fullTypes as permanent (non-removable).
--- @param parts string|string[]  e.g. "MWA.RailUp" or { "MWA.RailUp", "MWA.RailLeft" }
function PreventRemoval.Register(parts)
    if type(parts) == "string" then
        PreventRemoval.KnownParts[parts] = true
    elseif type(parts) == "table" then
        for _, fullType in ipairs(parts) do
            PreventRemoval.KnownParts[fullType] = true
        end
    end
end

--- Check whether a weapon part fullType is registered as permanent.
--- @param fullType string
--- @return boolean
function PreventRemoval.IsPermanent(fullType)
    return PreventRemoval.KnownParts[fullType] == true
end

return PreventRemoval
