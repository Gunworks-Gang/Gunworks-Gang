local Magazine = {}

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
-- Registration API
-------------------------------------------------

--- Register one or more weapons to a magazine profile.
---@param profileName string
---@param weaponTypes string|string[]  single fullType or array of fullTypes
function Magazine.RegisterWeaponProfile(profileName, weaponTypes)
    if type(weaponTypes) == "string" then
        Magazine.WeaponMagazineProfile[weaponTypes] = profileName
    else
        for i = 1, #weaponTypes do
            Magazine.WeaponMagazineProfile[weaponTypes[i]] = profileName
        end
    end
end

--- Register (or replace) a magazine profile.
---@param profileName string
---@param magazineTypes string[]  ordered list of magazine fullTypes
function Magazine.RegisterMagazineProfile(profileName, magazineTypes)
    Magazine.MagazineProfiles[profileName] = magazineTypes
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
    local typeList = Magazine.MagazineProfiles[profileName]
    if not typeList then return false end
    for _, allowedType in ipairs(typeList) do
        if allowedType == magType then
            return true
        end
    end
    return false
end

-------------------------------------------------
-- Magazine operations
-------------------------------------------------

function Magazine.reloadMagazine(playerObj, magazine)
    if not magazine then
        return 0
    end
    local itemKey = magazine:getAmmoType():getItemKey();
    local ammoCount = magazine:getCurrentAmmoCount() +
        ISInventoryPaneContextMenu.transferBullets(playerObj, itemKey, magazine:getCurrentAmmoCount(),
            magazine:getMaxAmmo())
    if ammoCount > 0 then
        ISTimedActionQueue.add(ISLoadBulletsInMagazine:new(playerObj, magazine, ammoCount))
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
    local typeList = Magazine.GetMagazineTypesForGun(gun)
    return typeList and Magazine.getBestMagazineFromList(playerObj, gun, typeList)
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
    -- Set the cycle index so the next reload starts after this mag type
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

return Magazine
