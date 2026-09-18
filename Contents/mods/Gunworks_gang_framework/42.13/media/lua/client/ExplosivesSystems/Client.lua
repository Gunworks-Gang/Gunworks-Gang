local ExplosivesSystems          = require("ExplosivesSystems/Physics")
local OrdnanceFactory            = require("ExplosivesSystems/OrdnanceFactory")

ExplosivesSystems.visualOrdnance = {}

local function suppressVanillaThrow(weapon)
    weapon:setMaxHitCount(0)
    if weapon.setPhysicsObject then
        weapon:setPhysicsObject(nil)
    end
end

local function suppressRegisteredThrowable(weapon)
    if not weapon or not weapon.getFullType then return false end

    local fullType = weapon:getFullType()
    if not fullType or not OrdnanceFactory.IsRegistered(fullType) then
        return false
    end

    suppressVanillaThrow(weapon)
    return true
end

function ExplosivesSystems.onWeaponSwingEarly(player, weapon)
    if not player or not weapon then return end

    if suppressRegisteredThrowable(weapon) then return end

    if not player:isLocalPlayer() then return end
end

function ExplosivesSystems.onWeaponSwingHitPoint(player, weapon)
    if not player or not weapon then return end

    local fullType    = weapon:getFullType()
    local isThrowable = suppressRegisteredThrowable(weapon)

    if not player:isLocalPlayer() then return end

    local explosiveAmmo = weapon:getModData().GWG_FiringExplosiveAmmo

    if not isThrowable and not explosiveAmmo then return end

    local params
    local launchSource
    local isAmmoLaunch = false

    if isThrowable then
        params       = OrdnanceFactory.GetParams(fullType)
        launchSource = fullType
    else
        isAmmoLaunch                                = true
        params                                      = OrdnanceFactory.GetAmmoParams(explosiveAmmo)
        launchSource                                = explosiveAmmo

        weapon:getModData().GWG_FiringExplosiveAmmo = nil
    end

    if not params then return end

    local playerIndex = player:getPlayerNum()
    local mx          = getMouseX()
    local my          = getMouseY()
    local pz          = player:getZ()
    local aimOffset   = params.aimOffset or 0

    local mouseX      = screenToIsoX(playerIndex, mx, my, pz) + aimOffset
    local mouseY      = screenToIsoY(playerIndex, mx, my, pz) + aimOffset
    local destZ       = pz

    if isClient() then
        sendClientCommand(player, ExplosivesSystems.MODULE_NAME, "throwOrdnance", {
            sourceWeapon = launchSource,
            isAmmoLaunch = isAmmoLaunch,
            destX        = mouseX,
            destY        = mouseY,
            destZ        = destZ,
        })
    else
        local angleDeg = player:getDirectionAngle() or 0
        local angleRad = math.rad(angleDeg)
        local fwd      = (params and params.forwardOffset) or 0.50
        local hOff     = (params and params.heightOffset) or 0.55

        local originX  = player:getX() + math.cos(angleRad) * fwd
        local originY  = player:getY() + math.sin(angleRad) * fwd
        local originZ  = player:getZ() + hOff

        ExplosivesSystems.doSpawnOrdnance(player, launchSource, originX, originY, originZ, mouseX, mouseY, destZ, isAmmoLaunch)
    end
end

function ExplosivesSystems.onPlayerUpdate(player)
    if not player then return end

    suppressRegisteredThrowable(player:getPrimaryHandItem())
    suppressRegisteredThrowable(player:getSecondaryHandItem())
end

