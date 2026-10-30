local BipodSystem = {}

BipodSystem.Reach = 0.75
BipodSystem.Step = 0.05

-- Surface heights are tile pixels (96 = one floor). Tables 26-31, counters 35, bar counters 46.
BipodSystem.MinSurfaceHeight = 26
BipodSystem.MaxSurfaceHeight = 50

BipodSystem.MountType = {
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
        return thumpable, BipodSystem.MountType.LowWall
    end

    local edge = fromSq:getHoppableTo(toSq)
    if not edge then return nil end

    if isLowWall(edge) then
        return edge, BipodSystem.MountType.LowWall
    end
    if isOpenWindowFrame(fromSq, toSq, edge) then
        return edge, BipodSystem.MountType.Window
    end
    return nil
end

local function getMountableSurface(square)
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and not instanceof(obj, "IsoWorldInventoryObject") then
            local height = obj:getSurfaceOffsetNoTable()
            if height >= BipodSystem.MinSurfaceHeight and height <= BipodSystem.MaxSurfaceHeight then
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
    if surface then return surface, BipodSystem.MountType.Surface end

    if toSq:isSolid() or toSq:isSolidTrans() then return nil, nil, true end
    return nil
end

--- Traces forward from the player and returns the first bipod mount in reach.
--- @return IsoObject|nil, string|nil  mount object and BipodSystem.MountType
function BipodSystem.FindMountPoint(player)
    local current = player:getCurrentSquare()
    if not current then return nil end

    local cell = getCell()
    local z = current:getZ()
    local px, py = player:getX(), player:getY()
    local angle = math.rad(player:getDirectionAngle() or 0)
    local fx, fy = math.cos(angle), math.sin(angle)

    local dist = 0
    while dist < BipodSystem.Reach do
        dist = math.min(dist + BipodSystem.Step, BipodSystem.Reach)
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

function BipodSystem.TryDeploy(player)
    local mount = BipodSystem.FindMountPoint(player)
    if mount then
        print("Yes! you can deploy here")
    else
        print("Nothing to deploy")
    end
end

local function onKeyPressed(key)
    if key ~= Keyboard.KEY_L then return end

    local player = getPlayer()
    if player and not player:isDead() then
        BipodSystem.TryDeploy(player)
    end
end

Events.OnKeyPressed.Add(onKeyPressed)

return BipodSystem
