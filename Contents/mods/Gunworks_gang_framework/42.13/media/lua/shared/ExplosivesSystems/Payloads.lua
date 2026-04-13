local ExplosivesSystems = require("ExplosivesSystems/Init")

local Payloads = {}

--------------------------------------------------------------------
--- Create a temporary HandWeapon configured with explosion params,
--- build an IsoTrap from it, and detonate immediately.
--------------------------------------------------------------------
function Payloads.TriggerExplosion(square, config, shooter)
    if not square then return end
    if not config then return end

    local weaponItem = nil

    -- If the config references a real item type, create it so IsoTrap
    -- inherits its script-defined sprite, sounds, etc.
    local itemType = config.ProjectileItem or config._weaponFullType
    if itemType then
        weaponItem = instanceItem(itemType)
    end

    -- Fallback: create a pipe bomb as a generic explosive carrier
    if not weaponItem or not instanceof(weaponItem, "HandWeapon") then
        weaponItem = instanceItem("Base.PipeBomb")
    end

    if not weaponItem then return end

    -- Override explosion properties from config
    if config.ExplosionPower then
        weaponItem:setExplosionPower(config.ExplosionPower)
    end
    if config.ExplosionRange then
        weaponItem:setExplosionRange(config.ExplosionRange)
    end
    if config.FireRange then
        weaponItem:setFireRange(config.FireRange)
    end
    if config.FirePower then
        weaponItem:setFireStartingEnergy(config.FirePower)
    end
    if config.SmokeRange then
        weaponItem:setSmokeRange(config.SmokeRange)
    end
    if config.NoiseRange then
        weaponItem:setNoiseRange(config.NoiseRange)
    end
    if config.SoundImpact then
        weaponItem:setExplosionSound(config.SoundImpact)
    end

    -- Timer = 0 so it triggers immediately when place() is called
    weaponItem:setExplosionTimer(0)

    -- Create and trigger the trap
    local cell = square:getCell()
    local trap = IsoTrap.new(shooter, weaponItem, cell, square)
    trap:setInstantExplosion(true)
    trap:place()
end

--------------------------------------------------------------------
--- Resolve a projectile landing: trigger explosion + callbacks
--------------------------------------------------------------------
function Payloads.ResolveLanding(projectile)
    if not projectile then return end

    local square  = projectile.square
    local config  = projectile.config
    local shooter = projectile.player

    -- Fire the explosion via vanilla IsoTrap
    if config.IsExplosive and square then
        Payloads.TriggerExplosion(square, config, shooter)
    end

    -- Fire all registered landing callbacks
    for i = 1, #ExplosivesSystems.LandingCallbacks do
        local cb = ExplosivesSystems.LandingCallbacks[i]
        if cb then
            cb(projectile, square, config)
        end
    end
end

return Payloads
