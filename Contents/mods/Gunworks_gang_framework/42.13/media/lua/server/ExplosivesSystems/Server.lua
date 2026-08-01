local ExplosivesSystems                   = require("ExplosivesSystems/Init")
local Payloads                            = require("ExplosivesSystems/Payloads")
local OrdnanceFactory                     = require("ExplosivesSystems/OrdnanceFactory")
local ExplosionFX                         = require("ExplosivesSystems/ExplosionFX")

ExplosivesSystems.activeOrdnance          = {}
ExplosivesSystems.RANDOM                  = newrandom()
ExplosivesSystems.updateCounter           = 0
ExplosivesSystems.GRAVITY                 = 0.020
ExplosivesSystems.XY_STEP                 = 0.10
ExplosivesSystems.Z_STEP                  = 0.05
ExplosivesSystems.DRAG_XY                 = 0.995
ExplosivesSystems.DRAG_Z                  = 0.998
ExplosivesSystems.BOUNCE_RESTITUTION_WALL = 0.50
ExplosivesSystems.BOUNCE_RESTITUTION_CEIL = 0.30
ExplosivesSystems.BOUNCE_POSITION_CORRECT = 0.12
ExplosivesSystems.BOUNCE_MIN_VELOCITY     = 0.004
ExplosivesSystems.EDGE_TOL                = 0.15
ExplosivesSystems.LOW_WALL_Z_THRESHOLD    = 0.25
ExplosivesSystems.MIN_WORLD_Z             = -32

--- Find the floor an ordnance would land on in a given tile column.
--- Scans downward from startZ and returns the first square that has a floor.
---
--- A nil square means the chunk is not loaded, NOT that there is no floor -- bail out
--- rather than descending through it, or ordnance falls into the void at chunk edges.
---
--- Returns square, floorZ  (or nil, nil if nothing was found).
function ExplosivesSystems.resolveFloorColumn(tileX, tileY, startZ)
    local minZ = (getMinimumWorldLevel and getMinimumWorldLevel()) or ExplosivesSystems.MIN_WORLD_Z
    local maxZ = (getMaximumWorldLevel and getMaximumWorldLevel()) or 8

    -- A tall arc can peak above the top of the world. Starting the scan up there would
    -- hit the nil bail below and abandon a perfectly good floor further down.
    local checkZ = math.min(startZ, maxZ)

    while checkZ >= minZ do
        local sq = getCell():getGridSquare(tileX, tileY, checkZ)
        if not sq then return nil, nil end
        if sq:getFloor() then return sq, checkZ end
        checkZ = checkZ - 1
    end

    return nil, nil
end

function ExplosivesSystems.isLowWall(wall)
    if not wall then return false end
    local props = wall.getProperties and wall:getProperties() or nil
    if not props then return false end
    if props:has(IsoFlagType.transparentW)
        or props:has(IsoFlagType.transparentN)
        or props:has(IsoFlagType.HoppableW)
        or props:has(IsoFlagType.HoppableN)
    then
        return true
    end
    return false
end

function ExplosivesSystems.isBlockedBetweenSquares(fromSq, toSq, dir, ordZ)
    if not fromSq or not toSq or not dir then return false end

    local barrier = fromSq:getDoorOrWindowOrWindowFrame(dir, true)
    if not barrier then
        local revDir = dir:Rot180()
        barrier = toSq:getDoorOrWindowOrWindowFrame(revDir, true)
    end

    if barrier and (instanceof(barrier, "IsoDoor") or instanceof(barrier, "IsoWindow")) then
        local destroyed = barrier.isDestroyed and barrier:isDestroyed() or false
        if not barrier:IsOpen() and not destroyed then
            return true
        end
        return false
    end

    if fromSq:isWallTo(toSq) then
        local wall1 = fromSq:getWall()
        local wall2 = toSq:getWall()
        local isLow = (wall1 and ExplosivesSystems.isLowWall(wall1))
            or (wall2 and ExplosivesSystems.isLowWall(wall2))
        if isLow then
            return (ordZ or 0) < ExplosivesSystems.LOW_WALL_Z_THRESHOLD
        end
        return true
    end

    return false
