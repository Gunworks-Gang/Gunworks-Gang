require("TimedActions/ISReloadWeaponAction")
local StatsFactory                  = require("WeaponSystems/Utils/StatsFactory")
-------------------------------------------------
-- Rate of Fire Control System
-------------------------------------------------
local RateOfFire                    = {}

RateOfFire.lastFireTime             = {}
RateOfFire.DEFAULT_RPM              = 600
RateOfFire.BURST_DEFAULT_COUNT      = 3
RateOfFire.BURST_DELAY_MS           = 500
RateOfFire.burstState               = {}
RateOfFire.burstCooldown            = {}

RateOfFire.spreadState              = {}
RateOfFire.SPREAD_INITIAL_DEFAULT   = 0.1
RateOfFire.SPREAD_SUSTAINED_DEFAULT = 0.1
RateOfFire.SPREAD_MAX_DEFAULT       = 3
RateOfFire.SpreadPartModifiers      = {}

-------------------------------------------------
-- Registry tables  (keyed by weapon fullType)
-------------------------------------------------
RateOfFire.WeaponProfiles           = {} -- fullType -> { rpm = number, burstCount = number }

--- Register a single weapon with custom RPM and/or burst count.
---@param weaponType string       fullType e.g. "MWA.M16A3"
---@param entry table             { rpm = number?, burstCount = number?, enableSpread = boolean?,
---                                 initialSpread = number?, sustainedSpread = number?, maxSpread = number? }
function RateOfFire.RegisterWeapon(weaponType, entry)
    RateOfFire.WeaponProfiles[weaponType] = entry
end

--- Convenience: register the same profile for multiple weapon types.
---@param weaponTypes string[]    array of fullType strings
---@param entry table             { rpm = number?, burstCount = number?, enableSpread = boolean?,
---                                 initialSpread = number?, sustainedSpread = number?, maxSpread = number? }
function RateOfFire.RegisterWeapons(weaponTypes, entry)
    for i = 1, #weaponTypes do
        RateOfFire.WeaponProfiles[weaponTypes[i]] = entry
    end
end

--- Register a spread multiplier for a single weapon part fullType.
--- When a weapon has this part attached, sustainedSpread and maxSpread are multiplied.
---@param partType string         fullType of the part e.g. "MWA.ForegripVert"
---@param entry table             { sustainedSpreadMult = number?, maxSpreadMult = number? }
function RateOfFire.RegisterSpreadPartModifier(partType, entry)
    RateOfFire.SpreadPartModifiers[partType] = entry
end

--- Convenience: register spread multipliers for multiple part types at once.
---@param modifiers table         { [partType] = { sustainedSpreadMult = number?, maxSpreadMult = number? } }
function RateOfFire.RegisterSpreadPartModifiers(modifiers)
    for partType, entry in pairs(modifiers) do
        RateOfFire.SpreadPartModifiers[partType] = entry
    end
end

-------------------------------------------------
-- Query helpers
-------------------------------------------------

--- Returns the spread profile for the weapon, or nil if spread is not enabled.
---@return table|nil  { initialSpread, sustainedSpread, maxSpread }
function RateOfFire.getSpreadProfile(weapon)
    if not weapon then return nil end
    local profile = RateOfFire.WeaponProfiles[weapon:getFullType()]
    if not profile or not profile.enableSpread then return nil end

    local sp = {
        initialSpread   = profile.initialSpread or RateOfFire.SPREAD_INITIAL_DEFAULT,
        sustainedSpread = profile.sustainedSpread or RateOfFire.SPREAD_SUSTAINED_DEFAULT,
        maxSpread       = profile.maxSpread or RateOfFire.SPREAD_MAX_DEFAULT,
    }

    local parts = weapon:getAllWeaponParts()
    if parts then
        for i = 0, parts:size() - 1 do
            local mod = RateOfFire.SpreadPartModifiers[parts:get(i):getFullType()]
            if mod then
                if mod.sustainedSpreadMult then
                    sp.sustainedSpread = sp.sustainedSpread * mod.sustainedSpreadMult
                end
                if mod.maxSpreadMult then
                    sp.maxSpread = sp.maxSpread * mod.maxSpreadMult
                end
            end
        end
    end

    return sp
