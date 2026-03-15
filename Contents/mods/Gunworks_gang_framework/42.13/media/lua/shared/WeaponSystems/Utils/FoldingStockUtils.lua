local FoldingStock = {}
local StatsFactory = require("WeaponSystems/Utils/StatsFactory")

-------------------------------------------------
-- Single source of truth: weaponType -> { modifiers, models?, attachments? }
-- modifiers:    array of StatsFactory modifier functions (applied when folded)
--
-- Visual mode (pick ONE):
--   models:      { unfolded = "SPRITE_NAME", folded = "SPRITE_NAME" }
--   attachments: { partType = "stock", unfolded = "MyMod.StockOpen", folded = "MyMod.StockClosed" }
-------------------------------------------------
FoldingStock.WeaponsWithFoldableStock = {}

-------------------------------------------------
-- Restore Stats: set of stat names stock modifiers may modify.
-- Content mods populate this via FoldingStock.RegisterRestoreStats.
-------------------------------------------------
FoldingStock.RestoreStats = {}

--- Declare which stats stock profiles may modify.
---@param statNames string[]  e.g. { "ReloadTime", ... }
function FoldingStock.RegisterRestoreStats(statNames)
    for _, name in ipairs(statNames) do
        FoldingStock.RestoreStats[name] = true
    end
end

-------------------------------------------------
-- Registration API for modders
-------------------------------------------------

--- Register a weapon as having a foldable stock
--- @param weaponType string   e.g. "MyMod.MyAK"
--- @param entry table  { modifiers = { ... }, models = { ... }?, attachments = { ... }? }
function FoldingStock.RegisterWeapon(weaponType, entry)
    FoldingStock.WeaponsWithFoldableStock[weaponType] = entry
end

-------------------------------------------------
-- Core functions
-------------------------------------------------

function FoldingStock.HasFoldableStock(weapon)
    if not weapon then return false end
    return FoldingStock.WeaponsWithFoldableStock[weapon:getFullType()] ~= nil
end

function FoldingStock.IsStockFolded(weapon)
    if not weapon then return false end
    return weapon:getModData().StockFolded
end

function FoldingStock.FoldedStockAdjustStats(weapon)
    if not weapon then return end
    StatsFactory.ReapplyAllModifiers(weapon)
end

function FoldingStock.SwapStockAttachment(weapon, partType, newItemType)
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

function FoldingStock.SwapStockVisual(weapon, folded)
    if not weapon then return end

    local entry = FoldingStock.WeaponsWithFoldableStock[weapon:getFullType()]
    if not entry then return end

    if entry.attachments then
        local att = entry.attachments
        local itemType = folded and att.folded or att.unfolded
        FoldingStock.SwapStockAttachment(weapon, att.partType, itemType)
    elseif entry.models then
        local newSprite = folded and entry.models.folded or entry.models.unfolded
        weapon:setWeaponSprite(newSprite)
    end
end

function FoldingStock.ToggleFoldStock(weapon)
    if not weapon then return end
    if not FoldingStock.HasFoldableStock(weapon) then return end

    local newFolded = not FoldingStock.IsStockFolded(weapon)
    weapon:getModData().StockFolded = newFolded
    FoldingStock.SwapStockVisual(weapon, newFolded)
    FoldingStock.FoldedStockAdjustStats(weapon)
end

function FoldingStock.SetStockFolded(weapon, folded)
    if not weapon then return end
    if not FoldingStock.HasFoldableStock(weapon) then return end

    weapon:getModData().StockFolded = folded
    FoldingStock.SwapStockVisual(weapon, folded)
    FoldingStock.FoldedStockAdjustStats(weapon)
end

function FoldingStock.RestoreFoldedStockState(weapon)
    if not weapon then return end
    if not FoldingStock.HasFoldableStock(weapon) then return end

    local isFolded = FoldingStock.IsStockFolded(weapon)
    if isFolded then
        FoldingStock.SwapStockVisual(weapon, true)
        FoldingStock.FoldedStockAdjustStats(weapon)
    end
end

-------------------------------------------------
-- Register modifier layer with StatsFactory
-------------------------------------------------
StatsFactory.RegisterModifierLayer("FoldingStock", function(weapon)
    if not FoldingStock.IsStockFolded(weapon) then return nil end
    local entry = FoldingStock.WeaponsWithFoldableStock[weapon:getFullType()]
    return entry and entry.modifiers
end, FoldingStock.RestoreStats)

return FoldingStock
