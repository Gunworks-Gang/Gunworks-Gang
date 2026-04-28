require("WeaponSystems/Utils/CustomStatsAttachments")

local Bayonet      = require("WeaponSystems/Utils/Bayonet")
local FoldingStock = require("WeaponSystems/Utils/FoldingStock")
local FoldingBipod = require("WeaponSystems/Utils/FoldingBipod")
local StatsFactory = require("WeaponSystems/Utils/StatsFactory")
local Underbarrel  = require("WeaponSystems/Utils/Underbarrel")

local function restoreContainer(container)
    if not container then return end
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)

        if instanceof(item, "HandWeapon") and item:isRanged() then
            Underbarrel.RestoreOnLoad(item)
            FoldingStock.RestoreFoldedStockState(item)
            FoldingBipod.RestoreDeployedBipodState(item)
            Bayonet.RestoreIntegratedBayonetState(item)
            StatsFactory.ReapplyAllModifiers(item)
        end

        if item.getInventory and item:getInventory() then
            restoreContainer(item:getInventory())
        end
    end
end

local function restorePlayer(playerObj)
    if not playerObj then return end
    restoreContainer(playerObj:getInventory())
end

local function consumeSyncEquipRestoreSkip(weapon)
    if not weapon then return false end
    local modData = weapon:getModData()
    local remaining = modData.GW_SkipEquipRestoreCount
    if not remaining or remaining <= 0 then
        return false
    end

    remaining = remaining - 1
    if remaining > 0 then
        modData.GW_SkipEquipRestoreCount = remaining
    else
        modData.GW_SkipEquipRestoreCount = nil
    end

    return true
end

local function restoreEquippedWeapon(playerObj, weapon)
    if not playerObj or not weapon then return end
    if instanceof(weapon, "HandWeapon") and weapon:isRanged() then
        if consumeSyncEquipRestoreSkip(weapon) then return end
        Underbarrel.RestoreOnLoad(weapon)
        FoldingStock.RestoreFoldedStockState(weapon)
        FoldingBipod.RestoreDeployedBipodState(weapon)
        Bayonet.RestoreIntegratedBayonetState(weapon)
        StatsFactory.ReapplyAllModifiers(weapon)
    end
end

Events.OnGameStart.Add(function()
    for i = 0, getNumActivePlayers() - 1 do
        restorePlayer(getSpecificPlayer(i))
    end
end)

Events.OnCreatePlayer.Add(function(_, playerObj)
    restorePlayer(playerObj)
end)

Events.OnEquipPrimary.Add(restoreEquippedWeapon)

Events.OnEquipSecondary.Add(restoreEquippedWeapon)