end

function RateOfFire.getWeaponRPM(weapon)
    if not weapon then return RateOfFire.DEFAULT_RPM end

    local profile = RateOfFire.WeaponProfiles[weapon:getFullType()]
    if profile and profile.rpm then return profile.rpm end

    return RateOfFire.DEFAULT_RPM
end

function RateOfFire.canFire(player, weapon)
    if not player then return false end

    local playerId = player:getPlayerNum()
    local now = getTimestampMs()

    local rpm = RateOfFire.getWeaponRPM(weapon)
    if not rpm or rpm <= 0 then rpm = RateOfFire.DEFAULT_RPM end

    local intervalMs = math.floor((60000 / rpm) + 0.5)

    local nextAllowed = RateOfFire.lastFireTime[playerId] or 0

    if now >= nextAllowed then
        local newNext = nextAllowed + intervalMs
        if newNext < now then
            newNext = now + intervalMs
        end

        RateOfFire.lastFireTime[playerId] = newNext
        return true, intervalMs
    end

    return false
end

function RateOfFire.canStartBurst(player)
    local playerId = player:getPlayerNum()
    local now = getTimestampMs()
    local cooldownEnd = RateOfFire.burstCooldown[playerId] or 0
    return now >= cooldownEnd
end

function RateOfFire.getWeaponBurstCount(weapon)
    if not weapon then return RateOfFire.BURST_DEFAULT_COUNT end

    local profile = RateOfFire.WeaponProfiles[weapon:getFullType()]
    if profile and profile.burstCount then return profile.burstCount end

    return RateOfFire.BURST_DEFAULT_COUNT
end

function RateOfFire.applySpreadOnShot(player, weapon, intervalMs)
    local sp = RateOfFire.getSpreadProfile(weapon)
    if not sp then return end

    local playerId = player:getPlayerNum()
    local now      = getTimestampMs()
    local fullType = weapon:getFullType()
    local state    = RateOfFire.spreadState[playerId]

    if not state or state.weaponType ~= fullType then
        weapon:setRangeFalloff(true)
        state = {
            currentSpread = sp.initialSpread,
            lastShotTime  = now,
            lastDecayTime = now,
            intervalMs    = intervalMs,
            weaponType    = fullType,
        }
        RateOfFire.spreadState[playerId] = state
        weapon:setProjectileSpread(state.currentSpread)
        return
    end

    state.currentSpread = math.min(state.currentSpread + sp.sustainedSpread, sp.maxSpread)
    state.lastShotTime  = now
    state.lastDecayTime = now
    state.intervalMs    = intervalMs
    weapon:setProjectileSpread(state.currentSpread)
end

function RateOfFire.decaySpreadTick()
    local now = getTimestampMs()

    for playerId, state in pairs(RateOfFire.spreadState) do
        local profile = RateOfFire.WeaponProfiles[state.weaponType]
        if not profile or not profile.enableSpread then
            RateOfFire.spreadState[playerId] = nil
        else
            local sp            = RateOfFire.getSpreadProfile_fromProfile(profile)
            local timeSinceFire = now - state.lastShotTime

            if timeSinceFire >= state.intervalMs then
                local decayWindow   = now - state.lastDecayTime
                local decayAmount   = sp.sustainedSpread * (decayWindow / state.intervalMs)
                state.currentSpread = math.max(state.currentSpread - decayAmount, sp.initialSpread)
                state.lastDecayTime = now

                local player        = getSpecificPlayer(playerId)
                if player and not player:isDead() then
                    local weapon = player:getPrimaryHandItem()
                    if weapon and instanceof(weapon, "HandWeapon")
                        and weapon:getFullType() == state.weaponType then
                        weapon:setProjectileSpread(state.currentSpread)
                    end
                end
            end
        end
    end
end

function RateOfFire.getSpreadProfile_fromProfile(profile)
    return {
        initialSpread   = profile.initialSpread or RateOfFire.SPREAD_INITIAL_DEFAULT,
        sustainedSpread = profile.sustainedSpread or RateOfFire.SPREAD_SUSTAINED_DEFAULT,
        maxSpread       = profile.maxSpread or RateOfFire.SPREAD_MAX_DEFAULT,
    }
