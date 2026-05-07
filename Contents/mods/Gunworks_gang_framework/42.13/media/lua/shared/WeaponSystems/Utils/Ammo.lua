local Ammo = {}
local StatsFactory = require("WeaponSystems/Utils/StatsFactory")

-------------------------------------------------
-- Table 1: Item -> Ammo Family
-- Maps any weapon or magazine type to its ammo family
-------------------------------------------------
Ammo.ItemAmmoFamily = {}

-------------------------------------------------
-- Table 2: Ammo Families
-- Each family defines its bullet types with enum and optional profile
-------------------------------------------------
Ammo.AmmoFamilies = {}

-------------------------------------------------
-- Ammo Stats: each profile is an array of modifier functions
-- Use StatsFactory.Adjust / StatsFactory.Set / StatsFactory.Multiply or raw function(weapon, base)
-------------------------------------------------
Ammo.AmmoStats = {}

-------------------------------------------------
-- Restore Stats: set of stat names ammo profiles may modify.
-- Content mods populate this via Ammo.RegisterRestoreStats.
-------------------------------------------------
Ammo.RestoreStats = {}

--- Declare which stats ammo profiles may modify.
--- These stats will be restored to base before reapplying modifiers.
---@param statNames string[]  e.g. { "MaxDamage", "MinDamage", ... }
function Ammo.RegisterRestoreStats(statNames)
    for _, name in ipairs(statNames) do
        Ammo.RestoreStats[name] = true
    end
end

-------------------------------------------------
-- Helper functions (query AmmoFamilies directly)
-------------------------------------------------

--- Find a bullet entry across all families
--- @param bulletType string  e.g. "Base.556Bullets"
--- @return table|nil entry, string|nil family
function Ammo.FindBulletEntry(bulletType)
    for family, bullets in pairs(Ammo.AmmoFamilies) do
        for _, entry in ipairs(bullets) do
            if entry.type == bulletType then
                return entry, family
            end
        end
    end
    return nil, nil
end

--- Get the AmmoType enum for a bullet type
--- @param bulletType string
--- @return userdata|nil enum
function Ammo.GetEnumForBullet(bulletType)
    local entry = Ammo.FindBulletEntry(bulletType)
    return entry and entry.enum
end

--- Get list of bullet type strings for a family (for UI iteration)
--- @param family string
--- @return table|nil  array of type strings, or nil if family not found
function Ammo.GetBulletTypesForFamily(family)
    local entries = Ammo.AmmoFamilies[family]
    if not entries then return nil end
    local types = {}
    for _, entry in ipairs(entries) do
        table.insert(types, entry.type)
    end
    return types
end

--- Pick reload ammo with the simplest rule set:
--- use the family's registered base ammo first, otherwise use the next
--- registered ammo type that exists in inventory.
---@param playerObj IsoPlayer
---@param item InventoryItem
---@return string|nil
function Ammo.GetAutomaticReloadAmmoType(playerObj, item)
    if not playerObj or not item or not item.getAmmoType then return nil end

    local inventory = playerObj:getInventory()
    if not inventory then return nil end

    local family = Ammo.ItemAmmoFamily[item:getFullType()]
    local bulletTypes = family and Ammo.GetBulletTypesForFamily(family)
    if bulletTypes and #bulletTypes > 0 then
        for i = 1, #bulletTypes do
            local bulletType = bulletTypes[i]
            if inventory:getCountTypeRecurse(bulletType) > 0 then
                return bulletType
            end
        end
        return nil
    end

    local ammoType = item:getAmmoType()
    local itemKey = ammoType and ammoType:getItemKey()
    if itemKey and inventory:getCountTypeRecurse(itemKey) > 0 then
        return itemKey
    end

    return nil
end

-------------------------------------------------
-- Registration API for modders
-------------------------------------------------

--- Register one or more weapons/magazines to an ammo family
--- @param family string           e.g. "5.56x45mm"
--- @param itemTypes string|table  single type string or array of type strings
function Ammo.RegisterItemWithFamily(family, itemTypes)
    if type(itemTypes) == "table" then
        for _, itemType in ipairs(itemTypes) do
            Ammo.ItemAmmoFamily[itemType] = family
        end
    else
        Ammo.ItemAmmoFamily[itemTypes] = family
    end
end

function Ammo.RegisterMultipleItemsWithFamilies(entriesTable)
    if not entriesTable then return end

    for family, itemTypes in pairs(entriesTable) do
        Ammo.RegisterItemWithFamily(family, itemTypes)
    end
end

