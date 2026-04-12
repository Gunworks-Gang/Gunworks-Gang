require("WeaponSystems/Utils/CustomStatsAttachmentsUtil")

local FoldingStock = require("WeaponSystems/Utils/FoldingStockUtils")
local FoldingBipod = require("WeaponSystems/Utils/FoldingBipodUtils")
local StatsFactory = require("WeaponSystems/Utils/StatsFactory")
local Underbarrel  = require("WeaponSystems/Utils/UnderbarrelUtils")

local function restoreContainer(container)
    if not container then return end
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)

        if instanceof(item, "HandWeapon") and item:isRanged() then
            -- Force back to main-weapon mode BEFORE other restores so that
            -- ReapplyAllModifiers always starts from a clean original base.
            Underbarrel.RestoreOnLoad(item)
            FoldingStock.RestoreFoldedStockState(item)
            FoldingBipod.RestoreDeployedBipodState(item)
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

local function restoreEquippedWeapon(playerObj, weapon)
    if not playerObj or not weapon then return end
    if instanceof(weapon, "HandWeapon") and weapon:isRanged() then
        Underbarrel.RestoreOnLoad(weapon)
        FoldingStock.RestoreFoldedStockState(weapon)
        FoldingBipod.RestoreDeployedBipodState(weapon)
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
