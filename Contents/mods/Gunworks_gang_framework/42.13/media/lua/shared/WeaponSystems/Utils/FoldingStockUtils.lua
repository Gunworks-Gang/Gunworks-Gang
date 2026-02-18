local FoldingStock = {}

FoldingStock.WeaponsWithFoldableStock = {
    ["MWA.M16A3"] = true,
}
FoldingStock.FoldedStockStats = {}

function FoldingStock.FoldedStockAdjustStats(weapon)
    if not weapon then return end

    local weaponType = weapon:getFullType()
    local stockStats = FoldingStock.FoldedStockStats[weaponType]
    if not stockStats then return end

    local isFolded                        = FoldingStock.IsStockFolded(weapon)
    local foldedMod                       = isFolded and 1 or 0
    local weaponBaseStats                 = instanceItem(weaponType)

    local baseAimingPerkCritModifier      = weaponBaseStats:getAimingPerkCritModifier()
    local baseAimingPerkHitChanceModifier = weaponBaseStats:getAimingPerkHitChanceModifier()
    local baseAimingTime                  = weaponBaseStats:getAimingTime()

    weapon:setAimingPerkCritModifier(baseAimingPerkCritModifier + (stockStats.AimingPerkCritModifier or 0) * foldedMod)
    weapon:setAimingPerkHitChanceModifier(baseAimingPerkHitChanceModifier + (stockStats.AimingPerkHitChanceModifier or 0) * foldedMod)
    weapon:setAimingTime(baseAimingTime + (stockStats.AimingTime or 0) * foldedMod)
end

function FoldingStock.HasFoldableStock(weapon)
    return FoldingStock.WeaponsWithFoldableStock[weapon:getFullType()]
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
