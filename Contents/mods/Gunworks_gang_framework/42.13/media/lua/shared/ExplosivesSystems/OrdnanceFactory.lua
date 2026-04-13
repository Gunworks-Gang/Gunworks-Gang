local OrdnanceFactory                  = {}

--------------------------------------------------------------------
--- Default throwing parameters – how the item travels through air
--------------------------------------------------------------------
OrdnanceFactory.DefaultThrowParams     = {
    throwForce    = 8,    -- cells per second flight velocity
    lobHeight     = 0,    -- arc steepness multiplier (higher = taller lob)
    maxThrowDist  = 20,   -- max throw / launch distance in cells
    worldModel    = nil,  -- world item shown in flight (nil = use weapon fullType)
    forwardOffset = 0.50, -- spawn origin offset from player facing
    heightOffset  = 0.55, -- spawn height offset
    floorBounces  = 0,    -- bounces before settling (0 = no bounce)
    bounceEnergy  = 0.45, -- energy retained per bounce
}

--------------------------------------------------------------------
--- Default explosive parameters – detonation behavior.
--- Only applied if the item is registered with explosive overrides.
--------------------------------------------------------------------
OrdnanceFactory.DefaultExplosiveParams = {
    explosionPower   = 50,
    explosionRange   = 5,
    fireRange        = 0,
    firePower        = 0,
    smokeRange       = 0,
    noiseRange       = 30,
    detonateOnImpact = true, -- true = detonate on ground contact; false = wait for detonationDelay
    detonationDelay  = 0,    -- ticks after settling before detonation (used when detonateOnImpact = false)
}

--------------------------------------------------------------------
--- Explosive stat mapping: explosiveParam key → HandWeapon setter
--- (same pattern as WeaponSystems StatsFactory.Registry)
--------------------------------------------------------------------
OrdnanceFactory.ExplosiveStats         = {
    explosionPower = "setExplosionPower",
    explosionRange = "setExplosionRange",
    fireRange      = "setFireRange",
    firePower      = "setFireStartingEnergy",
    smokeRange     = "setSmokeRange",
    noiseRange     = "setNoiseRange",
}

--------------------------------------------------------------------
--- Apply explosive params onto a HandWeapon item via the registry.
--------------------------------------------------------------------
function OrdnanceFactory.ApplyExplosiveParams(weaponItem, explosiveParams)
    if not weaponItem or not explosiveParams then return end
    for key, setter in pairs(OrdnanceFactory.ExplosiveStats) do
        local value = explosiveParams[key]
        if value ~= nil and weaponItem[setter] then
            weaponItem[setter](weaponItem, value)
        end
    end
end

--------------------------------------------------------------------
--- Registries: weaponFullType → params table
--------------------------------------------------------------------
OrdnanceFactory.ThrowRegistry     = {}
OrdnanceFactory.ExplosiveRegistry = {}

--------------------------------------------------------------------
--- Internal: merge a defaults table with an overrides table
--------------------------------------------------------------------
local function mergeDefaults(defaults, overrides)
    local result = {}
    for k, v in pairs(defaults) do result[k] = v end
    if overrides then
        for k, v in pairs(overrides) do result[k] = v end
    end
    return result
end

--------------------------------------------------------------------
--- Register a throwable item.
--- Pass explosiveOverrides to give the item an explosive component.
--- Omit it (or pass nil) for throw-only items.
---
---   OrdnanceFactory.Register("MyMod.Grenade",
---       { throwForce = 10, lobHeight = 0.4 },
---       { explosionPower = 80, detonateOnImpact = true }
---   )
---
---   OrdnanceFactory.Register("MyMod.Rock",
---       { throwForce = 12 }
---   )
--------------------------------------------------------------------
function OrdnanceFactory.Register(fullType, throwOverrides, explosiveOverrides)
    if not fullType then return end

    local throwParams = mergeDefaults(OrdnanceFactory.DefaultThrowParams, throwOverrides)
    throwParams._sourceWeapon = fullType
    OrdnanceFactory.ThrowRegistry[fullType] = throwParams

    if explosiveOverrides then
        local expParams = mergeDefaults(OrdnanceFactory.DefaultExplosiveParams, explosiveOverrides)
        OrdnanceFactory.ExplosiveRegistry[fullType] = expParams
    else
        OrdnanceFactory.ExplosiveRegistry[fullType] = nil
    end
end

--------------------------------------------------------------------
--- Getters
--------------------------------------------------------------------
function OrdnanceFactory.GetThrowParams(fullType)
    return OrdnanceFactory.ThrowRegistry[fullType]
end

function OrdnanceFactory.GetExplosiveParams(fullType)
    return OrdnanceFactory.ExplosiveRegistry[fullType]
end

--------------------------------------------------------------------
--- Checks
--------------------------------------------------------------------
function OrdnanceFactory.IsRegistered(fullType)
    return OrdnanceFactory.ThrowRegistry[fullType] ~= nil
end

function OrdnanceFactory.IsExplosive(fullType)
    return OrdnanceFactory.ExplosiveRegistry[fullType] ~= nil
end

return OrdnanceFactory
