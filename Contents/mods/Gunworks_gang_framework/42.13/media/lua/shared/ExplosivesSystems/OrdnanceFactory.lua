local OrdnanceFactory          = {}

--------------------------------------------------------------------
--- Default ordnance parameters – merged throw + explosive config
--------------------------------------------------------------------
OrdnanceFactory.Defaults       = {
    -- Throw / flight
    throwForce       = 8,    -- initial velocity multiplier (scales hSpeed)
    maxThrowDist     = 20,   -- max throw / launch distance in cells
    worldModel       = nil,  -- world item shown in flight (nil = use weapon fullType)
    forwardOffset    = 0.50, -- spawn origin offset from player facing
    heightOffset     = 0.55, -- spawn height offset
    floorBounces     = 0,    -- bounces before settling (0 = no bounce)
    bounceEnergy     = 0.45, -- energy retained per floor bounce
    throwSpeed       = 12,   -- flight speed in cells/sec (guided phase)
    arcFactor        = 0.12, -- arc height = distance * arcFactor
    maxArc           = 1.5,  -- maximum arc height in cells
    soundThrow       = nil,  -- sound on throw
    soundBounce      = nil,  -- sound on bounce

    -- Explosive (nil / 0 values = non-explosive throwable)
    explosionPower   = 0,
    explosionRange   = 0,
    fireRange        = 0,
    firePower        = 0,
    smokeRange       = 0,
    noiseRange       = 0,
    detonateOnImpact = false,
    detonationDelay  = 0,
    soundDetonate    = nil,
}

--------------------------------------------------------------------
--- Explosive stat mapping: param key → HandWeapon setter
--- (same pattern as WeaponSystems StatsFactory.Registry)
--------------------------------------------------------------------
OrdnanceFactory.ExplosiveStats = {
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
function OrdnanceFactory.ApplyExplosiveParams(weaponItem, params)
    if not weaponItem or not params then return end
    for key, setter in pairs(OrdnanceFactory.ExplosiveStats) do
        local value = params[key]
        if value ~= nil and weaponItem[setter] then
            weaponItem[setter](weaponItem, value)
        end
    end
end

--------------------------------------------------------------------
--- Single registry: weaponFullType → merged params table
--------------------------------------------------------------------
OrdnanceFactory.Registry = {}

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
--- Register a throwable / explosive item.
--- Pass a single table with any overrides; unspecified keys use defaults.
---
---   OrdnanceFactory.Register("MyMod.Grenade", {
---       throwForce = 10, maxThrowDist = 25, floorBounces = 3,
---       explosionPower = 80, explosionRange = 5,
---       detonateOnImpact = true,
---   })
---
---   OrdnanceFactory.Register("MyMod.Rock", {
---       throwForce = 12, floorBounces = 4,
---   })
--------------------------------------------------------------------
function OrdnanceFactory.Register(fullType, overrides)
    if not fullType then return end
    local params = mergeDefaults(OrdnanceFactory.Defaults, overrides)
    params._sourceWeapon = fullType
    OrdnanceFactory.Registry[fullType] = params
end

--------------------------------------------------------------------
--- Getters
--------------------------------------------------------------------
function OrdnanceFactory.GetParams(fullType)
    return OrdnanceFactory.Registry[fullType]
end

--------------------------------------------------------------------
--- Checks
--------------------------------------------------------------------
function OrdnanceFactory.IsRegistered(fullType)
    return OrdnanceFactory.Registry[fullType] ~= nil
end

function OrdnanceFactory.IsExplosive(fullType)
    local p = OrdnanceFactory.Registry[fullType]
    return p ~= nil and (p.explosionPower or 0) > 0
end

return OrdnanceFactory
