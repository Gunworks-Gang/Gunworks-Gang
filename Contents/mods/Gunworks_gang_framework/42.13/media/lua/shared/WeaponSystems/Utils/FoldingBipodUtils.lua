local FoldingBipod = {}
local StatsFactory = require("WeaponSystems/Utils/StatsFactory")

-------------------------------------------------
-- Single source of truth: weaponType -> { modifiers, models?, attachments? }
-- modifiers:    array of StatsFactory modifier functions (applied when deployed)
--
-- Visual mode (pick ONE):
--   models:      { folded = "SPRITE_NAME", deployed = "SPRITE_NAME" }
--   attachments: { partType = "bipod", folded = "MyMod.BipodFolded", deployed = "MyMod.BipodDeployed" }
-------------------------------------------------
FoldingBipod.WeaponsWithFoldableBipod = {}

-------------------------------------------------
-- Registration API for modders
-------------------------------------------------

--- Register a weapon as having a foldable bipod
--- @param weaponType string   e.g. "MyMod.MyLMG"
--- @param entry table  { modifiers = { ... }, models = { ... }?, attachments = { ... }? }
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
    StatsFactory.ReapplyAllModifiers(weapon)
end

function FoldingBipod.SwapBipodAttachment(weapon, partType, newItemType)
    if not weapon or not partType or not newItemType then return end

    local currentPart = weapon:getWeaponPart(partType)
    if currentPart then
        weapon:detachWeaponPart(currentPart)
    end

    local newPart = instanceItem(newItemType)
    if newPart and instanceof(newPart, "WeaponPart") then
        weapon:attachWeaponPart(newPart, true)
    end
end

function FoldingBipod.SwapBipodVisual(weapon, deployed)
    if not weapon then return end

    local entry = FoldingBipod.WeaponsWithFoldableBipod[weapon:getFullType()]
    if not entry then return end

    if entry.attachments then
        local att = entry.attachments
        local itemType = deployed and att.deployed or att.folded
        FoldingBipod.SwapBipodAttachment(weapon, att.partType, itemType)
    elseif entry.models then
        local newSprite = deployed and entry.models.deployed or entry.models.folded
        weapon:setWeaponSprite(newSprite)
    end
end

function FoldingBipod.ToggleDeployBipod(weapon)
    if not weapon then return end
    if not FoldingBipod.HasFoldableBipod(weapon) then return end

    local newDeployed = not FoldingBipod.IsBipodDeployed(weapon)
    weapon:getModData().BipodDeployed = newDeployed
    FoldingBipod.SwapBipodVisual(weapon, newDeployed)
    FoldingBipod.DeployedBipodAdjustStats(weapon)
end

function FoldingBipod.SetBipodDeployed(weapon, deployed)
    if not weapon then return end
    if not FoldingBipod.HasFoldableBipod(weapon) then return end

    weapon:getModData().BipodDeployed = deployed
    FoldingBipod.SwapBipodVisual(weapon, deployed)
    FoldingBipod.DeployedBipodAdjustStats(weapon)
end

function FoldingBipod.RestoreDeployedBipodState(weapon)
    if not weapon then return end
    if not FoldingBipod.HasFoldableBipod(weapon) then return end

    local isDeployed = FoldingBipod.IsBipodDeployed(weapon)
    if isDeployed then
        FoldingBipod.SwapBipodVisual(weapon, true)
        FoldingBipod.DeployedBipodAdjustStats(weapon)
    end
end

-------------------------------------------------
-- Register modifier layer with StatsFactory
-------------------------------------------------
StatsFactory.RegisterModifierLayer("FoldingBipod", function(weapon)
    if not FoldingBipod.IsBipodDeployed(weapon) then return nil end
    local entry = FoldingBipod.WeaponsWithFoldableBipod[weapon:getFullType()]
    return entry and entry.modifiers
end)

return FoldingBipod
