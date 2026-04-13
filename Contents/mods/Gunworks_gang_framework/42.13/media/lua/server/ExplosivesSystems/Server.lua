local ExplosivesSystems                   = require("ExplosivesSystems/Init")
local Payloads                            = require("ExplosivesSystems/Payloads")
local OrdnanceFactory                     = require("ExplosivesSystems/OrdnanceFactory")

--------------------------------------------------------------------
--- Active ordnance list (mirrors SpentCasingPhysics.activeCasings)
--------------------------------------------------------------------
ExplosivesSystems.activeOrdnance          = {}
ExplosivesSystems.RANDOM                  = newrandom()
ExplosivesSystems.updateCounter           = 0

--------------------------------------------------------------------
--- Physics constants (shared with Hot Brass casing physics)
--------------------------------------------------------------------
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

--------------------------------------------------------------------
--- Utility: check if a wall sprite is a low wall (fence/railing)
--- (from Hot Brass SpentCasingPhysics.isLowWall)
--------------------------------------------------------------------
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

--------------------------------------------------------------------
--- Utility: check if a wall/door/window blocks between two squares
--- Low walls only block if ordnance is below LOW_WALL_Z_THRESHOLD.
--- (from Hot Brass SpentCasingPhysics)
--------------------------------------------------------------------
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

--------------------------------------------------------------------
--- Utility: remove a world item from its square
--- (from Hot Brass SpentCasingPhysics.removeWorldItem)
--------------------------------------------------------------------
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

--------------------------------------------------------------------
--- Utility: get the top surface Z offset on a square
--- (from Hot Brass SpentCasingPhysics.getTileTopZ)
--------------------------------------------------------------------
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

--------------------------------------------------------------------
--- GameTime helper
--------------------------------------------------------------------
function ExplosivesSystems.GT()
    return GameTime.getInstance()
end

--------------------------------------------------------------------
--- Spawn ordnance from origin toward destination.
--- Called server-side (or solo).
--------------------------------------------------------------------
function ExplosivesSystems.doSpawnOrdnance(player, sourceWeapon, originX, originY, originZ, destX, destY, destZ)
    local params = OrdnanceFactory.GetParams(sourceWeapon)
    if not params then return end

    local dx       = destX - originX
    local dy       = destY - originY
    local distance = math.sqrt(dx * dx + dy * dy)

    -- Clamp to max throw distance
    local maxDist  = params.maxThrowDist or 20
    if distance > maxDist then
        local ratio = maxDist / distance
        destX       = originX + dx * ratio
        destY       = originY + dy * ratio
        distance    = maxDist
    end

    -- Guided-flight parameters: grenade follows parametric arc to cursor,
    -- then transitions to physics for bouncing.  Guarantees landing at the
    -- aimed position regardless of distance.
    local throwSpeed = math.max(1, params.throwSpeed or 12)
    local arcFactor  = params.arcFactor or 0.12
    local maxArc     = params.maxArc or 1.5

    local flightTime = math.max(0.02, distance / throwSpeed)
    local arcHeight  = math.min(maxArc, distance * arcFactor)

    -- Direction unit vector
    local dirX       = (distance > 0.01) and (dx / distance) or 0
    local dirY       = (distance > 0.01) and (dy / distance) or 0

    -- Determine the square at the origin position
    local sq         = getCell():getGridSquare(math.floor(originX), math.floor(originY), math.floor(originZ))
    if not sq then return end

    -- Determine the world model to display in flight
    local modelType = params.worldModel or sourceWeapon

    local localX = originX - sq:getX()
    local localY = originY - sq:getY()
    local localZ = originZ - sq:getZ()

    -- Create the world item visual
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
        remainingBounces = ExplosivesSystems.randomizeBounces(params.floorBounces or 0),
        -- Guided flight state (parametric arc → physics bounce)
        flightMode       = "guided",
        elapsed          = 0,
        flightTime       = flightTime,
        arcHeight        = arcHeight,
        originWorldX     = originX,
        originWorldY     = originY,
        originZLocal     = localZ,
        destWorldX       = destX,
        destWorldY       = destY,
        guidedDirX       = dirX,
        guidedDirY       = dirY,
        -- Velocities (zero during guided phase; computed on transition)
        velocityX        = 0,
        velocityY        = 0,
        velocityZ        = 0,
    }

    table.insert(ExplosivesSystems.activeOrdnance, ordnanceData)
