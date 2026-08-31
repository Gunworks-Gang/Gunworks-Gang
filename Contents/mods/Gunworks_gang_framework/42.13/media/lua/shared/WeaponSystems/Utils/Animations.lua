local Animations = {}

-------------------------------------------------
-- Registry tables for weapons with custom moving parts
-------------------------------------------------
Animations.WeaponsWithAnimatedParts = {}

-------------------------------------------------
-- Cycle timing (how long the action stays racked open before it auto-closes)
-------------------------------------------------
local TICKS_PER_SECOND = 60
Animations.DEFAULT_CYCLE_TICKS = 10 -- default: 10/60 seconds

local function GetCycleSeconds(fullType)
    local entry = Animations.WeaponsWithAnimatedParts[fullType]
    local ticks = (entry and entry.cycleTicks) or Animations.DEFAULT_CYCLE_TICKS
    return ticks / TICKS_PER_SECOND
end

--- Register a single weapon with animated moving parts.
---@param fullType string  fullType e.g. "Base.M16A3"
---@param entry table      { SingleAttachment = { open = "Part.Open", locked = "Part.Locked" } }
---                     OR { MultipleAttachment = { Slide = { open = "Part.Open", locked = "Part.Locked" } } }
---                     OR { MultipleAttachmentsVariant = { Slide = { partType = "Slide", variants = { ["Part.A"] = { open = "Part.OpenA", locked = "Part.LockedA" }, ["Part.B"] = { open = "Part.OpenB", locked = "Part.LockedB" } } } } }
---                     OR { Models     = { open = "Sprite_Open", locked = "Sprite_Locked" } }
---                     Optional: `cycleTicks` (number of ticks at 60 ticks/second) controls how long the action stays racked open before auto-closing. Defaults to Animations.DEFAULT_CYCLE_TICKS (10, i.e. 10/60 seconds).
---                     Optional: `force` bypasses the checks and trigger the animation on firing (perfect for revolver type weapons)
function Animations.RegisterWeaponWithAnimatedParts(fullType, entry)
    Animations.WeaponsWithAnimatedParts[fullType] = entry
end

function Animations.RegisterMultipleWeaponsWithAnimatedParts(entriesTables)
    if not entriesTables then return end

    for fullType, entry in pairs(entriesTables) do
        Animations.WeaponsWithAnimatedParts[fullType] = entry
    end
end

-- We gonna use this silly function to force animation without breaking the current logic
local function getIsForcedAnimate(weapon)
    local entry = Animations.WeaponsWithAnimatedParts[weapon:getFullType()]
    if entry and entry.force then
        return true
    end
    return false
end

local firingRefresh = false

function Animations.IsFiringRefresh()
    return firingRefresh
end

function Animations.CallSyncHandWeaponFields(player, weapon)
    syncHandWeaponFields(player, weapon)
    player:setPrimaryHandItem(nil)
    if weapon:isTwoHandWeapon() then
        player:setSecondaryHandItem(nil)
    end
    player:setPrimaryHandItem(weapon)
    if weapon:isTwoHandWeapon() then
        player:setSecondaryHandItem(weapon)
    end
    player:resetEquippedHandsModels()
end

local function ApplyAttachmentState(weapon, attachmentState, key)
    if not weapon or not attachmentState then return end
    local stateValue = attachmentState[key]
    if not stateValue then return end
    weapon:attachWeaponPart(instanceItem(stateValue), true)
end

local function ApplyMultipleAttachmentState(weapon, attachmentState, key)
    if not weapon or not attachmentState then return end

    local partType = attachmentState.partType
    local currentPart = partType and weapon:getWeaponPart(partType)
    if not currentPart then return end

    local variants = attachmentState.variants
    if not variants then
        ApplyAttachmentState(weapon, attachmentState, key)
        return
    end

    local currentFullType = currentPart:getFullType()
    local selectedVariant = variants[currentFullType]
    if not selectedVariant then return end

    ApplyAttachmentState(weapon, selectedVariant, key)
end

function Animations.CallAnimationFunction(weapon, open)
    local entry = Animations.WeaponsWithAnimatedParts[weapon:getFullType()]
    if not entry then return end

    local key = open and "open" or "locked"

    if entry.Models then
        weapon:setWeaponSprite(entry.Models[key])
    end

    if entry.SingleAttachment then
        ApplyAttachmentState(weapon, entry.SingleAttachment, key)
    end

    if entry.MultipleAttachment then
        for _, attachment in pairs(entry.MultipleAttachment) do
            ApplyAttachmentState(weapon, attachment, key)
        end
    end

    if entry.MultipleAttachmentsVariant then
        for _, attachmentState in pairs(entry.MultipleAttachmentsVariant) do
            ApplyMultipleAttachmentState(weapon, attachmentState, key)
        end
    end
end

function Animations.CallAnimate(player, weapon, open)
    firingRefresh = true
    Animations.CallAnimationFunction(weapon, open)
    Animations.CallSyncHandWeaponFields(player, weapon)
    firingRefresh = false
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

function Animations.releaseActionLockForce(player, weapon)
    if not weapon or not player then return end
    Animations.CallAnimate(player, weapon, false)
end

function Animations.lockActionOpen(player, weapon)
    if not weapon or not player or not weapon:isRanged() then return end

    local forced = getIsForcedAnimate(weapon)

    if not forced then
        if weapon:isRackAfterShoot() or weapon:isJammed() or not weapon:haveChamber() or not weapon:isRoundChambered() then return end
    end

    Animations.CallAnimate(player, weapon, true)

    local seconds = GetCycleSeconds(weapon:getFullType())
    local releaseFunc = forced and Animations.releaseActionLockForce or Animations.releaseActionLock

    Animations.scheduleActionClose(seconds, releaseFunc, player, weapon)
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
