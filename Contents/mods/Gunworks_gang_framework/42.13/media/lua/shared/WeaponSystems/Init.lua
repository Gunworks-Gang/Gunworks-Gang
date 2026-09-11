require("WeaponSystems/Utils/CustomStatsAttachments")
require("WeaponSystems/Utils/ConditionalModel")

local Animations   = require("WeaponSystems/Utils/Animations")
local Bayonet      = require("WeaponSystems/Utils/Bayonet")
local FoldingStock = require("WeaponSystems/Utils/FoldingStock")
local FoldingBipod = require("WeaponSystems/Utils/FoldingBipod")
local Magazine     = require("WeaponSystems/Utils/Magazine")
local StatsFactory = require("WeaponSystems/Utils/StatsFactory")
local Underbarrel  = require("WeaponSystems/Utils/Underbarrel")
local Ammo         = require("WeaponSystems/Utils/Ammo")

local function restoreContainer(container)
    if not container then return end
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)

        if instanceof(item, "HandWeapon") and item:isRanged() then
            Magazine.RestoreMagazineType(item)
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
    Ammo.RestoreOnLoad(playerObj)
    Underbarrel.RecoverLostHost(playerObj)
end

local function restoreEquippedWeapon(playerObj, weapon)
    if not playerObj or not weapon then return end
    if instanceof(weapon, "HandWeapon") and weapon:isRanged() then
        if Animations.IsFiringRefresh() then return end
        Magazine.RestoreMagazineType(weapon)
        Underbarrel.RestoreOnLoad(weapon)
        FoldingStock.RestoreFoldedStockState(weapon)
        FoldingBipod.RestoreDeployedBipodState(weapon)
        Bayonet.RestoreIntegratedBayonetState(weapon)
        StatsFactory.ReapplyAllModifiers(weapon)
    end
end

Events.OnGameStart.Add(function()
    local player = getSpecificPlayer(0)
    if player then
        restorePlayer(player)
    end
end)

Events.OnCreatePlayer.Add(function(_, playerObj)
    restorePlayer(playerObj)
end)

Events.OnEquipPrimary.Add(restoreEquippedWeapon)
Events.OnEquipSecondary.Add(restoreEquippedWeapon)