end

--------------------------------------------------------------------
--- Randomize bounce count: returns a value between 0 and maxBounces
--------------------------------------------------------------------
function ExplosivesSystems.randomizeBounces(maxBounces)
    if maxBounces <= 0 then return 0 end
    return ExplosivesSystems.RANDOM:random(0, maxBounces)
end

--------------------------------------------------------------------
--- Force-detonate ordnance (fuse expired, possibly mid-air)
--------------------------------------------------------------------
function ExplosivesSystems.forceDetonate(ord, index)
    ExplosivesSystems.removeWorldItem(ord)
    Payloads.ResolveImpact(ord)
    ord.active = false
    table.remove(ExplosivesSystems.activeOrdnance, index)
    return true
end

--------------------------------------------------------------------
--- Transition from guided flight to physics-based motion.
--- Computes residual velocity from the parametric trajectory at the
--- current progress t so that wall bounces and floor bounces behave
--- naturally after the guided phase ends.
--------------------------------------------------------------------
function ExplosivesSystems.guidedToPhysics(ord, t)
    if ord.flightMode ~= "guided" then return end
    ord.flightMode    = "physics"

    -- Horizontal approach speed (world units/sec) → internal velocity
    local dist        = math.sqrt(
        (ord.destWorldX - ord.originWorldX) * (ord.destWorldX - ord.originWorldX) +
        (ord.destWorldY - ord.originWorldY) * (ord.destWorldY - ord.originWorldY)
    )
    local hSpeedWorld = (ord.flightTime > 0) and (dist / ord.flightTime) or 0
    local XY_CONV     = ExplosivesSystems.XY_STEP * 60
    local Z_CONV      = ExplosivesSystems.Z_STEP * 60

    -- Retain half of flight speed as residual horizontal velocity for bouncing
    local residual    = 0.5
    ord.velocityX     = ord.guidedDirX * hSpeedWorld * residual / XY_CONV
    ord.velocityY     = ord.guidedDirY * hSpeedWorld * residual / XY_CONV

    -- Z velocity from derivative of arc: z(t) = originZ*(1-t) + arcH*4*t*(1-t)
    --   dz/dt = -originZ + arcH * 4 * (1 - 2t)
    -- Convert from per-normalised-time to per-second, then to internal units
    local dzdt        = -ord.originZLocal + ord.arcHeight * 4.0 * (1.0 - 2.0 * t)
    local zSpeedWorld = (ord.flightTime > 0) and (dzdt / ord.flightTime) or 0
    local zVel        = zSpeedWorld / Z_CONV

    -- Clamp to prevent extreme velocity on very short throws
    zVel              = math.max(zVel, -1.5)
    zVel              = math.min(zVel, 1.5)
    ord.velocityZ     = zVel
end