end

function ExplosivesSystems.removeWorldItem(ord)
    if not ord.worldItem then return end
    local wobj = ord.worldItem:getWorldItem()
    if wobj then
        local wSquare = wobj:getSquare()
        if wSquare then
            if isServer() then
                wSquare:transmitRemoveItemFromSquare(wobj)
            end
            wSquare:removeWorldObject(wobj)
        end
    end
    ord.worldItem = nil
end

function ExplosivesSystems.getTileTopZ(square)
    if not square then return nil end
    local objects = square:getObjects()
    if not objects then return nil end

    local topZ = nil
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj then
            local surfOff = nil
            if obj.getSurfaceOffsetNoTable then
                surfOff = obj:getSurfaceOffsetNoTable()
            end
            if (not surfOff or surfOff <= 0) and obj.getSurfaceOffset then
                local so = obj:getSurfaceOffset()
                if so and so > 0 then surfOff = so end
            end
            if surfOff and surfOff > 0 then
                local z = surfOff / 96.0
                if not topZ or z > topZ then topZ = z end
            end
        end
    end
    return topZ
end

function ExplosivesSystems.GT()
    return GameTime.getInstance()
end

function ExplosivesSystems.doSpawnOrdnance(player, sourceWeapon, originX, originY, originZ, destX, destY, destZ, isAmmoLaunch)
    local params
    if isAmmoLaunch then
        params = OrdnanceFactory.GetAmmoParams(sourceWeapon)
    else
        params = OrdnanceFactory.GetParams(sourceWeapon)
    end
    if not params then return end

    local dx       = destX - originX
    local dy       = destY - originY
    local distance = math.sqrt(dx * dx + dy * dy)

    local maxDist  = params.maxThrowDist or 20
    if distance > maxDist then
        local ratio = maxDist / distance
        destX       = originX + dx * ratio
        destY       = originY + dy * ratio
        distance    = maxDist
    end

    local throwSpeed = math.max(1, params.throwSpeed or 12)
    local arcFactor  = params.arcFactor or 0.12
    local maxArc     = params.maxArc or 1.5

    local flightTime = math.max(0.02, distance / throwSpeed)
    local arcHeight  = math.min(maxArc, distance * arcFactor)

    local dirX       = (distance > 0.01) and (dx / distance) or 0
    local dirY       = (distance > 0.01) and (dy / distance) or 0

    local sq         = getCell():getGridSquare(math.floor(originX), math.floor(originY), math.floor(originZ))
    if not sq then
        -- Fractional originZ on a staircase, or a forward offset that pushed the origin
        -- into an unloaded tile. Fall back to the thrower's own square before giving up.
        sq = player and player:getCurrentSquare() or nil
        if not sq then return end
    end

    local modelType = params.worldModel or sourceWeapon

    local localX = originX - sq:getX()
    local localY = originY - sq:getY()
    local localZ = originZ - sq:getZ()

    local worldItem = sq:AddWorldInventoryItem(modelType, localX, localY, localZ)
    local detonationTimer = params.detonationDelay or 0
    local ordnanceData = {
        player           = player,
        params           = params,
        sourceWeapon     = sourceWeapon,
        square           = sq,
        originX          = originX,
        originY          = originY,
        originZ          = originZ,
        destX            = destX,
        destY            = destY,
        destZ            = destZ,
        x                = localX,
        y                = localY,
        z                = localZ,
        worldItem        = worldItem,
        active           = true,
        detonationTimer  = detonationTimer,
        hasHitFloor      = false,
        atRest           = false,
        remainingBounces = ExplosivesSystems.randomizeBounces(params.floorBounces or 1),
        flightMode       = "guided",
        elapsed          = 0,
        flightTime       = flightTime,
        arcHeight        = arcHeight,
        originWorldX     = originX,
        originWorldY     = originY,
        originWorldZ     = originZ,
        destWorldX       = destX,
        destWorldY       = destY,
        -- The arc always targets the THROWER's own tier -- never a guessed lower one.
        -- Mid-flight, the per-tick floor scan below (mirroring Hot Brass's casing drop)
        -- detects any actual terrain drop and lands early; there is nothing to predict.
        destWorldZ       = sq:getZ(),
        prevWorldZ       = originZ,
        guidedDirX       = dirX,
        guidedDirY       = dirY,
        velocityX        = 0,
        velocityY        = 0,
        velocityZ        = 0,
    }

    table.insert(ExplosivesSystems.activeOrdnance, ordnanceData)
end

function ExplosivesSystems.consumeThrowableFromPlayer(player, sourceWeapon)
    if not player or not sourceWeapon then return false end

    local inventory = player:getInventory()
    if not inventory then return false end

    local removedItem = inventory:RemoveOneOf(sourceWeapon, true)
    if not removedItem then
        return false
    end

    sendRemoveItemFromContainer(inventory, removedItem)
    return true
end

function ExplosivesSystems.randomizeBounces(maxBounces)
    if maxBounces <= 0 then return 1 end
    return ExplosivesSystems.RANDOM:random(1, maxBounces)
end

function ExplosivesSystems.forceDetonate(ord, index)
    ExplosivesSystems.removeWorldItem(ord)
    Payloads.ResolveImpact(ord)
    if ord.params and ord.params.explosionFXObject then
        ExplosionFX.PlayEffect(
            ord.square,
            ord.params.explosionFXObject,
            ord.x, ord.y, ord.z,
            ord.params.explosionFXDuration
        )
    end
    ord.active = false
    table.remove(ExplosivesSystems.activeOrdnance, index)
    return true
end

function ExplosivesSystems.guidedToPhysics(ord, t)
    if ord.flightMode ~= "guided" then return end
    ord.flightMode    = "physics"

    local dist        = math.sqrt(
        (ord.destWorldX - ord.originWorldX) * (ord.destWorldX - ord.originWorldX) +
        (ord.destWorldY - ord.originWorldY) * (ord.destWorldY - ord.originWorldY)
    )
    local hSpeedWorld = (ord.flightTime > 0) and (dist / ord.flightTime) or 0
    local XY_CONV     = ExplosivesSystems.XY_STEP * 60
    local Z_CONV      = ExplosivesSystems.Z_STEP * 60

    local residual    = 0.5
    ord.velocityX     = ord.guidedDirX * hSpeedWorld * residual / XY_CONV
    ord.velocityY     = ord.guidedDirY * hSpeedWorld * residual / XY_CONV

    -- Analytic derivative of the world-Z arc:
    --   worldZ(t) = originWorldZ + dz*t + 4*arcHeight*t*(1-t)
    local dzdt        = (ord.destWorldZ - ord.originWorldZ) + ord.arcHeight * 4.0 * (1.0 - 2.0 * t)
    local zSpeedWorld = (ord.flightTime > 0) and (dzdt / ord.flightTime) or 0
    local zVel        = zSpeedWorld / Z_CONV

    zVel              = math.max(zVel, -1.5)
    zVel              = math.min(zVel, 1.5)
    ord.velocityZ     = zVel
end

function ExplosivesSystems.updateGuidedFlight(ord, index, scale, shouldRender)
    local dt = ExplosivesSystems.GT():getTimeDelta()

    ord.elapsed = ord.elapsed + dt
    local t = ord.elapsed / ord.flightTime
    local arrived = t >= 1.0
    if arrived then t = 1.0 end

    local oldEdgeX   = ord.x
    local oldEdgeY   = ord.y

    local prevWorldZ = ord.prevWorldZ or ord.originWorldZ

    -- The arc lives in ABSOLUTE world space. worldZ is authoritative; ord.z is derived
    -- from it once the parent square is known. Doing it the other way round is what made
    -- the old code cut: the per-tick reparent rebased ord.z correctly, then the next
    -- tick recomputed ord.z from scratch in the new frame and threw the rebase away.
    --
    -- dz*t + 4*arc*t*(1-t) has a constant second derivative (-8*arc), so this is the
    -- exact constant-gravity path from originWorldZ to destWorldZ. Descent accelerates.
    local worldX     = ord.originWorldX + (ord.destWorldX - ord.originWorldX) * t
    local worldY     = ord.originWorldY + (ord.destWorldY - ord.originWorldY) * t
    local dz         = ord.destWorldZ - ord.originWorldZ
    local worldZ     = ord.originWorldZ + dz * t + ord.arcHeight * 4.0 * t * (1.0 - t)

    local sx         = ord.square:getX()
    local sy         = ord.square:getY()
    local sz         = ord.square:getZ()

    -- Keep the square-local coords coherent so the wall/edge checks below read correctly.
    ord.x            = worldX - sx
    ord.y            = worldY - sy
    ord.z            = worldZ - sz

    local EDGE_TOL = ExplosivesSystems.EDGE_TOL
    local blockX   = false
    local blockY   = false

    local effVelX  = ord.destWorldX - ord.originWorldX
    local effVelY  = ord.destWorldY - ord.originWorldY

    if effVelX > 0 and oldEdgeX < (1.0 - EDGE_TOL) and ord.x >= (1.0 - EDGE_TOL) then
        local neighbor = getCell():getGridSquare(sx + 1, sy, sz)
        if neighbor and ExplosivesSystems.isBlockedBetweenSquares(
                ord.square, neighbor, IsoDirections.E, ord.z) then
            blockX = true
        end
    elseif effVelX < 0 and oldEdgeX > EDGE_TOL and ord.x <= EDGE_TOL then
        local neighbor = getCell():getGridSquare(sx - 1, sy, sz)
        if neighbor and ExplosivesSystems.isBlockedBetweenSquares(
                ord.square, neighbor, IsoDirections.W, ord.z) then
            blockX = true
        end
    end

    if effVelY > 0 and oldEdgeY < (1.0 - EDGE_TOL) and ord.y >= (1.0 - EDGE_TOL) then
        local neighbor = getCell():getGridSquare(sx, sy + 1, sz)
        if neighbor and ExplosivesSystems.isBlockedBetweenSquares(
                ord.square, neighbor, IsoDirections.S, ord.z) then
            blockY = true
        end
    elseif effVelY < 0 and oldEdgeY > EDGE_TOL and ord.y <= EDGE_TOL then
        local neighbor = getCell():getGridSquare(sx, sy - 1, sz)
        if neighbor and ExplosivesSystems.isBlockedBetweenSquares(
                ord.square, neighbor, IsoDirections.N, ord.z) then
            blockY = true
        end
    end

    if blockX or blockY then
        ExplosivesSystems.guidedToPhysics(ord, t)

        if blockX then
            ord.velocityX = -ord.velocityX * ExplosivesSystems.BOUNCE_RESTITUTION_WALL
            ord.x = ord.x + (ord.velocityX * ExplosivesSystems.BOUNCE_POSITION_CORRECT)
            if math.abs(ord.velocityX) < ExplosivesSystems.BOUNCE_MIN_VELOCITY then
                ord.velocityX = 0
            end
            if ord.params.detonateOnImpact then
                return ExplosivesSystems.forceDetonate(ord, index)
            end
        end

        if blockY then
            ord.velocityY = -ord.velocityY * ExplosivesSystems.BOUNCE_RESTITUTION_WALL
            ord.y = ord.y + (ord.velocityY * ExplosivesSystems.BOUNCE_POSITION_CORRECT)
            if math.abs(ord.velocityY) < ExplosivesSystems.BOUNCE_MIN_VELOCITY then
                ord.velocityY = 0
            end
            if ord.params.detonateOnImpact then
                return ExplosivesSystems.forceDetonate(ord, index)
            end
        end
    end

    worldX = ord.square:getX() + ord.x
    worldY = ord.square:getY() + ord.y
    local targetTileX = math.floor(worldX)
    local targetTileY = math.floor(worldY)

    -- Ceiling: test the level worldZ is actually in, not the level of the parent square.
    -- Those two diverge the moment the ordnance is reparented mid-flight.
    -- Gated on RISING only: worldZ also passes through a X.95 fractional value while
    -- falling through a tier boundary from above, and a descending ordnance is not
    -- hitting a ceiling, it's passing the floor of the tier it's leaving.
    local rising = worldZ > prevWorldZ
    local zi = math.floor(worldZ)
    if rising and (worldZ - zi) >= 0.95 then
        local aboveSq = getCell():getGridSquare(targetTileX, targetTileY, zi + 1)
        if aboveSq and aboveSq:TreatAsSolidFloor() then
            if ord.flightMode == "guided" then
                ExplosivesSystems.guidedToPhysics(ord, t)
            end
            ord.velocityZ = -math.abs(ord.velocityZ) * ExplosivesSystems.BOUNCE_RESTITUTION_CEIL
            worldZ = zi + 0.95
        end
    end

    -- Scan from the PREVIOUS worldZ, not the current one: a fast ordnance can cross more
    -- than one level in a tick, and scanning from the new Z would let it tunnel straight
    -- through a floor it should have hit.
    local targetSquare, landZ =
        ExplosivesSystems.resolveFloorColumn(targetTileX, targetTileY, math.floor(prevWorldZ))

    if not targetSquare then
        targetSquare = ord.square
        landZ        = nil
    end

    ord.square = targetSquare
    ord.x      = worldX - targetSquare:getX()
    ord.y      = worldY - targetSquare:getY()
    ord.z      = worldZ - targetSquare:getZ()

    -- Land whenever we are descending and have reached the resolved floor. This is NOT
    -- gated on arrival any more: an ordnance thrown off a ledge onto nearby ground meets
    -- its floor well before t reaches 1.
    local descending = (dz + ord.arcHeight * 4.0 * (1.0 - 2.0 * t)) <= 0
    local landed     = (landZ ~= nil) and descending and (worldZ <= landZ + 0.01)

    if landed then
        if ord.flightMode == "guided" then
            ExplosivesSystems.guidedToPhysics(ord, t)
        end

        ord.z = 0

        if not ord.hasHitFloor then
            ord.hasHitFloor = true
            if ord.params.detonateOnImpact then
                return ExplosivesSystems.forceDetonate(ord, index)
            end
        end

        if ord.remainingBounces > 0 then
            ord.remainingBounces = ord.remainingBounces - 1
            ord.z = 0.01
            local restitution = ord.params.bounceEnergy or 0.45
            ord.velocityZ = math.abs(ord.velocityZ) * restitution
            ord.velocityX = ord.velocityX * 0.6
            ord.velocityY = ord.velocityY * 0.6

            local bounceSound = ord.params.soundBounce
            if bounceSound and ord.player then
                if isServer() then
                    sendServerCommand(ord.player, ExplosivesSystems.MODULE_NAME, "playSound", {
                        sound = bounceSound
                    })
                elseif ord.player.getEmitter then
                    ord.player:getEmitter():playSound(bounceSound)
                end
            end

            worldZ = targetSquare:getZ() + ord.z
        else
            ord.atRest    = true
            ord.velocityX = 0
            ord.velocityY = 0
            ord.velocityZ = 0
            ord.z         = 0

            if shouldRender then
                ExplosivesSystems.removeWorldItem(ord)
                ord.worldItem = ord.square:AddWorldInventoryItem(
                    ord.params.worldModel or ord.sourceWeapon,
                    PZMath.clamp_01(ord.x), PZMath.clamp_01(ord.y), 0
                )
            end

            ord.prevWorldZ = targetSquare:getZ()

            if ord.params.detonateOnImpact or (ord.params.detonationDelay or 0) > 0 then
                if ord.detonationTimer <= 0 then
                    return ExplosivesSystems.forceDetonate(ord, index)
                end
                return false
            end

            Payloads.ResolveImpact(ord)
            ord.active = false
            table.remove(ExplosivesSystems.activeOrdnance, index)
            return true
        end
    elseif arrived and ord.flightMode == "guided" then
        -- Flight time is spent but we are still airborne: the target Z was wrong, the
        -- floor was destroyed mid-flight, or the throw sailed past a ledge. Hand off to
        -- the ballistic integrator, which handles multi-level descent correctly. It can
        -- never hang in mid-air the way a truncated guided arc would.
        ExplosivesSystems.guidedToPhysics(ord, 1.0)
    end

    ord.prevWorldZ = worldZ

    ord.x = PZMath.clamp_01(ord.x)
    ord.y = PZMath.clamp_01(ord.y)

    if shouldRender then
        ExplosivesSystems.removeWorldItem(ord)
        ord.worldItem = ord.square:AddWorldInventoryItem(
            ord.params.worldModel or ord.sourceWeapon,
            ord.x, ord.y, ord.z
        )
    end

    return false
end

function ExplosivesSystems.update()
    local dt           = ExplosivesSystems.GT():getTimeDelta()
    local scale        = dt * 60

    local buffer       = SandboxVars.GWG.MultiplayerTick or 0
    local shouldRender = true
    if buffer > 0 then
        ExplosivesSystems.updateCounter = ExplosivesSystems.updateCounter + 1
        if ExplosivesSystems.updateCounter > buffer then
            ExplosivesSystems.updateCounter = 0
        else
            shouldRender = false
        end
    end

    local i = 1
    while i <= #ExplosivesSystems.activeOrdnance do
        local ord     = ExplosivesSystems.activeOrdnance[i]
        local removed = false

        if not ord or not ord.active then
            table.remove(ExplosivesSystems.activeOrdnance, i)
            removed = true
        else
            removed = ExplosivesSystems.updateOrdnance(ord, i, scale, shouldRender)
        end

        if not removed then
            i = i + 1
        end
    end
end

function ExplosivesSystems.updateOrdnance(ord, index, scale, shouldRender)
    local dt = ExplosivesSystems.GT():getTimeDelta()
    if ord.detonationTimer > 0 then
        ord.detonationTimer = ord.detonationTimer - dt
        if ord.detonationTimer <= 0 then
            return ExplosivesSystems.forceDetonate(ord, index)
        end
    end

    if ord.atRest then
        return false
    end

    if ord.flightMode == "guided" then
        return ExplosivesSystems.updateGuidedFlight(ord, index, scale, shouldRender)
    end

    local prevZ    = ord.z
    ord.velocityZ  = ord.velocityZ - (ExplosivesSystems.GRAVITY * scale)

    local oldEdgeX = ord.x
    local oldEdgeY = ord.y

    ord.x          = ord.x + (ord.velocityX * ExplosivesSystems.XY_STEP * scale)
    ord.y          = ord.y + (ord.velocityY * ExplosivesSystems.XY_STEP * scale)
    ord.z          = ord.z + (ord.velocityZ * ExplosivesSystems.Z_STEP * scale)

    local dragXY   = math.pow(ExplosivesSystems.DRAG_XY, scale)
    local dragZ    = math.pow(ExplosivesSystems.DRAG_Z, scale)
    ord.velocityX  = ord.velocityX * dragXY
    ord.velocityY  = ord.velocityY * dragXY
    ord.velocityZ  = ord.velocityZ * dragZ

    local sx       = ord.square:getX()
    local sy       = ord.square:getY()
    local sz       = ord.square:getZ()
    local EDGE_TOL = ExplosivesSystems.EDGE_TOL

    local blockX   = false
    local blockY   = false

    if ord.velocityX > 0 and oldEdgeX < (1.0 - EDGE_TOL) and ord.x >= (1.0 - EDGE_TOL) then
        local neighbor = getCell():getGridSquare(sx + 1, sy, sz)
        if neighbor and ExplosivesSystems.isBlockedBetweenSquares(
                ord.square, neighbor, IsoDirections.E, ord.z) then
            blockX = true
        end
    elseif ord.velocityX < 0 and oldEdgeX > EDGE_TOL and ord.x <= EDGE_TOL then
        local neighbor = getCell():getGridSquare(sx - 1, sy, sz)
        if neighbor and ExplosivesSystems.isBlockedBetweenSquares(
                ord.square, neighbor, IsoDirections.W, ord.z) then
            blockX = true
        end
    end

    if ord.velocityY > 0 and oldEdgeY < (1.0 - EDGE_TOL) and ord.y >= (1.0 - EDGE_TOL) then
        local neighbor = getCell():getGridSquare(sx, sy + 1, sz)
        if neighbor and ExplosivesSystems.isBlockedBetweenSquares(
                ord.square, neighbor, IsoDirections.S, ord.z) then
            blockY = true
        end
    elseif ord.velocityY < 0 and oldEdgeY > EDGE_TOL and ord.y <= EDGE_TOL then
        local neighbor = getCell():getGridSquare(sx, sy - 1, sz)
        if neighbor and ExplosivesSystems.isBlockedBetweenSquares(
                ord.square, neighbor, IsoDirections.N, ord.z) then
            blockY = true
        end
    end

    if blockX then
        ord.velocityX = -ord.velocityX * ExplosivesSystems.BOUNCE_RESTITUTION_WALL
        ord.x = ord.x + (ord.velocityX * ExplosivesSystems.BOUNCE_POSITION_CORRECT)
        if math.abs(ord.velocityX) < ExplosivesSystems.BOUNCE_MIN_VELOCITY then
            ord.velocityX = 0
        end
        if ord.params.detonateOnImpact then
            return ExplosivesSystems.forceDetonate(ord, index)
        end
    end

    if blockY then
        ord.velocityY = -ord.velocityY * ExplosivesSystems.BOUNCE_RESTITUTION_WALL
        ord.y = ord.y + (ord.velocityY * ExplosivesSystems.BOUNCE_POSITION_CORRECT)
        if math.abs(ord.velocityY) < ExplosivesSystems.BOUNCE_MIN_VELOCITY then
            ord.velocityY = 0
        end
        if ord.params.detonateOnImpact then
            return ExplosivesSystems.forceDetonate(ord, index)
        end
    end

    local worldX = ord.square:getX() + ord.x
    local worldY = ord.square:getY() + ord.y
    local targetTileX = math.floor(worldX)
    local targetTileY = math.floor(worldY)

    if ord.z >= 1.0 then
        local aboveSq = getCell():getGridSquare(targetTileX, targetTileY, sz + 1)
        if aboveSq and aboveSq:TreatAsSolidFloor() then
            ord.velocityZ = -math.abs(ord.velocityZ) * ExplosivesSystems.BOUNCE_RESTITUTION_CEIL
            ord.z = 0.95
        end
    end

    local worldZ = sz + ord.z

    local targetSquare = ExplosivesSystems.resolveFloorColumn(targetTileX, targetTileY, sz)

    if targetSquare then
        ord.z = worldZ - targetSquare:getZ()
    else
        targetSquare = ord.square
    end

    if targetSquare ~= ord.square then
        ord.square = targetSquare
    end

    ord.x = worldX - ord.square:getX()
    ord.y = worldY - ord.square:getY()

    ord.prevWorldZ = ord.square:getZ() + ord.z

    if ord.z <= 0 then
        ord.z = 0

        if not ord.hasHitFloor then
            ord.hasHitFloor = true
            if ord.params.detonateOnImpact then
                return ExplosivesSystems.forceDetonate(ord, index)
            end
        end

        if ord.remainingBounces > 0 then
            ord.remainingBounces = ord.remainingBounces - 1
            ord.z = 0.01
            local restitution = ord.params.bounceEnergy or 0.45
            ord.velocityZ = math.abs(ord.velocityZ) * restitution
            ord.velocityX = ord.velocityX * 0.6
            ord.velocityY = ord.velocityY * 0.6

            local bounceSound = ord.params.soundBounce
            if bounceSound and ord.player then
                if isServer() then
                    sendServerCommand(ord.player, ExplosivesSystems.MODULE_NAME, "playSound", {
                        sound = bounceSound
                    })
                elseif ord.player.getEmitter then
                    ord.player:getEmitter():playSound(bounceSound)
                end
            end
        else
            ord.atRest    = true
            ord.velocityX = 0
            ord.velocityY = 0
            ord.velocityZ = 0
            ord.z         = 0

            if shouldRender then
                ExplosivesSystems.removeWorldItem(ord)
                ord.worldItem = ord.square:AddWorldInventoryItem(
                    ord.params.worldModel or ord.sourceWeapon,
                    PZMath.clamp_01(ord.x), PZMath.clamp_01(ord.y), 0
                )
            end

            if ord.params.detonateOnImpact or (ord.params.detonationDelay or 0) > 0 then
                if ord.detonationTimer <= 0 then
                    return ExplosivesSystems.forceDetonate(ord, index)
                end
                return false
            end

            Payloads.ResolveImpact(ord)
            ord.active = false
            table.remove(ExplosivesSystems.activeOrdnance, index)
            return true
        end
    end

    ord.x = PZMath.clamp_01(ord.x)
    ord.y = PZMath.clamp_01(ord.y)
    ord.z = math.max(0, ord.z)

    if shouldRender then
        ExplosivesSystems.removeWorldItem(ord)
        ord.worldItem = ord.square:AddWorldInventoryItem(
            ord.params.worldModel or ord.sourceWeapon,
            ord.x, ord.y, ord.z
        )
    end

    return false
end

function ExplosivesSystems.onClientCommand(module, command, player, args)
    if module ~= ExplosivesSystems.MODULE_NAME then return end
    if not player or not args then return end

    if command == "throwOrdnance" then
        local sourceWeapon = args.sourceWeapon
        if not sourceWeapon then return end

        local isAmmoLaunch = args.isAmmoLaunch or false
        local params
        if isAmmoLaunch then
            params = OrdnanceFactory.GetAmmoParams(sourceWeapon)
        else
            if not OrdnanceFactory.IsRegistered(sourceWeapon) then return end
            params = OrdnanceFactory.GetParams(sourceWeapon)
        end
        if not params then return end

        if not isAmmoLaunch then
            if not ExplosivesSystems.consumeThrowableFromPlayer(player, sourceWeapon) then
                return
            end
        end

        local px       = player:getX()
        local py       = player:getY()
        local pz       = player:getZ()

        local angleDeg = player:getDirectionAngle() or 0
        local angleRad = math.rad(angleDeg)
        local fwd      = params.forwardOffset or 0.50
        local hOff     = params.heightOffset or 0.55

        local originX  = px + math.cos(angleRad) * fwd
        local originY  = py + math.sin(angleRad) * fwd
        local originZ  = pz + hOff

        local destX    = args.destX
        local destY    = args.destY
        local destZ    = args.destZ or pz

        if not destX or not destY then return end
        ExplosivesSystems.doSpawnOrdnance(player, sourceWeapon, originX, originY, originZ, destX, destY, destZ, isAmmoLaunch)

        if isServer() then
            local onlinePlayers = getOnlinePlayers()
            for i = 0, onlinePlayers:size() - 1 do
                local other = onlinePlayers:get(i)
                if other and other ~= player then
                    sendServerCommand(other, ExplosivesSystems.MODULE_NAME, "remoteThrow", {
                        sourceWeapon = sourceWeapon,
                        originX      = originX,
                        originY      = originY,
                        originZ      = originZ,
                        destX        = destX,
                        destY        = destY,
                        destZ        = destZ,
                    })
                end
            end
        end
    end
end

Events.OnClientCommand.Add(ExplosivesSystems.onClientCommand)
Events.OnTick.Add(ExplosivesSystems.update)
