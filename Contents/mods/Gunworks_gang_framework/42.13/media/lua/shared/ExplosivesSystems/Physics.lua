local ExplosivesSystems                   = require("ExplosivesSystems/Init")

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
ExplosivesSystems.GRAVITY_WORLD_Z         = ExplosivesSystems.GRAVITY * ExplosivesSystems.Z_STEP * 3600

function ExplosivesSystems.GT()
    return GameTime.getInstance()
end

function ExplosivesSystems.predictUnitHorizontalRange(vzInternal, startZ)
    local velocityX = 1.0
    local velocityZ = vzInternal
    local x, z = 0, startZ or 0
    for _ = 1, 1200 do
        velocityZ = velocityZ - ExplosivesSystems.GRAVITY
        x         = x + velocityX * ExplosivesSystems.XY_STEP
        z         = z + velocityZ * ExplosivesSystems.Z_STEP
        velocityX = velocityX * ExplosivesSystems.DRAG_XY
        velocityZ = velocityZ * ExplosivesSystems.DRAG_Z
        if z <= 0 then return x end
    end
    return x
end

function ExplosivesSystems.resolveFloorColumn(tileX, tileY, startZ)
    local minZ = (getMinimumWorldLevel and getMinimumWorldLevel()) or ExplosivesSystems.MIN_WORLD_Z
    local maxZ = (getMaximumWorldLevel and getMaximumWorldLevel()) or 8
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

function ExplosivesSystems.computeLaunchVelocity(params, originX, originY, originZ, destX, destY, destZ)
    local dx       = destX - originX
    local dy       = destY - originY
    local distance = math.sqrt(dx * dx + dy * dy)

    local maxDist  = params.maxThrowDist or 20
    if distance > maxDist then
        local ratio = maxDist / distance
        destX       = originX + dx * ratio
        destY       = originY + dy * ratio
        dx          = dx * ratio
        dy          = dy * ratio
        distance    = maxDist
    end

    local throwSpeed = math.max(1, params.throwSpeed or 12)
    local forceMul   = (params.throwForce or 8) / 8
    local XY_CONV    = ExplosivesSystems.XY_STEP * 60
    local Z_CONV     = ExplosivesSystems.Z_STEP * 60

    local seedVelX, seedVelY, seedVelZ

    if params.directProjectile then
        local dirX           = (distance > 0.01) and (dx / distance) or 0
        local dirY           = (distance > 0.01) and (dy / distance) or 0

        local hSpeedInternal = throwSpeed / XY_CONV * forceMul
        local startZLocal    = originZ - destZ

        local ticks          = 1
        if hSpeedInternal > 0.0001 then
            ticks = math.max(1, distance / (hSpeedInternal * ExplosivesSystems.XY_STEP))
        end

        local vz0Internal = (ExplosivesSystems.GRAVITY * (ticks + 1) / 2)
            - (startZLocal / (ExplosivesSystems.Z_STEP * ticks))

        seedVelX = dirX * hSpeedInternal
        seedVelY = dirY * hSpeedInternal
        seedVelZ = vz0Internal
    else
        local arcFactor   = params.arcFactor or 0.12
        local maxArc      = params.maxArc or 1.5
        local arcHeight   = math.min(maxArc, distance * arcFactor)

        local dirX        = (distance > 0.01) and (dx / distance) or 0
        local dirY        = (distance > 0.01) and (dy / distance) or 0

        local gWorld      = ExplosivesSystems.GRAVITY_WORLD_Z
        local vz0World    = math.sqrt(math.max(0, 2.0 * gWorld * arcHeight))
        local vz0Internal = vz0World / Z_CONV

        local startZLocal = math.max(0, originZ - destZ)
        local unitRange   = ExplosivesSystems.predictUnitHorizontalRange(vz0Internal, startZLocal)
        local hSpeedNeeded
        if unitRange > 0.001 then
            hSpeedNeeded = (distance / unitRange) * XY_CONV
        else
            hSpeedNeeded = distance / 0.02
        end
        local hSpeedWorld = math.min(hSpeedNeeded, throwSpeed)

        seedVelX = dirX * hSpeedWorld / XY_CONV * forceMul
        seedVelY = dirY * hSpeedWorld / XY_CONV * forceMul
        seedVelZ = vz0World / Z_CONV * forceMul
    end

    return seedVelX, seedVelY, seedVelZ, destX, destY, distance