--------------------------------------------------------------------
--- Guided-flight update: parametric arc trajectory that guarantees
--- the grenade lands at the cursor position.  Handles wall/ceiling
--- collision (transitions to physics on impact) and arrival
--- (transitions to physics for bouncing).
--------------------------------------------------------------------
function ExplosivesSystems.updateGuidedFlight(ord, index, scale, shouldRender)
    local dt = ExplosivesSystems.GT():getTimeDelta()

    -- Advance elapsed time
    ord.elapsed = ord.elapsed + dt
    local t = ord.elapsed / ord.flightTime
    local arrived = t >= 1.0
    if arrived then t = 1.0 end

    -- Save old local position for wall edge-crossing checks
    local oldEdgeX = ord.x
    local oldEdgeY = ord.y

    -- Parametric world position (linear interpolation)
    local worldX   = ord.originWorldX + (ord.destWorldX - ord.originWorldX) * t
    local worldY   = ord.originWorldY + (ord.destWorldY - ord.originWorldY) * t

    -- Parabolic arc: t=0 → originZLocal, t=0.5 → peak, t=1 → 0
    ord.z          = ord.originZLocal * (1.0 - t) + ord.arcHeight * 4.0 * t * (1.0 - t)

    -- Update local coords in current square
    local sx       = ord.square:getX()
    local sy       = ord.square:getY()
    local sz       = ord.square:getZ()
    ord.x          = worldX - sx
    ord.y          = worldY - sy

    ----------------------------------------------------------------
    -- WALL COLLISION (edge-crossing, same logic as physics mode)
    ----------------------------------------------------------------
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

    ----------------------------------------------------------------
    -- WORLD POSITION & SQUARE TRANSITION
    ----------------------------------------------------------------
    worldX = ord.square:getX() + ord.x
    worldY = ord.square:getY() + ord.y
    local targetTileX = math.floor(worldX)
    local targetTileY = math.floor(worldY)

    ----------------------------------------------------------------
    -- CEILING CHECK
    ----------------------------------------------------------------
    if ord.z >= 1.0 then
        local aboveSq = getCell():getGridSquare(targetTileX, targetTileY, sz + 1)
        if aboveSq and aboveSq:TreatAsSolidFloor() then
            if ord.flightMode == "guided" then
                ExplosivesSystems.guidedToPhysics(ord, t)
            end
            ord.velocityZ = -math.abs(ord.velocityZ) * ExplosivesSystems.BOUNCE_RESTITUTION_CEIL
            ord.z = 0.95
        end
    end

    ----------------------------------------------------------------
    -- FLOOR SEARCH (same as physics mode)
    ----------------------------------------------------------------
    local worldZ = sz + ord.z
    local targetSquare = nil
    local checkZ = sz
    while checkZ >= 0 do
        local sq = getCell():getGridSquare(targetTileX, targetTileY, checkZ)
        if not sq then break end
        if sq:getFloor() then
            targetSquare = sq
            break
        end
        checkZ = checkZ - 1
    end

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

    ----------------------------------------------------------------
    -- ARRIVAL: transition to physics for landing / bounce
    ----------------------------------------------------------------
    if arrived and ord.flightMode == "guided" then
        ExplosivesSystems.guidedToPhysics(ord, 1.0)

        if ord.z <= 0.01 then
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
                -- No bounces: settle immediately
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

                if (ord.params.explosionPower or 0) > 0 then
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
        -- If z > 0.01 (thrown off a ledge), physics handles descent
    end

    ----------------------------------------------------------------
    -- CLAMP & VISUAL UPDATE
    ----------------------------------------------------------------
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

--------------------------------------------------------------------
--- Per-tick update of all active ordnance
--- Unified physics loop (Hot Brass pattern)
--------------------------------------------------------------------
function ExplosivesSystems.update()
    local dt           = ExplosivesSystems.GT():getTimeDelta()
    local scale        = dt * 60

    -- Multiplayer render buffer (reduce world item churn)
    local buffer       = 2
    local shouldRender = true
    if isServer() and buffer > 0 then
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

