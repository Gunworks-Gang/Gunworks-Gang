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

    if sourceWeapon then
        weaponItem = instanceItem(sourceWeapon)
    end

    if not weaponItem or not instanceof(weaponItem, "HandWeapon") then
        weaponItem = instanceItem("Base.PipeBomb")
    end

    if not weaponItem then return end
    OrdnanceFactory.ApplyExplosiveParams(weaponItem, explosiveParams)
    weaponItem:setExplosionTimer(0)

    local cell = square:getCell()
    local explosive = IsoTrap.new(shooter, weaponItem, cell, square)
    explosive:setInstantExplosion(true)
    explosive:place()
end

--------------------------------------------------------------------
--- Resolve ordnance impact: detonate if explosive, then fire hooks.
--- By the time this is called, timing decisions (immediate vs delay)
--- have already been made by the physics engine.
--------------------------------------------------------------------
function Payloads.ResolveImpact(ordnance)
    if not ordnance then return end

    local square = ordnance.square

    local params = ordnance.params
    if params and (params.explosionPower or 0) > 0 and square then
        Payloads.Detonate(square, params, ordnance.player, ordnance.sourceWeapon)
    end

    for i = 1, #ExplosivesSystems.ImpactHooks do
        local hook = ExplosivesSystems.ImpactHooks[i]
        if hook then
            hook(ordnance, square)
        end
    end
end

return Payloads
