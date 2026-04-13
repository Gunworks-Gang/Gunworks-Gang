local ExplosivesSystems = require("ExplosivesSystems/Init")
local OrdnanceFactory   = require("ExplosivesSystems/OrdnanceFactory")

--------------------------------------------------------------------
--- Client: hook weapon swing for registered throwables,
--- send throw command to server, handle remote sounds.
--------------------------------------------------------------------

--------------------------------------------------------------------
--- OnWeaponSwing: suppress vanilla throw EARLY (before hit point)
--------------------------------------------------------------------
function ExplosivesSystems.onWeaponSwingEarly(player, weapon)
    if not player or not weapon then return end
    if not player:isLocalPlayer() then return end

    local fullType = weapon:getFullType()
    if not OrdnanceFactory.IsRegistered(fullType) then return end

    -- Kill vanilla throw physics and hit detection before they fire
    weapon:setMaxHitCount(0)
    if weapon.setPhysicsObject then
        weapon:setPhysicsObject(nil)
    end
end

--------------------------------------------------------------------
--- OnWeaponSwingHitPoint: throw ordnance at the release frame
--------------------------------------------------------------------
function ExplosivesSystems.onWeaponSwingHitPoint(player, weapon)
    if not player or not weapon then return end
    if not player:isLocalPlayer() then return end

    local fullType = weapon:getFullType()
    if not OrdnanceFactory.IsRegistered(fullType) then return end

    -- Ensure vanilla is still suppressed
    weapon:setMaxHitCount(0)
    if weapon.setPhysicsObject then
        weapon:setPhysicsObject(nil)
    end

    -- Get cursor world position as destination
    local playerIndex = player:getPlayerNum()
    local mouseX      = screenToIsoX(playerIndex, getMouseX(), getMouseY(), player:getZ())
    local mouseY      = screenToIsoY(playerIndex, getMouseX(), getMouseY(), player:getZ())
    local destZ       = player:getZ()

    -- Play throw sound locally
    local throwParams = OrdnanceFactory.GetThrowParams(fullType)
    if throwParams and throwParams.soundThrow then
        player:getEmitter():playSound(throwParams.soundThrow)
    end

    -- Send throw command
    if isClient() then
        sendClientCommand(player, ExplosivesSystems.MODULE_NAME, "throwOrdnance", {
            sourceWeapon = fullType,
            destX        = mouseX,
            destY        = mouseY,
            destZ        = destZ,
        })
    else
        -- Solo / host: spawn ordnance directly
        local angleDeg = player:getDirectionAngle() or 0
        local angleRad = math.rad(angleDeg)
        local fwd      = (throwParams and throwParams.forwardOffset) or 0.50
        local hOff     = (throwParams and throwParams.heightOffset) or 0.55

        local originX  = player:getX() + math.cos(angleRad) * fwd
        local originY  = player:getY() + math.sin(angleRad) * fwd
        local originZ  = player:getZ() + hOff

        ExplosivesSystems.doSpawnOrdnance(player, fullType, originX, originY, originZ, mouseX, mouseY, destZ)
    end
end

--------------------------------------------------------------------
--- OnServerCommand: handle remote throw visuals and sounds
--------------------------------------------------------------------
function ExplosivesSystems.onServerCommand(module, command, args)
    if module ~= ExplosivesSystems.MODULE_NAME then return end
    if not args then return end

    if command == "remoteThrow" then
        -- Remote player threw ordnance — if we have the server
        -- physics running (SP/host), this is already handled.
        -- On a dedicated server client, world item updates handle
        -- visuals via the AddWorldInventoryItem broadcast.
        return
    end

    if command == "playSound" then
        local player = getPlayer()
        if player and args.sound then
            player:getEmitter():playSound(args.sound)
        end
        return
    end
end

Events.OnWeaponSwing.Add(ExplosivesSystems.onWeaponSwingEarly)
Events.OnWeaponSwingHitPoint.Add(ExplosivesSystems.onWeaponSwingHitPoint)
Events.OnServerCommand.Add(ExplosivesSystems.onServerCommand)
