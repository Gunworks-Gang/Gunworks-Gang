local ExplosivesSystems = {}

--------------------------------------------------------------------
--- Module identifier for client/server commands
--------------------------------------------------------------------
ExplosivesSystems.MODULE_NAME = "GWG_Explosives"

--------------------------------------------------------------------
--- Registry: weaponFullType → config
--------------------------------------------------------------------
ExplosivesSystems.Registry = {}

--------------------------------------------------------------------
--- Landing callbacks: list of fn(projectile, square, config)
--------------------------------------------------------------------
ExplosivesSystems.LandingCallbacks = {}

--------------------------------------------------------------------
--- Default configuration — merged with per-weapon overrides
--------------------------------------------------------------------
ExplosivesSystems.Defaults = {
    Speed             = 12,  -- cells per second flight speed
    ArcHeightFactor   = 0.1, -- arc multiplier (higher = taller arc)
    MaxRange          = 20,  -- max throw / launch range in cells
    ProjectileItem    = nil, -- world item shown in flight (nil = use weapon fullType)
    FuseDelay         = 0,   -- ticks after landing before detonation (0 = instant)

    -- Explosion params (forwarded to IsoTrap)
    ExplosionPower    = 50,
    ExplosionRange    = 5,
    FireRange         = 0,
    FirePower         = 0,
    SmokeRange        = 0,
    NoiseRange        = 30,
    NoiseGlobal       = false,

    -- Sounds
    SoundLaunch       = "PipeBombThrow",
    SoundImpact       = "PipeBombExplode",

    -- Flags
    IsExplosive       = true, -- triggers IsoTrap on landing
    RemoveOnLand      = true, -- remove projectile visual on impact
    Bounces           = 0,    -- floor bounces before detonation (0 = explode on contact)
    BounceRestitution = 0.45, -- energy kept per bounce

    -- Launch origin offsets (relative to player facing)
    ForwardOffset     = 0.50,
    HeightOffset      = 0.55,
}

--------------------------------------------------------------------
--- Register a weapon / throwable into the trajectory system
--------------------------------------------------------------------
function ExplosivesSystems.Register(fullType, config)
    if not fullType then return end
    config = config or {}
    ExplosivesSystems.Registry[fullType] = config
end

--------------------------------------------------------------------
--- Unregister
--------------------------------------------------------------------
function ExplosivesSystems.Unregister(fullType)
    if not fullType then return end
    ExplosivesSystems.Registry[fullType] = nil
end

--------------------------------------------------------------------
--- Get merged config for weapon (registry values override defaults)
--------------------------------------------------------------------
function ExplosivesSystems.GetConfig(fullType)
    local overrides = ExplosivesSystems.Registry[fullType]
    if not overrides then return nil end

    local merged = {}
    for k, v in pairs(ExplosivesSystems.Defaults) do
        merged[k] = v
    end
    for k, v in pairs(overrides) do
        merged[k] = v
    end
    merged._weaponFullType = fullType
    return merged
end

--------------------------------------------------------------------
--- Check if a weapon fullType is registered
--------------------------------------------------------------------
function ExplosivesSystems.IsRegistered(fullType)
    return ExplosivesSystems.Registry[fullType] ~= nil
end

--------------------------------------------------------------------
--- Landing callbacks
--------------------------------------------------------------------
function ExplosivesSystems.AddLandingCallback(fn)
    if type(fn) ~= "function" then return end
    ExplosivesSystems.LandingCallbacks[#ExplosivesSystems.LandingCallbacks + 1] = fn
end

function ExplosivesSystems.RemoveLandingCallback(fn)
    for i = #ExplosivesSystems.LandingCallbacks, 1, -1 do
        if ExplosivesSystems.LandingCallbacks[i] == fn then
            table.remove(ExplosivesSystems.LandingCallbacks, i)
            return
        end
    end
end

return ExplosivesSystems
