local FoldingBipod = {}
local StatsFactory = require("WeaponSystems/Utils/StatsFactory")

-------------------------------------------------
-- Single source of truth: weaponType -> { modifiers, models }
-- modifiers: array of StatsFactory modifier functions (applied when deployed)
-- models:   { folded = "SPRITE_NAME", deployed = "SPRITE_NAME" }
-------------------------------------------------
FoldingBipod.WeaponsWithFoldableBipod = {}

-------------------------------------------------
-- Registration API for modders
-------------------------------------------------

--- Register a weapon as having a foldable bipod
--- @param weaponType string   e.g. "MyMod.MyLMG"
--- @param entry table  { modifiers = { ... }, models = { folded = "...", deployed = "..." } }
function FoldingBipod.RegisterWeapon(weaponType, entry)
    FoldingBipod.WeaponsWithFoldableBipod[weaponType] = entry
end

-------------------------------------------------
-- Core functions
-------------------------------------------------

function FoldingBipod.HasFoldableBipod(weapon)
    if not weapon then return false end
    return FoldingBipod.WeaponsWithFoldableBipod[weapon:getFullType()] ~= nil
end

function FoldingBipod.IsBipodDeployed(weapon)
    if not weapon then return false end
    return weapon:getModData().BipodDeployed
end

function FoldingBipod.DeployedBipodAdjustStats(weapon)
    if not weapon then return end

    local entry = FoldingBipod.WeaponsWithFoldableBipod[weapon:getFullType()]
    if not entry or not entry.modifiers then return end

    local baseStats  = StatsFactory.GetBaseStatsWithAttachments(weapon)
    local isDeployed = FoldingBipod.IsBipodDeployed(weapon)

    StatsFactory.RestoreBaseStats(weapon, baseStats)

    if isDeployed then
        StatsFactory.ApplyModifiers(weapon, baseStats, entry.modifiers)
    end
end

function FoldingBipod.SwapBipodModel(weapon, deployed)
    if not weapon then return end

    local entry = FoldingBipod.WeaponsWithFoldableBipod[weapon:getFullType()]
    if not entry or not entry.models then return end

    local newSprite = deployed and entry.models.deployed or entry.models.folded
    weapon:setWeaponSprite(newSprite)
end

function FoldingBipod.ToggleDeployBipod(weapon)
    if not weapon then return end
    if not FoldingBipod.HasFoldableBipod(weapon) then return end

    local newDeployed = not FoldingBipod.IsBipodDeployed(weapon)
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

return FoldingBipod
