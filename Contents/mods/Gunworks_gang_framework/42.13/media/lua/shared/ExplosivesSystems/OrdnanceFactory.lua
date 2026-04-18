local OrdnanceFactory        = {}

--------------------------------------------------------------------
--- Default ordnance parameters – merged throw + explosive config
--------------------------------------------------------------------
OrdnanceFactory.Defaults     = {
    -- Throw / flight
    throwForce          = 8,    -- initial velocity multiplier (scales hSpeed)
    maxThrowDist        = 20,   -- max throw / launch distance in cells
    worldModel          = nil,  -- world item shown in flight (nil = use weapon fullType)
    forwardOffset       = 0.50, -- spawn origin offset from player facing
    heightOffset        = 0.55, -- spawn height offset
    floorBounces        = 0,    -- bounces before settling (0 = no bounce)
    bounceEnergy        = 0.45, -- energy retained per floor bounce
    throwSpeed          = 12,   -- flight speed in cells/sec (guided phase)
    arcFactor           = 0.12, -- arc height = distance * arcFactor
    maxArc              = 1.5,  -- maximum arc height in cells
    soundThrow          = nil,  -- sound on throw
    soundBounce         = nil,  -- sound on bounce
    detonateOnImpact    = false,
    detonationDelay     = 0,
    soundDetonate       = nil,
    parentItem          = nil, -- ammo only: item whose script stats are used for detonation
    explosionFXObject   = nil, -- item type to spawn as 3D FX (e.g. "MWA.nade_explosion")
    explosionFXDuration = 5,   -- ms the FX object remains visible before being removed
}

--------------------------------------------------------------------
--- Single registry: weaponFullType → merged params table
--------------------------------------------------------------------
OrdnanceFactory.Registry     = {}

--------------------------------------------------------------------
--- Ammo registry: bulletFullType → merged params table
--- Ammunition types registered here will be intercepted when fired
--- from a ranged weapon and spawned as ordnance projectiles instead
--- of vanilla bullets.
--------------------------------------------------------------------
OrdnanceFactory.AmmoRegistry = {}

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
    return p ~= nil and (p.detonateOnImpact == true or (p.detonationDelay or 0) > 0)
end

--------------------------------------------------------------------
--- Register an ammunition type as explosive ordnance.
--- When this bullet type is chambered and fired from a ranged weapon,
--- the framework intercepts the shot, suppresses the vanilla bullet,
--- and spawns an ordnance projectile using the existing physics engine.
---
---   OrdnanceFactory.RegisterAmmo("MyMod.40mm_HE", {
---       throwSpeed = 25, maxThrowDist = 40, arcFactor = 0.03,
---       explosionPower = 180, explosionRange = 4,
---       detonateOnImpact = true,
---       worldModel = "MyMod.40mm_Projectile",
---   })
--------------------------------------------------------------------
function OrdnanceFactory.RegisterAmmo(bulletFullType, overrides)
    if not bulletFullType then return end
    local params = mergeDefaults(OrdnanceFactory.Defaults, overrides)
    OrdnanceFactory.AmmoRegistry[bulletFullType] = params
end

--------------------------------------------------------------------
--- Ammo registry getters
--------------------------------------------------------------------
function OrdnanceFactory.GetAmmoParams(bulletFullType)
    return OrdnanceFactory.AmmoRegistry[bulletFullType]
end

function OrdnanceFactory.IsAmmoRegistered(bulletFullType)
    return OrdnanceFactory.AmmoRegistry[bulletFullType] ~= nil
end

function OrdnanceFactory.IsAmmoExplosive(bulletFullType)
    local p = OrdnanceFactory.AmmoRegistry[bulletFullType]
    return p ~= nil and (p.detonateOnImpact == true or (p.detonationDelay or 0) > 0)
end

return OrdnanceFactory
