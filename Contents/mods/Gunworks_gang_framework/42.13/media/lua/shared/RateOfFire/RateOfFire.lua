require("TimedActions/ISReloadWeaponAction")
local StatsFactory = require("WeaponSystems/Utils/StatsFactory")
-------------------------------------------------
-- Rate of Fire Control System
-------------------------------------------------
local RateOfFire = {}

RateOfFire.lastFireTime = {}
RateOfFire.DEFAULT_RPM = 600
RateOfFire.BURST_DEFAULT_COUNT = 3
RateOfFire.BURST_DELAY_MS = 500
RateOfFire.burstState = {}
RateOfFire.burstCooldown = {}

-------------------------------------------------
-- Registry tables  (keyed by weapon fullType)
-------------------------------------------------
RateOfFire.WeaponProfiles = {} -- fullType -> { rpm = number, burstCount = number }

--- Register a single weapon with custom RPM and/or burst count.
---@param weaponType string       fullType e.g. "MWA.M16A3"
---@param entry table             { rpm = number?, burstCount = number? }
function RateOfFire.RegisterWeapon(weaponType, entry)
    RateOfFire.WeaponProfiles[weaponType] = entry
end

--- Convenience: register the same profile for multiple weapon types.
---@param weaponTypes string[]    array of fullType strings
---@param entry table             { rpm = number?, burstCount = number? }
function RateOfFire.RegisterWeapons(weaponTypes, entry)
    for i = 1, #weaponTypes do
        RateOfFire.WeaponProfiles[weaponTypes[i]] = entry
    end
end

-------------------------------------------------
-- Query helpers
-------------------------------------------------

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
