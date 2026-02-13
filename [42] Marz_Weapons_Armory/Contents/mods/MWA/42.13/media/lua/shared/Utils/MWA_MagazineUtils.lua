require "MWA_Core"

function MWA_Utils.isMagazineInProfile(magType, profileList)
    if not profileList then return false end
    for _, allowedType in ipairs(profileList) do
        if allowedType == magType then
            return true
        end
    end
    return false
end

function MWA_Utils.manageMagazineAttachment(weapon, magazine, insert)
    if not weapon then return end

    if insert then
        weapon:attachWeaponPart(instanceItem(magazine:getFullType()), true)
    end

    if not insert then
        weapon:detachWeaponPart(weapon:getWeaponPart("Clip"))
    end
end

function MWA_Utils.reloadMagazine(playerObj, magazine)
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

function MWA_Utils.getBestMagazineFromList(playerObj, gun, typeList)
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

function MWA_Utils.getBestMagazineForGun(playerObj, gun)
    local typeList = MWA_Utils.MagazineProfileList[gun:getModData().MagazineProfile]
    return MWA_Utils.getBestMagazineFromList(playerObj, gun, typeList)
end

function MWA_Utils.ReloadBestMagazineFromList(playerObj, gun)
    local magazine = MWA_Utils.getBestMagazineForGun(playerObj, gun)
    local ammoCount = MWA_Utils.reloadMagazine(playerObj, magazine)
    if not magazine or ammoCount == 0 then
        return
    end
    ISTimedActionQueue.add(ISInsertMagazine:new(playerObj, gun, magazine))
end

function MWA_Utils.SaveMagazineType(gun, magType)
    if not gun or not magType then return end
    local modData = gun:getModData()
    modData[MWA_Utils.MAG_TYPE_KEY] = magType
end

function MWA_Utils.GetMagazineType(gun)
    if not gun then return nil end
    local modData = gun:getModData()
    return modData and modData[MWA_Utils.MAG_TYPE_KEY]
end

function MWA_Utils.ClearMagazineType(gun)
    if not gun then return end
    local modData = gun:getModData()
    modData[MWA_Utils.MAG_TYPE_KEY] = nil
end
