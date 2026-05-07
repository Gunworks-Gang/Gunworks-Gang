local Railing = {}
local StatsFactory = require("WeaponSystems/Utils/StatsFactory")

-------------------------------------------------
-- Registry: railingFullType -> { accessoryFullType, ... }
-- A railing (WeaponPart already on the weapon) defines which
-- accessories can be mounted through it.
-------------------------------------------------
Railing.AcceptedAccessories = {}

-------------------------------------------------
-- Reverse lookup: accessoryFullType -> true
-- Built automatically so we can quickly tell if a given
-- installed part was mounted via the railing system.
-------------------------------------------------
Railing.KnownAccessories = {}

-------------------------------------------------
-- Exclusives: accessoryFullType -> { otherFullType = true, ... }
-- Two items registered as exclusive cannot both be mounted
-- on the same weapon, even if they use different PartTypes.
-------------------------------------------------
Railing.Exclusives = {}

-------------------------------------------------
-- Weapon exclusions: weaponFullType -> { accessoryFullType = true, ... }
-- Lets shared rails reuse the same accepted accessory list while
-- still blocking specific accessories on specific weapons.
-------------------------------------------------
Railing.WeaponExclusions = {}

local function normalizeWeaponType(weaponOrWeaponType)
    if not weaponOrWeaponType then return nil end
    if type(weaponOrWeaponType) == "string" then
        return weaponOrWeaponType
    end
    return weaponOrWeaponType:getFullType()
end

-------------------------------------------------
-- Registration API
-------------------------------------------------

--- Register a railing and the accessories it accepts.
--- @param railingType string|string[]  e.g. "MWA.PICATINNY_RAIL" or { "MWA.PICATINNY_RAIL", "MWA.AK_MOUNT" }
--- @param accessories string[]        e.g. { "Base.2xScope", "Base.4xScope" }
function Railing.RegisterRailing(railingType, accessories)
    if not railingType or not accessories then return end

    if type(railingType) == "table" then
        for _, currentRailingType in ipairs(railingType) do
            if currentRailingType then
                Railing.RegisterRailing(currentRailingType, accessories)
            end
        end
        return
    end

    Railing.AcceptedAccessories[railingType] = accessories
    for _, acc in ipairs(accessories) do
        Railing.KnownAccessories[acc] = true
    end
end

--- Register one or more accessories as blocked on a specific weapon.
--- This only applies after a railing has already accepted the accessory.
--- @param weaponType string|HandWeapon|string[]  e.g. "MWA.AA12" or { "MWA.AA12", "MWA.AA13" }
--- @param accessories string|string[]   e.g. "Base.8xScope" or { "Base.8xScope", "Base.Laser" }
function Railing.RegisterWeaponExclusions(weaponType, accessories)
    if not weaponType or not accessories then return end

    if type(weaponType) == "table" then
        for _, currentWeaponType in ipairs(weaponType) do
            if currentWeaponType then
                Railing.RegisterWeaponExclusions(currentWeaponType, accessories)
            end
        end
        return
    end

    local normalizedWeaponType = normalizeWeaponType(weaponType)
    if not normalizedWeaponType then return end

    if not Railing.WeaponExclusions[normalizedWeaponType] then
        Railing.WeaponExclusions[normalizedWeaponType] = {}
    end

    local blockedAccessories = accessories
    if type(blockedAccessories) ~= "table" then
        blockedAccessories = { blockedAccessories }
    end

    for _, accessoryType in ipairs(blockedAccessories) do
        if accessoryType then
            Railing.WeaponExclusions[normalizedWeaponType][accessoryType] = true
        end
    end
end

--- Register one or more items as mutually exclusive with one or more other items.
--- If one is mounted, the other cannot be mounted.
--- @param itemA string|string[]  e.g. "MWA.BIPOD_DEPLOYED" or { "MWA.BOOSTER_ON", "MWA.BOOSTER_OFF" }
--- @param itemB string|string[]  e.g. "MWA.INTEGRATED_BIPOD_DEPLOYED" or { "MWA.SCOPE_A", "MWA.SCOPE_B" }
function Railing.SetExclusives(itemA, itemB)
    if not itemA or not itemB then return end

    if type(itemA) == "table" then
        for _, primaryItem in ipairs(itemA) do
            if primaryItem then
                Railing.SetExclusives(primaryItem, itemB)
            end
        end
        return
    end

    if not Railing.Exclusives[itemA] then Railing.Exclusives[itemA] = {} end

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
            if not Railing.Exclusives[exclusiveItem] then Railing.Exclusives[exclusiveItem] = {} end
            Railing.Exclusives[itemA][exclusiveItem] = true
            Railing.Exclusives[exclusiveItem][itemA] = true
        end
    end
end

-------------------------------------------------

--- Check if an accessory is blocked by an exclusive item already on the weapon.
--- @param weapon HandWeapon
--- @param accessoryType string
--- @return boolean  true if blocked
function Railing.IsBlockedByExclusive(weapon, accessoryType)
    local exclusives = Railing.Exclusives[accessoryType]
    if not exclusives then return false end

    local parts = weapon:getAllWeaponParts()
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part and exclusives[part:getFullType()] then
            return true
        end
    end
    return false
end

--- Check if an accessory is blocked on the current weapon regardless of the railing.
--- @param weapon HandWeapon|string
--- @param accessoryType string
--- @return boolean  true if blocked on this weapon
function Railing.IsBlockedByWeapon(weapon, accessoryType)
    local weaponType = normalizeWeaponType(weapon)
    if not weaponType or not accessoryType then return false end

    local blockedAccessories = Railing.WeaponExclusions[weaponType]
    return blockedAccessories ~= nil and blockedAccessories[accessoryType] == true
