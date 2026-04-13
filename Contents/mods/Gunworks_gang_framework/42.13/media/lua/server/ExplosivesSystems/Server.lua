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
ExplosivesSystems.DRAG_XY                 = 0.97
ExplosivesSystems.DRAG_Z                  = 0.995
ExplosivesSystems.BOUNCE_RESTITUTION_WALL = 0.50
ExplosivesSystems.BOUNCE_POSITION_CORRECT = 0.12
ExplosivesSystems.BOUNCE_MIN_VELOCITY     = 0.004

--------------------------------------------------------------------
--- Utility: check if a wall/door/window blocks between two squares
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
    local throwParams = OrdnanceFactory.GetThrowParams(sourceWeapon)
    if not throwParams then return end

    local explosiveParams = OrdnanceFactory.GetExplosiveParams(sourceWeapon) -- may be nil

    local dx              = destX - originX
    local dy              = destY - originY
    local distance        = math.sqrt(dx * dx + dy * dy)

    -- Clamp to max throw distance
    local maxDist         = throwParams.maxThrowDist or 20
    if distance > maxDist then
        local ratio = maxDist / distance
        destX       = originX + dx * ratio
        destY       = originY + dy * ratio
        distance    = maxDist
    end

    -- Travel duration in seconds
    local force          = throwParams.throwForce or 12
    local travelDuration = distance / force
    if travelDuration < 0.1 then travelDuration = 0.1 end

    -- Lob peak height: how high the arc goes above the baseline
    local lobFactor = throwParams.lobHeight or 0.3
    local lobPeak   = math.max(1.5, distance * lobFactor)

    -- Determine the square at the origin position
    local sq        = getCell():getGridSquare(math.floor(originX), math.floor(originY), math.floor(originZ))
    if not sq then return end

    -- Determine the world model to display in flight
    local modelType = throwParams.worldModel or sourceWeapon

    local localX = originX - sq:getX()
    local localY = originY - sq:getY()
    local localZ = originZ - sq:getZ()

    -- Create the world item visual
    local worldItem = sq:AddWorldInventoryItem(modelType, localX, localY, localZ)

    -- Determine detonation timer from explosive params (if present)
    local detonationTimer = 0
    if explosiveParams then
        detonationTimer = explosiveParams.detonationDelay or 0
    end

    local ordnanceData = {
        player           = player,
        throwParams      = throwParams,
        explosiveParams  = explosiveParams,
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
        elapsed          = 0,
        travelDuration   = travelDuration,
        lobPeak          = lobPeak,
        worldItem        = worldItem,
        active           = true,
        detonationTimer  = detonationTimer,
        settled          = false,
        remainingBounces = ExplosivesSystems.randomizeBounces(throwParams.floorBounces or 0),
        -- Velocity fields used during settling / bounce phase
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
--- Per-tick update of all active ordnance
--- (mirrors SpentCasingPhysics.update)
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
        elseif ord.settled then
            -- Post-impact: bouncing or waiting on detonation timer
            removed = ExplosivesSystems.updateSettling(ord, i, scale, shouldRender)
        else
            -- In-flight: lobbed arc interpolation
            removed = ExplosivesSystems.updateAirborne(ord, i, scale, shouldRender)
        end

        if not removed then
            i = i + 1
        end
    end
end

--------------------------------------------------------------------
--- Update ordnance that is still airborne (lobbed arc)
--------------------------------------------------------------------
function ExplosivesSystems.updateAirborne(ord, index, scale, shouldRender)
    local dt = ExplosivesSystems.GT():getTimeDelta()

    -- Tick fuse timer during flight (mid-air detonation, timer-fused only)
    if ord.explosiveParams and not ord.explosiveParams.detonateOnImpact and ord.detonationTimer > 0 then
        ord.detonationTimer = ord.detonationTimer - dt
        if ord.detonationTimer <= 0 then
            return ExplosivesSystems.forceDetonate(ord, index)
        end
    end

    ord.elapsed = ord.elapsed + dt

    -- Normalized progress [0, 1]
    local progress = ord.elapsed / ord.travelDuration
    if progress > 1.0 then progress = 1.0 end

    -- Horizontal: linear interpolation along throw direction
    local worldX = ord.originX + (ord.destX - ord.originX) * progress
    local worldY = ord.originY + (ord.destY - ord.originY) * progress

    -- Vertical: linear base + parabolic lob
    local baseZ  = ord.originZ + (ord.destZ - ord.originZ) * progress
    local lobZ   = ord.lobPeak * 4.0 * progress * (1.0 - progress)
    local worldZ = baseZ + lobZ

    -- Find the grid square at this position
    local floorZ = math.floor(ord.originZ)
    local nextSq = getCell():getGridSquare(math.floor(worldX), math.floor(worldY), floorZ)

    -- Check for wall collision between current and new square
    if nextSq and ord.square and nextSq ~= ord.square then
        local sx = ord.square:getX()
        local sy = ord.square:getY()
        local tx = nextSq:getX()
        local ty = nextSq:getY()

        local blocked = false
        if tx > sx then
            blocked = ExplosivesSystems.isBlockedBetweenSquares(ord.square, nextSq, IsoDirections.E, worldZ - floorZ)
        elseif tx < sx then
            blocked = ExplosivesSystems.isBlockedBetweenSquares(ord.square, nextSq, IsoDirections.W, worldZ - floorZ)
        end
        if not blocked and ty > sy then
            blocked = ExplosivesSystems.isBlockedBetweenSquares(ord.square, nextSq, IsoDirections.S, worldZ - floorZ)
        elseif not blocked and ty < sy then
            blocked = ExplosivesSystems.isBlockedBetweenSquares(ord.square, nextSq, IsoDirections.N, worldZ - floorZ)
        end

        if blocked then
            -- Hit a wall → settle immediately at current square
            ExplosivesSystems.beginSettling(ord, ord.square)
            return ExplosivesSystems.resolveOnImpact(ord, index)
        end
    end

    if not nextSq then
        nextSq = ord.square
    end

    -- Update position
    local localX = worldX - nextSq:getX()
    local localY = worldY - nextSq:getY()
    local localZ = worldZ - floorZ

    -- Check ground collision (arc descending below floor)
    if progress >= 1.0 or localZ <= 0 then
        localZ = math.max(0, localZ)
        ExplosivesSystems.beginSettling(ord, nextSq)
        return ExplosivesSystems.resolveOnImpact(ord, index)
    end

    -- Update visual
    if shouldRender then
        ExplosivesSystems.removeWorldItem(ord)
        ord.worldItem = nextSq:AddWorldInventoryItem(
            ord.throwParams.worldModel or ord.sourceWeapon,
            PZMath.clamp_01(localX),
            PZMath.clamp_01(localY),
            localZ
        )
    end

    ord.square = nextSq
    ord.x = localX
    ord.y = localY
    ord.z = localZ

    return false
end

--------------------------------------------------------------------
--- Transition ordnance to settled state – compute residual velocity
--- for bounces (mirrors casing floor-bounce setup)
--------------------------------------------------------------------
function ExplosivesSystems.beginSettling(ord, square)
    ord.settled     = true
    ord.square      = square

    -- Calculate residual velocity from throw direction
    local dx        = ord.destX - ord.originX
    local dy        = ord.destY - ord.originY
    local totalDist = math.sqrt(dx * dx + dy * dy)
    if totalDist < 0.01 then totalDist = 0.01 end

    local dirX = dx / totalDist
    local dirY = dy / totalDist

    -- Remaining speed factor (slower at end of arc)
    local residualForce = (ord.throwParams.throwForce or 12) * 0.15
    ord.velocityX = dirX * residualForce * 0.1
    ord.velocityY = dirY * residualForce * 0.1
    ord.velocityZ = 0.04 -- small upward bounce

    ord.x = PZMath.clamp_01(ord.x or 0.5)
    ord.y = PZMath.clamp_01(ord.y or 0.5)
    ord.z = 0.05
end

--------------------------------------------------------------------
--- Resolve impact: decide whether to detonate now or enter settling.
--- Called once when ordnance first contacts ground / wall.
---
--- detonateOnImpact = true  → explode on ANY collision, ignore timer
--- detonateOnImpact = false → never explode on collision, timer only
--------------------------------------------------------------------
function ExplosivesSystems.resolveOnImpact(ord, index)
    local explosive = ord.explosiveParams

    if explosive then
        if explosive.detonateOnImpact then
            -- Impact-fused: detonate immediately on any collision
            return ExplosivesSystems.forceDetonate(ord, index)
        end
        -- Timer-fused: let it bounce/settle, timer handles detonation
        return false
    else
        -- Non-explosive ordnance
        if ord.remainingBounces > 0 then
            return false -- let it bounce in settling phase
        end
        -- Just landed: fire hooks, leave world item on ground
        Payloads.ResolveImpact(ord)
        ord.active = false
        table.remove(ExplosivesSystems.activeOrdnance, index)
        return true
    end
end

--------------------------------------------------------------------
--- Update settled ordnance (bouncing / detonation countdown)
--- (mirrors SpentCasingPhysics bounce logic)
--------------------------------------------------------------------
function ExplosivesSystems.updateSettling(ord, index, scale, shouldRender)
    local explosive = ord.explosiveParams

    -- Detonation timer countdown (explosive ordnance only)
    local dt = ExplosivesSystems.GT():getTimeDelta()
    if explosive and ord.detonationTimer > 0 then
        ord.detonationTimer = ord.detonationTimer - dt
        if ord.detonationTimer <= 0 then
            return ExplosivesSystems.forceDetonate(ord, index)
        end
    end

    -- Bounce / drift physics
    local stillActive = ord.remainingBounces > 0 or (explosive and ord.detonationTimer > 0)

    if stillActive then
        ord.velocityZ = ord.velocityZ - (ExplosivesSystems.GRAVITY * scale)
        ord.x         = ord.x + (ord.velocityX * ExplosivesSystems.XY_STEP * scale)
        ord.y         = ord.y + (ord.velocityY * ExplosivesSystems.XY_STEP * scale)
        ord.z         = ord.z + (ord.velocityZ * ExplosivesSystems.Z_STEP * scale)

        local dragXY  = math.pow(ExplosivesSystems.DRAG_XY, scale)
        local dragZ   = math.pow(ExplosivesSystems.DRAG_Z, scale)
        ord.velocityX = ord.velocityX * dragXY
        ord.velocityY = ord.velocityY * dragXY
        ord.velocityZ = ord.velocityZ * dragZ

        -- Floor bounce
        if ord.z <= 0 then
            ord.z = 0.01
            if ord.remainingBounces > 0 then
                ord.remainingBounces = ord.remainingBounces - 1
                local restitution = ord.throwParams.bounceEnergy or 0.45
                ord.velocityZ = math.abs(ord.velocityZ) * restitution
                ord.velocityX = ord.velocityX * 0.6
                ord.velocityY = ord.velocityY * 0.6

                -- Play bounce sound (uses throwParams.soundBounce, NOT the detonation sound)
                local bounceSound = ord.throwParams.soundBounce
                if bounceSound and ord.player then
                    if isServer() then
                        sendServerCommand(ord.player, ExplosivesSystems.MODULE_NAME, "playSound", {
                            sound = bounceSound
                        })
                    elseif ord.player.getEmitter then
                        ord.player:getEmitter():playSound(bounceSound)
                    end
                end
            end

            -- Check if bouncing is done
            if ord.remainingBounces <= 0 then
                if explosive then
                    if ord.detonationTimer <= 0 then
                        -- No timer remaining: detonate now
                        return ExplosivesSystems.forceDetonate(ord, index)
                    end
                    -- Still waiting for detonation timer (fuse-style)
                else
                    -- Non-explosive, done bouncing: stop and fire hooks
                    Payloads.ResolveImpact(ord)
                    ord.active = false
                    table.remove(ExplosivesSystems.activeOrdnance, index)
                    return true
                end
            end
        end

        -- Square transitions
        local worldX = ord.square:getX() + ord.x
        local worldY = ord.square:getY() + ord.y
        local targetTileX = math.floor(worldX)
        local targetTileY = math.floor(worldY)
        local newSq = getCell():getGridSquare(targetTileX, targetTileY, ord.square:getZ())
        if newSq and newSq ~= ord.square then
            ord.square = newSq
        end

        ord.x = PZMath.clamp_01(worldX - ord.square:getX())
        ord.y = PZMath.clamp_01(worldY - ord.square:getY())
        ord.z = math.max(0, ord.z)

        -- Update visual
        if shouldRender then
            ExplosivesSystems.removeWorldItem(ord)
            ord.worldItem = ord.square:AddWorldInventoryItem(
                ord.throwParams.worldModel or ord.sourceWeapon,
                ord.x, ord.y, ord.z
            )
        end
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

        local throwParams = OrdnanceFactory.GetThrowParams(sourceWeapon)
        if not throwParams then return end

        -- Compute spawn position from player facing
        local angleDeg = player:getDirectionAngle() or 0
        local angleRad = math.rad(angleDeg)
        local fwd      = throwParams.forwardOffset or 0.50
        local hOff     = throwParams.heightOffset or 0.55

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
