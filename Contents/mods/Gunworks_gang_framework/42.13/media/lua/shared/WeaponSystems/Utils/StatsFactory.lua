local StatsFactory = {}
-------------------------------------------------
-- Stat Registry: maps stat name -> Java getter/setter method names
-- Used by the factory helpers below. Modders can extend this
-- to support custom weapon stats from other mods.
-------------------------------------------------
StatsFactory.StatRegistry = {
    AimingPerkCritModifier       = { get = "getAimingPerkCritModifier", set = "setAimingPerkCritModifier" },
    AimingPerkHitChanceModifier  = { get = "getAimingPerkHitChanceModifier", set = "setAimingPerkHitChanceModifier" },
    AimingPerkMinAngleModifier   = { get = "getAimingPerkMinAngleModifier", set = "setAimingPerkMinAngleModifier" },
    AimingPerkRangeModifier      = { get = "getAimingPerkRangeModifier", set = "setAimingPerkRangeModifier" },
    AimingTime                   = { get = "getAimingTime", set = "setAimingTime" },
    CritDmgMultiplier            = { get = "getCriticalDamageMultiplier", set = "setCriticalDamageMultiplier" },
    CriticalChance               = { get = "getCriticalChance", set = "setCriticalChance" },
    DoorDamage                   = { get = "getDoorDamage", set = "setDoorDamage" },
    HitChance                    = { get = "getHitChance", set = "setHitChance" },
    JamGunChance                 = { get = "getJamGunChance", set = "setJamGunChance" },
    MaxAmmo                      = { get = "getMaxAmmo", set = "setMaxAmmo" },
    MaxDamage                    = { get = "getMaxDamage", set = "setMaxDamage" },
    MaxHitCount                  = { get = "getMaxHitCount", set = "setMaxHitCount" },
    MaxRange                     = { get = "getMaxRange", set = "setMaxRange" },
    MaxSightRange                = { get = "getMaxSightRange", set = "setMaxSightRange" },
    MinDamage                    = { get = "getMinDamage", set = "setMinDamage" },
    MinRange                     = { get = "getMinRange", set = "setMinRange" },
    MinSightRange                = { get = "getMinSightRange", set = "setMinSightRange" },
    MuzzleFlashModelKey          = { get = "getMuzzleFlashModelKey", set = "setMuzzleFlashModelKey" },
    ProjectileCount              = { get = "getProjectileCount", set = "setProjectileCount" },
    ProjectileSpread             = { get = "getProjectileSpread", set = "setProjectileSpread" },
    ProjectileWeightCenter       = { get = "getProjectileWeightCenter", set = "setProjectileWeightCenter" },
    ReloadTime                   = { get = "getReloadTime", set = "setReloadTime" },
    SoundRadius                  = { get = "getSoundRadius", set = "setSoundRadius" },
    SoundVolume                  = { get = "getSoundVolume", set = "setSoundVolume" },
    ToHitModifier                = { get = "getToHitModifier", set = "setToHitModifier" },
    SwingTime                    = { get = "getSwingTime", set = "setSwingTime" },
    MinAngle                     = { get = "getMinAngle", set = "setMinAngle" },
    KnockdownMod                 = { get = "getKnockdownMod", set = "setKnockdownMod" },
    RecoilDelay                  = { get = "getRecoilDelay", set = "setRecoilDelay" },
    ConditionMax                 = { get = "getConditionMax", set = "setConditionMax" },
    SplatNumber                  = { get = "getSplatNumber", set = "setSplatNumber" },
    ConditionLowerChanceOneIn    = { get = "getConditionLowerChance", set = "setConditionLowerChance" },
    PushBackMod                  = { get = "getPushBackMod", set = "setPushBackMod" },
    MaxAngle                     = { get = "getMaxAngle", set = "setMaxAngle" },
    ClipSize                     = { get = "getClipSize", set = "setClipSize" },
    MinRangeRanged               = { get = "getMinRangeRanged", set = "setMinRangeRanged" },
    BaseSpeed                    = { get = "getBaseSpeed", set = "setBaseSpeed" },
    EnduranceMod                 = { get = "getEnduranceMod", set = "setEnduranceMod" },
    SoundGain                    = { get = "getSoundGain", set = "setSoundGain" },
    TreeDamage                   = { get = "getTreeDamage", set = "setTreeDamage" },

    RackAfterShot                = { get = "isRackAfterShoot", set = "setRackAfterShoot" },
    PiercingBullets              = { get = "isPiercingBullets", set = "setPiercingBullets" },
    AngleFalloff                 = { get = "isAngleFalloff", set = "setAngleFalloff" },
    RangeFalloff                 = { get = "isRangeFalloff", set = "setRangeFalloff" },
    KnockBackOnNoDeath           = { get = "isKnockBackOnNoDeath", set = "setKnockBackOnNoDeath" },
    SplatBloodOnNoDeath          = { get = "isSplatBloodOnNoDeath", set = "setSplatBloodOnNoDeath" },
    MultipleHitConditionAffected = { get = "isMultipleHitConditionAffected", set = "setMultipleHitConditionAffected" },
}

