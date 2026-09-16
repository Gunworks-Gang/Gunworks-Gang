local Magazine = {}
local Ammo = require("WeaponSystems/Utils/Ammo")

-------------------------------------------------
-- Table 1.a: Weapon -> Magazine Profile
-- Maps weapon fullType to a magazine profile name
-------------------------------------------------
Magazine.WeaponMagazineProfile = {}

-------------------------------------------------
-- Table 1.b: WeaponPart -> Magazine Profile
-- Maps a weapon-part fullType to a magazine profile name. When the part is
-- installed on a weapon this profile overrides the weapon's own (Table 1.a).
-------------------------------------------------
Magazine.WeaponPartMagazineProfile = {}

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

--- Register one or more weaponPart to a magazine profile.
---@param profileName string
---@param weaponPartType string|string[]  single fullType or array of fullTypes
function Magazine.RegisterWeaponPartWithProfile(profileName, weaponPartType)
    if type(weaponPartType) == "string" then
        Magazine.WeaponPartMagazineProfile[weaponPartType] = profileName
    else
        for i = 1, #weaponPartType do
            Magazine.WeaponPartMagazineProfile[weaponPartType[i]] = profileName
        end
    end
end

function Magazine.RegisterMultipleWeaponPartsWithProfiles(entriesTable)
    if not entriesTable then return end

    for profileName, weaponPartType in pairs(entriesTable) do
        Magazine.RegisterWeaponPartWithProfile(profileName, weaponPartType)
    end
end

--- Register a new magazine profile or add magazine types to an existing one.
--- Duplicate magazine types are skipped so round-robin selection isn't skewed.
---@param profileName string
---@param magazineTypes string[]  ordered list of magazine fullTypes
function Magazine.RegisterMagazineProfile(profileName, magazineTypes)
    local list = Magazine.MagazineProfiles[profileName]
    if not list then
        list = {}
        Magazine.MagazineProfiles[profileName] = list
    end
    local set = Magazine.ProfileMagazineSet[profileName]
    if not set then
        set = {}
        Magazine.ProfileMagazineSet[profileName] = set
    end
    for i = 1, #magazineTypes do
        local magType = magazineTypes[i]
        if not set[magType] then
            set[magType] = true
            list[#list + 1] = magType
        end
    end
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

--- Get the magazine profile name for a weapon part.
---@param weaponPart WeaponPart
---@return string|nil
function Magazine.GetProfileForWeaponPart(weaponPart)
    return Magazine.WeaponPartMagazineProfile[weaponPart:getFullType()]
end

--- Scan the weapon's installed parts for one registered with its own magazine
--- profile. An installed part's profile overrides the weapon's own profile, so a
--- magwell adapter / conversion part can change which magazines (and therefore
--- which ammo) the weapon accepts. The first registered part found wins.
---@param gun HandWeapon
---@return string|nil profileName
---@return WeaponPart|nil part
function Magazine.GetPartProfileForGun(gun)
    if not gun or not gun.getAllWeaponParts then return nil end

    local parts = gun:getAllWeaponParts()
    if not parts then return nil end

    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part then
            local profile = Magazine.WeaponPartMagazineProfile[part:getFullType()]
            if profile then return profile, part end
        end
    end
    return nil
end

--- Get the effective magazine profile name for a weapon. An installed weapon
--- part registered with its own profile takes priority over the weapon's own
--- WeaponMagazineProfile entry.
---@param gun HandWeapon
---@return string|nil
function Magazine.GetProfileForGun(gun)
    if not gun then return nil end
    return Magazine.GetPartProfileForGun(gun) or Magazine.WeaponMagazineProfile[gun:getFullType()]
end

--- Get the magazine type list for a weapon (part profile takes priority).
---@param gun HandWeapon
---@return string[]|nil
function Magazine.GetMagazineTypesForGun(gun)
    local profile = Magazine.GetProfileForGun(gun)
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

--- Predicate: returns true if the item is a magazine in the given profile set.
--- The set is resolved once by the caller (part profile takes priority) and
--- passed straight through, so this runs cheaply per inventory item.
---@param item InventoryItem
---@param profileSet table<string, boolean>
---@return boolean
function Magazine.predicateInProfile(item, profileSet)
    return profileSet and profileSet[item:getFullType()] or false
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
        ISInventoryPaneContextMenu.transferIfNeeded(playerObj, magazine)
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
    local profile = Magazine.GetProfileForGun(gun)
    local profileSet = profile and Magazine.ProfileMagazineSet[profile]
    if not profileSet then return nil end
    return playerObj:getInventory():getBestEvalArgRecurse(
        Magazine.predicateInProfile, Magazine.compareAmmoCount, profileSet
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

---@param weapon HandWeapon
function Magazine.RestoreMagazineType(weapon)
    if not weapon then return end
    local magType = Magazine.GetMagazineType(weapon)
    if not magType or magType == "" then return end
    if weapon:getMagazineType() ~= magType then
        local mag = instanceItem(magType)
        weapon:setMagazineType(magType)
        weapon:setMaxAmmo(mag:getMaxAmmo())
    end
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
        local currentClip = weapon:getWeaponPart("Clip") or weapon:getWeaponPart("Magazine")
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
        local clipPart = weapon:getWeaponPart("Clip") or weapon:getWeaponPart("Magazine")
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
    local currentClip = weapon:getWeaponPart("Clip") or weapon:getWeaponPart("Magazine")
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
    local clipPart = weapon:getWeaponPart("Clip") or weapon:getWeaponPart("Magazine")
    if clipPart then
        weapon:detachWeaponPart(clipPart)
    end
end

return Magazine
