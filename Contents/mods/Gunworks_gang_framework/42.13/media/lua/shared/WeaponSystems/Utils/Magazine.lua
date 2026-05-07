local Magazine = {}
local Ammo = require("WeaponSystems/Utils/Ammo")

-------------------------------------------------
-- Table 1: Weapon -> Magazine Profile
-- Maps weapon fullType to a magazine profile name
-------------------------------------------------
Magazine.WeaponMagazineProfile = {}

-------------------------------------------------
-- Table 2: Magazine Profiles
-- Maps profile name to an ordered list of magazine fullTypes
-------------------------------------------------
Magazine.MagazineProfiles = {}

-------------------------------------------------
-- Table 3: Magazine Profile Sets (reverse lookup)
-- Maps profile name to a set {[magFullType] = true} for O(1) membership checks
-------------------------------------------------
Magazine.ProfileMagazineSet = {}

-------------------------------------------------
-- Registration API
-------------------------------------------------

--- Register one or more weapons to a magazine profile.
---@param profileName string
---@param weaponTypes string|string[]  single fullType or array of fullTypes
function Magazine.RegisterWeaponWithProfile(profileName, weaponTypes)
    if type(weaponTypes) == "string" then
        Magazine.WeaponMagazineProfile[weaponTypes] = profileName
    else
        for i = 1, #weaponTypes do
            Magazine.WeaponMagazineProfile[weaponTypes[i]] = profileName
        end
    end
end

function Magazine.RegisterMultipleWeaponsWithProfiles(entriesTable)
    if not entriesTable then return end

    for profileName, weaponTypes in pairs(entriesTable) do
        Magazine.RegisterWeaponWithProfile(profileName, weaponTypes)
    end
end

--- Register (or replace) a magazine profile.
---@param profileName string
---@param magazineTypes string[]  ordered list of magazine fullTypes
function Magazine.RegisterMagazineProfile(profileName, magazineTypes)
    Magazine.MagazineProfiles[profileName] = magazineTypes
    local set = {}
    for i = 1, #magazineTypes do
        set[magazineTypes[i]] = true
    end
    Magazine.ProfileMagazineSet[profileName] = set
end

function Magazine.RegisterMultipleMagazineProfiles(entriesTable)
    if not entriesTable then return end

    for profileName, magazineTypes in pairs(entriesTable) do
        Magazine.RegisterMagazineProfile(profileName, magazineTypes)
    end
end

-------------------------------------------------
-- Query helpers
-------------------------------------------------

--- Get the magazine profile name for a weapon.
---@param gun HandWeapon
---@return string|nil
function Magazine.GetProfileForGun(gun)
    return Magazine.WeaponMagazineProfile[gun:getFullType()]
end

--- Get the magazine type list for a weapon.
---@param gun HandWeapon
---@return string[]|nil
function Magazine.GetMagazineTypesForGun(gun)
    local profile = Magazine.WeaponMagazineProfile[gun:getFullType()]
    return profile and Magazine.MagazineProfiles[profile]
end

--- Check if a magazine type belongs to a given profile.
---@param magType string
---@param profileName string
---@return boolean
function Magazine.IsMagazineInProfile(magType, profileName)
    local set = Magazine.ProfileMagazineSet[profileName]
    return set and set[magType] or false
end

-------------------------------------------------
-- Predicate & comparator for getBestEvalArgRecurse
-------------------------------------------------

--- Predicate: returns true if item belongs to the gun's magazine profile.
---@param item InventoryItem
---@param gun HandWeapon
---@return boolean
function Magazine.predicateInProfile(item, gun)
    local profile = Magazine.WeaponMagazineProfile[gun:getFullType()]
    if not profile then return false end
    local set = Magazine.ProfileMagazineSet[profile]
    return set and set[item:getFullType()] or false
end

--- Comparator: higher ammo count = better.
---@param a InventoryItem
---@param b InventoryItem
---@return number
function Magazine.compareAmmoCount(a, b)
    return a:getCurrentAmmoCount() - b:getCurrentAmmoCount()
end

-------------------------------------------------
-- Magazine operations
-------------------------------------------------

function Magazine.reloadMagazine(playerObj, magazine)
    if not magazine then
        return 0
    end
    local itemKey = Ammo.GetAutomaticReloadAmmoType(playerObj, magazine)
    if not itemKey then
        return 0
    end
    local ammoCount = magazine:getCurrentAmmoCount() +
        ISInventoryPaneContextMenu.transferBullets(playerObj, itemKey, magazine:getCurrentAmmoCount(),
            magazine:getMaxAmmo())
    if ammoCount > 0 then
        ISTimedActionQueue.add(ISLoadBulletsInMagazine:new(playerObj, magazine, ammoCount, nil, itemKey))
    end
    return ammoCount
