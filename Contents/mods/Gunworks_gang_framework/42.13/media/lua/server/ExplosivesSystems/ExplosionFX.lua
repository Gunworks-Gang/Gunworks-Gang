local ExplosionFX = {}

ExplosionFX.activeEffects = {}

-- fallback duration (in ticks, pre-/60) for a frame missing from a per-frame explosionFXDuration table
local DEFAULT_FRAME_DURATION = 3

local function removeWorldItem(fx)
    if not fx.worldItem then return end
    local wobj = fx.worldItem:getWorldItem()
    if wobj then
        local wSquare = wobj:getSquare()
        if wSquare then
            if isServer() then
                wSquare:transmitRemoveItemFromSquare(wobj)
            end
            wSquare:removeWorldObject(wobj)
        end
    end
    fx.worldItem = nil
end

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

function ExplosionFX.PlayEffect(square, itemType, lx, ly, lz, duration, frames)
    if not square then return end
    if not itemType then return end

    local sequence              = buildSequence(itemType, frames)
    local frameStep, timeToLive = buildFrameStep(duration, sequence)

    local fx                    = {
        square     = square,
        itemType   = itemType,
        sequence   = sequence,
        frameIndex = 1,
        frameTimer = 0,
        frameStep  = frameStep,
        lx         = lx or 0.5,
        ly         = ly or 0.5,
        lz         = lz or 0,
        timeToLive = timeToLive,
        worldItem  = square:AddWorldInventoryItem(sequence and sequence[1] or itemType, lx or 0.5, ly or 0.5, lz or 0),
        active     = true,
    }

    local list                  = ExplosionFX.activeEffects
    list[#list + 1]             = fx
end

function ExplosionFX.tick()
    local dt = GameTime.getInstance():getTimeDelta()
    local i  = #ExplosionFX.activeEffects
    while i >= 1 do
        local fx = ExplosionFX.activeEffects[i]
        if fx and fx.active then
            removeWorldItem(fx)
            fx.timeToLive = fx.timeToLive - dt
            if fx.timeToLive <= 0 then
                fx.active = false
                local lastIndex = #ExplosionFX.activeEffects
                ExplosionFX.activeEffects[i] = ExplosionFX.activeEffects[lastIndex]
                ExplosionFX.activeEffects[lastIndex] = nil
            else
                local currentType = fx.itemType
                if fx.sequence then
                    fx.frameTimer = fx.frameTimer + dt
                    while fx.frameTimer >= currentFrameStep(fx) and fx.frameIndex < #fx.sequence do
                        fx.frameTimer = fx.frameTimer - currentFrameStep(fx)
                        fx.frameIndex = fx.frameIndex + 1
                    end
                    currentType = fx.sequence[fx.frameIndex]
                end
                fx.worldItem = fx.square:AddWorldInventoryItem(currentType, fx.lx, fx.ly, fx.lz)
                fx.worldItem:setWorldZRotation(0)
            end
        else
            local lastIndex = #ExplosionFX.activeEffects
            ExplosionFX.activeEffects[i] = ExplosionFX.activeEffects[lastIndex]
            ExplosionFX.activeEffects[lastIndex] = nil
        end
        i = i - 1
    end
end

Events.OnTick.Add(ExplosionFX.tick)

return ExplosionFX
