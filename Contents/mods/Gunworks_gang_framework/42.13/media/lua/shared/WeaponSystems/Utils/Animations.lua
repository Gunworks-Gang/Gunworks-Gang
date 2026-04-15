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

function Animations.CallSyncHandWeaponFields(player, weapon)
    syncHandWeaponFields(player, weapon)
    player:setPrimaryHandItem(nil)
    player:setSecondaryHandItem(nil)
    player:setPrimaryHandItem(weapon)
    if weapon:isTwoHandWeapon() then
        player:setSecondaryHandItem(weapon)
    end
    player:resetEquippedHandsModels()
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
    if weapon:isJammed() or not weapon:haveChamber() then return end
    local open = not weapon:isRoundChambered()
    Animations.CallAnimationFunction(weapon, open)
    Animations.CallSyncHandWeaponFields(player, weapon)
end

function Animations.lockActionOpen(player, weapon)
    if not weapon or not weapon:isRanged() or not player then return end
    if weapon:isRackAfterShoot() then return end
    if weapon:isJammed() or not weapon:haveChamber() then return end
    if not weapon:isRoundChambered() then return end

    Animations.CallAnimationFunction(weapon, true)
    Animations.CallSyncHandWeaponFields(player, weapon)
    local seconds = 10 / 60
    Animations.scheduleActionClose(seconds, Animations.releaseActionLock, player, weapon)
end

function Animations.rackAction(player, weapon, starting)
    if not weapon or not player then return end
    if starting then
        Animations.CallAnimationFunction(weapon, true)
        Animations.CallSyncHandWeaponFields(player, weapon)
    else
        Animations.CallAnimationFunction(weapon, false)
        Animations.CallSyncHandWeaponFields(player, weapon)
    end
end

-------------------------------------------------
-- Registry tables  (keyed by weapon fullType)
-------------------------------------------------
Animations.RegisterTableStates = {}

--- Register a single weapon with custom callback function to handle swaps.
---@param fullType string       fullType e.g. "Base.M60"
---@param paramsTable table      { threshold = 1, part = "MWA.Bullet_1", slot = "Animated1" }
function Animations.RegisterTableState(fullType, paramsTable)
    Animations.RegisterTableStates[fullType] = paramsTable
end

function Animations.GetTableStates(fullType)
    return Animations.RegisterTableStates[fullType]
end

function Animations.IsWeaponRegistered(fullType)
    return Animations.RegisterTableStates[fullType] ~= nil
end

function Animations.AmmoCheck(weapon)
    if not weapon then return false end
    local ammoCount = weapon:getCurrentAmmoCount()

    local stages = Animations.GetTableStates(weapon:getFullType())
    if not stages then return end

    for _, stage in ipairs(stages) do
        if ammoCount >= stage.threshold then
            weapon:attachWeaponPart(instanceItem(stage.part), true)
        else
            local ammoItem = weapon:getWeaponPart(stage.slot)
            if ammoItem then
                weapon:detachWeaponPart(ammoItem)
            end
        end
    end
end

return Animations
