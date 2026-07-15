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
RateOfFire.SPREAD_INITIAL_DEFAULT   = 0.0
RateOfFire.SPREAD_SUSTAINED_DEFAULT = 0.1
RateOfFire.SPREAD_MAX_DEFAULT       = 3
RateOfFire.SpreadPartModifiers      = {}

RateOfFire.MOODLE_SPREAD_MULT       = { [0] = 1.0, [1] = 1.5, [2] = 2.0, [3] = 3.0, [4] = 4.0 }

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
function RateOfFire.RegisterMultipleWeaponsWithSameProfile(weaponTypes, entry)
    for i = 1, #weaponTypes do
        RateOfFire.WeaponProfiles[weaponTypes[i]] = entry
    end
end

--- Convenience: register multiple weapon types with their entry.
---@param entriesTable table    { [weaponType] = { rpm = number?, burstCount = number?, enableSpread = boolean?,
---                                 initialSpread = number?, sustainedSpread = number?, maxSpread = number? } }
function RateOfFire.RegisterMultipleWeapons(entriesTable)
    for weaponType, entry in pairs(entriesTable) do
        RateOfFire.WeaponProfiles[weaponType] = entry
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
---@param modifiersTable table         { [partType] = { sustainedSpreadMult = number?, maxSpreadMult = number? } }
function RateOfFire.RegisterMultipleSpreadPartModifier(modifiersTable)
    for partType, entry in pairs(modifiersTable) do
        RateOfFire.SpreadPartModifiers[partType] = entry
    end
end

--- Register a spread multiplier for a single weapon ammo fullType.
--- When a weapon uses this ammo, sustainedSpread and maxSpread are multiplied.
---@param ammoType string         fullType of the ammo e.g. "MWA.556x45"
---@param entry table             { sustainedSpreadMult = number?, maxSpreadMult = number? }
function RateOfFire.RegisterSpreadAmmoModifier(ammoType, entry)
    RateOfFire.SpreadPartModifiers[ammoType] = entry
end

--- Convenience: register spread multipliers for multiple ammo types at once.
---@param modifiersTable table         { [ammoType] = { sustainedSpreadMult = number?, maxSpreadMult = number? } }
function RateOfFire.RegisterMultipleSpreadAmmoModifier(modifiersTable)
    for ammoType, entry in pairs(modifiersTable) do
        RateOfFire.SpreadPartModifiers[ammoType] = entry
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

    local ammo = weapon:getAmmoType():getItemKey()
    if ammo then
        local mod = RateOfFire.SpreadPartModifiers[ammo]
        if mod then
            if mod.sustainedSpreadMult then
                sp.sustainedSpread = sp.sustainedSpread * mod.sustainedSpreadMult
            end
            if mod.maxSpreadMult then
                sp.maxSpread = sp.maxSpread * mod.maxSpreadMult
            end
        end
    end

    return sp
end

--- Returns the combined spread multiplier from ENDURANCE and TIRED moodles.
--- Both moodles stack multiplicatively (mirrors vanilla melee damage penalty).
--- initialSpread is intentionally unaffected — only sustainedSpread and maxSpread are scaled.
---@param player any  player object
---@return number     multiplier >= 1.0
function RateOfFire.getMoodleSpreadMult(player)
    if not player then return 1.0 end
    local moodles = player:getMoodles()
    if not moodles then return 1.0 end
    local enduranceMult = RateOfFire.MOODLE_SPREAD_MULT[moodles:getMoodleLevel(MoodleType.ENDURANCE)] or 1.0
    local tiredMult     = RateOfFire.MOODLE_SPREAD_MULT[moodles:getMoodleLevel(MoodleType.TIRED)] or 1.0
    return enduranceMult * tiredMult
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

    local intervalMs = 60000 / rpm

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

    local moodleMult   = RateOfFire.getMoodleSpreadMult(player)
    sp.sustainedSpread = sp.sustainedSpread * moodleMult
    sp.maxSpread       = sp.maxSpread * moodleMult

    local playerId     = player:getPlayerNum()
    local now          = getTimestampMs()
    local fullType     = weapon:getFullType()
    local state        = RateOfFire.spreadState[playerId]

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

    StatsFactory.ReapplyAllModifiers(weapon)
end

function RateOfFire.GetWeaponById(player, itemId)
    if not player or not itemId then return nil end
    local item = player:getInventory():getItemById(itemId)
    if item and instanceof(item, "HandWeapon") then return item end
    return nil
end

StatsFactory.RegisterModifierLayer("RateOfFire", function(weapon)
    if not weapon or not weapon:isRanged() then return nil end
    local mode = weapon:getFireMode()
    if mode == "RealAuto" or mode == "RealBurst" then
        return { StatsFactory.Set("RecoilDelay", 1) }
    end
    return nil
end, { RecoilDelay = true })

return RateOfFire
