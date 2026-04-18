local ExplosionFX         = {}

ExplosionFX.activeEffects = {}
ExplosionFX.TICK_MS       = 35 -- approximate server tick duration in ms

--------------------------------------------------------------------
--- Remove the FX world object from the square.
--- Mirrors the Hot Brass removeWorldItem pattern exactly.
--------------------------------------------------------------------
local function removeWorldItem(fx)
    if not fx.worldItem then return end
    local wobj = fx.worldItem:getWorldItem()
    if wobj then
        local wSquare = wobj:getSquare()
        if wSquare then
            if isServer() then
                wSquare:transmitRemoveItemFromSquare(wobj)
            end
            wSquare:removeWorldObject(wobj)
        end
    end
    fx.worldItem = nil
end

--------------------------------------------------------------------
--- Spawn a 3D world object at the grenade's exact resting position,
--- repeatedly removing and re-adding it every tick for the given
--- duration to simulate movement/animation rather than a static hold.
---   square:   IsoGridSquare where the explosion occurred
---   itemType: exact item type to spawn (e.g. "MWA.nade_explosion")
---   lx,ly,lz: local coords within the square (from ord.x/y/z)
---   duration: ms the effect runs before final removal (default 500)
--------------------------------------------------------------------
function ExplosionFX.PlayEffect(square, itemType, lx, ly, lz, duration)
    if not square then return end
    if not itemType then return end

    local ms          = tonumber(duration) or 500
    local ticksToLive = math.max(1, math.floor(ms / ExplosionFX.TICK_MS))

    local fx          = {
        square      = square,
        itemType    = itemType,
        lx          = lx or 0.5,
        ly          = ly or 0.5,
        lz          = lz or 0,
        ticksToLive = ticksToLive,
        worldItem   = square:AddWorldInventoryItem(itemType, lx or 0.5, ly or 0.5, lz or 0),
        active      = true,
    }

    table.insert(ExplosionFX.activeEffects, fx)
end

--------------------------------------------------------------------
--- OnTick handler – each tick: remove and re-add the FX object to
--- simulate movement. On the final tick remove without re-adding.
--------------------------------------------------------------------
function ExplosionFX.tick()
    local i = #ExplosionFX.activeEffects
    while i >= 1 do
        local fx = ExplosionFX.activeEffects[i]
        if fx and fx.active then
            removeWorldItem(fx)
            fx.ticksToLive = fx.ticksToLive - 1
            if fx.ticksToLive <= 0 then
                fx.active = false
                table.remove(ExplosionFX.activeEffects, i)
            else
                fx.worldItem = fx.square:AddWorldInventoryItem(fx.itemType, fx.lx, fx.ly, fx.lz)
            end
        else
            table.remove(ExplosionFX.activeEffects, i)
        end
        i = i - 1
    end
end

Events.OnTick.Add(ExplosionFX.tick)

return ExplosionFX