-------------------------------------------------
-- Weapon State Registry: operational state that is NOT a design-time
-- stat but needs saving / restoring during underbarrel swaps.
-- These are runtime values (ammo loaded, chamber, magazine clip).
-------------------------------------------------
StatsFactory.WeaponStateRegistry = {
    AmmoType              = { get = "getAmmoType", set = "setAmmoType" },
    MagazineType          = { get = "getMagazineType", set = "setMagazineType" },
    WeaponReloadType      = { get = "getWeaponReloadType", set = "setWeaponReloadType" },
    FireMode              = { get = "getFireMode", set = "setFireMode" },
    FireModePossibilities = { get = "getFireModePossibilities", set = "setFireModePossibilities" },
    RoundChambered        = { get = "isRoundChambered", set = "setRoundChambered" },
    ContainsClip          = { get = "isContainsClip", set = "setContainsClip" },
    CurrentAmmoCount      = { get = "getCurrentAmmoCount", set = "setCurrentAmmoCount" },
    SpentRoundChambered   = { get = "isSpentRoundChambered", set = "setSpentRoundChambered" },
    SpentRoundCount       = { get = "getSpentRoundCount", set = "setSpentRoundCount" },
    Jammed                = { get = "isJammed", set = "setJammed" },

    SwingSound            = { get = "getSwingSound", set = "setSwingSound" },
    ClickSound            = { get = "getClickSound", set = "setClickSound" },
    RackSound             = { get = "getRackSound", set = "setRackSound" },
    BreakSound            = { get = "getBreakSound", set = "setBreakSound" },
    ShellFallSound        = { get = "getShellFallSound", set = "setShellFallSound" },
    ImpactSound           = { get = "getImpactSound", set = "setImpactSound" },
    DoorHitSound          = { get = "getDoorHitSound", set = "setDoorHitSound" },
    HitFloorSound         = { get = "getHitFloorSound", set = "setHitFloorSound" },
    BulletOutSound        = { get = "getBulletOutSound", set = "setBulletOutSound" },
}

-------------------------------------------------
-- Snapshot / Apply helpers for underbarrel-style full stat swaps
-------------------------------------------------

--- Capture every stat in StatRegistry from a weapon into a plain Lua table.
--- The table is safe to store in modData for save/load persistence.
---@param weapon userdata  the weapon to read from
---@return table snapshot  { StatName = value, ... }
function StatsFactory.SnapshotStats(weapon)
    local snap = {}
    for name, reg in pairs(StatsFactory.StatRegistry) do
        snap[name] = weapon[reg.get](weapon)
    end
    return snap
end

--- Write every value from a snapshot back onto a weapon.
---@param weapon userdata  the weapon to write to
---@param snapshot table   table produced by SnapshotStats
function StatsFactory.ApplySnapshot(weapon, snapshot)
    for name, value in pairs(snapshot) do
        local reg = StatsFactory.StatRegistry[name]
        if reg then
            weapon[reg.set](weapon, value)
        end
    end
end

--- Capture operational state (chamber, clip, ammo count) into a plain table.
---@param weapon userdata
---@return table state  { RoundChambered = bool, ContainsClip = bool, CurrentAmmoCount = int }
function StatsFactory.SnapshotState(weapon)
    local state = {}
    for name, reg in pairs(StatsFactory.WeaponStateRegistry) do
        state[name] = weapon[reg.get](weapon)
    end
    return state
end

--- Restore operational state onto a weapon.
---@param weapon userdata
---@param state table  table produced by SnapshotState
function StatsFactory.ApplyState(weapon, state)
    for name, value in pairs(state) do
        local reg = StatsFactory.WeaponStateRegistry[name]
        if reg then
            weapon[reg.set](weapon, value)
        end
    end
end

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
