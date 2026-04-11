local Animations = {}

-------------------------------------------------
-- Registry tables  (keyed by weapon fullType)
-------------------------------------------------
Animations.RegisterModels = {}

--- Register a single weapon with custom callback function to handle swaps.
---@param fullType string       fullType e.g. "Base.M16A3"
---@param modelFunction function  function to handle model swaps
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

-- Send slide state to the server so it can broadcast to all other clients.
-- Only fires on the owning client; server and SP are no-ops.
function Animations.SyncSlideState(player, weapon, open)
    if not isClient() or not player or not weapon then return end
    sendClientCommand(player, "SWMG", "slideState", {
        weaponId = weapon:getID(),
        open     = open,
    })
end

function Animations.releaseActionLock(player, weapon)
    if not weapon or not player then return end
    if weapon:isJammed() or not weapon:haveChamber() then return end
    -- Always re-apply the correct state: the engine's syncHandWeaponFields may have
    -- reset the hand models between the open and this callback, stomping our visual.
    local open = not weapon:isRoundChambered()
    Animations.CallAnimationFunction(weapon, open)
    player:resetEquippedHandsModels()
    Animations.SyncSlideState(player, weapon, open)
end

function Animations.lockActionOpen(player, weapon)
    if not weapon or not weapon:isRanged() or not player then return end
    if weapon:isRackAfterShoot() then return end
    if weapon:isJammed() or not weapon:haveChamber() then return end

    Animations.CallAnimationFunction(weapon, true)
    player:resetEquippedHandsModels()
    Animations.SyncSlideState(player, weapon, true)
    local seconds = 10 / 60
    Animations.scheduleActionClose(seconds, Animations.releaseActionLock, player, weapon)
end

function Animations.rackAction(player, weapon, starting)
    if not weapon or not player then return end
    if starting then
        Animations.CallAnimationFunction(weapon, true)
        player:resetEquippedHandsModels()
        Animations.SyncSlideState(player, weapon, true)
    else
        Animations.CallAnimationFunction(weapon, false)
        player:resetEquippedHandsModels()
        Animations.SyncSlideState(player, weapon, false)
    end
end

Events.OnWeaponSwing.Add(Animations.lockActionOpen)

return Animations
