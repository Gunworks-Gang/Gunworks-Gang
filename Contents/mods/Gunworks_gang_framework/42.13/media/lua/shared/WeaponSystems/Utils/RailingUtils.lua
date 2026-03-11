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

--- Find the first installed railing on a weapon that is registered.
--- @param weapon HandWeapon
--- @return string|nil railingType, WeaponPart|nil railingPart
function Railing.GetInstalledRailing(weapon)
    if not weapon then return nil end

    local parts = weapon:getAllWeaponParts()
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part then
            local fullType = part:getFullType()
            if Railing.AcceptedAccessories[fullType] then
                return fullType, part
            end
        end
    end
    return nil
end

--- Check if the weapon has any registered railing installed.
--- @param weapon HandWeapon
--- @return boolean
function Railing.HasRailing(weapon)
    return Railing.GetInstalledRailing(weapon) ~= nil
end

--- Get the list of accessory fullTypes that the installed railing accepts.
--- @param weapon HandWeapon
--- @return string[]|nil
function Railing.GetAcceptedAccessories(weapon)
    local railingType = Railing.GetInstalledRailing(weapon)
    if not railingType then return nil end
    return Railing.AcceptedAccessories[railingType]
end

--- Find installed accessories on the weapon that were mounted via the
--- railing system (i.e. their fullType is in KnownAccessories).
--- @param weapon HandWeapon
--- @return WeaponPart[]  array of currently mounted railing accessories
function Railing.GetMountedAccessories(weapon)
    local mounted = {}
    if not weapon then return mounted end

    local accepted = Railing.GetAcceptedAccessories(weapon)
    if not accepted then return mounted end

    -- Build a quick lookup set from the railing's accepted list
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
--- @param weapon HandWeapon
--- @param accessoryType string
--- @return boolean
function Railing.CanMountAccessory(weapon, accessoryType)
    if not weapon or not accessoryType then return false end

    local accepted = Railing.GetAcceptedAccessories(weapon)
    if not accepted then return false end

    -- Is this accessory in the railing's accepted list?
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
