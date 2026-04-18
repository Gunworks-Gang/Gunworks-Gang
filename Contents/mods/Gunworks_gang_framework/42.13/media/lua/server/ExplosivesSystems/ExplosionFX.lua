local ExplosionFX         = {}

ExplosionFX.activeEffects = {}

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

function ExplosionFX.PlayEffect(square, itemType, lx, ly, lz, duration)
    if not square then return end
    if not itemType then return end

    local fx = {
        square     = square,
        itemType   = itemType,
        lx         = lx or 0.5,
        ly         = ly or 0.5,
        lz         = lz or 0,
        timeToLive = (tonumber(duration) or 30) / 60,
        worldItem  = square:AddWorldInventoryItem(itemType, lx or 0.5, ly or 0.5, lz or 0),
        active     = true,
    }

    table.insert(ExplosionFX.activeEffects, fx)
end

function ExplosionFX.tick()
    local dt = GameTime.getInstance():getTimeDelta()
    local i  = #ExplosionFX.activeEffects
    while i >= 1 do
        local fx = ExplosionFX.activeEffects[i]
        if fx and fx.active then
            removeWorldItem(fx)
            fx.timeToLive = fx.timeToLive - dt
            if fx.timeToLive <= 0 then
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
