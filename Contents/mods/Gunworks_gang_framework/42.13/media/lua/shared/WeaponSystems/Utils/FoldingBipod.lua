local FoldingBipod = {}
local StatsFactory = require("WeaponSystems/Utils/StatsFactory")

-------------------------------------------------
-- Single source of truth: weaponType -> { modifiers, models?, attachments?, initialState? }
-- modifiers:    { folded = { ... }, deployed = { ... } }  (each key is optional)
--              StatsFactory modifier functions applied in the matching state.
-- initialState: "folded" (default) | "deployed"  — state on first use (no saved ModData)
--
-- Visual mode (pick ONE):
--   models:      { folded = "SPRITE_NAME", deployed = "SPRITE_NAME" }
--   attachments: { partType = "bipod", folded = "MyMod.BipodFolded", deployed = "MyMod.BipodDeployed" }
-------------------------------------------------
FoldingBipod.WeaponsWithFoldableBipod = {}

-------------------------------------------------
-- Restore Stats: set of stat names bipod modifiers may modify.
-- Content mods populate this via FoldingBipod.RegisterRestoreStats.
-------------------------------------------------
FoldingBipod.RestoreStats = {}

--- Declare which stats bipod profiles may modify.
---@param statNames string[]  e.g. { "RecoilDelay", "SwingTime", ... }
function FoldingBipod.RegisterRestoreStats(statNames)
    for _, name in ipairs(statNames) do
        FoldingBipod.RestoreStats[name] = true
    end
end

-------------------------------------------------
-- Registration API for modders
-------------------------------------------------

--- Register a weapon as having a foldable bipod
--- @param weaponType string   e.g. "MyMod.MyLMG"
--- @param entry table  { modifiers = { folded = { ... }?, deployed = { ... }? }, models = { ... }?, attachments = { ... }?, initialState = "folded"|"deployed"? }
function FoldingBipod.RegisterWeapon(weaponType, entry)
    FoldingBipod.WeaponsWithFoldableBipod[weaponType] = entry
end

function FoldingBipod.RegisterMultipleWeapons(entriesTable)
    if not entriesTable then return end

    for weaponType, entry in pairs(entriesTable) do
        FoldingBipod.RegisterWeapon(weaponType, entry)
    end
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

    local md = weapon:getModData()
    if md.BipodDeployed == nil then
        local entry = FoldingBipod.WeaponsWithFoldableBipod[weapon:getFullType()]
        local initial = entry and entry.initialState or "folded"
        md.BipodDeployed = (initial == "deployed")
    end
    FoldingBipod.SwapBipodVisual(weapon, md.BipodDeployed)
    FoldingBipod.DeployedBipodAdjustStats(weapon)
end

-------------------------------------------------
-- Register modifier layer with StatsFactory
-------------------------------------------------
StatsFactory.RegisterModifierLayer("FoldingBipod", function(weapon)
    local entry = FoldingBipod.WeaponsWithFoldableBipod[weapon:getFullType()]
    if not entry or not entry.modifiers then return nil end
    local state = FoldingBipod.IsBipodDeployed(weapon) and "deployed" or "folded"
    return entry.modifiers[state]
end, FoldingBipod.RestoreStats)

return FoldingBipod
