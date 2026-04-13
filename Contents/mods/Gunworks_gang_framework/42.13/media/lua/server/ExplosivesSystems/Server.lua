local ExplosivesSystems                   = require("ExplosivesSystems/Init")
local Payloads                            = require("ExplosivesSystems/Payloads")

--------------------------------------------------------------------
--- Active projectiles list
--------------------------------------------------------------------
ExplosivesSystems.activeProjectiles       = {}
ExplosivesSystems.RANDOM                  = newrandom()
ExplosivesSystems.updateCounter           = 0

--------------------------------------------------------------------
--- Physics constants
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
--- (adapted from Hot Brass SpentCasingPhysics)
--------------------------------------------------------------------
function ExplosivesSystems.isBlockedBetweenSquares(fromSq, toSq, dir, projZ)
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
--------------------------------------------------------------------
function ExplosivesSystems.removeWorldItem(proj)
    if not proj.worldItem then return end
    local wobj = proj.worldItem:getWorldItem()
    if wobj then
        local wSquare = wobj:getSquare()
        if wSquare then
            if isServer() then
                wSquare:transmitRemoveItemFromSquare(wobj)
            end
            wSquare:removeWorldObject(wobj)
        end
    end
    proj.worldItem = nil
end

--------------------------------------------------------------------
--- Utility: get the top surface Z offset on a square
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
--- Launch a projectile from startPos toward targetPos
--- Called server-side (or solo).
--------------------------------------------------------------------
function ExplosivesSystems.Launch(player, weaponFullType, startX, startY, startZ, targetX, targetY, targetZ)
    local config = ExplosivesSystems.GetConfig(weaponFullType)
    if not config then return end

    local dx       = targetX - startX
    local dy       = targetY - startY
    local dz       = targetZ - startZ
    local distance = math.sqrt(dx * dx + dy * dy)

    -- Clamp to max range
    if distance > config.MaxRange then
        local scale = config.MaxRange / distance
        targetX = startX + dx * scale
        targetY = startY + dy * scale
        distance = config.MaxRange
    end

    -- Flight time in seconds, then convert to ticks (60 tps assumed for normalization)
    local speed      = config.Speed or 12
    local flightTime = distance / speed
    if flightTime < 0.1 then flightTime = 0.1 end

    local arcFactor = config.ArcHeightFactor or 0.3
    local arcHeight = math.max(1.5, distance * arcFactor)

    -- Determine the square at the start position
    local sq = getCell():getGridSquare(math.floor(startX), math.floor(startY), math.floor(startZ))
    if not sq then return end

    -- Determine the projectile item to display
    local projectileItemType = config.ProjectileItem or weaponFullType

    local localX = startX - sq:getX()
    local localY = startY - sq:getY()
    local localZ = startZ - sq:getZ()

    -- Create the world item visual
    local worldItem = sq:AddWorldInventoryItem(projectileItemType, localX, localY, localZ)

    local projData = {
        player         = player,
        config         = config,
        weaponFullType = weaponFullType,
        square         = sq,
        startX         = startX,
        startY         = startY,
        startZ         = startZ,
        targetX        = targetX,
        targetY        = targetY,
        targetZ        = targetZ,
        x              = localX,
        y              = localY,
        z              = localZ,
        timeElapsed    = 0,
        flightTime     = flightTime,
        arcHeight      = arcHeight,
        worldItem      = worldItem,
        active         = true,
        fuseTimer      = config.FuseDelay or 0,
        landed         = false,
        bounces        = config.Bounces or 0,
        -- For bounce-based physics (after landing, if bounces > 0)
        velocityX      = 0,
        velocityY      = 0,
        velocityZ      = 0,
    }

    table.insert(ExplosivesSystems.activeProjectiles, projData)
end

--------------------------------------------------------------------
--- Per-tick update of all active projectiles
--------------------------------------------------------------------
function ExplosivesSystems.UpdateProjectiles()
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
    while i <= #ExplosivesSystems.activeProjectiles do
        local proj    = ExplosivesSystems.activeProjectiles[i]
        local removed = false

        if not proj or not proj.active then
            table.remove(ExplosivesSystems.activeProjectiles, i)
            removed = true
        elseif proj.landed then
            -- Post-landing: either waiting on fuse or bouncing
            removed = ExplosivesSystems.updateLanded(proj, i, scale, shouldRender)
        else
            -- In-flight: parabolic arc interpolation
            removed = ExplosivesSystems.updateInFlight(proj, i, scale, shouldRender)
        end

        if not removed then
            i = i + 1
        end
    end
end

