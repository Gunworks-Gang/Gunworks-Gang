local Ammo = {}
local StatsFactory = require("WeaponSystems/Utils/StatsFactory")

-------------------------------------------------
-- Table 1: Item -> Ammo Family
-- Maps any weapon, magazine, OR weapon-part type to its ammo family. A part
-- entry lets a caliber-conversion kit / swap barrel override its host weapon's
-- family while installed - see Ammo.GetFamilyForItem.
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

function Ammo.GetEnumForBullet(bulletType)
    local entry = Ammo.FindBulletEntry(bulletType)
    return entry and entry.enum
end

function Ammo.GetBulletTypesForFamily(family)
    local entries = Ammo.AmmoFamilies[family]
    if not entries then return nil end
    local types = {}
    for _, entry in ipairs(entries) do
        types[#types + 1] = entry.type
    end
    return types
end

local function checkIfMagazine(part)
    local partType = part:getPartType()
    if partType == "Clip" or partType == "Magazine" then return true end
    return false
end

--- Resolve the ammo family for an item. For a weapon, an installed part that is
--- registered with its own family (a caliber-conversion kit, a swap barrel)
--- overrides the weapon's own family, so the part dictates what the weapon
--- chambers. The first registered part found on the weapon wins. Magazines have
--- no parts and resolve straight from ItemAmmoFamily.
---@param item InventoryItem  weapon or magazine
---@return string|nil
function Ammo.GetFamilyForItem(item)
    if not item then return nil end

    if item.getAllWeaponParts then
        local parts = item:getAllWeaponParts()
        if parts then
            for i = 0, parts:size() - 1 do
                local part = parts:get(i)
                -- TODO: I need to patch this better but this will do for now
                if part and not checkIfMagazine(part) then
                    local family = Ammo.ItemAmmoFamily[part:getFullType()]
                    if family then return family end
                end
            end
        end
    end

    return Ammo.ItemAmmoFamily[item:getFullType()]
end

-------------------------------------------------
-- Reload ammo preference (per-player, per-family)
--
-- Players can reorder how the automatic reload (R) picks between the bullet
-- types in a family. The order is stored in the player's modData so it
-- persists and survives relog; in MP it is a client-side ordering hint only
-- and never mutates the shared Ammo.AmmoFamilies registry. <- important to keep this independent
-------------------------------------------------

function Ammo.GetReloadPreferenceForFamily(playerObj, family)
    if not playerObj or not family then return nil end
    local prefs = playerObj:getModData().GunworksAmmoPref
    return prefs and prefs[family]
end

function Ammo.SetReloadPreferenceForFamily(playerObj, family, orderedTypes)
    if not playerObj or not family or not orderedTypes then return end

    local registryList = Ammo.GetBulletTypesForFamily(family)
    if not registryList then return end

    local inRegistry = {}
    for _, t in ipairs(registryList) do inRegistry[t] = true end

    local clean, seen = {}, {}
    for _, t in ipairs(orderedTypes) do
        if inRegistry[t] and not seen[t] then
            clean[#clean + 1] = t
            seen[t] = true
        end
    end

    local md = playerObj:getModData()
    if not md.GunworksAmmoPref then md.GunworksAmmoPref = {} end
    md.GunworksAmmoPref[family] = clean

    if isClient() then
        playerObj:transmitModData()
    end
end

function Ammo.GetOrderedBulletTypesForFamily(playerObj, family)
    local registryList = Ammo.GetBulletTypesForFamily(family)
    if not registryList then return nil end

    local pref = Ammo.GetReloadPreferenceForFamily(playerObj, family)
    if not pref or #pref == 0 then return registryList end

    local inRegistry = {}
    for _, t in ipairs(registryList) do inRegistry[t] = true end

    local ordered, seen = {}, {}
    for _, t in ipairs(pref) do
        if inRegistry[t] and not seen[t] then
            ordered[#ordered + 1] = t
            seen[t] = true
        end
    end
    for _, t in ipairs(registryList) do
        if not seen[t] then
            ordered[#ordered + 1] = t
            seen[t] = true
        end
    end
    return ordered
end

function Ammo.GetAutomaticReloadAmmoType(playerObj, item)
    if not playerObj or not item or not item.getAmmoType then return nil end

    local inventory = playerObj:getInventory()
    if not inventory then return nil end

    local family = Ammo.GetFamilyForItem(item)
    local bulletTypes = family and Ammo.GetOrderedBulletTypesForFamily(playerObj, family)
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

function Ammo.FindBulletIndexInFamily(family, bulletType)
    local list = Ammo.AmmoFamilies[family]
    if not list then return nil end
    for i, entry in ipairs(list) do
        if entry.type == bulletType then
            return i
        end
    end
    return nil
end

--- Register a new ammo family or add bullets to an existing one.
--- Two mods can independently register the same round into the same family
--- A new entry whose `type` already exists in the family replaces the earlier one in place - last mod to load wins.
--- @param family string  e.g. "5.56x45mm"
--- @param bullets table  array of { type, enum, profile? }
function Ammo.RegisterAmmoFamily(family, bullets)
    if not Ammo.AmmoFamilies[family] then
        Ammo.AmmoFamilies[family] = {}
    end
    local list = Ammo.AmmoFamilies[family]
    for _, entry in ipairs(bullets) do
        local index = Ammo.FindBulletIndexInFamily(family, entry.type)
        if index then
            list[index] = entry
        else
            list[#list + 1] = entry
        end
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
        print("Ammo Profile Setting!")
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
        print("Magazine Ammo Profile Setting!")
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

function Ammo.SplitAmmoListOnEject(gun)
    local gunModData = gun:getModData()
    local gunList = gunModData.AmmoList

    if not gunList or #gunList == 0 then
        gunModData.AmmoList = nil
        return nil
    end

    if gun:isRoundChambered() and #gunList > 1 then
        local ammoListForMag = Ammo.CopyAmmoList(gunList) or {}
        ammoListForMag[#ammoListForMag] = nil
        gunModData.AmmoList = { gunList[#gunList] }
        return ammoListForMag
    elseif gun:isRoundChambered() then
        gunModData.AmmoList = { gunList[#gunList] }
        return nil
    end

    local ammoListForMag = Ammo.CopyAmmoList(gunList)
    gunModData.AmmoList = nil
    return ammoListForMag
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

return Ammo
