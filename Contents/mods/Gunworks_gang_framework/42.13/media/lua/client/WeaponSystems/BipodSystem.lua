local BipodSystem = require("WeaponSystems/Utils/BipodSystem")
local GunworksKeybinds = require("WeaponSystems/ISUI/GunworksKeybinds")

local KEYBIND_BIPOD_STANCE = "Gunworks_BipodStance"

local BipodSystemClient = {}

BipodSystemClient.Reach = 1
BipodSystemClient.Step = 0.05
BipodSystemClient.MinSurfaceHeight = 26
BipodSystemClient.MaxSurfaceHeight = 50
BipodSystemClient.Standoff = 0.5
BipodSystemClient.Arc = 60
BipodSystemClient.MaxDrift = 0.75
BipodSystemClient.AnimVariable = "GunworksBipodDeployed"

BipodSystemClient.MountType = {
    LowWall = "LowWall",
    Window  = "Window",
    Surface = "Surface",
}

local function isLowWall(obj)
    local props = obj:getProperties()
    if not props then return false end
    return props:has(IsoFlagType.HoppableW) or props:has(IsoFlagType.HoppableN)
end

local function isOpenWindowFrame(fromSq, toSq, frame)
    if fromSq:isWindowBlockedTo(toSq) then return false end
    if instanceof(frame, "IsoWindowFrame") and frame:isBarricaded() then return false end
    return true
end

local function getMountableEdge(fromSq, toSq)
    local thumpable = fromSq:getHoppableThumpableTo(toSq)
    if thumpable then
        return thumpable, BipodSystemClient.MountType.LowWall
    end

    local edge = fromSq:getHoppableTo(toSq)
    if not edge then return nil end

    if isLowWall(edge) then
        return edge, BipodSystemClient.MountType.LowWall
    end
    if isOpenWindowFrame(fromSq, toSq, edge) then
        return edge, BipodSystemClient.MountType.Window
    end
    return nil
end

local function getMountableSurface(square)
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and not instanceof(obj, "IsoWorldInventoryObject") then
            local height = obj:getSurfaceOffsetNoTable()
            if height >= BipodSystemClient.MinSurfaceHeight and height <= BipodSystemClient.MaxSurfaceHeight then
                return obj
            end
        end
    end
    return nil
end

local function checkStep(fromSq, toSq)
    if not toSq then return nil, nil, true end

    local edge, mountType = getMountableEdge(fromSq, toSq)
    if edge then return edge, mountType end

    if fromSq:isBlockedTo(toSq) then return nil, nil, true end

    local surface = getMountableSurface(toSq)
    if surface then return surface, BipodSystemClient.MountType.Surface end

    if toSq:isSolid() or toSq:isSolidTrans() then return nil, nil, true end
    return nil
end

--- Traces forward from the player and returns the first bipod mount in reach.
--- @return IsoObject|nil, string|nil  mount object and BipodSystemClient.MountType
function BipodSystemClient.FindMountPoint(player)
    local current = player:getCurrentSquare()
    if not current then return nil end

    local cell = getCell()
    local z = current:getZ()
    local px, py = player:getX(), player:getY()
    local angle = math.rad(player:getDirectionAngle() or 0)
    local fx, fy = math.cos(angle), math.sin(angle)

    local dist = 0
    while dist < BipodSystemClient.Reach do
        dist = math.min(dist + BipodSystemClient.Step, BipodSystemClient.Reach)
        local tx = math.floor(px + fx * dist)
        local ty = math.floor(py + fy * dist)
        local cx, cy = current:getX(), current:getY()

        if tx ~= cx or ty ~= cy then
            if tx ~= cx and ty ~= cy then
                local side = cell:getGridSquare(tx, cy, z)
                local obj, mountType, blocked = checkStep(current, side)
                if obj or blocked then return obj, mountType end
                current = side
            end

            local nextSq = cell:getGridSquare(tx, ty, z)
            local obj, mountType, blocked = checkStep(current, nextSq)
            if obj or blocked then return obj, mountType end
            current = nextSq
        end
    end
    return nil
end

local stances = {}

local function angleDelta(a, b)
    return (a - b + 180) % 360 - 180
end

local function getBipodWeapon(player)
    local weapon = player:getPrimaryHandItem()
    if not weapon or not instanceof(weapon, "HandWeapon") or not weapon:isRanged() then return nil end
    if not BipodSystem.IsRegisterBipodDeployed(weapon) then return nil end
    return weapon
