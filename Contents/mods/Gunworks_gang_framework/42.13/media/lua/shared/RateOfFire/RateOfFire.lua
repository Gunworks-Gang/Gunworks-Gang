require("TimedActions/ISReloadWeaponAction")
-------------------------------------------------
-- Rate of Fire Control System
-------------------------------------------------
local RateOfFire = {}

RateOfFire.lastFireTime = {}
RateOfFire.DEFAULT_RPM = 600
RateOfFire.RPMTagList = {
    { Gunworks_Tags.RPM1200, 1200 },
    { Gunworks_Tags.RPM1150, 1150 },
    { Gunworks_Tags.RPM1100, 1100 },
    { Gunworks_Tags.RPM1050, 1050 },
    { Gunworks_Tags.RPM1000, 1000 },
    { Gunworks_Tags.RPM950,  950 },
    { Gunworks_Tags.RPM900,  900 },
    { Gunworks_Tags.RPM850,  850 },
    { Gunworks_Tags.RPM800,  800 },
    { Gunworks_Tags.RPM750,  750 },
    { Gunworks_Tags.RPM700,  700 },
    { Gunworks_Tags.RPM650,  650 },
    { Gunworks_Tags.RPM600,  600 },
    { Gunworks_Tags.RPM550,  550 },
    { Gunworks_Tags.RPM500,  500 },
    { Gunworks_Tags.RPM450,  450 },
    { Gunworks_Tags.RPM400,  400 },
    { Gunworks_Tags.RPM350,  350 },
    { Gunworks_Tags.RPM300,  300 },
}
RateOfFire.burstState = {}
RateOfFire.BURST_DEFAULT_COUNT = 3
RateOfFire.BURST_DELAY_MS = 500
RateOfFire.burstCooldown = {}
RateOfFire.BURSTTagList = {
    { Gunworks_Tags.BURST4, 4 },
    { Gunworks_Tags.BURST3, 3 },
    { Gunworks_Tags.BURST2, 2 },
}

function RateOfFire.getWeaponRPM(weapon)
    if not weapon then return RateOfFire.DEFAULT_RPM end
    for _, entry in ipairs(RateOfFire.RPMTagList) do
        local tag, rpm = entry[1], entry[2]
        if weapon:hasTag(tag) then return rpm end
    end
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
    for _, entry in ipairs(RateOfFire.BURSTTagList) do
        local tag, rpm = entry[1], entry[2]
        if weapon:hasTag(tag) then return rpm end
    end
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
    local shadow = instanceItem(weapon:getFullType())

    local parts = weapon:getAllWeaponParts()
    if parts then
        for i = 0, parts:size() - 1 do
            local part = parts:get(i)
            if part then
                local partCopy = instanceItem(part:getFullType())
                if partCopy and instanceof(partCopy, "WeaponPart") then
                    if shadow.canAttachWeaponPart == nil or shadow:canAttachWeaponPart(partCopy) then
                        shadow:attachWeaponPart(partCopy)
                    end
                end
            end
        end
    end
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
