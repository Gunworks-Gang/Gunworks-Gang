local ExplosivesSystems = require("ExplosivesSystems/Init")
local Payloads          = {}

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
