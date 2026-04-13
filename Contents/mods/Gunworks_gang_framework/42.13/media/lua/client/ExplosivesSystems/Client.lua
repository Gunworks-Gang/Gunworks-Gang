local ExplosivesSystems = require("ExplosivesSystems/Init")

--------------------------------------------------------------------
--- Client: hook weapon swing for registered throwables / launchers,
--- send launch command to server, handle remote sounds.
--------------------------------------------------------------------

--------------------------------------------------------------------
--- OnWeaponSwingHitPoint: intercept registered throwables/launchers
--------------------------------------------------------------------
function ExplosivesSystems.onWeaponSwing(player, weapon)
    if not player or not weapon then return end
    if not player:isLocalPlayer() then return end

    local fullType = weapon:getFullType()
    if not ExplosivesSystems.IsRegistered(fullType) then return end

    -- Get cursor world position as target
    local playerIndex = player:getPlayerNum()
    local mouseX = screenToIsoX(playerIndex, getMouseX(), getMouseY(), player:getZ())
    local mouseY = screenToIsoY(playerIndex, getMouseX(), getMouseY(), player:getZ())
    local targetZ = player:getZ()

    -- Prevent vanilla throw/hit behavior
    weapon:setMaxHitCount(0)

    -- Play launch sound locally
    local config = ExplosivesSystems.GetConfig(fullType)
    if config and config.SoundLaunch then
        player:getEmitter():playSound(config.SoundLaunch)
    end

    -- Send launch command
    if isClient() then
        sendClientCommand(player, ExplosivesSystems.MODULE_NAME, "Launch", {
            weaponFullType = fullType,
            targetX        = mouseX,
            targetY        = mouseY,
            targetZ        = targetZ,
        })
    else
        -- Solo / host: launch directly
        local angleDeg = player:getDirectionAngle() or 0
        local angleRad = math.rad(angleDeg)
        local fwd = (config and config.ForwardOffset) or 0.50
        local hOff = (config and config.HeightOffset) or 0.55

        local startX = player:getX() + math.cos(angleRad) * fwd
        local startY = player:getY() + math.sin(angleRad) * fwd
        local startZ = player:getZ() + hOff

        ExplosivesSystems.Launch(player, fullType, startX, startY, startZ, mouseX, mouseY, targetZ)
    end
end

--------------------------------------------------------------------
--- OnServerCommand: handle remote launch visuals and sounds
--------------------------------------------------------------------
function ExplosivesSystems.onServerCommand(module, command, args)
    if module ~= ExplosivesSystems.MODULE_NAME then return end
    if not args then return end

    if command == "RemoteLaunch" then
        -- Remote player launched a projectile — if we have the server
        -- physics running (SP/host), this is already handled.
        -- On a dedicated server client, we need to spawn a local visual.
        -- For now, the server's world item updates handle visuals via
        -- the AddWorldInventoryItem broadcast. Nothing extra needed.
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

Events.OnWeaponSwingHitPoint.Add(ExplosivesSystems.onWeaponSwing)
Events.OnServerCommand.Add(ExplosivesSystems.onServerCommand)
