local StatsFactory = {}

local function patchTable(value)
    if type(value) == "table" then
        local arrayList = ArrayList.new()
        for _, fireMode in ipairs(value) do
            arrayList:add(fireMode)
        end
        return arrayList
    end

    return value
end

-------------------------------------------------
-- Unified Registry: getter/setter lookup for all weapon properties.
-- Systems dynamically declare which stats they need via restore sets.
-- Modders can extend this table to support custom weapon stats.
-------------------------------------------------
StatsFactory.Registry = {
    AimingPerkCritModifier       = { get = "getAimingPerkCritModifier", set = "setAimingPerkCritModifier" },
    AimingPerkHitChanceModifier  = { get = "getAimingPerkHitChanceModifier", set = "setAimingPerkHitChanceModifier" },
    AimingPerkMinAngleModifier   = { get = "getAimingPerkMinAngleModifier", set = "setAimingPerkMinAngleModifier" },
    AimingPerkRangeModifier      = { get = "getAimingPerkRangeModifier", set = "setAimingPerkRangeModifier" },
    AimingTime                   = { get = "getAimingTime", set = "setAimingTime" },
    Condition                    = { get = "getCondition", set = "setCondition" },
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
    UseEndurance                 = { get = "isUseEndurance", set = "setUseEndurance" },
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
    WeaponSprite                 = { get = "getWeaponSprite", set = "setWeaponSprite" },

    AmmoType                     = { get = "getAmmoType", set = "setAmmoType" },
    MagazineType                 = { get = "getMagazineType", set = "setMagazineType" },
    WeaponReloadType             = { get = "getWeaponReloadType", set = "setWeaponReloadType" },
    FireMode                     = { get = "getFireMode", set = "setFireMode" },
    FireModePossibilities        = { get = "getFireModePossibilities", set = "setFireModePossibilities" },
    HaveChamber                  = { get = "haveChamber", set = "setHaveChamber" },
    RoundChambered               = { get = "isRoundChambered", set = "setRoundChambered" },
    ContainsClip                 = { get = "isContainsClip", set = "setContainsClip" },
    CurrentAmmoCount             = { get = "getCurrentAmmoCount", set = "setCurrentAmmoCount" },
    SpentRoundChambered          = { get = "isSpentRoundChambered", set = "setSpentRoundChambered" },
    SpentRoundCount              = { get = "getSpentRoundCount", set = "setSpentRoundCount" },
    Jammed                       = { get = "isJammed", set = "setJammed" },

    SwingSound                   = { get = "getSwingSound", set = "setSwingSound" },
    ClickSound                   = { get = "getClickSound", set = "setClickSound" },
    RackSound                    = { get = "getRackSound", set = "setRackSound" },
    BreakSound                   = { get = "getBreakSound", set = "setBreakSound" },
    ShellFallSound               = { get = "getShellFallSound", set = "setShellFallSound" },
    ImpactSound                  = { get = "getImpactSound", set = "setImpactSound" },
    DoorHitSound                 = { get = "getDoorHitSound", set = "setDoorHitSound" },
    HitFloorSound                = { get = "getHitFloorSound", set = "setHitFloorSound" },
    BulletOutSound               = { get = "getBulletOutSound", set = "setBulletOutSound" },

}

-------------------------------------------------
-- Snapshot / Apply
-------------------------------------------------