--- Register a new ammo family or add bullets to an existing one
--- @param family string  e.g. "5.56x45mm"
--- @param bullets table  array of { type, enum, profile? }
function Ammo.RegisterAmmoFamily(family, bullets)
    if not Ammo.AmmoFamilies[family] then
        Ammo.AmmoFamilies[family] = {}
    end
    for _, entry in ipairs(bullets) do
        table.insert(Ammo.AmmoFamilies[family], entry)
    end
end

function Ammo.RegisterMultipleAmmoFamilies(entriesTable)
    if not entriesTable then return end

    for family, bullets in pairs(entriesTable) do
        Ammo.RegisterAmmoFamily(family, bullets)
    end
end

--- Register a new ammo stat profile or overwrite an existing one
--- @param profileName string  e.g. "IncendiaryAmmo"
--- @param modifiers table  array of modifier functions (StatsFactory.Adjust / .Set / .Multiply / raw function)
function Ammo.RegisterAmmoStats(profileName, modifiers)
    Ammo.AmmoStats[profileName] = modifiers
end

function Ammo.RegisterMultipleAmmoStats(entriesTable)
    if not entriesTable then return end

    for profileName, modifiers in pairs(entriesTable) do
        Ammo.RegisterAmmoStats(profileName, modifiers)
    end
end

-------------------------------------------------

function Ammo.GetAmmoCharacteristics(bulletType)
    local entry = Ammo.FindBulletEntry(bulletType)
    return entry and entry.profile
end

function Ammo.AmmoAdjustWeaponStats(weapon, bulletType, ammoEnum)
    local profileName = Ammo.GetAmmoCharacteristics(bulletType)
    weapon:getModData().ActiveAmmoProfile = profileName
    weapon:setAmmoType(ammoEnum)
    StatsFactory.ReapplyAllModifiers(weapon)
end

function Ammo.AmmoProfileSetter(weapon, bulletType)
    local ammoEnum = Ammo.GetEnumForBullet(bulletType)
    if not ammoEnum then return end

    if weapon:getAmmoType() == ammoEnum then
        return
    end

    if isClient() then
        local playerObj = getSpecificPlayer(0)
        if playerObj then
            sendClientCommand(playerObj, "SWMG", "ammoProfile", {
                itemId = weapon:getID(),
                bulletType = bulletType
            })
        end
    else
        print('Ammo Profile Setting!')
        print(weapon:getAmmoType(), "  -->   ", ammoEnum)
    end

    Ammo.AmmoAdjustWeaponStats(weapon, bulletType, ammoEnum)
end

function Ammo.MagazineAmmoProfileSetter(magazine, bulletType)
    local ammoEnum = Ammo.GetEnumForBullet(bulletType)
    if not ammoEnum then return end

    if magazine:getAmmoType() == ammoEnum then
        return
    end

    if isClient() then
        local playerObj = getSpecificPlayer(0)
        if playerObj then
            sendClientCommand(playerObj, "SWMG", "magazineAmmoProfile", {
                itemId = magazine:getID(),
                bulletType = bulletType
            })
        end
    else
        print('Magazine Ammo Profile Setting!')
        print(magazine:getAmmoType(), "  -->   ", ammoEnum)
    end

    magazine:setAmmoType(ammoEnum)
end

function Ammo.CopyAmmoList(source)
    if not source then return nil end
    local copy = {}
    for i = 1, #source do
        copy[i] = source[i]
    end
    return copy
end

-------------------------------------------------
-- MP helper: sync an item's AmmoList from server
-- to the owning client via an explicit command.
-------------------------------------------------
function Ammo.SyncAmmoListToClient(character, item)
    if not isServer() then return end
    sendServerCommand(character, "SWMG", "syncAmmoList", {
        itemId = item:getID(),
        ammoList = item:getModData().AmmoList
    })
end

-------------------------------------------------
-- Register modifier layer with StatsFactory
-------------------------------------------------
StatsFactory.RegisterModifierLayer("Ammo", function(weapon)
    local profileName = weapon:getModData().ActiveAmmoProfile
    if not profileName then return nil end
    return Ammo.AmmoStats[profileName]
end, Ammo.RestoreStats)

function Ammo.RestoreOnLoad(player)
    local inv = player:getInventory()
    if not inv then return end
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and instanceof(item, "HandWeapon") and item:isRanged() then
            local md = item:getModData()
            if md.ActiveAmmoProfile then
                md.ActiveAmmoProfile = nil
                local base = StatsFactory.GetBaseStatsWithAttachments(item)
                StatsFactory.RestoreStats(item, base, Ammo.RestoreStats)
            end
        end
    end
end

Events.OnGameStart.Add(function()
    local player = getSpecificPlayer(0)
    if player then
        Ammo.RestoreOnLoad(player)
    end
end)

return Ammo
