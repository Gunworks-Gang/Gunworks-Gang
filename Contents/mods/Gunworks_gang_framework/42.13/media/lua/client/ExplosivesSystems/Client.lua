local ExplosivesSystems = require("ExplosivesSystems/Init")
local OrdnanceFactory   = require("ExplosivesSystems/OrdnanceFactory")

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
end

function ExplosivesSystems.onWeaponSwingHitPoint(player, weapon)
    if not player or not weapon then return end
    if not player:isLocalPlayer() then return end

    local fullType      = weapon:getFullType()
    local isThrowable   = OrdnanceFactory.IsRegistered(fullType)
    local explosiveAmmo = weapon:getModData().GWG_FiringExplosiveAmmo

    if not isThrowable and not explosiveAmmo then return end

    local params
    local launchSource
    local isAmmoLaunch = false

    if isThrowable then
        weapon:setMaxHitCount(0)
        if weapon.setPhysicsObject then
            weapon:setPhysicsObject(nil)
        end
        params       = OrdnanceFactory.GetParams(fullType)
        launchSource = fullType
    else
        isAmmoLaunch                                = true
        params                                      = OrdnanceFactory.GetAmmoParams(explosiveAmmo)
        launchSource                                = explosiveAmmo

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

function ExplosivesSystems.onServerCommand(module, command, args)
    if module ~= ExplosivesSystems.MODULE_NAME then return end
    if not args then return end

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
