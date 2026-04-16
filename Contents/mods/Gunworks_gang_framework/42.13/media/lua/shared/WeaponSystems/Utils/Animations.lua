local Animations = {}

-------------------------------------------------
-- Registry tables for weapons with custom moving parts
-------------------------------------------------
Animations.WeaponsWithAnimatedParts = {}

--- Register a single weapon with animated moving parts.
---@param fullType string  fullType e.g. "Base.M16A3"
---@param entry table      { attachments = { open = "Part.Open", locked = "Part.Locked" } }
---                     OR { models     = { open = "Sprite_Open", locked = "Sprite_Locked" } }
function Animations.RegisterWeaponWithAnimatedParts(fullType, entry)
    Animations.WeaponsWithAnimatedParts[fullType] = entry
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
    local entry = Animations.WeaponsWithAnimatedParts[weapon:getFullType()]
    if not entry then return end
    local key = open and "open" or "locked"
    if entry.models then
        weapon:setWeaponSprite(entry.models[key])
    end
    if entry.attachments then
        weapon:attachWeaponPart(instanceItem(entry.attachments[key]), true)
    end
end

function Animations.CallAnimate(player, weapon, open)
    Animations.CallAnimationFunction(weapon, open)
    Animations.CallSyncHandWeaponFields(player, weapon)
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
    Animations.CallAnimate(player, weapon, open)
end

function Animations.lockActionOpen(player, weapon)
    if not weapon or not weapon:isRanged() or not player then return end
    if weapon:isRackAfterShoot() then return end
    if weapon:isJammed() or not weapon:haveChamber() then return end
    if not weapon:isRoundChambered() then return end

    Animations.CallAnimate(player, weapon, true)
    local seconds = 10 / 60
    Animations.scheduleActionClose(seconds, Animations.releaseActionLock, player, weapon)
end

function Animations.rackAction(player, weapon, starting)
    if not weapon or not player then return end
    if starting then
        Animations.CallAnimate(player, weapon, true)
    else
        Animations.CallAnimate(player, weapon, false)
    end
end

-------------------------------------------------
-- Registry tables for weapons with custom states at certain ammoPlaces
-------------------------------------------------
Animations.WeaponsWithCustomStates = {}

--- Register a single weapon with custom states.
---@param fullType string       fullType e.g. "Base.M60"
---@param paramsTable table      { threshold = 1, part = "MWA.Bullet_1", slot = "Animated1" }
function Animations.RegisterWeaponsWithCustomStates(fullType, paramsTable)
    Animations.WeaponsWithCustomStates[fullType] = paramsTable
end

function Animations.GetStatesTable(fullType)
    return Animations.WeaponsWithCustomStates[fullType]
end

function Animations.IsWeaponWithCustomStates(fullType)
    return Animations.WeaponsWithCustomStates[fullType] ~= nil
end

function Animations.CheckStates(weapon)
    if not weapon then return false end
    local ammoCount = weapon:getCurrentAmmoCount()

    local stages = Animations.GetStatesTable(weapon:getFullType())
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