--------------------------------------------------------------------
--- Unified ordnance physics update (replaces separate airborne/settling)
--- Handles: gravity, drag, wall bounce, floor/ceiling, Z-level transitions
--------------------------------------------------------------------
function ExplosivesSystems.updateOrdnance(ord, index, scale, shouldRender)
    local dt = ExplosivesSystems.GT():getTimeDelta()

    ----------------------------------------------------------------
    -- 1. FUSE TIMER (ticks every frame regardless of flight phase)
    ----------------------------------------------------------------
    if ord.detonationTimer > 0 then
        ord.detonationTimer = ord.detonationTimer - dt
        if ord.detonationTimer <= 0 then
            return ExplosivesSystems.forceDetonate(ord, index)
        end
    end

    -- At rest: bounces done, just waiting for timer — no physics
    if ord.atRest then
        return false
    end

    -- Guided flight mode: parametric arc to cursor
    if ord.flightMode == "guided" then
        return ExplosivesSystems.updateGuidedFlight(ord, index, scale, shouldRender)
    end

    ----------------------------------------------------------------
    -- 2. GRAVITY
    ----------------------------------------------------------------
    local prevZ    = ord.z
    ord.velocityZ  = ord.velocityZ - (ExplosivesSystems.GRAVITY * scale)

    ----------------------------------------------------------------
    -- 3. POSITION UPDATE (store old edge positions for wall checks)
    ----------------------------------------------------------------
    local oldEdgeX = ord.x
    local oldEdgeY = ord.y

    ord.x          = ord.x + (ord.velocityX * ExplosivesSystems.XY_STEP * scale)
    ord.y          = ord.y + (ord.velocityY * ExplosivesSystems.XY_STEP * scale)
    ord.z          = ord.z + (ord.velocityZ * ExplosivesSystems.Z_STEP * scale)

    ----------------------------------------------------------------
    -- 4. AIR DRAG (applied every frame, flight and bounce alike)
    ----------------------------------------------------------------
    local dragXY   = math.pow(ExplosivesSystems.DRAG_XY, scale)
    local dragZ    = math.pow(ExplosivesSystems.DRAG_Z, scale)
    ord.velocityX  = ord.velocityX * dragXY
    ord.velocityY  = ord.velocityY * dragXY
    ord.velocityZ  = ord.velocityZ * dragZ

    ----------------------------------------------------------------
    -- 5. WALL COLLISION (edge-based, from Hot Brass)
    --    X and Y checked independently so corner hits bounce both axes
    ----------------------------------------------------------------
    local sx       = ord.square:getX()
    local sy       = ord.square:getY()
    local sz       = ord.square:getZ()
    local EDGE_TOL = ExplosivesSystems.EDGE_TOL

    local blockX   = false
    local blockY   = false

    -- X-axis: crossing right edge
    if ord.velocityX > 0 and oldEdgeX < (1.0 - EDGE_TOL) and ord.x >= (1.0 - EDGE_TOL) then
        local neighbor = getCell():getGridSquare(sx + 1, sy, sz)
        if neighbor and ExplosivesSystems.isBlockedBetweenSquares(
                ord.square, neighbor, IsoDirections.E, ord.z) then
            blockX = true
        end
        -- X-axis: crossing left edge
    elseif ord.velocityX < 0 and oldEdgeX > EDGE_TOL and ord.x <= EDGE_TOL then
        local neighbor = getCell():getGridSquare(sx - 1, sy, sz)
        if neighbor and ExplosivesSystems.isBlockedBetweenSquares(
                ord.square, neighbor, IsoDirections.W, ord.z) then
            blockX = true
        end
    end

    -- Y-axis: crossing south edge
    if ord.velocityY > 0 and oldEdgeY < (1.0 - EDGE_TOL) and ord.y >= (1.0 - EDGE_TOL) then
        local neighbor = getCell():getGridSquare(sx, sy + 1, sz)
        if neighbor and ExplosivesSystems.isBlockedBetweenSquares(
                ord.square, neighbor, IsoDirections.S, ord.z) then
            blockY = true
        end
        -- Y-axis: crossing north edge
    elseif ord.velocityY < 0 and oldEdgeY > EDGE_TOL and ord.y <= EDGE_TOL then
        local neighbor = getCell():getGridSquare(sx, sy - 1, sz)
        if neighbor and ExplosivesSystems.isBlockedBetweenSquares(
                ord.square, neighbor, IsoDirections.N, ord.z) then
            blockY = true
        end
    end

    -- Wall bounce response
    if blockX then
        ord.velocityX = -ord.velocityX * ExplosivesSystems.BOUNCE_RESTITUTION_WALL
        ord.x = ord.x + (ord.velocityX * ExplosivesSystems.BOUNCE_POSITION_CORRECT)
        if math.abs(ord.velocityX) < ExplosivesSystems.BOUNCE_MIN_VELOCITY then
            ord.velocityX = 0
        end
        -- Impact-fused ordnance detonates on wall hit
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

    ----------------------------------------------------------------
    -- 6. WORLD POSITION & SQUARE TRANSITION
    ----------------------------------------------------------------
    local worldX = ord.square:getX() + ord.x
    local worldY = ord.square:getY() + ord.y
    local targetTileX = math.floor(worldX)
    local targetTileY = math.floor(worldY)

    ----------------------------------------------------------------
    -- 7. CEILING CHECK (must happen BEFORE floor transition)
    --    If the grenade reached ceiling height (Z >= 1.0), check
    --    if there is a solid floor directly above on the CURRENT
    --    square's level. A solid floor above = ceiling = bounce.
    --    No floor above = open air, grenade continues upward.
    ----------------------------------------------------------------
    if ord.z >= 1.0 then
        local aboveSq = getCell():getGridSquare(targetTileX, targetTileY, sz + 1)
        if aboveSq and aboveSq:TreatAsSolidFloor() then
            ord.velocityZ = -math.abs(ord.velocityZ) * ExplosivesSystems.BOUNCE_RESTITUTION_CEIL
            ord.z = 0.95
        end
    end

    ----------------------------------------------------------------
    -- 8. FLOOR SEARCH (downward only, like Hot Brass)
    --    Start from the current square's level and search downward.
    --    Grenade can fall to lower floors but never land on an
    --    upper floor — ceiling check (step 7) bounces it back.
    ----------------------------------------------------------------
    local worldZ = sz + ord.z

    local targetSquare = nil
    local checkZ = sz
    while checkZ >= 0 do
        local sq = getCell():getGridSquare(targetTileX, targetTileY, checkZ)
        if not sq then break end
        if sq:getFloor() then
            targetSquare = sq
            break
        end
        checkZ = checkZ - 1
    end

    if targetSquare then
        ord.z = worldZ - targetSquare:getZ()
    else
        targetSquare = ord.square
    end

    ----------------------------------------------------------------
    -- 9. UPDATE SQUARE REFERENCE
    ----------------------------------------------------------------
    if targetSquare ~= ord.square then
        ord.square = targetSquare
    end

    -- Recalculate local coords within the (possibly new) square
    ord.x = worldX - ord.square:getX()
    ord.y = worldY - ord.square:getY()

    ----------------------------------------------------------------
    -- 10. FLOOR COLLISION & BOUNCE
    ----------------------------------------------------------------
    if ord.z <= 0 then
        ord.z = 0

        -- First floor contact
        if not ord.hasHitFloor then
            ord.hasHitFloor = true
            -- Impact-fused: detonate on first ground contact
            if ord.params.detonateOnImpact then
                return ExplosivesSystems.forceDetonate(ord, index)
            end
        end

        if ord.remainingBounces > 0 then
            -- Execute floor bounce
            ord.remainingBounces = ord.remainingBounces - 1
            ord.z = 0.01
            local restitution = ord.params.bounceEnergy or 0.45
            ord.velocityZ = math.abs(ord.velocityZ) * restitution
            ord.velocityX = ord.velocityX * 0.6
            ord.velocityY = ord.velocityY * 0.6

            -- Play bounce sound
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
            -- Bounces exhausted → final rest
            ord.atRest    = true
            ord.velocityX = 0
            ord.velocityY = 0
            ord.velocityZ = 0
            ord.z         = 0

            -- Place final resting visual once
            if shouldRender then
                ExplosivesSystems.removeWorldItem(ord)
                ord.worldItem = ord.square:AddWorldInventoryItem(
                    ord.params.worldModel or ord.sourceWeapon,
                    PZMath.clamp_01(ord.x), PZMath.clamp_01(ord.y), 0
                )
            end

            -- Explosive with remaining timer: keep alive
            if (ord.params.explosionPower or 0) > 0 then
                if ord.detonationTimer <= 0 then
                    return ExplosivesSystems.forceDetonate(ord, index)
                end
                return false
            end

            -- Non-explosive: fire hooks and remove
            Payloads.ResolveImpact(ord)
            ord.active = false
            table.remove(ExplosivesSystems.activeOrdnance, index)
            return true
        end
    end

    ----------------------------------------------------------------
    -- 11. CLAMP & VISUAL UPDATE
    ----------------------------------------------------------------
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

--------------------------------------------------------------------
--- Server command handler: receive throw requests from clients
--------------------------------------------------------------------
function ExplosivesSystems.onClientCommand(module, command, player, args)
    if module ~= ExplosivesSystems.MODULE_NAME then return end
    if not player or not args then return end

    if command == "throwOrdnance" then
        local sourceWeapon = args.sourceWeapon
        if not sourceWeapon then return end
        if not OrdnanceFactory.IsRegistered(sourceWeapon) then return end

        local px = player:getX()
        local py = player:getY()
        local pz = player:getZ()

        local params = OrdnanceFactory.GetParams(sourceWeapon)
        if not params then return end

        -- Compute spawn position from player facing
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

        -- Spawn the ordnance server-side
        ExplosivesSystems.doSpawnOrdnance(player, sourceWeapon, originX, originY, originZ, destX, destY, destZ)

        -- Broadcast to other clients for visual sync
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