end

-------------------------------------------------
-- Query helpers
-------------------------------------------------

--- Find all installed railings on a weapon that are registered.
--- @param weapon HandWeapon
--- @return table[] array of { railingType = string, part = WeaponPart }
function Railing.GetInstalledRailings(weapon)
    local railings = {}
    if not weapon then return railings end

    local parts = weapon:getAllWeaponParts()
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part then
            local fullType = part:getFullType()
            if Railing.AcceptedAccessories[fullType] then
                table.insert(railings, { railingType = fullType, part = part })
            end
        end
    end
    return railings
end

--- Check if the weapon has any registered railing installed.
--- @param weapon HandWeapon
--- @return boolean
function Railing.HasRailing(weapon)
    return #Railing.GetInstalledRailings(weapon) > 0
end

--- Get the combined list of accessory fullTypes that all installed railings accept.
--- @param weapon HandWeapon
--- @return string[]|nil
function Railing.GetAcceptedAccessories(weapon)
    local railings = Railing.GetInstalledRailings(weapon)
    if #railings == 0 then return nil end

    local combined = {}
    local seen = {}
    for _, r in ipairs(railings) do
        local accList = Railing.AcceptedAccessories[r.railingType]
        if accList then
            for _, acc in ipairs(accList) do
                if not seen[acc] then
                    seen[acc] = true
                    table.insert(combined, acc)
                end
            end
        end
    end
    if #combined == 0 then return nil end
    return combined
end

--- Find installed accessories on the weapon that were mounted via the
--- railing system (i.e. their fullType is accepted by any installed railing).
--- @param weapon HandWeapon
--- @return WeaponPart[]  array of currently mounted railing accessories
function Railing.GetMountedAccessories(weapon)
    local mounted = {}
    if not weapon then return mounted end

    local accepted = Railing.GetAcceptedAccessories(weapon)
    if not accepted then return mounted end

    local acceptedSet = {}
    for _, acc in ipairs(accepted) do
        acceptedSet[acc] = true
    end

    local parts = weapon:getAllWeaponParts()
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part and acceptedSet[part:getFullType()] then
            table.insert(mounted, part)
        end
    end
    return mounted
end

--- Check whether a specific installed railing still has any mounted accessory depending on it.
--- @param weapon HandWeapon
--- @param railingPart WeaponPart|string
--- @return boolean
function Railing.HasMountedAccessoryOnRailing(weapon, railingPart)
    if not weapon or not railingPart then return false end

    local railingType = railingPart
    if type(railingPart) ~= "string" then
        railingType = railingPart:getFullType()
    end

    local accepted = Railing.AcceptedAccessories[railingType]
    if not accepted then return false end

    local acceptedSet = {}
    for _, acc in ipairs(accepted) do
        acceptedSet[acc] = true
    end

    local parts = weapon:getAllWeaponParts()
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part and acceptedSet[part:getFullType()] then
            return true
        end
    end

    return false
end

--- Check if a specific accessory type can be mounted right now.
--- Returns false if the weapon already has a part in the same PartType slot.
--- Checks across all installed railings.
--- @param weapon HandWeapon
--- @param accessoryType string
--- @return boolean
function Railing.CanMountAccessory(weapon, accessoryType)
    if not weapon or not accessoryType then return false end

    local accepted = Railing.GetAcceptedAccessories(weapon)
    if not accepted then return false end

    local found = false
    for _, acc in ipairs(accepted) do
        if acc == accessoryType then
            found = true
            break
        end
    end
    if not found then return false end

    if Railing.IsBlockedByWeapon(weapon, accessoryType) then return false end

    local tempPart = instanceItem(accessoryType)
    if not tempPart then return false end
    local partType = tempPart:getPartType()
    if not partType then return true end

    local existingPart = weapon:getWeaponPart(partType)
    if existingPart then return false end

    -- Check exclusives
    if Railing.IsBlockedByExclusive(weapon, accessoryType) then return false end

    return true
end

-------------------------------------------------
-- Mount / Unmount
-------------------------------------------------

--- Mount an accessory (from player inventory) onto the weapon via its railing.
--- @param weapon HandWeapon
--- @param accessoryItem InventoryItem  the actual inventory item to consume
--- @param player IsoPlayer
--- @return boolean success
function Railing.MountAccessory(weapon, accessoryItem, player)
    if not weapon or not accessoryItem or not player then return false end

    local accessoryType = accessoryItem:getFullType()
    if not Railing.CanMountAccessory(weapon, accessoryType) then return false end

    -- Remove from inventory and attach
    player:getInventory():Remove(accessoryItem)
    local newPart = instanceItem(accessoryType)
    if newPart and instanceof(newPart, "WeaponPart") then
        weapon:attachWeaponPart(newPart, true)
        StatsFactory.ReapplyAllModifiers(weapon)
        return true
    end
    return false
end

--- Unmount an accessory from the weapon and return it to the player's inventory.
--- @param weapon HandWeapon
--- @param accessoryPart WeaponPart  the part currently on the weapon
--- @param player IsoPlayer
--- @return boolean success
function Railing.UnmountAccessory(weapon, accessoryPart, player)
    if not weapon or not accessoryPart or not player then return false end

    local accessoryType = accessoryPart:getFullType()
    if not Railing.KnownAccessories[accessoryType] then return false end

    weapon:detachWeaponPart(accessoryPart)
    StatsFactory.ReapplyAllModifiers(weapon)

    local returnedItem = instanceItem(accessoryType)
    if returnedItem then
        player:getInventory():AddItem(returnedItem)
    end
    return true, returnedItem
end

return Railing
