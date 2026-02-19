local StatsFactory = {}
-------------------------------------------------
-- Stat Registry: maps stat name -> Java getter/setter method names
-- Used by the factory helpers below. Modders can extend this
-- to support custom weapon stats from other mods.
-------------------------------------------------
StatsFactory.StatRegistry = {
    MinDamage                   = { get = "getMinDamage", set = "setMinDamage" },
    MaxDamage                   = { get = "getMaxDamage", set = "setMaxDamage" },
    MinRange                    = { get = "getMinRange", set = "setMinRange" },
    MaxRange                    = { get = "getMaxRange", set = "setMaxRange" },
    MinSightRange               = { get = "getMinSightRange", set = "setMinSightRange" },
    MaxSightRange               = { get = "getMaxSightRange", set = "setMaxSightRange" },
    MaxHitCount                 = { get = "getMaxHitCount", set = "setMaxHitCount" },
    MaxAmmo                     = { get = "getMaxAmmo", set = "setMaxAmmo" },
    DoorDamage                  = { get = "getDoorDamage", set = "setDoorDamage" },
    SoundRadius                 = { get = "getSoundRadius", set = "setSoundRadius" },
    ToHitModifier               = { get = "getToHitModifier", set = "setToHitModifier" },
    CriticalChance              = { get = "getCriticalChance", set = "setCriticalChance" },
    CritDmgMultiplier           = { get = "getCriticalDamageMultiplier", set = "setCriticalDamageMultiplier" },
    AimingPerkCritModifier      = { get = "getAimingPerkCritModifier", set = "setAimingPerkCritModifier" },
    AimingPerkRangeModifier     = { get = "getAimingPerkRangeModifier", set = "setAimingPerkRangeModifier" },
    AimingPerkHitChanceModifier = { get = "getAimingPerkHitChanceModifier", set = "setAimingPerkHitChanceModifier" },
    AimingPerkMinAngleModifier  = { get = "getAimingPerkMinAngleModifier", set = "setAimingPerkMinAngleModifier" },
    HitChance                   = { get = "getHitChance", set = "setHitChance" },
    ReloadTime                  = { get = "getReloadTime", set = "setReloadTime" },
    AimingTime                  = { get = "getAimingTime", set = "setAimingTime" },
    JamGunChance                = { get = "getJamGunChance", set = "setJamGunChance" },
    ProjectileCount             = { get = "getProjectileCount", set = "setProjectileCount" },
    ProjectileSpread            = { get = "getProjectileSpread", set = "setProjectileSpread" },
    ProjectileWeightCenter      = { get = "getProjectileWeightCenter", set = "setProjectileWeightCenter" },
    SoundVolume                 = { get = "getSoundVolume", set = "setSoundVolume" },
    PiercingBullets             = { get = "isPiercingBullets", set = "setPiercingBullets" },
    RackAfterShot               = { get = "isRackAfterShoot", set = "setRackAfterShoot" },
}

-------------------------------------------------
-- StatsFactory helpers: return modifier functions (weapon, baseStats) -> void
-------------------------------------------------

--- Additive modifier: base + offset
--- @param statName string  key in StatRegistry, e.g. "MaxDamage"
--- @param offset number    e.g. -0.5
function StatsFactory.Adjust(statName, offset)
    local reg = StatsFactory.StatRegistry[statName]
    return function(weapon, base)
        weapon[reg.set](weapon, base[reg.get](base) + offset)
    end
end

--- Absolute setter: ignores base, sets exact value
--- @param statName string  key in StatRegistry
--- @param value any        the value to set
function StatsFactory.Set(statName, value)
    local reg = StatsFactory.StatRegistry[statName]
    return function(weapon, base)
        weapon[reg.set](weapon, value)
    end
end

--- Multiplicative modifier: base * factor
--- @param statName string  key in StatRegistry
--- @param factor number    e.g. 0.8
function StatsFactory.Multiply(statName, factor)
    local reg = StatsFactory.StatRegistry[statName]
    return function(weapon, base)
        weapon[reg.set](weapon, base[reg.get](base) * factor)
    end
end

--- Apply an array of modifier functions to a weapon
--- @param weapon userdata  the weapon instance to modify
--- @param baseStats userdata  the base stats from instanceItem()
--- @param modifiers table  array of function(weapon, base)
function StatsFactory.ApplyModifiers(weapon, baseStats, modifiers)
    for _, modifier in ipairs(modifiers) do
        modifier(weapon, baseStats)
    end
end

--- Restore all stats in the registry back to base values
--- @param weapon userdata  the weapon instance to restore
--- @param baseStats userdata  the base stats from instanceItem()
function StatsFactory.RestoreBaseStats(weapon, baseStats)
    for _, reg in pairs(StatsFactory.StatRegistry) do
        weapon[reg.set](weapon, baseStats[reg.get](baseStats))
    end
end

return StatsFactory
