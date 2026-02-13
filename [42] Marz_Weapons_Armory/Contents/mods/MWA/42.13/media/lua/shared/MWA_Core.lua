MWA_Utils = MWA_Utils or {}

MWA_Utils.MagazineProfileList = {
    ['Stanag'] = { "MWA.556Magazine20", "MWA.556Magazine25", "MWA.556Magazine30", }
}

MWA_Utils.AmmoProfilesList = {
    ["5.56x45mm"] = { "Base.556Bullets", "Base.223Bullets", "Base.556Bullets_Subsonics" },
    ["7.62x51mm"] = { "Base.308Bullets", "Base.76251Bullets" },
    ["12Gauge"] = { "Base.ShotgunShells", "Base.ShotgunShells_Slugs" },
    ["7.62x54mmR"] = { "Base.76254Bullets" }
}

MWA_Utils.ItemFullTypeToAmmoType = {
    ["Base.Bullets38"] = AmmoType.BULLETS_38,
    ["Base.Bullets44"] = AmmoType.BULLETS_44,
    ["Base.Bullets45"] = AmmoType.BULLETS_45,
    ["Base.Bullets9mm"] = AmmoType.BULLETS_9MM,
    ["Base.3006Bullets"] = MWA_AmmoTypes.MWA_bullets_3006,
    ["Base.76254Bullets"] = MWA_AmmoTypes.MWA_bullets_76254,

    ["Base.223Bullets"] = AmmoType.BULLETS_223,
    ["Base.556Bullets"] = AmmoType.BULLETS_556,
    ["Base.556Bullets_Subsonics"] = MWA_AmmoTypes.MWA_bullets_556_SS,

    ["Base.308Bullets"] = AmmoType.BULLETS_308,
    ["Base.76251Bullets"] = MWA_AmmoTypes.MWA_bullets_76251,

    ["Base.ShotgunShells"] = AmmoType.SHOTGUN_SHELLS,
    ["Base.ShotgunShells_Slugs"] = MWA_AmmoTypes.MWA_shotgun_shells_slug,
}

MWA_Utils.AmmoStats = {
    ["BaseAmmo"] = { "We will use base stats when this is selected." },
    ["SubsonicAmmo"] = { MaxDamage = -0.5, MinDamage = -0.5, PiercingBullets = false, MaxHitCount = 1, ProjectileCount = 1, SoundRadius = -50, SoundVolume = -20, RackAfterShot = true },
    ["ArmorPiercingAmmo"] = { MaxDamage = -0.2, MinDamage = -0.2, PiercingBullets = true, MaxHitCount = 3, ProjectileCount = 1 },
    ["HollowPointAmmo"] = { MaxDamage = 1.5, MinDamage = 1.5, PiercingBullets = false, MaxHitCount = 1, ProjectileCount = 1 },
    ["SlugAmmo"] = { MaxDamage = 2.0, MinDamage = 2.0, PiercingBullets = true, MaxHitCount = 2, ProjectileCount = 1 },
    ["CivilianAmmo"] = { MaxDamage = -0.3, MinDamage = -0.3, PiercingBullets = false, MaxHitCount = 1, ProjectileCount = 1 },
}

MWA_Utils.FoldedStockStats = {
    ["MWA.SPAS_12"] = { AimingPerkCritModifier = -5, AimingPerkHitChanceModifier = -2, AimingTime = -20 },
    ["MWA.MP5"] = { AimingPerkCritModifier = -3, AimingPerkHitChanceModifier = -2, AimingTime = -20 },
}

MWA_Utils.DeployedBipodStats = {
    -- Add weapon-specific bipod stats here
    -- Example: ["MWA.M249"] = { AimingPerkCritModifier = 5, AimingPerkHitChanceModifier = 5, AimingTime = 10, RecoilDelay = 5 },
}

MWA_Utils.MAG_TYPE_KEY = "MWAMagazineType"
MWA_Utils.STOCK_FOLDED_KEY = "MWA_StockFolded"
MWA_Utils.BIPOD_DEPLOYED_KEY = "MWA_BipodDeployed"
MWA_Utils.PendingWeaponRestorations = {}
MWA_Utils.PendingHotbarRestorations = {}

local function restoreContainer(container)
    if not container then return end
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)

        if instanceof(item, "HandWeapon") and item:isRanged() then
            MWA_Utils.RestoreFoldedStockState(item)
            MWA_Utils.RestoreDeployedBipodState(item)
        end

        if item.getInventory and item:getInventory() then
            restoreContainer(item:getInventory())
        end
    end
end

local function restorePlayer(playerObj)
    if not playerObj then return end
    restoreContainer(playerObj:getInventory())
end

Events.OnGameStart.Add(function()
    for i = 0, getNumActivePlayers() - 1 do
        restorePlayer(getSpecificPlayer(i))
    end
end)

Events.OnCreatePlayer.Add(function(_, playerObj)
    restorePlayer(playerObj)
end)
