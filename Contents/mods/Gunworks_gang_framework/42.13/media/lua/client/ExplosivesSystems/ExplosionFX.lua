local ExplosivesSystems      = require("ExplosivesSystems/Init")
local ExplosionFX            = {}

ExplosionFX.activeEffects    = {}

local DEFAULT_FRAME_DURATION = 3

local function buildSequence(itemType, frames)
    if type(frames) ~= "table" then return nil end
    local first, last = frames[1], frames[2]
    if not first or not last then return nil end

    local sequence = {}
    for i = first, last do
        sequence[#sequence + 1] = itemType .. i
    end
    return sequence
end

local function buildFrameStep(duration, sequence)
    if type(duration) == "table" and sequence then
        local frameStep  = {}
        local timeToLive = 0
        for i = 1, #sequence do
            local step   = (tonumber(duration[i]) or DEFAULT_FRAME_DURATION) / 60
            frameStep[i] = step
            timeToLive   = timeToLive + step
        end
        return frameStep, timeToLive
    end

    local scalarDuration = type(duration) == "table" and duration[1] or duration
    local frameStep      = (tonumber(scalarDuration) or 30) / 60
    local timeToLive     = sequence and (frameStep * #sequence) or frameStep
    return frameStep, timeToLive
end

local function currentFrameStep(fx)
    if type(fx.frameStep) == "table" then
        return fx.frameStep[fx.frameIndex] or fx.frameStep[#fx.frameStep] or (DEFAULT_FRAME_DURATION / 60)
    end
    return fx.frameStep
end

local function instantiateFrameItems(itemType, sequence)
    if not sequence then
        local itemObj = instanceItem(itemType)
        return itemObj and { itemObj } or nil
    end

    local items = {}
    for i = 1, #sequence do
        items[i] = instanceItem(sequence[i])
    end
    return items
end

function ExplosionFX.PlayEffect(square, itemType, lx, ly, lz, duration, frames)
    if not square then return end
    if not itemType then return end

    local sequence              = buildSequence(itemType, frames)
    local frameStep, timeToLive = buildFrameStep(duration, sequence)
    local frameItems            = instantiateFrameItems(itemType, sequence)
    if not frameItems then return end

    local fx        = {
        square     = square,
        frameItems = frameItems,
        frameIndex = 1,
        frameTimer = 0,
        frameStep  = frameStep,
        lx         = lx or 0.5,
        ly         = ly or 0.5,
        lz         = lz or 0,
        timeToLive = timeToLive,
        active     = true,
    }

    local list      = ExplosionFX.activeEffects
    list[#list + 1] = fx
end

function ExplosionFX.tick()
    local dt = GameTime.getInstance():getTimeDelta()
    local i  = #ExplosionFX.activeEffects
    while i >= 1 do
        local fx = ExplosionFX.activeEffects[i]
        if fx and fx.active then
            fx.timeToLive = fx.timeToLive - dt
            if fx.timeToLive <= 0 then
                fx.active = false
                local lastIndex = #ExplosionFX.activeEffects
                ExplosionFX.activeEffects[i] = ExplosionFX.activeEffects[lastIndex]
                ExplosionFX.activeEffects[lastIndex] = nil
            elseif #fx.frameItems > 1 then
                fx.frameTimer = fx.frameTimer + dt
                while fx.frameTimer >= currentFrameStep(fx) and fx.frameIndex < #fx.frameItems do
                    fx.frameTimer = fx.frameTimer - currentFrameStep(fx)
                    fx.frameIndex = fx.frameIndex + 1
                end
            end
        else
            local lastIndex = #ExplosionFX.activeEffects
            ExplosionFX.activeEffects[i] = ExplosionFX.activeEffects[lastIndex]
            ExplosionFX.activeEffects[lastIndex] = nil
        end
        i = i - 1
    end
end

function ExplosionFX.render()
    local list = ExplosionFX.activeEffects
    for i = 1, #list do
        local fx = list[i]
        local itemObj = fx.frameItems[fx.frameIndex]
        if itemObj then
            Render3DItem(
                itemObj,
                fx.square,
                fx.square:getX() + fx.lx,
                fx.square:getY() + fx.ly,
                fx.square:getZ() + fx.lz,
                0
            )
        end
    end
end

local function onServerCommand(module, command, args)
    if module ~= ExplosivesSystems.MODULE_NAME then return end
    if command ~= "playExplosionFX" then return end
    if not args then return end

    local square = getCell():getGridSquare(args.sqX, args.sqY, args.sqZ)
    ExplosionFX.PlayEffect(square, args.itemType, args.lx, args.ly, args.lz, args.duration, args.frames)
end

ExplosivesSystems.PlayExplosionFXLocal = ExplosionFX.PlayEffect

Events.OnServerCommand.Add(onServerCommand)
Events.OnTick.Add(ExplosionFX.tick)
Events.RenderOpaqueObjectsInWorld.Add(ExplosionFX.render)

return ExplosionFX
