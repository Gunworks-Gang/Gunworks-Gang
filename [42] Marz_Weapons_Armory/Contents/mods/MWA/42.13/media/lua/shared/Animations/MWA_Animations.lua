AnimationWeaponAction = {}

function AnimationWeaponAction.scheduleActionClose(seconds, callback, ...)
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

function AnimationWeaponAction.releaseActionLock(player, weapon)
    if not weapon or not player then return end
    if weapon:isRoundChambered() and not weapon:isJammed() and weapon:haveChamber() then
        MWAOpenModel(weapon, false)
        player:resetEquippedHandsModels()
    end
end

function AnimationWeaponAction.lockActionOpen(player, weapon)
    if not weapon or not weapon:isRanged() or not player then return end
    if weapon:isRackAfterShoot() then return end

    if weapon:isRoundChambered() and not weapon:isJammed() and weapon:haveChamber() then
        MWAOpenModel(weapon, true)
        player:resetEquippedHandsModels()
        local seconds = 10 / 60
        AnimationWeaponAction.scheduleActionClose(seconds, AnimationWeaponAction.releaseActionLock, player, weapon)
    end
end

function AnimationWeaponAction.rackAction(player, weapon, starting)
    if not weapon or not player then return end
    if starting then
        MWAOpenModel(weapon, false)
        player:resetEquippedHandsModels()
    else
        MWAOpenModel(weapon, true)
        player:resetEquippedHandsModels()
    end
end

Events.OnWeaponSwing.Add(AnimationWeaponAction.lockActionOpen)