--- Capture stat values from a weapon.
--- Pass an array of stat names to snapshot only those, or nil for all.
--- The snapshot stores a _keys array so Apply knows which stats to set,
--- even when some values are nil (Lua tables drop nil entries).
---@param weapon userdata
---@param statNames string[]|nil
---@return table snapshot
function StatsFactory.Snapshot(weapon, statNames)
    local snap = {}
    local keys = {}
    if statNames then
        for _, name in ipairs(statNames) do
            local reg = StatsFactory.Registry[name]
            if reg then
                keys[#keys + 1] = name
                snap[name] = weapon[reg.get](weapon)
            end
        end
    else
        for name, reg in pairs(StatsFactory.Registry) do
            keys[#keys + 1] = name
            snap[name] = weapon[reg.get](weapon)
        end
    end
    snap._keys = keys
    return snap
end

--- Apply snapshot values onto a weapon.
---@param weapon userdata
---@param snapshot table
function StatsFactory.Apply(weapon, snapshot)
    local keys = snapshot._keys
    if keys then
        for _, name in ipairs(keys) do
            local reg = StatsFactory.Registry[name]
            if reg then
                weapon[reg.set](weapon, snapshot[name])
            end
        end
    else
        for name, value in pairs(snapshot) do
            local reg = StatsFactory.Registry[name]
            if reg then
                weapon[reg.set](weapon, value)
            end
        end
    end
end

-------------------------------------------------
-- Modifier helpers
-------------------------------------------------

--- Additive modifier: current + offset
function StatsFactory.Adjust(statName, offset)
    local reg = StatsFactory.Registry[statName]
    return function(weapon, base)
        weapon[reg.set](weapon, weapon[reg.get](weapon) + offset)
    end
end

--- Absolute setter: sets exact value
function StatsFactory.Set(statName, value)
    local reg = StatsFactory.Registry[statName]
    return function(weapon, base)
        weapon[reg.set](weapon, patchTable(value))
    end
end

--- Multiplicative modifier: current * factor
function StatsFactory.Multiply(statName, factor)
    local reg = StatsFactory.Registry[statName]
    return function(weapon, base)
        weapon[reg.set](weapon, weapon[reg.get](weapon) * factor)
    end
end

--- Apply an array of modifier functions to a weapon
function StatsFactory.ApplyModifiers(weapon, baseStats, modifiers)
    for _, modifier in ipairs(modifiers) do
        modifier(weapon, baseStats)
    end
end

--- Restore specific stats back to their shadow-copy base values.
---@param weapon userdata
---@param baseStats userdata  shadow copy from GetBaseStatsWithAttachments
---@param statSet table  { StatName = true, ... } set of stat names to restore
function StatsFactory.RestoreStats(weapon, baseStats, statSet)
    for name in pairs(statSet) do
        local reg = StatsFactory.Registry[name]
        if reg then
            weapon[reg.set](weapon, baseStats[reg.get](baseStats))
        end
    end
end

-------------------------------------------------
-- Modifier Layer System
-- Each subsystem (ammo, bipod, etc.) registers a layer along with
-- a restoreStats set declaring which stats it may modify.
-- ReapplyAllModifiers only restores stats from active layers.
-------------------------------------------------
StatsFactory.ModifierLayers = {}
StatsFactory.RestoreHandlers = {}

--- Register a handler that runs after ReapplyAllModifiers has restored base stats
--- and re-applied every active modifier layer.
---@param id string
---@param handler fun(weapon:userdata)
function StatsFactory.RegisterRestoreHandler(id, handler)
    if not id or type(handler) ~= "function" then return end

    for i = 1, #StatsFactory.RestoreHandlers do
        local entry = StatsFactory.RestoreHandlers[i]
        if entry.id == id then
            entry.handler = handler
            return
        end
    end

    StatsFactory.RestoreHandlers[#StatsFactory.RestoreHandlers + 1] = {
        id = id,
        handler = handler,
    }
end

function StatsFactory.RunRestoreHandlers(weapon)
    for i = 1, #StatsFactory.RestoreHandlers do
        StatsFactory.RestoreHandlers[i].handler(weapon)
    end
end

--- Register a modifier layer.
--- restoreStats: { StatName = true, ... } set of stats this layer may modify.
--- These stats are restored to base before reapplying modifiers.
---@param id string                           unique layer name
---@param getModifiersFn fun(weapon):table|nil  returns modifier array or nil if inactive
---@param restoreStats table|nil  { StatName = true, ... }
function StatsFactory.RegisterModifierLayer(id, getModifiersFn, restoreStats)
    StatsFactory.ModifierLayers[#StatsFactory.ModifierLayers + 1] = {
        id = id,
        getModifiers = getModifiersFn,
        restoreStats = restoreStats or {},
    }
end

--- Restore base stats then apply every active modifier layer in order.
--- Stats declared in any registered layer's restoreStats are restored first,
--- so toggled-off layers correctly roll back to base values.
---@param weapon userdata  the live weapon instance
function StatsFactory.ReapplyAllModifiers(weapon)
    local baseStats = StatsFactory.GetBaseStatsWithAttachments(weapon)

    local toRestore = {}
    local activeLayers = {}
    for _, layer in ipairs(StatsFactory.ModifierLayers) do
        for name in pairs(layer.restoreStats) do
            toRestore[name] = true
        end

        local modifiers = layer.getModifiers(weapon)
        if modifiers then
            activeLayers[#activeLayers + 1] = modifiers
        end
    end

    StatsFactory.RestoreStats(weapon, baseStats, toRestore)

    for _, modifiers in ipairs(activeLayers) do
        StatsFactory.ApplyModifiers(weapon, baseStats, modifiers)
    end

    StatsFactory.RunRestoreHandlers(weapon)
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