--------------------------------------------------------------------
--- Update a projectile that is still in flight (parabolic arc)
--------------------------------------------------------------------
function ExplosivesSystems.updateInFlight(proj, index, scale, shouldRender)
    local dt = ExplosivesSystems.GT():getTimeDelta()

    proj.timeElapsed = proj.timeElapsed + dt

    -- Normalized progress [0, 1]
    local t = proj.timeElapsed / proj.flightTime
    if t > 1.0 then t = 1.0 end

    -- Horizontal: linear interpolation
    local worldX   = proj.startX + (proj.targetX - proj.startX) * t
    local worldY   = proj.startY + (proj.targetY - proj.startY) * t

    -- Vertical: linear base + parabolic arc
    local baseZ    = proj.startZ + (proj.targetZ - proj.startZ) * t
    local arcZ     = proj.arcHeight * 4.0 * t * (1.0 - t)
    local worldZ   = baseZ + arcZ

    -- Find the grid square at this position
    local floorZ   = math.floor(proj.startZ)
    local targetSq = getCell():getGridSquare(math.floor(worldX), math.floor(worldY), floorZ)

    -- Check for wall collision between current and new square
    if targetSq and proj.square and targetSq ~= proj.square then
        local sx = proj.square:getX()
        local sy = proj.square:getY()
        local tx = targetSq:getX()
        local ty = targetSq:getY()

        local blocked = false
        if tx > sx then
            blocked = ExplosivesSystems.isBlockedBetweenSquares(proj.square, targetSq, IsoDirections.E, worldZ - floorZ)
        elseif tx < sx then
            blocked = ExplosivesSystems.isBlockedBetweenSquares(proj.square, targetSq, IsoDirections.W, worldZ - floorZ)
        end
        if not blocked and ty > sy then
            blocked = ExplosivesSystems.isBlockedBetweenSquares(proj.square, targetSq, IsoDirections.S, worldZ - floorZ)
        elseif not blocked and ty < sy then
            blocked = ExplosivesSystems.isBlockedBetweenSquares(proj.square, targetSq, IsoDirections.N, worldZ - floorZ)
        end

        if blocked then
            -- Hit a wall → land immediately at current square
            ExplosivesSystems.landProjectile(proj, proj.square)
            return ExplosivesSystems.handleLanding(proj, index)
        end
    end

    if not targetSq then
        targetSq = proj.square
    end

    -- Update position
    local localX = worldX - targetSq:getX()
    local localY = worldY - targetSq:getY()
    local localZ = worldZ - floorZ

    -- Check ground collision (arc descending below floor)
    if t >= 1.0 or localZ <= 0 then
        localZ = math.max(0, localZ)
        ExplosivesSystems.landProjectile(proj, targetSq)
        return ExplosivesSystems.handleLanding(proj, index)
    end

    -- Update visual
    if shouldRender then
        ExplosivesSystems.removeWorldItem(proj)
        proj.worldItem = targetSq:AddWorldInventoryItem(
            proj.config.ProjectileItem or proj.weaponFullType,
            PZMath.clamp_01(localX),
            PZMath.clamp_01(localY),
            localZ
        )
    end

    proj.square = targetSq
    proj.x = localX
    proj.y = localY
    proj.z = localZ

    return false
end

--------------------------------------------------------------------
--- Mark projectile as landed – compute residual velocity for bounces
--------------------------------------------------------------------
function ExplosivesSystems.landProjectile(proj, square)
    proj.landed = true
    proj.square = square

    -- Calculate residual velocity from the arc's derivative at t=1
    local dx = proj.targetX - proj.startX
    local dy = proj.targetY - proj.startY
    local totalDist = math.sqrt(dx * dx + dy * dy)
    if totalDist < 0.01 then totalDist = 0.01 end

    local dirX = dx / totalDist
    local dirY = dy / totalDist

    -- Remaining speed factor (slower at end of arc )
    local residualSpeed = (proj.config.Speed or 12) * 0.15
    proj.velocityX = dirX * residualSpeed * 0.1
    proj.velocityY = dirY * residualSpeed * 0.1
    proj.velocityZ = 0.04 -- small upward bounce

    proj.x = PZMath.clamp_01(proj.x or 0.5)
    proj.y = PZMath.clamp_01(proj.y or 0.5)
    proj.z = 0.05
end

--------------------------------------------------------------------
--- Handle landing: detonate immediately or start bounce/fuse
--------------------------------------------------------------------
function ExplosivesSystems.handleLanding(proj, index)
    if proj.bounces <= 0 and proj.fuseTimer <= 0 then
        -- Immediate detonation
        ExplosivesSystems.removeWorldItem(proj)
        Payloads.ResolveLanding(proj)
        proj.active = false
        table.remove(ExplosivesSystems.activeProjectiles, index)
        return true
    end
    -- Has bounces or fuse: don't remove yet, handled in updateLanded
    return false
end