end

local function canHoldStance(player)
    return player:isAiming()
        and not player:isDead()
        and not player:getVehicle()
        and not player:isSneaking()
        and not player:isClimbing()
        and not player:isOnFloor()
        and not player:isSitOnGround()
end

function BipodSystemClient.IsInStance(player)
    return stances[player:getPlayerNum()] ~= nil
end

function BipodSystemClient.EnterStance(player, mount, mountType)
    local facing = player:getDirectionAngle()
    local rad = math.rad(facing)
    local x, y = player:getX(), player:getY()
    stances[player:getPlayerNum()] = {
        weapon    = player:getPrimaryHandItem(),
        mount     = mount,
        mountType = mountType,
        facing    = facing,
        pivotX    = x + math.cos(rad) * BipodSystemClient.Standoff,
        pivotY    = y + math.sin(rad) * BipodSystemClient.Standoff,
        z         = math.floor(player:getZ()),
        lastX     = x,
        lastY     = y,
    }
    player:setVariable(BipodSystemClient.AnimVariable, true)
end

function BipodSystemClient.ExitStance(player)
    stances[player:getPlayerNum()] = nil
    player:setVariable(BipodSystemClient.AnimVariable, false)
end

function BipodSystemClient.ToggleStance(player)
    if BipodSystemClient.IsInStance(player) then
        BipodSystemClient.ExitStance(player)
        return
    end
    if not getBipodWeapon(player) or not canHoldStance(player) then return end

    local mount, mountType = BipodSystemClient.FindMountPoint(player)
    if not mount then
        print("Nothing to deploy")
        return
    end
    BipodSystemClient.EnterStance(player, mount, mountType)
end

local function followAim(player, stance)
    local facing = player:getDirectionAngle()
    if math.abs(angleDelta(facing, stance.facing)) > BipodSystemClient.Arc then return false end

    local driftX, driftY = player:getX() - stance.lastX, player:getY() - stance.lastY
    if driftX * driftX + driftY * driftY > BipodSystemClient.MaxDrift * BipodSystemClient.MaxDrift then return false end

    local rad = math.rad(facing)
    local x = stance.pivotX - math.cos(rad) * BipodSystemClient.Standoff
    local y = stance.pivotY - math.sin(rad) * BipodSystemClient.Standoff

    local from = player:getCurrentSquare()
    local to = getCell():getGridSquare(math.floor(x), math.floor(y), stance.z)
    if not from or not to then return true end
    if to ~= from and (from:isBlockedTo(to) or to:isSolid() or to:isSolidTrans()) then return true end

    player:setX(x)
    player:setY(y)
    stance.lastX, stance.lastY = x, y
    return true
end

local function onPlayerUpdate(player)
    if not player:isLocalPlayer() then return end
    local stance = stances[player:getPlayerNum()]
    if not stance then return end

    if player:getPrimaryHandItem() ~= stance.weapon
        or not getBipodWeapon(player)
        or not canHoldStance(player)
        or not followAim(player, stance)
    then
        BipodSystemClient.ExitStance(player)
    end
end

local function onPlayerDeath(player)
    if player:isLocalPlayer() and BipodSystemClient.IsInStance(player) then
        BipodSystemClient.ExitStance(player)
    end
end

local function onKeyPressed(key)
    if key ~= GunworksKeybinds.GetBoundKey(KEYBIND_BIPOD_STANCE, Keyboard.KEY_L) then return end

    local player = getPlayer()
    if player and not player:isDead() then
        BipodSystemClient.ToggleStance(player)
    end
end

Events.OnKeyPressed.Add(onKeyPressed)
Events.OnPlayerUpdate.Add(onPlayerUpdate)
Events.OnPlayerDeath.Add(onPlayerDeath)

return BipodSystemClient


-- DEFAULT ORIGINAL VALUES FOR MYSELF
-- BipodSystemClient.Reach = 0.75
-- BipodSystemClient.Step = 0.05
-- BipodSystemClient.MinSurfaceHeight = 26
-- BipodSystemClient.MaxSurfaceHeight = 50
-- BipodSystemClient.Standoff = 0.5
-- BipodSystemClient.Arc = 45
-- BipodSystemClient.MaxDrift = 0.5
-- BipodSystemClient.AnimVariable = "GunworksBipodDeployed"
