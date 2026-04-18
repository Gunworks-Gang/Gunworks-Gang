local ExplosivesSystems = require("ExplosivesSystems/Init")
local Payloads          = {}

--------------------------------------------------------------------
--- Create a HandWeapon from the source item, build an IsoTrap,
--- and detonate immediately. Explosion stats come directly from
--- the item's script definition.
--------------------------------------------------------------------
function Payloads.Detonate(square, shooter, sourceWeapon, parentItem)
    if not square then return end

    local weaponItem = nil

    if sourceWeapon then
        weaponItem = instanceItem(sourceWeapon)
    end

    if not weaponItem or not instanceof(weaponItem, "HandWeapon") then
        weaponItem = instanceItem(parentItem or "Base.PipeBomb")
    end

    if not weaponItem then return end

    if weaponItem:getExplosionPower() <= 0
        and weaponItem:getSmokeRange() <= 0
        and weaponItem:getFireRange() <= 0
        and weaponItem:getNoiseRange() <= 0 then
        return
    end

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
    if params and square then
        Payloads.Detonate(square, ordnance.player, ordnance.sourceWeapon, params.parentItem)
    end

    for i = 1, #ExplosivesSystems.ImpactHooks do
        local hook = ExplosivesSystems.ImpactHooks[i]
        if hook then
            hook(ordnance, square)
        end
    end
end

return Payloads
