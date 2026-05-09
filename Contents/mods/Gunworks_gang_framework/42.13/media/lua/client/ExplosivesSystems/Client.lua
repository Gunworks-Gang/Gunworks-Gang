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
    local mouseX      = screenToIsoX(playerIndex, mx, my, player:getZ())
    local mouseY      = screenToIsoY(playerIndex, mx, my, player:getZ())
    local destZ       = player:getZ()

    -- Resolve the true floor Z at the target position.
    -- The mouse gives no Z info; screenToIsoX/Y projects onto the player's current
    -- floor plane. If the visual target is a floor below (e.g. a balcony), the
    -- projected square has no floor and the ordnance desync-teleports downward.
    -- Walk Z down from the player's level until we find a square with a floor,
    -- then re-project X/Y at that Z so the isometric offset is also corrected.
    -- this shit is not perfect but whatever. I will work it out later.
    -- TODO let me leave this here.
    do
        local ix     = math.floor(mouseX)
        local iy     = math.floor(mouseY)
        local checkZ = destZ
        local minZ   = math.max(0, destZ - 5)
        while checkZ >= minZ do
            local sq = getCell():getGridSquare(ix, iy, checkZ)
            if sq and sq:getFloor() then
                if checkZ ~= destZ then
                    mouseX = screenToIsoX(playerIndex, mx, my, checkZ)
                    mouseY = screenToIsoY(playerIndex, mx, my, checkZ)
                    destZ  = checkZ
                end
                break
            end
            checkZ = checkZ - 1
        end
    end

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
