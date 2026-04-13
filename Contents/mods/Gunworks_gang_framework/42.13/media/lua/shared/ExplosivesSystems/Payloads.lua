local ExplosivesSystems = require("ExplosivesSystems/Init")
local OrdnanceFactory   = require("ExplosivesSystems/OrdnanceFactory")

local Payloads          = {}

--------------------------------------------------------------------
--- Create a temporary HandWeapon configured with explosive params,
--- build an IsoTrap from it, and detonate immediately.
--------------------------------------------------------------------
function Payloads.Detonate(square, explosiveParams, shooter, sourceWeapon)
    if not square then return end
    if not explosiveParams then return end

    local weaponItem = nil

    -- Try to instance the source weapon for IsoTrap sprite/sound inheritance
    if sourceWeapon then
        weaponItem = instanceItem(sourceWeapon)
    end

    -- Fallback: generic explosive carrier
    if not weaponItem or not instanceof(weaponItem, "HandWeapon") then
        weaponItem = instanceItem("Base.PipeBomb")
    end

    if not weaponItem then return end

    -- Apply explosion properties via OrdnanceFactory registry
    OrdnanceFactory.ApplyExplosiveParams(weaponItem, explosiveParams)

    -- Timer = 0 so it triggers immediately when place() is called
    weaponItem:setExplosionTimer(0)

    -- Create and trigger the trap
    local cell = square:getCell()
    local trap = IsoTrap.new(shooter, weaponItem, cell, square)
    trap:setInstantExplosion(true)
    trap:place()
end

--------------------------------------------------------------------
--- Resolve ordnance impact: detonate if explosive, then fire hooks.
--- By the time this is called, timing decisions (immediate vs delay)
--- have already been made by the physics engine.
--------------------------------------------------------------------
function Payloads.ResolveImpact(ordnance)
    if not ordnance then return end

    local square = ordnance.square

    -- Detonate if this ordnance carries an explosive component
    local params = ordnance.params
    if params and (params.explosionPower or 0) > 0 and square then
        Payloads.Detonate(square, params, ordnance.player, ordnance.sourceWeapon)
    end

    -- Fire all registered impact hooks
    for i = 1, #ExplosivesSystems.ImpactHooks do
        local hook = ExplosivesSystems.ImpactHooks[i]
        if hook then
            hook(ordnance, square)
        end
    end
end

return Payloads
