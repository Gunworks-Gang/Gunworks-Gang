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
    AimingTime                  = { get = "getAimingTime", set = "setAimingTime" },
    Condition                   = { get = "getCondition", set = "setCondition" },
    CritDmgMultiplier           = { get = "getCriticalDamageMultiplier", set = "setCriticalDamageMultiplier" },
    CriticalChance              = { get = "getCriticalChance", set = "setCriticalChance" },
    DoorDamage                  = { get = "getDoorDamage", set = "setDoorDamage" },
    HitChance                   = { get = "getHitChance", set = "setHitChance" },
    JamGunChance                = { get = "getJamGunChance", set = "setJamGunChance" },
    MaxAmmo                     = { get = "getMaxAmmo", set = "setMaxAmmo" },
    MaxDamage                   = { get = "getMaxDamage", set = "setMaxDamage" },
    MaxHitCount                 = { get = "getMaxHitCount", set = "setMaxHitCount" },
    MaxRange                    = { get = "getMaxRange", set = "setMaxRange" },
    MaxSightRange               = { get = "getMaxSightRange", set = "setMaxSightRange" },
    MinDamage                   = { get = "getMinDamage", set = "setMinDamage" },
    MinRange                    = { get = "getMinRange", set = "setMinRange" },
    MinSightRange               = { get = "getMinSightRange", set = "setMinSightRange" },
    MuzzleFlashModelKey         = { get = "getMuzzleFlashModelKey", set = "setMuzzleFlashModelKey" },
    PiercingBullets             = { get = "isPiercingBullets", set = "setPiercingBullets" },
    ProjectileCount             = { get = "getProjectileCount", set = "setProjectileCount" },
    ProjectileSpread            = { get = "getProjectileSpread", set = "setProjectileSpread" },
    ProjectileWeightCenter      = { get = "getProjectileWeightCenter", set = "setProjectileWeightCenter" },
    RackAfterShot               = { get = "isRackAfterShoot", set = "setRackAfterShoot" },
    ReloadTime                  = { get = "getReloadTime", set = "setReloadTime" },
    SoundRadius                 = { get = "getSoundRadius", set = "setSoundRadius" },
    SoundVolume                 = { get = "getSoundVolume", set = "setSoundVolume" },
    ToHitModifier               = { get = "getToHitModifier", set = "setToHitModifier" },
}

-------------------------------------------------
-- StatsFactory helpers: return modifier functions (weapon, baseStats) -> void
-------------------------------------------------

--- Additive modifier: current + offset (stacks across layers)
--- @param statName string  key in StatRegistry, e.g. "MaxDamage"
--- @param offset number    e.g. -0.5
function StatsFactory.Adjust(statName, offset)
    local reg = StatsFactory.StatRegistry[statName]
    return function(weapon, base)
        weapon[reg.set](weapon, weapon[reg.get](weapon) + offset)
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

--- Multiplicative modifier: current * factor (stacks across layers)
--- @param statName string  key in StatRegistry
--- @param factor number    e.g. 0.8
function StatsFactory.Multiply(statName, factor)
    local reg = StatsFactory.StatRegistry[statName]
    return function(weapon, base)
        weapon[reg.set](weapon, weapon[reg.get](weapon) * factor)
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

-------------------------------------------------
-- Modifier Layer System
-- Each subsystem (stock, bipod, ammo, etc.) registers a layer.
-- ReapplyAllModifiers restores base once and applies all active layers.
-------------------------------------------------
StatsFactory.ModifierLayers = {}

--- Register a modifier layer. Layers are applied in registration order.
---@param id string                           unique layer name
---@param getModifiersFn fun(weapon):table|nil  returns modifier array or nil if inactive
function StatsFactory.RegisterModifierLayer(id, getModifiersFn)
    StatsFactory.ModifierLayers[#StatsFactory.ModifierLayers + 1] = {
        id = id,
        getModifiers = getModifiersFn,
    }
end

--- Restore base stats then apply every active modifier layer in order.
---@param weapon userdata  the live weapon instance
function StatsFactory.ReapplyAllModifiers(weapon)
    local baseStats = StatsFactory.GetBaseStatsWithAttachments(weapon)
    StatsFactory.RestoreBaseStats(weapon, baseStats)

    for _, layer in ipairs(StatsFactory.ModifierLayers) do
        local modifiers = layer.getModifiers(weapon)
        if modifiers then
            StatsFactory.ApplyModifiers(weapon, baseStats, modifiers)
        end
    end
end

-------------------------------------------------
-- Shadow copy helper
-------------------------------------------------

--- Create a shadow copy of a weapon with its attachments applied.
--- This gives you the true "base" stats that account for scopes, stocks, etc.
--- @param weapon userdata  the live weapon instance
--- @return userdata  shadow item with all current parts attached
function StatsFactory.GetBaseStatsWithAttachments(weapon)
    local shadow = instanceItem(weapon:getFullType())
    local parts  = weapon:getAllWeaponParts()
    if parts then
        for i = 0, parts:size() - 1 do
            local part = parts:get(i)
            if part then
                local partCopy = instanceItem(part:getFullType())
                if partCopy and instanceof(partCopy, "WeaponPart") then
                    if shadow.canAttachWeaponPart == nil or shadow:canAttachWeaponPart(partCopy) then
                        shadow:attachWeaponPart(partCopy)
                    end
                end
            end
        end
    end
    return shadow
end

return StatsFactory
