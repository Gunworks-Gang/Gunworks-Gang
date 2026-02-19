local FoldingStock = {}
local StatsFactory = require("WeaponSystems/Utils/StatsFactory")

FoldingStock.WeaponsWithFoldableStock = {}

-------------------------------------------------
-- Folded Stock Stats: weaponType -> array of modifier functions
-- Modifiers only apply when stock is folded; base stats restore when unfolded
-------------------------------------------------
FoldingStock.FoldedStockStats = {}

-------------------------------------------------
-- Registration API for modders
-------------------------------------------------

-- FoldingStock.RegisterWeapon("MyMod.MyAK", {
--     SF.Adjust("AimingTime", -5),
-- })

--- Register a weapon as having a foldable stock
--- @param weaponType string  e.g. "MyMod.MyGun"
--- @param modifiers table|nil  optional array of StatsFactory modifier functions
function FoldingStock.RegisterWeapon(weaponType, modifiers)
    table.insert(FoldingStock.WeaponsWithFoldableStock, weaponType)
    if modifiers then
        FoldingStock.FoldedStockStats[weaponType] = modifiers
    end
end

function FoldingStock.FoldedStockAdjustStats(weapon)
    if not weapon then return end

    local weaponType = weapon:getFullType()
    local modifiers  = FoldingStock.FoldedStockStats[weaponType]
    if not modifiers then return end

    local baseStats = instanceItem(weaponType)
    local isFolded  = FoldingStock.IsStockFolded(weapon)

    if isFolded then
        StatsFactory.ApplyModifiers(weapon, baseStats, modifiers)
    else
        StatsFactory.RestoreBaseStats(weapon, baseStats)
    end
end

function FoldingStock.HasFoldableStock(weapon)
    if not weapon then return false end
    local weaponType = weapon:getFullType()
    for _, entry in ipairs(FoldingStock.WeaponsWithFoldableStock) do
        if entry == weaponType then return true end
    end
    return false
end

function FoldingStock.IsStockFolded(weapon)
    if not weapon then return false end
    return weapon:getModData().StockFolded
end

function FoldingStock.ToggleFoldStock(weapon)
    if not weapon then return end
    if not FoldingStock.HasFoldableStock(weapon) then return end

    local isFolded = FoldingStock.IsStockFolded(weapon)
    local newFolded = not isFolded

    weapon:getModData().StockFolded = newFolded
    FoldingStock.MWAFoldedModel(weapon, newFolded)
    FoldingStock.FoldedStockAdjustStats(weapon)
end

function FoldingStock.SetStockFolded(weapon, folded)
    if not weapon then return end
    if not FoldingStock.HasFoldableStock(weapon) then return end

    weapon:getModData().StockFolded = not folded
    FoldingStock.MWAFoldedModel(weapon, folded)
    FoldingStock.FoldedStockAdjustStats(weapon)
end

function FoldingStock.RestoreFoldedStockState(weapon)
    if not weapon then return end
    if not FoldingStock.HasFoldableStock(weapon) then return end

    local isFolded = weapon:getModData().StockFolded
    if isFolded then
        FoldingStock.MWAFoldedModel(weapon, true)
        FoldingStock.FoldedStockAdjustStats(weapon)
    end
end

function FoldingStock.MWAFoldedModel(weapon, folded)
    if not weapon then return end

    local currentSprite = weapon:getWeaponSprite()
    local hasOpen = currentSprite:match("_OPEN$") ~= nil
    local baseSprite = currentSprite:gsub("_OPEN$", ""):gsub("_FOLDED$", "")

    local newSprite = baseSprite
    if folded then
        newSprite = newSprite .. "_FOLDED"
    end
    if hasOpen then
        newSprite = newSprite .. "_OPEN"
    end

    weapon:setWeaponSprite(newSprite)
end

return FoldingStock
