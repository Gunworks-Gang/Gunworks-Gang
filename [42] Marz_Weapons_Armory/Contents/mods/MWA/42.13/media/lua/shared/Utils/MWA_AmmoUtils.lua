require "MWA_Core"

function MWA_Utils.isAmmoInProfile(ammoType, profileList)
    if not profileList then return false end
    for _, allowedType in ipairs(profileList) do
        if allowedType == ammoType then
            return true
        end
    end
    return false
end

function MWA_Utils.GetAmmoCharacteristics(bulletType)
    local ammoItem = instanceItem(bulletType)
    if not ammoItem then
        return "BaseAmmo"
    end

    local md = ammoItem:getModData()
    if md and md.AmmoCharacteristics then
        return md.AmmoCharacteristics
    end

    return "BaseAmmo"
end

function MWA_Utils.AmmoAdjustWeaponStats(weapon, bulletType, ammoEnum)
    local weaponBaseStats     = instanceItem(weapon:getFullType())
    local ammoCharacteristics = MWA_Utils.GetAmmoCharacteristics(bulletType)
    local ammoStats           = MWA_Utils.AmmoStats[ammoCharacteristics] or {}

    local baseMaxDamage       = weaponBaseStats:getMaxDamage()
    local baseMinDamage       = weaponBaseStats:getMinDamage()
    local basePiercingBullets = weaponBaseStats:isPiercingBullets()
    local baseMaxHitCount     = weaponBaseStats:getMaxHitCount()
    local baseProjectileCount = weaponBaseStats:getProjectileCount()
    local baseSoundRadius     = weaponBaseStats:getSoundRadius()
    local baseSoundVolume     = weaponBaseStats:getSoundVolume()
    local baseRackAfterShot   = weaponBaseStats:isRackAfterShoot()

    local newMaxDamage        = baseMaxDamage + (ammoStats.MaxDamage or 0)
    local newMinDamage        = baseMinDamage + (ammoStats.MinDamage or 0)
    local newSoundRadius      = baseSoundRadius + (ammoStats.SoundRadius or 0)
    local newSoundVolume      = baseSoundVolume + (ammoStats.SoundVolume or 0)

    weapon:setMaxDamage(newMaxDamage)
    weapon:setMinDamage(newMinDamage)
    weapon:setSoundRadius(newSoundRadius)
    weapon:setSoundVolume(newSoundVolume)

    if ammoStats.PiercingBullets then
        weapon:setPiercingBullets(ammoStats.PiercingBullets)
    else
        weapon:setPiercingBullets(basePiercingBullets)
    end

    if ammoStats.MaxHitCount then
        weapon:setMaxHitCount(ammoStats.MaxHitCount)
    else
        weapon:setMaxHitCount(baseMaxHitCount)
    end

    if ammoStats.ProjectileCount then
        weapon:setProjectileCount(ammoStats.ProjectileCount)
    else
        weapon:setProjectileCount(baseProjectileCount)
    end

    if ammoStats.RackAfterShot then
        weapon:setRackAfterShoot(ammoStats.RackAfterShot)
    else
        weapon:setRackAfterShoot(baseRackAfterShot)
    end

    weapon:setAmmoType(ammoEnum)
end

function MWA_Utils.AmmoProfileSetter(weapon, bulletType)
    local ammoEnum = MWA_Utils.ItemFullTypeToAmmoType and MWA_Utils.ItemFullTypeToAmmoType[bulletType]
    if not ammoEnum then return end

    if weapon:getAmmoType() == ammoEnum then
        return
    end

    print('Ammo Profile Setting!')
    print(weapon:getAmmoType(), "  -->   ", ammoEnum)

    MWA_Utils.AmmoAdjustWeaponStats(weapon, bulletType, ammoEnum)
end

function MWA_Utils.MagazineAmmoProfileSetter(magazine, bulletType)
    local ammoEnum = MWA_Utils.ItemFullTypeToAmmoType and MWA_Utils.ItemFullTypeToAmmoType[bulletType]
    if not ammoEnum then return end

    if magazine:getAmmoType() == ammoEnum then
        return
    end

    print('Magazine Ammo Profile Setting!')
    print(magazine:getAmmoType(), "  -->   ", ammoEnum)

    magazine:setAmmoType(ammoEnum)
end
