local SWMG_Core = {}

SWMG_Core.MagazineProfileList = {
    -- ['Stanag'] = { "MWA.556Magazine20", "MWA.556Magazine25", "MWA.556Magazine30", }
}

SWMG_Core.AmmoProfilesList = {
    -- ["5.56x45mm"] = { "Base.556Bullets", "Base.223Bullets", "Base.556Bullets_Subsonics" },
    -- ["7.62x51mm"] = { "Base.308Bullets", "Base.76251Bullets" },
    -- ["12Gauge"] = { "Base.ShotgunShells", "Base.ShotgunShells_Slugs" },
    -- ["7.62x54mmR"] = { "Base.76254Bullets" }
}

SWMG_Core.ItemFullTypeToAmmoType = {
    -- ["Base.Bullets38"] = AmmoType.BULLETS_38,
    -- ["Base.Bullets44"] = AmmoType.BULLETS_44,
    -- ["Base.Bullets45"] = AmmoType.BULLETS_45,
    -- ["Base.Bullets9mm"] = AmmoType.BULLETS_9MM,
    -- ["Base.3006Bullets"] = MWA_AmmoTypes.MWA_bullets_3006,
    -- ["Base.76254Bullets"] = MWA_AmmoTypes.MWA_bullets_76254,

    -- ["Base.223Bullets"] = AmmoType.BULLETS_223,
    -- ["Base.556Bullets"] = AmmoType.BULLETS_556,
    -- ["Base.556Bullets_Subsonics"] = MWA_AmmoTypes.MWA_bullets_556_SS,

    -- ["Base.308Bullets"] = AmmoType.BULLETS_308,
    -- ["Base.76251Bullets"] = MWA_AmmoTypes.MWA_bullets_76251,

    -- ["Base.ShotgunShells"] = AmmoType.SHOTGUN_SHELLS,
    -- ["Base.ShotgunShells_Slugs"] = MWA_AmmoTypes.MWA_shotgun_shells_slug,
}

SWMG_Core.AmmoStats = {
    -- ["BaseAmmo"] = { "We will use base stats when this is selected." },
    -- ["SubsonicAmmo"] = { MaxDamage = -0.5, MinDamage = -0.5, PiercingBullets = false, MaxHitCount = 1, ProjectileCount = 1, SoundRadius = -50, SoundVolume = -20, RackAfterShot = true },
    -- ["ArmorPiercingAmmo"] = { MaxDamage = -0.2, MinDamage = -0.2, PiercingBullets = true, MaxHitCount = 3, ProjectileCount = 1 },
    -- ["HollowPointAmmo"] = { MaxDamage = 1.5, MinDamage = 1.5, PiercingBullets = false, MaxHitCount = 1, ProjectileCount = 1 },
    -- ["SlugAmmo"] = { MaxDamage = 2.0, MinDamage = 2.0, PiercingBullets = true, MaxHitCount = 2, ProjectileCount = 1 },
    -- ["CivilianAmmo"] = { MaxDamage = -0.3, MinDamage = -0.3, PiercingBullets = false, MaxHitCount = 1, ProjectileCount = 1 },
}

SWMG_Core.FoldedStockStats = {
    -- ["MWA.SPAS_12"] = { AimingPerkCritModifier = -5, AimingPerkHitChanceModifier = -2, AimingTime = -20 },
    -- ["MWA.MP5"] = { AimingPerkCritModifier = -3, AimingPerkHitChanceModifier = -2, AimingTime = -20 },
}

SWMG_Core.DeployedBipodStats = {
    -- Add weapon-specific bipod stats here
    -- Example: ["MWA.M249"] = { AimingPerkCritModifier = 5, AimingPerkHitChanceModifier = 5, AimingTime = 10, RecoilDelay = 5 },
}

SWMG_Core.MAG_TYPE_KEY = "MWAMagazineType"
SWMG_Core.STOCK_FOLDED_KEY = "MWA_StockFolded"
SWMG_Core.BIPOD_DEPLOYED_KEY = "MWA_BipodDeployed"
SWMG_Core.PendingWeaponRestorations = {}
SWMG_Core.PendingHotbarRestorations = {}

return SWMG_Core
