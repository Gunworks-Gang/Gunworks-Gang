local ExplosivesSystems = require("ExplosivesSystems/Init")
local OrdnanceFactory   = require("ExplosivesSystems/OrdnanceFactory")

--------------------------------------------------------------------
--- Client: hook weapon swing for registered throwables,
--- send throw command to server, handle remote sounds.
--------------------------------------------------------------------

--------------------------------------------------------------------
--- OnWeaponSwing: suppress vanilla throw EARLY (before hit point)
--- Also suppress vanilla bullet for ranged weapons firing explosive ammo.
--------------------------------------------------------------------
function ExplosivesSystems.onWeaponSwingEarly(player, weapon)
    if not player or not weapon then return end
    if not player:isLocalPlayer() then return end

    -- Case 1: registered throwable ordnance (existing behavior)
    local fullType = weapon:getFullType()
    if OrdnanceFactory.IsRegistered(fullType) then
        weapon:setMaxHitCount(0)
        if weapon.setPhysicsObject then
            weapon:setPhysicsObject(nil)
        end
        return
    end

    -- Case 2: ranged weapon firing explosive ammo
    local explosiveAmmo = weapon:getModData().GWG_FiringExplosiveAmmo
    if explosiveAmmo and weapon:isRanged() then
        -- Save original maxHitCount so we can restore it after the shot
        weapon:getModData().GWG_OriginalMaxHitCount = weapon:getMaxHitCount()
        weapon:setMaxHitCount(0)
    end
end

--------------------------------------------------------------------
--- OnWeaponSwingHitPoint: throw ordnance at the release frame,
--- or launch explosive ammo projectile for ranged weapons.
--------------------------------------------------------------------
function ExplosivesSystems.onWeaponSwingHitPoint(player, weapon)
    if not player or not weapon then return end
    if not player:isLocalPlayer() then return end

    local fullType      = weapon:getFullType()
    local isThrowable   = OrdnanceFactory.IsRegistered(fullType)
    local explosiveAmmo = weapon:getModData().GWG_FiringExplosiveAmmo

    -- If neither a registered throwable nor explosive ammo, bail out
    if not isThrowable and not explosiveAmmo then return end

    -- Determine which params to use
    local params
    local launchSource -- identifier sent to server for param lookup
    local isAmmoLaunch = false

    if isThrowable then
        -- Existing throwable behavior
        weapon:setMaxHitCount(0)
        if weapon.setPhysicsObject then
            weapon:setPhysicsObject(nil)
        end
        params       = OrdnanceFactory.GetParams(fullType)
        launchSource = fullType
    else
        -- Ranged weapon firing explosive ammo
        isAmmoLaunch       = true
        params             = OrdnanceFactory.GetAmmoParams(explosiveAmmo)
        launchSource       = explosiveAmmo

        -- Restore the weapon's original maxHitCount
        local origHitCount = weapon:getModData().GWG_OriginalMaxHitCount
        if origHitCount then
            weapon:setMaxHitCount(origHitCount)
            weapon:getModData().GWG_OriginalMaxHitCount = nil
        end
        -- Clear the flag
        weapon:getModData().GWG_FiringExplosiveAmmo = nil
    end

    if not params then return end

    -- Get cursor world position as destination
    local playerIndex = player:getPlayerNum()
    local mouseX      = screenToIsoX(playerIndex, getMouseX(), getMouseY(), player:getZ())
    local mouseY      = screenToIsoY(playerIndex, getMouseX(), getMouseY(), player:getZ())
    local destZ       = player:getZ()

    if not isAmmoLaunch then
        local aimOffset = 1.5
        mouseX          = mouseX + aimOffset
        mouseY          = mouseY + aimOffset
    end

    -- Play throw sound locally
    if params and params.soundThrow then
        -- player:getEmitter():playSound(params.soundThrow)
    end

    -- Send command to server
    if isClient() then
        sendClientCommand(player, ExplosivesSystems.MODULE_NAME, "throwOrdnance", {
            sourceWeapon = launchSource,
            isAmmoLaunch = isAmmoLaunch,
            destX        = mouseX,
            destY        = mouseY,
            destZ        = destZ,
        })
    else
        -- Solo / host: spawn ordnance directly
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
