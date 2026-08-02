local ExplosivesSystems = require("ExplosivesSystems/Init")
local OrdnanceFactory   = require("ExplosivesSystems/OrdnanceFactory")

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

    -- Target is resolved on the THROWER's own plane, same as vanilla mouse targeting.
    -- We do not try to guess a lower destination tier here: guessing from the cursor
    -- alone is fragile (the projected pixel drifts at every Z candidate, and a wrong
    -- guess fights the real terrain mid-flight). The server-side flight instead detects
    -- any actual drop in the terrain tick-by-tick as it travels, the same way Hot Brass
    -- casings do.
    local mouseX = screenToIsoX(playerIndex, mx, my, pz) + aimOffset
    local mouseY = screenToIsoY(playerIndex, mx, my, pz) + aimOffset
    local destZ  = pz

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
Events.OnPlayerUpdate.Add(ExplosivesSystems.onPlayerUpdate)
Events.OnServerCommand.Add(ExplosivesSystems.onServerCommand)
