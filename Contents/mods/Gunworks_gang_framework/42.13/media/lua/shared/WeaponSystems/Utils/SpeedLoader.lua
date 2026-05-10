local SpeedLoader = {}

-------------------------------------------------
-- Table 1: Weapon -> compatible speedloader types
-------------------------------------------------
SpeedLoader.WeaponSpeedLoaders = {}

local function copyTypeList(source)
    if not source then return nil end

    local copy = {}
    if type(source) == "string" then
        copy[1] = source
        return copy
    end

    for i = 1, #source do
        copy[i] = source[i]
    end
    return copy
end

-------------------------------------------------
-- Registration API
-------------------------------------------------

--- Register one or more weapons with one or more compatible speedloaders.
---@param weaponTypes string|string[]
---@param speedLoaderTypes string|string[]
function SpeedLoader.RegisterWeapon(weaponTypes, speedLoaderTypes)
    local typeList = copyTypeList(speedLoaderTypes)
    if not weaponTypes or not typeList or #typeList == 0 then return end

    if type(weaponTypes) == "string" then
        SpeedLoader.WeaponSpeedLoaders[weaponTypes] = copyTypeList(typeList)
    else
        for i = 1, #weaponTypes do
            SpeedLoader.WeaponSpeedLoaders[weaponTypes[i]] = copyTypeList(typeList)
        end
    end
end

function SpeedLoader.RegisterMultipleWeapons(entriesTable)
    if not entriesTable then return end

    for weaponType, speedLoaderTypes in pairs(entriesTable) do
        SpeedLoader.RegisterWeapon(weaponType, speedLoaderTypes)
    end
end

-------------------------------------------------
-- Query helpers
-------------------------------------------------

---@param gun HandWeapon
---@return string[]|nil
function SpeedLoader.GetSpeedLoaderTypesForGun(gun)
    if not gun then return nil end
    return SpeedLoader.WeaponSpeedLoaders[gun:getFullType()]
end

---@param gun HandWeapon
---@return boolean
function SpeedLoader.IsRegisteredGun(gun)
    local typeList = SpeedLoader.GetSpeedLoaderTypesForGun(gun)
    return typeList ~= nil and #typeList > 0
end

---@param speedLoaderType string
---@param gun HandWeapon
---@return boolean
function SpeedLoader.IsCompatibleTypeForGun(speedLoaderType, gun)
    if not speedLoaderType or not gun then return false end

    local typeList = SpeedLoader.GetSpeedLoaderTypesForGun(gun)
    if not typeList then return false end

    for i = 1, #typeList do
        if typeList[i] == speedLoaderType then
            return true
        end
    end

    return false
end

---@param playerObj IsoPlayer
---@param gun HandWeapon
---@return InventoryItem|nil
function SpeedLoader.GetBestSpeedLoaderForGun(playerObj, gun)
    local typeList = SpeedLoader.GetSpeedLoaderTypesForGun(gun)
    if not playerObj or not gun or not typeList or #typeList == 0 then return nil end

    local inv = playerObj:getInventory()
    if not inv then return nil end

    for i = 1, #typeList do
        local typeName = typeList[i]
        local items = inv:getAllTypeRecurse(typeName)
        if items then
            for itemIndex = 0, items:size() - 1 do
                local speedLoader = items:get(itemIndex)
                if speedLoader and speedLoader:getCurrentAmmoCount() > 0 then
                    return speedLoader
                end
            end
        end
    end

    return nil
end

-------------------------------------------------
-- Transfer helpers
-------------------------------------------------

local function appendBulletToGunAmmoList(gun, bulletType)
    if not gun or not bulletType then return end

    local gunModData = gun:getModData()
    gunModData.AmmoList = gunModData.AmmoList or {}
    local ammoList = gunModData.AmmoList

    if gun:isRoundChambered() and #ammoList > 0 then
        local chamberedType = ammoList[#ammoList]
        ammoList[#ammoList] = bulletType
        ammoList[#ammoList + 1] = chamberedType
        return
    end

    ammoList[#ammoList + 1] = bulletType
end

---@param gun HandWeapon
---@param speedLoader InventoryItem
---@return number
function SpeedLoader.TransferAmmoToGun(gun, speedLoader)
    if not gun or not speedLoader then
        return 0
    end

    local freeSpace = gun:getMaxAmmo() - gun:getCurrentAmmoCount()
    if freeSpace <= 0 then
        return 0
    end

    local available = speedLoader:getCurrentAmmoCount()
    local transferCount = math.min(available, freeSpace)
    if transferCount <= 0 then
        return 0
    end

    local speedLoaderModData = speedLoader:getModData()
    local speedLoaderAmmoList = speedLoaderModData.AmmoList
    local fallbackAmmoType = speedLoader:getAmmoType()
    local fallbackBulletType = fallbackAmmoType and fallbackAmmoType:getItemKey()

    for _ = 1, transferCount do
        local bulletType = nil
        if speedLoaderAmmoList and #speedLoaderAmmoList > 0 then
            bulletType = table.remove(speedLoaderAmmoList, 1)
        end
        appendBulletToGunAmmoList(gun, bulletType or fallbackBulletType)
    end

    gun:setCurrentAmmoCount(gun:getCurrentAmmoCount() + transferCount)
    speedLoader:setCurrentAmmoCount(available - transferCount)

    if speedLoaderAmmoList and #speedLoaderAmmoList == 0 then
        speedLoaderModData.AmmoList = nil
    end

    return transferCount
end

return SpeedLoader
