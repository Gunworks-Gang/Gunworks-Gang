local Railing = {}

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
-- Registration API
-------------------------------------------------

--- Register a railing and the accessories it accepts.
--- @param railingType string          e.g. "MWA.PICATINNY_RAIL"
--- @param accessories string[]        e.g. { "Base.2xScope", "Base.4xScope" }
function Railing.RegisterRailing(railingType, accessories)
    Railing.AcceptedAccessories[railingType] = accessories
    for _, acc in ipairs(accessories) do
        Railing.KnownAccessories[acc] = true
    end
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

    -- Build a quick lookup set from ALL railings' accepted lists
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

    -- Is this accessory in any railing's accepted list?
    local found = false
    for _, acc in ipairs(accepted) do
        if acc == accessoryType then
            found = true
            break
        end
    end
    if not found then return false end

    -- Check if the slot is already occupied by looking at the accessory's PartType
    local tempPart = instanceItem(accessoryType)
    if not tempPart then return false end
    local partType = tempPart:getPartType()
    if not partType then return true end

    local existingPart = weapon:getWeaponPart(partType)
    if existingPart then return false end

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

    local returnedItem = instanceItem(accessoryType)
    if returnedItem then
        player:getInventory():AddItem(returnedItem)
    end
    return true
end

return Railing