function ExplosivesSystems.spawnVisualOrdnance(args)
    if not args or not args.sourceWeapon then return end

    local params
    if args.isAmmoLaunch then
        params = OrdnanceFactory.GetAmmoParams(args.sourceWeapon)
    else
        params = OrdnanceFactory.GetParams(args.sourceWeapon)
    end
    if not params then return end

    local sq = getCell():getGridSquare(
        math.floor(args.originX), math.floor(args.originY), math.floor(args.originZ))
    if not sq then return end

    local itemType = params.worldModel or args.sourceWeapon
    local itemObj = instanceItem(itemType)
    if not itemObj then return end

    local seedVelX, seedVelY, seedVelZ = ExplosivesSystems.computeLaunchVelocity(
        params, args.originX, args.originY, args.originZ, args.destX, args.destY, args.destZ)

    local player = getPlayer()
    local isOwnOrdnance = player ~= nil and player:getOnlineID() == args.shooterOnlineID

    local visual = {
        ordnanceId       = args.ordnanceId,
        square           = sq,
        x                = args.originX - sq:getX(),
        y                = args.originY - sq:getY(),
        z                = args.originZ - sq:getZ(),
        velocityX        = seedVelX,
        velocityY        = seedVelY,
        velocityZ        = seedVelZ,
        hasHitFloor      = false,
        remainingBounces = args.remainingBounces or 0,
        prevWorldZ       = args.originZ,
        params           = params,
        itemObj          = itemObj,
        rotation         = args.rotation or 0,
        spinSpeed        = args.spinSpeed or 0,
        isOwnOrdnance    = isOwnOrdnance,
    }

    local list = ExplosivesSystems.visualOrdnance
    list[#list + 1] = visual
end

function ExplosivesSystems.removeVisualOrdnance(ordnanceId)
    local list = ExplosivesSystems.visualOrdnance
    for i = #list, 1, -1 do
        if list[i].ordnanceId == ordnanceId then
            list[i] = list[#list]
            list[#list] = nil
        end
    end
end

function ExplosivesSystems.playVisualBounceSound(visual)
    if not visual.isOwnOrdnance then return end
    local soundBounce = visual.params.soundBounce
    if not soundBounce then return end

    local player = getPlayer()
    if player and player.getEmitter then
        player:getEmitter():playSound(soundBounce)
    end
end

function ExplosivesSystems.updateVisualOrdnance()
    local list = ExplosivesSystems.visualOrdnance
    local n = #list
    if n == 0 then return end

    local dt = ExplosivesSystems.GT():getTimeDelta()
    local scale = dt * 60

    local i = 1
    while i <= n do
        local visual = list[i]
        local status = ExplosivesSystems.stepOrdnance(visual, scale)
        if not visual.atRest then
            visual.rotation = (visual.rotation + visual.spinSpeed * scale) % 360
        end
        local remove = false

        if status == "floorbounce" then
            ExplosivesSystems.playVisualBounceSound(visual)
        elseif status == "wallhit" or status == "floorimpact" then
            remove = visual.params.detonateOnImpact == true
        elseif status == "rest" then
            visual.atRest = true
            remove = not (visual.params.detonateOnImpact
                or (visual.params.detonationDelay or 0) > 0)
        end

        if remove then
            list[i] = list[n]
            list[n] = nil
            n = n - 1
        else
            i = i + 1
        end
    end
end

function ExplosivesSystems.renderVisualOrdnance()
    local list = ExplosivesSystems.visualOrdnance
    for i = 1, #list do
        local visual = list[i]
        Render3DItem(
            visual.itemObj,
            visual.square,
            visual.square:getX() + visual.x,
            visual.square:getY() + visual.y,
            visual.square:getZ() + visual.z,
            visual.rotation
        )
    end
end

function ExplosivesSystems.onServerCommand(module, command, args)
    if module ~= ExplosivesSystems.MODULE_NAME then return end
    if not args then return end

    if command == "playSound" then
        local player = getPlayer()
        if player and args.sound then
            player:getEmitter():playSound(args.sound)
        end
    elseif command == "spawnOrdnanceVisual" then
        ExplosivesSystems.spawnVisualOrdnance(args)
    elseif command == "removeOrdnanceVisual" then
        ExplosivesSystems.removeVisualOrdnance(args.ordnanceId)
    end
end

Events.OnWeaponSwing.Add(ExplosivesSystems.onWeaponSwingEarly)
Events.OnWeaponSwingHitPoint.Add(ExplosivesSystems.onWeaponSwingHitPoint)
Events.OnPlayerUpdate.Add(ExplosivesSystems.onPlayerUpdate)
Events.OnServerCommand.Add(ExplosivesSystems.onServerCommand)
Events.OnTick.Add(ExplosivesSystems.updateVisualOrdnance)
Events.RenderOpaqueObjectsInWorld.Add(ExplosivesSystems.renderVisualOrdnance)