--------------------------------------------------------------------
--- Update a landed projectile (bouncing / fuse countdown)
--------------------------------------------------------------------
function ExplosivesSystems.updateLanded(proj, index, scale, shouldRender)
    -- Fuse countdown
    if proj.fuseTimer > 0 then
        proj.fuseTimer = proj.fuseTimer - 1
        if proj.fuseTimer <= 0 and proj.bounces <= 0 then
            ExplosivesSystems.removeWorldItem(proj)
            Payloads.ResolveLanding(proj)
            proj.active = false
            table.remove(ExplosivesSystems.activeProjectiles, index)
            return true
        end
    end

    -- Bounce physics (simplified gravity + drag)
    if proj.bounces > 0 or proj.fuseTimer > 0 then
        proj.velocityZ = proj.velocityZ - (ExplosivesSystems.GRAVITY * scale)
        proj.x         = proj.x + (proj.velocityX * ExplosivesSystems.XY_STEP * scale)
        proj.y         = proj.y + (proj.velocityY * ExplosivesSystems.XY_STEP * scale)
        proj.z         = proj.z + (proj.velocityZ * ExplosivesSystems.Z_STEP * scale)

        local dragXY   = math.pow(ExplosivesSystems.DRAG_XY, scale)
        local dragZ    = math.pow(ExplosivesSystems.DRAG_Z, scale)
        proj.velocityX = proj.velocityX * dragXY
        proj.velocityY = proj.velocityY * dragXY
        proj.velocityZ = proj.velocityZ * dragZ

        -- Floor bounce
        if proj.z <= 0 then
            proj.z = 0.01
            if proj.bounces > 0 then
                proj.bounces = proj.bounces - 1
                local restitution = proj.config.BounceRestitution or 0.45
                proj.velocityZ = math.abs(proj.velocityZ) * restitution
                proj.velocityX = proj.velocityX * 0.6
                proj.velocityY = proj.velocityY * 0.6

                -- Play bounce sound
                if proj.player and proj.config.SoundImpact then
                    if isServer() then
                        sendServerCommand(proj.player, ExplosivesSystems.MODULE_NAME, "playSound", {
                            sound = proj.config.SoundImpact
                        })
                    elseif proj.player.getEmitter then
                        proj.player:getEmitter():playSound(proj.config.SoundImpact)
                    end
                end
            end

            -- If no more bounces and no fuse, detonate
            if proj.bounces <= 0 and proj.fuseTimer <= 0 then
                ExplosivesSystems.removeWorldItem(proj)
                Payloads.ResolveLanding(proj)
                proj.active = false
                table.remove(ExplosivesSystems.activeProjectiles, index)
                return true
            end
        end

        -- Square transitions
        local worldX = proj.square:getX() + proj.x
        local worldY = proj.square:getY() + proj.y
        local targetTileX = math.floor(worldX)
        local targetTileY = math.floor(worldY)
        local newSq = getCell():getGridSquare(targetTileX, targetTileY, proj.square:getZ())
        if newSq and newSq ~= proj.square then
            proj.square = newSq
        end

        proj.x = PZMath.clamp_01(worldX - proj.square:getX())
        proj.y = PZMath.clamp_01(worldY - proj.square:getY())
        proj.z = math.max(0, proj.z)

        -- Update visual
        if shouldRender then
            ExplosivesSystems.removeWorldItem(proj)
            proj.worldItem = proj.square:AddWorldInventoryItem(
                proj.config.ProjectileItem or proj.weaponFullType,
                proj.x, proj.y, proj.z
            )
        end
    end

    return false
end

--------------------------------------------------------------------
--- Server command handler: receive launch requests from clients
--------------------------------------------------------------------
function ExplosivesSystems.onClientCommand(module, command, player, args)
    if module ~= ExplosivesSystems.MODULE_NAME then return end
    if not player or not args then return end

    if command == "Launch" then
        local weaponFullType = args.weaponFullType
        if not weaponFullType then return end
        if not ExplosivesSystems.IsRegistered(weaponFullType) then return end

        local px = player:getX()
        local py = player:getY()
        local pz = player:getZ()

        local config = ExplosivesSystems.GetConfig(weaponFullType)
        if not config then return end

        -- Compute spawn position from player facing
        local angleDeg = player:getDirectionAngle() or 0
        local angleRad = math.rad(angleDeg)
        local fwd      = config.ForwardOffset or 0.50
        local hOff     = config.HeightOffset or 0.55

        local startX   = px + math.cos(angleRad) * fwd
        local startY   = py + math.sin(angleRad) * fwd
        local startZ   = pz + hOff

        local targetX  = args.targetX
        local targetY  = args.targetY
        local targetZ  = args.targetZ or pz

        if not targetX or not targetY then return end

        -- Launch the projectile server-side
        ExplosivesSystems.Launch(player, weaponFullType, startX, startY, startZ, targetX, targetY, targetZ)

        -- Broadcast to other clients for visual sync
        if isServer() then
            local onlinePlayers = getOnlinePlayers()
            for i = 0, onlinePlayers:size() - 1 do
                local other = onlinePlayers:get(i)
                if other and other ~= player then
                    sendServerCommand(other, ExplosivesSystems.MODULE_NAME, "RemoteLaunch", {
                        weaponFullType = weaponFullType,
                        startX         = startX,
                        startY         = startY,
                        startZ         = startZ,
                        targetX        = targetX,
                        targetY        = targetY,
                        targetZ        = targetZ,
                    })
                end
            end
        end
    end
end

Events.OnClientCommand.Add(ExplosivesSystems.onClientCommand)
Events.OnTick.Add(ExplosivesSystems.UpdateProjectiles)