end

function RateOfFire.startBurst(player, weapon, intervalMs, Original_Attack_Hook, chargeDelta)
    local playerId = player:getPlayerNum()

    if RateOfFire.burstState[playerId] then return false end
    if not RateOfFire.canStartBurst(player) then return false end
    if weapon:isRackAfterShoot() then return false end

    RateOfFire.burstState[playerId] = {
        shotsRemaining = RateOfFire.getWeaponBurstCount(weapon) - 1,
        intervalMs = intervalMs,
        weapon = weapon,
        attackHook = Original_Attack_Hook,
        chargeDelta = chargeDelta,
        nextShotTime = getTimestampMs() + intervalMs
    }
end

function RateOfFire.burstTickHandler()
    local now = getTimestampMs()

    for playerId, state in pairs(RateOfFire.burstState) do
        if state.shotsRemaining <= 0 then
            RateOfFire.burstState[playerId] = nil
        elseif now >= state.nextShotTime then
            local player = getSpecificPlayer(playerId)

            if player and not player:isDead() and player:isAiming() then
                local weapon = state.weapon
                if weapon and ISReloadWeaponAction.canShoot(player, weapon) then
                    RateOfFire.applySpreadOnShot(player, weapon, state.intervalMs)
                    state.attackHook(player, state.chargeDelta, weapon)
                end
            end

            state.shotsRemaining = state.shotsRemaining - 1
            state.nextShotTime = now + state.intervalMs

            if state.shotsRemaining <= 0 then
                RateOfFire.burstCooldown[playerId] = now + RateOfFire.BURST_DELAY_MS
                RateOfFire.burstState[playerId] = nil
            end
        end
    end
end

Events.OnGameStart.Add(function()
    local Original_Attack_Hook = ISReloadWeaponAction.attackHook

    ISReloadWeaponAction.RAFattackHook = function(character, chargeDelta, weapon)
        if weapon:isRanged() and not character:isDoShove() then
            local canFire, intervalMs = RateOfFire.canFire(character, weapon)
            if not canFire then return end

            RateOfFire.applySpreadOnShot(character, weapon, intervalMs)

            if weapon:getFireMode() == "RealBurst" then
                if RateOfFire.burstState[character:getPlayerNum()] then return end
                if not RateOfFire.canStartBurst(character) then return end

                local result = Original_Attack_Hook(character, chargeDelta, weapon)
                RateOfFire.startBurst(character, weapon, intervalMs, Original_Attack_Hook, chargeDelta)
                return result
            end
        end

        return Original_Attack_Hook(character, chargeDelta, weapon)
    end

    Hook.Attack.Remove(ISReloadWeaponAction.attackHook)
    Hook.Attack.Add(ISReloadWeaponAction.RAFattackHook)
    Events.OnTick.Add(RateOfFire.burstTickHandler)
    Events.OnTick.Add(RateOfFire.decaySpreadTick)
end)

-------------------------------------------------
-- Recoil Delay Utilities (shared for SP + MP)
-------------------------------------------------

function RateOfFire.CalcRecoilDelayShadow(weapon)
    local shadow = StatsFactory.GetBaseStatsWithAttachments(weapon)
    return shadow:getRecoilDelay()
end

function RateOfFire.RecoilDelayAdjuster(player, weapon)
    if not weapon or not player then return end
    if not weapon:isRanged() then return end

    local mode = weapon:getFireMode()

    if mode == "RealAuto" or mode == "RealBurst" then
        weapon:setRecoilDelay(1)
    elseif mode == "RealSingle" then
        weapon:setRecoilDelay(RateOfFire.CalcRecoilDelayShadow(weapon))
    end
end

function RateOfFire.GetWeaponById(player, itemId)
    if not player or not itemId then return nil end
    local item = player:getInventory():getItemById(itemId)
    if item and instanceof(item, "HandWeapon") then return item end
    return nil
end

return RateOfFire
