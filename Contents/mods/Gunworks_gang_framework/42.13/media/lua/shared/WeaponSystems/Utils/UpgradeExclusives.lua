local UpgradeExclusives = {}

-------------------------------------------------
-- Exclusives: partFullType -> { otherFullType = true, ... }
-- Two registered vanilla weapon parts cannot both be installed
-- on the same weapon at the same time.
-- The context menu "Upgrade" option for the pending part is hidden
-- while any of its exclusives are already attached.
-------------------------------------------------
UpgradeExclusives.Exclusives = {}

-------------------------------------------------
-- Registration API
-------------------------------------------------

--- Register two vanilla upgrade parts as mutually exclusive.
--- While one is mounted the other upgrade option will be hidden.
--- @param itemA string  e.g. "Base.Bipod"
--- @param itemB string|string[]  e.g. "Base.Foregrip" or { "Base.Scope", "Base.Sling" }
function UpgradeExclusives.SetExclusives(itemA, itemB)
    if not itemA or not itemB then return end

    if not UpgradeExclusives.Exclusives[itemA] then UpgradeExclusives.Exclusives[itemA] = {} end

    local itemsB = {}
    if type(itemB) == "table" then
        for _, exclusiveItem in ipairs(itemB) do
            table.insert(itemsB, exclusiveItem)
        end
    else
        table.insert(itemsB, itemB)
    end

    for _, exclusiveItem in ipairs(itemsB) do
        if exclusiveItem then
            if not UpgradeExclusives.Exclusives[exclusiveItem] then UpgradeExclusives.Exclusives[exclusiveItem] = {} end
            UpgradeExclusives.Exclusives[itemA][exclusiveItem] = true
            UpgradeExclusives.Exclusives[exclusiveItem][itemA] = true
        end
    end
end

--- Convenience registry that allows you to pass a table of entries
--- e.g. { ["Base.Bipod"] = "Base.Foregrip", ["Base.Scope"] = { "Base.Sling", "Base.Laser" } }
function UpgradeExclusives.RegisterMultipleSetOfExclusives(entriesTable)
    if not entriesTable then return end

    for itemA, itemB in pairs(entriesTable) do
        UpgradeExclusives.SetExclusives(itemA, itemB)
    end
end

-------------------------------------------------
-- Query
-------------------------------------------------

--- Check if a part is blocked by an exclusive already installed on the weapon.
--- @param weapon HandWeapon
--- @param partFullType string  fullType of the part the player wants to install
--- @return boolean  true if blocked
function UpgradeExclusives.IsBlockedByExclusive(weapon, partFullType)
    local exclusives = UpgradeExclusives.Exclusives[partFullType]
    if not exclusives then return false end

    local parts = weapon:getAllWeaponParts()
    if not parts then return false end

    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part and exclusives[part:getFullType()] then
            return true
        end
    end
    return false
end

return UpgradeExclusives
