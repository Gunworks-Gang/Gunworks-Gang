local Animations = {}

Animations.RegisterModels = {}

function Animations.RegisterModel(fullType, modelFunction)
    Animations.RegisterModels[fullType] = modelFunction
end

function Animations.CallAnimationFunction(weapon, open)
    local modelFn = Animations.RegisterModels[weapon:getFullType()]
    if modelFn then
        modelFn(weapon, open)
    end
end

function Animations.scheduleActionClose(seconds, callback, ...)
    local elapsed = 0
    local gameTime = GameTime.getInstance()
    local parameters = { ... }

    local function tick()
        elapsed = elapsed + gameTime:getRealworldSecondsSinceLastUpdate()
        if elapsed < seconds then return end

        Events.OnTick.Remove(tick)
        callback(unpack(parameters))
    end

    Events.OnTick.Add(tick)

    return function()
        Events.OnTick.Remove(tick)
    end
end

function Animations.releaseActionLock(player, weapon)
    if not weapon or not player then return end
    if weapon:isRoundChambered() and not weapon:isJammed() and weapon:haveChamber() then
        Animations.CallAnimationFunction(weapon, false)
        player:resetEquippedHandsModels()
    end
end

function Animations.lockActionOpen(player, weapon)
    if not weapon or not weapon:isRanged() or not player then return end
    if weapon:isRackAfterShoot() then return end

    if weapon:isRoundChambered() and not weapon:isJammed() and weapon:haveChamber() then
        Animations.CallAnimationFunction(weapon, true)
        player:resetEquippedHandsModels()
        local seconds = 10 / 60
        Animations.scheduleActionClose(seconds, Animations.releaseActionLock, player, weapon)
    end
end

function Animations.rackAction(player, weapon, starting)
    if not weapon or not player then return end
    if starting then
        Animations.CallAnimationFunction(weapon, false)
        player:resetEquippedHandsModels()
    else
        Animations.CallAnimationFunction(weapon, true)
        player:resetEquippedHandsModels()
    end
end

Events.OnWeaponSwing.Add(Animations.lockActionOpen)

return Animations
