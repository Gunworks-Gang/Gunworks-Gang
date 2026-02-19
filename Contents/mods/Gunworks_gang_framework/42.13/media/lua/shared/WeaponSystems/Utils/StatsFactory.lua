local StatsFactory = {}
-------------------------------------------------
-- Stat Registry: maps stat name -> Java getter/setter method names
-- Used by the factory helpers below. Modders can extend this
-- to support custom weapon stats from other mods.
-------------------------------------------------
StatsFactory.StatRegistry = {
    AimingPerkCritModifier      = { get = "getAimingPerkCritModifier", set = "setAimingPerkCritModifier" },
    AimingPerkHitChanceModifier = { get = "getAimingPerkHitChanceModifier", set = "setAimingPerkHitChanceModifier" },
    AimingPerkMinAngleModifier  = { get = "getAimingPerkMinAngleModifier", set = "setAimingPerkMinAngleModifier" },
    AimingPerkRangeModifier     = { get = "getAimingPerkRangeModifier", set = "setAimingPerkRangeModifier" },
    Aimingtime                  = { get = "getAimingTime", set = "setAimingTime" },
    CriticalChance              = { get = "getCriticalChance", set = "setCriticalChance" },
    DoorDamage                  = { get = "getDoorDamage", set = "setDoorDamage" },
    HitChance                   = { get = "getHitChance", set = "setHitChance" },
    MaxDamage                   = { get = "getMaxDamage", set = "setMaxDamage" },
    MinDamage                   = { get = "getMinDamage", set = "setMinDamage" },
    PiercingBullets             = { get = "isPiercingBullets", set = "setPiercingBullets" },
    MaxHitCount                 = { get = "getMaxHitCount", set = "setMaxHitCount" },
    ProjectileCount             = { get = "getProjectileCount", set = "setProjectileCount" },
    SoundRadius                 = { get = "getSoundRadius", set = "setSoundRadius" },
    SoundVolume                 = { get = "getSoundVolume", set = "setSoundVolume" },
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

return StatsFactory
