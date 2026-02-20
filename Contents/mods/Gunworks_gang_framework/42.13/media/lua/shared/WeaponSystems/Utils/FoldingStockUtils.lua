local FoldingStock = {}
local StatsFactory = require("WeaponSystems/Utils/StatsFactory")

-------------------------------------------------
-- Single source of truth: weaponType -> { modifiers, models }
-- modifiers: array of StatsFactory modifier functions (applied when folded)
-- models:   { unfolded = "SPRITE_NAME", folded = "SPRITE_NAME" }
-------------------------------------------------
FoldingStock.WeaponsWithFoldableStock = {}

-------------------------------------------------
-- Registration API for modders
-------------------------------------------------

--- Register a weapon as having a foldable stock
--- @param weaponType string   e.g. "MyMod.MyAK"
--- @param entry table  { modifiers = { ... }, models = { unfolded = "...", folded = "..." } }
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

    local entry = FoldingStock.WeaponsWithFoldableStock[weapon:getFullType()]
    if not entry or not entry.modifiers then return end

    local baseStats = StatsFactory.GetBaseStatsWithAttachments(weapon)
    local isFolded  = FoldingStock.IsStockFolded(weapon)

    StatsFactory.RestoreBaseStats(weapon, baseStats)

    if isFolded then
        StatsFactory.ApplyModifiers(weapon, baseStats, entry.modifiers)
    end
end

function FoldingStock.SwapStockModel(weapon, folded)
    if not weapon then return end

    local entry = FoldingStock.WeaponsWithFoldableStock[weapon:getFullType()]
    if not entry or not entry.models then return end

    local newSprite = folded and entry.models.folded or entry.models.unfolded
    weapon:setWeaponSprite(newSprite)
end

function FoldingStock.ToggleFoldStock(weapon)
    if not weapon then return end
    if not FoldingStock.HasFoldableStock(weapon) then return end

    local newFolded = not FoldingStock.IsStockFolded(weapon)
    weapon:getModData().StockFolded = newFolded
    FoldingStock.SwapStockModel(weapon, newFolded)
    FoldingStock.FoldedStockAdjustStats(weapon)
end

function FoldingStock.SetStockFolded(weapon, folded)
    if not weapon then return end
    if not FoldingStock.HasFoldableStock(weapon) then return end

    weapon:getModData().StockFolded = folded
    FoldingStock.SwapStockModel(weapon, folded)
    FoldingStock.FoldedStockAdjustStats(weapon)
end

function FoldingStock.RestoreFoldedStockState(weapon)
    if not weapon then return end
    if not FoldingStock.HasFoldableStock(weapon) then return end

    local isFolded = FoldingStock.IsStockFolded(weapon)
    if isFolded then
        FoldingStock.SwapStockModel(weapon, true)
        FoldingStock.FoldedStockAdjustStats(weapon)
    end
end

return FoldingStock
