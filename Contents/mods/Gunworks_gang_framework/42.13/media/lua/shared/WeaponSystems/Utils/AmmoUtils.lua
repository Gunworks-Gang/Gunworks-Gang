local Ammo = {}

Ammo.WeaponAmmoProfile = {
    ["MWA.SIDE_BY_SIDE"] = "12Gauge",
    ["MWA.BENELLI_M4"] = "12Gauge",
}

Ammo.MagazineAmmoProfile = {
    ["MWA.556Magazine20"] = "5.56x45mm",
    ["MWA.556Magazine25"] = "5.56x45mm",
    ["MWA.556Magazine30"] = "5.56x45mm",

    ["MWA.308Magazine5_M40"] = "7.62x51mm",
    ["MWA.308Magazine20_G3"] = "7.62x51mm",
    ["MWA.308Magazine20_FAL"] = "7.62x51mm",
    ["MWA.308Magazine20_M14"] = "7.62x51mm",
}

Ammo.AmmunitionTypeProfile = {
    ["Base.556Bullets"] = "BaseAmmo",
    ["Base.223Bullets"] = "CivilianAmmo",
    ["Base.556Bullets_Subsonics"] = "SubsonicAmmo",
}

Ammo.AmmoProfilesList = {
    ["5.56x45mm"] = { "Base.556Bullets", "Base.223Bullets", "Base.556Bullets_Subsonics" },
    ["7.62x51mm"] = { "Base.308Bullets", "Base.76251Bullets" },
    ["12Gauge"] = { "Base.ShotgunShells", "Base.ShotgunShells_Slugs" },
    ["7.62x54mmR"] = { "Base.76254Bullets" }
}

Ammo.ItemFullTypeToAmmoType = {
    ["Base.3030Bullets"] = AmmoType.BULLETS_3030,
    ["Base.308Bullets"] = AmmoType.BULLETS_308,
    ["Base.Bullets357"] = AmmoType.BULLETS_357,
    ["Base.Bullets38"] = AmmoType.BULLETS_38,
    ["Base.Bullets44"] = AmmoType.BULLETS_44,
    ["Base.Bullets45"] = AmmoType.BULLETS_45,
    ["Base.556Bullets"] = AmmoType.BULLETS_556,
    ["Base.Bullets9mm"] = AmmoType.BULLETS_9MM,
    ["Base.ShotgunShells"] = AmmoType.SHOTGUN_SHELLS,
    ["Base.223Bullets"] = AmmoType.BULLETS_223,

    -- custom ones

    ["Base.556Bullets_Subsonics"] = MWA_AmmoTypes.MWA_bullets_556_SS,
    ["Base.76251Bullets"] = MWA_AmmoTypes.MWA_bullets_76251,
    ["Base.3006Bullets"] = MWA_AmmoTypes.MWA_bullets_3006,
    ["Base.76254Bullets"] = MWA_AmmoTypes.MWA_bullets_76254,
    ["Base.ShotgunShells_Slugs"] = MWA_AmmoTypes.MWA_shotgun_shells_slug,
}

Ammo.AmmoStats = {
    ["BaseAmmo"] = { "We will use base stats when this is selected." },
    ["SubsonicAmmo"] = { MaxDamage = -0.5, MinDamage = -0.5, PiercingBullets = false, MaxHitCount = 1, ProjectileCount = 1, SoundRadius = -50, SoundVolume = -20, RackAfterShot = true },
    ["ArmorPiercingAmmo"] = { MaxDamage = -0.2, MinDamage = -0.2, PiercingBullets = true, MaxHitCount = 3, ProjectileCount = 1 },
    ["HollowPointAmmo"] = { MaxDamage = 1.5, MinDamage = 1.5, PiercingBullets = false, MaxHitCount = 1, ProjectileCount = 1 },
    ["SlugAmmo"] = { MaxDamage = 2.0, MinDamage = 2.0, PiercingBullets = true, MaxHitCount = 2, ProjectileCount = 1 },
    ["CivilianAmmo"] = { MaxDamage = -0.3, MinDamage = -0.3, PiercingBullets = false, MaxHitCount = 1, ProjectileCount = 1 },
}

function Ammo.GetAmmoCharacteristics(bulletType)
    return Ammo.AmmunitionTypeProfile[bulletType]
end

function Ammo.AmmoAdjustWeaponStats(weapon, bulletType, ammoEnum)
    local weaponBaseStats     = instanceItem(weapon:getFullType())
    local ammoCharacteristics = Ammo.GetAmmoCharacteristics(bulletType)
    local ammoStats           = Ammo.AmmoStats[ammoCharacteristics] or {}

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

function Ammo.AmmoProfileSetter(weapon, bulletType)
    local ammoEnum = Ammo.ItemFullTypeToAmmoType and Ammo.ItemFullTypeToAmmoType[bulletType]
    if not ammoEnum then return end

    if weapon:getAmmoType() == ammoEnum then
        return
    end

    if isClient() then
        local playerObj = getSpecificPlayer(0)
        if playerObj then
            sendClientCommand(playerObj, "MWA", "ammoProfile", {
                itemId = weapon:getID(),
                bulletType = bulletType
            })
        end
        return
    end

    print('Ammo Profile Setting!')
    print(weapon:getAmmoType(), "  -->   ", ammoEnum)

    Ammo.AmmoAdjustWeaponStats(weapon, bulletType, ammoEnum)
end

function Ammo.MagazineAmmoProfileSetter(magazine, bulletType)
    local ammoEnum = Ammo.ItemFullTypeToAmmoType and Ammo.ItemFullTypeToAmmoType[bulletType]
    if not ammoEnum then return end

    if magazine:getAmmoType() == ammoEnum then
        return
    end

    if isClient() then
        local playerObj = getSpecificPlayer(0)
        if playerObj then
            sendClientCommand(playerObj, "MWA", "magazineAmmoProfile", {
                itemId = magazine:getID(),
                bulletType = bulletType
            })
        end
        return
    end

    print('Magazine Ammo Profile Setting!')
    print(magazine:getAmmoType(), "  -->   ", ammoEnum)

    magazine:setAmmoType(ammoEnum)
end

return Ammo