end

function ExplosivesSystems.stepOrdnance(ord, scale)
    local prevWorldZ = ord.prevWorldZ or (ord.square:getZ() + ord.z)

    ord.velocityZ    = ord.velocityZ - (ExplosivesSystems.GRAVITY * scale)

    local oldEdgeX   = ord.x
    local oldEdgeY   = ord.y

    ord.x            = ord.x + (ord.velocityX * ExplosivesSystems.XY_STEP * scale)
    ord.y            = ord.y + (ord.velocityY * ExplosivesSystems.XY_STEP * scale)
    ord.z            = ord.z + (ord.velocityZ * ExplosivesSystems.Z_STEP * scale)

    local dragXY     = math.pow(ExplosivesSystems.DRAG_XY, scale)
    local dragZ      = math.pow(ExplosivesSystems.DRAG_Z, scale)
    ord.velocityX    = ord.velocityX * dragXY
    ord.velocityY    = ord.velocityY * dragXY
    ord.velocityZ    = ord.velocityZ * dragZ

    local sx         = ord.square:getX()
    local sy         = ord.square:getY()
    local sz         = ord.square:getZ()
    local EDGE_TOL   = ExplosivesSystems.EDGE_TOL

    local blockX     = false
    local blockY     = false

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
    end

    if blockY then
        ord.velocityY = -ord.velocityY * ExplosivesSystems.BOUNCE_RESTITUTION_WALL
        ord.y = ord.y + (ord.velocityY * ExplosivesSystems.BOUNCE_POSITION_CORRECT)
        if math.abs(ord.velocityY) < ExplosivesSystems.BOUNCE_MIN_VELOCITY then
            ord.velocityY = 0
        end
    end

    if (blockX or blockY) and ord.params.detonateOnImpact then
        return "wallhit", false
    end

    local worldX = ord.square:getX() + ord.x
    local worldY = ord.square:getY() + ord.y
    local targetTileX = math.floor(worldX)
    local targetTileY = math.floor(worldY)

    local worldZ = sz + ord.z

    local rising = worldZ > prevWorldZ
    if rising and ord.z >= 1.0 then
        local aboveSq = getCell():getGridSquare(targetTileX, targetTileY, sz + 1)
        if aboveSq and aboveSq:TreatAsSolidFloor() then
            ord.velocityZ = -math.abs(ord.velocityZ) * ExplosivesSystems.BOUNCE_RESTITUTION_CEIL
            ord.z = 0.95
            worldZ = sz + ord.z
        end
    end

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

        local firstFloorImpact = not ord.hasHitFloor
        if firstFloorImpact then
            ord.hasHitFloor = true
        end

        if firstFloorImpact and ord.params.detonateOnImpact then
            return "floorimpact", true
        end

        if ord.remainingBounces > 0 then
            ord.remainingBounces = ord.remainingBounces - 1
            ord.z = 0.01
            local restitution = ord.params.bounceEnergy or 0.45
            ord.velocityZ = math.abs(ord.velocityZ) * restitution
            ord.velocityX = ord.velocityX * 0.6
            ord.velocityY = ord.velocityY * 0.6
            return "floorbounce", firstFloorImpact
        end

        ord.velocityX = 0
        ord.velocityY = 0
        ord.velocityZ = 0
        ord.z = 0
        return "rest", firstFloorImpact
    end

    ord.x = PZMath.clamp_01(ord.x)
    ord.y = PZMath.clamp_01(ord.y)
    ord.z = math.max(0, ord.z)

    return "flying", false
end

return ExplosivesSystems