end

function Magazine.getBestMagazineFromList(playerObj, gun, typeList)
    local inv = playerObj:getInventory()
    local modData = gun:getModData()
    local listSize = #typeList

    local lastIndex = modData.MagazineTypeLastIndex or 0

    for offset = 1, listSize do
        local idx = ((lastIndex + offset - 1) % listSize) + 1
        local typeName = typeList[idx]
        local items = inv:getAllTypeRecurse(typeName)
        if items then
            for i = 0, items:size() - 1 do
                local mag = items:get(i)
                if mag and mag:getCurrentAmmoCount() > 0 then
                    modData.MagazineTypeLastIndex = idx
                    return mag
                end
            end
        end
    end

    for offset = 1, listSize do
        local idx = ((lastIndex + offset - 1) % listSize) + 1
        local typeName = typeList[idx]
        local mag = inv:getFirstTypeRecurse(typeName)
        if mag then
            modData.MagazineTypeLastIndex = idx
            return mag
        end
    end
end

function Magazine.getBestMagazineForGun(playerObj, gun)
    local profile = Magazine.WeaponMagazineProfile[gun:getFullType()]
    if not profile or not Magazine.ProfileMagazineSet[profile] then return nil end
    return playerObj:getInventory():getBestEvalArgRecurse(
        Magazine.predicateInProfile, Magazine.compareAmmoCount, gun
    )
end

function Magazine.ReloadBestMagazineFromList(playerObj, gun)
    local magazine = Magazine.getBestMagazineForGun(playerObj, gun)
    if not magazine then return end
    local ammoCount = Magazine.reloadMagazine(playerObj, magazine)
    if ammoCount == 0 then return end
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, magazine)
    ISTimedActionQueue.add(ISInsertMagazine:new(playerObj, gun, magazine))
end

function Magazine.SaveMagazineType(gun, magType)
    if not gun or not magType then return end
    local modData = gun:getModData()
    modData.MagazineType = magType

    local typeList = Magazine.GetMagazineTypesForGun(gun)
    if typeList then
        for i, t in ipairs(typeList) do
            if t == magType then
                modData.MagazineTypeLastIndex = i
                break
            end
        end
    end
end

function Magazine.GetMagazineType(gun)
    if not gun then return nil end
    local modData = gun:getModData()
    return modData and modData.MagazineType
end

function Magazine.ClearMagazineType(gun)
    if not gun then return end
    local modData = gun:getModData()
    modData.MagazineType = nil
end

---------------------------------------------------------------
-- Visual Magazine System
--
-- Driven by a single anim event that modders place in AnimSet XMLs:
--   InsertMag – hand is near the magazine well
--
-- On insert (reload):  attaches the visual Clip part to the weapon.
-- On eject (unload):   detaches the visual Clip part from the weapon.
-- On stop/complete the weapon's visual Clip part is synced to the
-- actual clip state and the weapon is re-synced for MP.
---------------------------------------------------------------

-- Sync the weapon's visual magazine part to its logical clip state.
function Magazine.manageMagazineAttachment(weapon, magTypeOverride)
    if not weapon then return end
    local magType = magTypeOverride or weapon:getMagazineType()
    if not magType or magType == "" then return end

    if weapon:isContainsClip() then
        local currentClip = weapon:getWeaponPart("Clip")
        if currentClip and currentClip:getFullType() ~= magType then
            weapon:detachWeaponPart(currentClip)
            currentClip = nil
        end
        if not currentClip then
            local magPart = instanceItem(magType)
            if magPart and instanceof(magPart, "WeaponPart") then
                weapon:attachWeaponPart(magPart, true)
            end
        end
    else
        local clipPart = weapon:getWeaponPart("Clip")
        if clipPart then
            weapon:detachWeaponPart(clipPart)
        end
    end
end

-- Force-attach the visual Clip part on the weapon model (ignores clip state).
function Magazine.attachMagazineVisual(weapon, magTypeOverride)
    if not weapon then return end
    local magType = magTypeOverride or weapon:getMagazineType()
    if not magType or magType == "" then return end
    local currentClip = weapon:getWeaponPart("Clip")
    if currentClip and currentClip:getFullType() ~= magType then
        weapon:detachWeaponPart(currentClip)
        currentClip = nil
    end
    if currentClip then return end
    local magPart = instanceItem(magType)
    if magPart and instanceof(magPart, "WeaponPart") then
        weapon:attachWeaponPart(magPart, true)
    end
end

-- Force-detach the visual Clip part from the weapon model (ignores clip state).
function Magazine.detachMagazineVisual(weapon)
    if not weapon then return end
    local clipPart = weapon:getWeaponPart("Clip")
    if clipPart then
        weapon:detachWeaponPart(clipPart)
    end
end

return Magazine
