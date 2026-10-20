local Bayonet = require("WeaponSystems/Utils/Bayonet")

local CHARGE_DELAY_MS = 1000
local sprintStartTimes = {}

local function bayonetCharge(player)
    if not player:isSprinting() then
        sprintStartTimes[player] = nil
        return
    end

    local weapon = player:getPrimaryHandItem()
    if not weapon then return end
    local weaponHasBayonet = weapon:getModData().GW_BayonetDeployed
    if not weaponHasBayonet then return end

    local now = getTimestampMs()
    local sprintStart = sprintStartTimes[player]
    if not sprintStart then
        sprintStartTimes[player] = now
        return
    end

    if now - sprintStart >= CHARGE_DELAY_MS then
        Bayonet.BayonetAttack(player, 0, weapon)
    end
end

Events.OnPlayerUpdate.Add(bayonetCharge)
