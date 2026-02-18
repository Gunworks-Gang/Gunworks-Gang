local Magazine = {}

Magazine.WeaponMagazineProfile = {
    ['MWA.M16A1'] = 'Stanag',
    ['MWA.M16A2'] = 'Stanag',
    ['MWA.M16A3'] = 'Stanag',
}

Magazine.MagazineProfileList = {
    ['Stanag'] = { "MWA.556Magazine20", "MWA.556Magazine25", "MWA.556Magazine30", }
}
Magazine.MAG_TYPE_KEY = "MagazineType"

function Magazine.isMagazineInProfile(magType, profileList)
    if not profileList then return false end
    for _, allowedType in ipairs(profileList) do
        if allowedType == magType then
            return true
        end
    end
    return false
end

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

    local bestMag = nil
    local bestAmmoCount = 0

    for _, typeName in ipairs(typeList) do
        local items = inv:getAllTypeRecurse(typeName)
        if items then
            for i = 0, items:size() - 1 do
                local mag = items:get(i)
                if mag then
                    local ammoCount = mag:getCurrentAmmoCount()
                    if ammoCount > bestAmmoCount then
                        bestMag = mag
                        bestAmmoCount = ammoCount
                    end
                end
            end
        end
    end

    if bestMag then
        return bestMag
    end

    for offset = 1, listSize do
        local idx = ((lastIndex + offset - 1) % listSize) + 1
        local typeName = typeList[idx]
        local mag = inv:getFirstTypeRecurse(typeName)
        modData.MagazineTypeLastIndex = idx
        if mag then
            return mag
        end
    end
end

function Magazine.getBestMagazineForGun(playerObj, gun)
    local typeList = Magazine.MagazineProfileList[Magazine.WeaponMagazineProfile[gun:getFullType()]]
    return Magazine.getBestMagazineFromList(playerObj, gun, typeList)
end

function Magazine.ReloadBestMagazineFromList(playerObj, gun)
    local magazine = Magazine.getBestMagazineForGun(playerObj, gun)
    local ammoCount = Magazine.reloadMagazine(playerObj, magazine)
    if not magazine or ammoCount == 0 then
        return
    end
    ISTimedActionQueue.add(ISInsertMagazine:new(playerObj, gun, magazine))
end

function Magazine.SaveMagazineType(gun, magType)
    if not gun or not magType then return end
    local modData = gun:getModData()
    modData[Magazine.MAG_TYPE_KEY] = magType
end

function Magazine.GetMagazineType(gun)
    if not gun then return nil end
    local modData = gun:getModData()
    return modData and modData[Magazine.MAG_TYPE_KEY]
end

function Magazine.ClearMagazineType(gun)
    if not gun then return end
    local modData = gun:getModData()
    modData[Magazine.MAG_TYPE_KEY] = nil
end

return Magazine
