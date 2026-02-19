local Ammo = {}

-------------------------------------------------
-- Table 1: Item -> Ammo Family
-- Maps any weapon or magazine type to its ammo family
-------------------------------------------------
Ammo.ItemAmmoFamily = {
    ["MWA.SIDE_BY_SIDE"]      = "12Gauge",
    ["MWA.BENELLI_M4"]        = "12Gauge",

    ["MWA.556Magazine20"]     = "5.56x45mm",
    ["MWA.556Magazine25"]     = "5.56x45mm",
    ["MWA.556Magazine30"]     = "5.56x45mm",

    ["MWA.308Magazine5_M40"]  = "7.62x51mm",
    ["MWA.308Magazine20_G3"]  = "7.62x51mm",
    ["MWA.308Magazine20_FAL"] = "7.62x51mm",
    ["MWA.308Magazine20_M14"] = "7.62x51mm",
}

-------------------------------------------------
-- Table 2: Ammo Families
-- Each family defines its bullet types with enum and optional profile
-------------------------------------------------
Ammo.AmmoFamilies = {
    ["5.56x45mm"] = {
        { type = "Base.556Bullets",           enum = AmmoType.BULLETS_556,             profile = "BaseAmmo" },
        { type = "Base.223Bullets",           enum = AmmoType.BULLETS_556,             profile = "CivilianAmmo" },
        { type = "Base.556Bullets_Subsonics", enum = MWA_AmmoTypes.MWA_bullets_556_SS, profile = "SubsonicAmmo" },
    },
    ["7.62x51mm"] = {
        { type = "Base.308Bullets",   enum = AmmoType.BULLETS_308 },
        { type = "Base.76251Bullets", enum = MWA_AmmoTypes.MWA_bullets_76251 },
    },
    ["12Gauge"] = {
        { type = "Base.ShotgunShells",       enum = AmmoType.SHOTGUN_SHELLS },
        { type = "Base.ShotgunShells_Slugs", enum = MWA_AmmoTypes.MWA_shotgun_shells_slug, profile = "SlugAmmo" },
    },
    ["7.62x54mmR"] = {
        { type = "Base.76254Bullets", enum = MWA_AmmoTypes.MWA_bullets_76254 },
    },
    [".30-30 Winchester"] = {
        { type = "Base.3030Bullets", enum = AmmoType.BULLETS_3030 },
    },
    [".357 Magnum"] = {
        { type = "Base.Bullets357", enum = AmmoType.BULLETS_357 },
    },
    [".38 Special"] = {
        { type = "Base.Bullets38", enum = AmmoType.BULLETS_38 },
    },
    [".44 Magnum"] = {
        { type = "Base.Bullets44", enum = AmmoType.BULLETS_44 },
    },
    [".45 ACP"] = {
        { type = "Base.Bullets45", enum = AmmoType.BULLETS_45 },
    },
    ["9x19mm"] = {
        { type = "Base.Bullets9mm", enum = AmmoType.BULLETS_9MM },
    },
    [".30-06 Springfield"] = {
        { type = "Base.3006Bullets", enum = MWA_AmmoTypes.MWA_bullets_3006 },
    },
}

-------------------------------------------------
-- Ammo Stats (shared config, rarely changed by modders)
-------------------------------------------------
Ammo.AmmoStats = {
    ["BaseAmmo"]          = { "We will use base stats when this is selected." },
    ["SubsonicAmmo"]      = { MaxDamage = -0.5, MinDamage = -0.5, PiercingBullets = false, MaxHitCount = 1, ProjectileCount = 1, SoundRadius = -50, SoundVolume = -20, RackAfterShot = true },
    ["ArmorPiercingAmmo"] = { MaxDamage = -0.2, MinDamage = -0.2, PiercingBullets = true, MaxHitCount = 3, ProjectileCount = 1 },
    ["HollowPointAmmo"]   = { MaxDamage = 1.5, MinDamage = 1.5, PiercingBullets = false, MaxHitCount = 1, ProjectileCount = 1 },
    ["SlugAmmo"]          = { MaxDamage = 2.0, MinDamage = 2.0, PiercingBullets = true, MaxHitCount = 2, ProjectileCount = 1 },
    ["CivilianAmmo"]      = { MaxDamage = -0.3, MinDamage = -0.3, PiercingBullets = false, MaxHitCount = 1, ProjectileCount = 1 },
}

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

-------------------------------------------------
-- Registration API for modders
-------------------------------------------------

--- Register a weapon or magazine to an ammo family
--- @param itemType string  e.g. "MyMod.MyGun" or "MyMod.MyMagazine"
--- @param family string    e.g. "5.56x45mm"
function Ammo.RegisterItemFamily(itemType, family)
    Ammo.ItemAmmoFamily[itemType] = family
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

--- Register a new ammo stat profile or overwrite an existing one
--- @param profileName string  e.g. "SubsonicAmmo"
--- @param stats table  e.g. { MaxDamage = -0.5, MinDamage = -0.5, SoundRadius = -50 }
function Ammo.RegisterAmmoStats(profileName, stats)
    Ammo.AmmoStats[profileName] = stats
end

function Ammo.GetAmmoCharacteristics(bulletType)
    local entry = Ammo.FindBulletEntry(bulletType)
    return entry and entry.profile
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
    local ammoEnum = Ammo.GetEnumForBullet(bulletType)
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
    local ammoEnum = Ammo.GetEnumForBullet(bulletType)
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
