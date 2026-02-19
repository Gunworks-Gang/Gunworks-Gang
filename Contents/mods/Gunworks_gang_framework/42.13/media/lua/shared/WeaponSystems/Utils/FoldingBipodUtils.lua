local FoldingBipod = {}
local StatsFactory = require("WeaponSystems/Utils/StatsFactory")

FoldingBipod.WeaponsWithFoldableBipod = {}

-------------------------------------------------
-- Deployed Bipod Stats: weaponType -> array of modifier functions
-- Modifiers only apply when bipod is deployed; base stats restore when folded
-------------------------------------------------
FoldingBipod.DeployedBipodStats = {}

-------------------------------------------------
-- Registration API for modders
-------------------------------------------------

-- FoldingBipod.RegisterWeapon("MyMod.MyLMG", {
--     SF.Adjust("RecoilDelay", 10),
--     SF.Multiply("AimingTime", 0.7),
-- })

--- Register a weapon as having a foldable bipod
--- @param weaponType string  e.g. "MyMod.MyGun"
--- @param modifiers table|nil  optional array of StatsFactory modifier functions
function FoldingBipod.RegisterWeapon(weaponType, modifiers)
    table.insert(FoldingBipod.WeaponsWithFoldableBipod, weaponType)
    if modifiers then
        FoldingBipod.DeployedBipodStats[weaponType] = modifiers
    end
end

function FoldingBipod.DeployedBipodAdjustStats(weapon)
    if not weapon then return end

    local weaponType = weapon:getFullType()
    local modifiers  = FoldingBipod.DeployedBipodStats[weaponType]
    if not modifiers then return end

    local baseStats  = instanceItem(weaponType)
    local isDeployed = FoldingBipod.IsBipodDeployed(weapon)

    if isDeployed then
        StatsFactory.ApplyModifiers(weapon, baseStats, modifiers)
    else
        StatsFactory.RestoreBaseStats(weapon, baseStats)
    end
end

function FoldingBipod.HasFoldableBipod(weapon)
    if not weapon then return false end
    local weaponType = weapon:getFullType()
    for _, entry in ipairs(FoldingBipod.WeaponsWithFoldableBipod) do
        if entry == weaponType then return true end
    end
    return false
end

function FoldingBipod.IsBipodDeployed(weapon)
    if not weapon then return false end
    return weapon:getModData().BipodDeployed
end

function FoldingBipod.ToggleDeployBipod(weapon)
    if not weapon then return end
    if not FoldingBipod.HasFoldableBipod(weapon) then return end

    local isDeployed = FoldingBipod.IsBipodDeployed(weapon)
    local newDeployed = not isDeployed

    weapon:getModData().BipodDeployed = newDeployed
    FoldingBipod.SwapBipodModel(weapon, newDeployed)
    FoldingBipod.DeployedBipodAdjustStats(weapon)
end

function FoldingBipod.SetBipodDeployed(weapon, deployed)
    if not weapon then return end
    if not FoldingBipod.HasFoldableBipod(weapon) then return end

    weapon:getModData().BipodDeployed = deployed
    FoldingBipod.SwapBipodModel(weapon, deployed)
    FoldingBipod.DeployedBipodAdjustStats(weapon)
end

function FoldingBipod.RestoreDeployedBipodState(weapon)
    if not weapon then return end
    if not FoldingBipod.HasFoldableBipod(weapon) then return end

    local isDeployed = FoldingBipod.IsBipodDeployed(weapon)
    if isDeployed then
        FoldingBipod.SwapBipodModel(weapon, true)
        FoldingBipod.DeployedBipodAdjustStats(weapon)
    end
end

function FoldingBipod.SwapBipodModel(weapon, deployed)
    if not weapon then return end

    local currentSprite = weapon:getWeaponSprite()
    local baseSprite = currentSprite:gsub("_DEPLOYED$", "")

    local newSprite = baseSprite
    if deployed then
        newSprite = newSprite .. "_DEPLOYED"
    end

    weapon:setWeaponSprite(newSprite)
end

return FoldingBipod
