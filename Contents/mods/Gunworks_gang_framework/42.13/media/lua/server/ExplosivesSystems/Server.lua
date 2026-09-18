local ExplosivesSystems          = require("ExplosivesSystems/Physics")
local Payloads                   = require("ExplosivesSystems/Payloads")
local OrdnanceFactory            = require("ExplosivesSystems/OrdnanceFactory")
local r                          = newrandom()

ExplosivesSystems.activeOrdnance = {}
ExplosivesSystems.nextOrdnanceId = 0

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

function ExplosivesSystems.randomizeBounces(maxBounces)
    if maxBounces <= 0 then return 1 end
    return r:random(1, maxBounces)
end

function ExplosivesSystems.doSpawnOrdnance(player, sourceWeapon, originX, originY, originZ, destX, destY, destZ, isAmmoLaunch)
    local params
    if isAmmoLaunch then
        params = OrdnanceFactory.GetAmmoParams(sourceWeapon)
    else
        params = OrdnanceFactory.GetParams(sourceWeapon)
    end
    if not params then return end

    local seedVelX, seedVelY, seedVelZ = ExplosivesSystems.computeLaunchVelocity(
        params, originX, originY, originZ, destX, destY, destZ)

    local sq = getCell():getGridSquare(math.floor(originX), math.floor(originY), math.floor(originZ))
    if not sq then
        sq = player and player:getCurrentSquare() or nil
        if not sq then return end
    end

    local localX = originX - sq:getX()
    local localY = originY - sq:getY()
    local localZ = originZ - sq:getZ()

    local remainingBounces = ExplosivesSystems.randomizeBounces(params.floorBounces or 1)

    local initialRotation, spinSpeed
    if params.directProjectile then
        local playerDirection = player:getDirectionAngle()
        initialRotation = playerDirection < 0 and (playerDirection + 360) or playerDirection
        spinSpeed = 0
    else
        local spinForce = params.spinForce or { 10, 30 }
        initialRotation = r:random(0, 359)
        spinSpeed = r:random(spinForce[1], spinForce[2])
    end

    ExplosivesSystems.nextOrdnanceId = ExplosivesSystems.nextOrdnanceId + 1
    local ordnanceId = ExplosivesSystems.nextOrdnanceId

    local visualArgs = {
        ordnanceId       = ordnanceId,
        sourceWeapon     = sourceWeapon,
        isAmmoLaunch     = isAmmoLaunch,
        originX          = originX,
        originY          = originY,
        originZ          = originZ,
        destX            = destX,
        destY            = destY,
        destZ            = destZ,
        remainingBounces = remainingBounces,
        shooterOnlineID  = player and player:getOnlineID() or -1,
        rotation         = initialRotation,
        spinSpeed        = spinSpeed,
    }

    if isServer() then
        sendServerCommand(ExplosivesSystems.MODULE_NAME, "spawnOrdnanceVisual", visualArgs)
    elseif ExplosivesSystems.spawnVisualOrdnance then
        ExplosivesSystems.spawnVisualOrdnance(visualArgs)
    end

    local detonationTimer = params.detonationDelay or 0
    local ordnanceData = {
        ordnanceId       = ordnanceId,
        player           = player,
        params           = params,
        sourceWeapon     = sourceWeapon,
        square           = sq,
        x                = localX,
        y                = localY,
        z                = localZ,
        active           = true,
        detonationTimer  = detonationTimer,
        hasHitFloor      = false,
        atRest           = false,
        remainingBounces = remainingBounces,
        prevWorldZ       = originZ,
        velocityX        = seedVelX,
        velocityY        = seedVelY,
        velocityZ        = seedVelZ,
        rotation         = initialRotation,
        spinSpeed        = spinSpeed,
    }

    local list = ExplosivesSystems.activeOrdnance
    list[#list + 1] = ordnanceData
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

function ExplosivesSystems.forceDetonate(ord, index)
    ExplosivesSystems.removeWorldItem(ord)

    if isServer() then
        sendServerCommand(ExplosivesSystems.MODULE_NAME, "removeOrdnanceVisual", {
            ordnanceId = ord.ordnanceId,
        })
    elseif ExplosivesSystems.removeVisualOrdnance then
        ExplosivesSystems.removeVisualOrdnance(ord.ordnanceId)
    end

    Payloads.ResolveImpact(ord)

    if ord.params and ord.params.explosionFXObject then
        local fxArgs = {
            sqX      = ord.square:getX(),
            sqY      = ord.square:getY(),
            sqZ      = ord.square:getZ(),
            itemType = ord.params.explosionFXObject,
            lx       = ord.x,
            ly       = ord.y,
            lz       = ord.z,
            duration = ord.params.explosionFXDuration,
            frames   = ord.params.frames,
        }

        if isServer() then
            sendServerCommand(ExplosivesSystems.MODULE_NAME, "playExplosionFX", fxArgs)
        elseif ExplosivesSystems.PlayExplosionFXLocal then
            ExplosivesSystems.PlayExplosionFXLocal(
                ord.square, fxArgs.itemType, fxArgs.lx, fxArgs.ly, fxArgs.lz, fxArgs.duration, fxArgs.frames)
        end
    end

    ord.active = false
    local list = ExplosivesSystems.activeOrdnance
    local lastIndex = #list
    list[index] = list[lastIndex]
    list[lastIndex] = nil
    return true
end

function ExplosivesSystems.update()
    local dt    = ExplosivesSystems.GT():getTimeDelta()
    local scale = dt * 60

    local i     = 1
    while i <= #ExplosivesSystems.activeOrdnance do
        local ord     = ExplosivesSystems.activeOrdnance[i]
        local removed = false

        if not ord or not ord.active then
            local list = ExplosivesSystems.activeOrdnance
            local lastIndex = #list
            list[i] = list[lastIndex]
            list[lastIndex] = nil
            removed = true
        else
            removed = ExplosivesSystems.updateOrdnance(ord, i, scale)
        end

        if not removed then
            i = i + 1
        end
    end
end

function ExplosivesSystems.updateOrdnance(ord, index, scale)
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

    local status = ExplosivesSystems.stepOrdnance(ord, scale)
    ord.rotation = (ord.rotation + ord.spinSpeed * scale) % 360

    if status == "wallhit" or status == "floorimpact" then
        return ExplosivesSystems.forceDetonate(ord, index)
    end

    if status == "rest" then
        ord.atRest = true

        if ord.params.detonateOnImpact or (ord.params.detonationDelay or 0) > 0 then
            if ord.detonationTimer <= 0 then
                return ExplosivesSystems.forceDetonate(ord, index)
            end

            ord.worldItem = ord.square:AddWorldInventoryItem(
                ord.params.worldModel or ord.sourceWeapon,
                ord.x, ord.y, ord.z
            )
            if ord.worldItem then
                ord.worldItem:setWorldZRotation(ord.rotation)
            end
            return false
        end

        ord.worldItem = ord.square:AddWorldInventoryItem(
            ord.params.worldModel or ord.sourceWeapon,
            ord.x, ord.y, ord.z
        )
        if ord.worldItem then
            ord.worldItem:setWorldZRotation(ord.rotation)
        end

        Payloads.ResolveImpact(ord)
        ord.active = false
        local list = ExplosivesSystems.activeOrdnance
        local lastIndex = #list
        list[index] = list[lastIndex]
        list[lastIndex] = nil
        return true
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
    end
end

Events.OnClientCommand.Add(ExplosivesSystems.onClientCommand)
Events.OnTick.Add(ExplosivesSystems.update)
