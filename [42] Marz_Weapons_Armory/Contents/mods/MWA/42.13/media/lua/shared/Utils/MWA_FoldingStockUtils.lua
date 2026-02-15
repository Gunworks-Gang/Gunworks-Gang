local SWMG_FoldingStock = {}

SWMG_FoldingStock.FoldedStockStats = {
    -- ["MWA.SPAS_12"] = { AimingPerkCritModifier = -5, AimingPerkHitChanceModifier = -2, AimingTime = -20 },
    -- ["MWA.MP5"] = { AimingPerkCritModifier = -3, AimingPerkHitChanceModifier = -2, AimingTime = -20 },
}
SWMG_FoldingStock.STOCK_FOLDED_KEY = "MWA_StockFolded"

function SWMG_FoldingStock.FoldedStockAdjustStats(weapon)
    if not weapon then return end

    local weaponType                      = weapon:getFullType()
    local stockStats                      = SWMG_FoldingStock.FoldedStockStats[weaponType]
    local isFolded                        = SWMG_FoldingStock.IsStockFolded(weapon)
    local foldedMod                       = isFolded and 1 or 0
    local weaponBaseStats                 = instanceItem(weaponType)

    local baseAimingPerkCritModifier      = weaponBaseStats:getAimingPerkCritModifier()
    local baseAimingPerkHitChanceModifier = weaponBaseStats:getAimingPerkHitChanceModifier()
    local baseAimingTime                  = weaponBaseStats:getAimingTime()

    weapon:setAimingPerkCritModifier(baseAimingPerkCritModifier + (stockStats.AimingPerkCritModifier or 0) * foldedMod)
    weapon:setAimingPerkHitChanceModifier(baseAimingPerkHitChanceModifier + (stockStats.AimingPerkHitChanceModifier or 0) * foldedMod)
    weapon:setAimingTime(baseAimingTime + (stockStats.AimingTime or 0) * foldedMod)
end

function SWMG_FoldingStock.HasFoldableStock(weapon)
    if not weapon then return false end
    local modData = weapon:getModData()
    return modData and modData.FoldableStock == "true"
end

function SWMG_FoldingStock.IsStockFolded(weapon)
    if not weapon then return false end
    local modData = weapon:getModData()
    return modData[SWMG_FoldingStock.STOCK_FOLDED_KEY] == true
end

function SWMG_FoldingStock.ToggleFoldStock(weapon)
    if not weapon then return end
    if not SWMG_FoldingStock.HasFoldableStock(weapon) then return end

    local isFolded = SWMG_FoldingStock.IsStockFolded(weapon)
    local newFolded = not isFolded

    weapon:getModData()[SWMG_FoldingStock.STOCK_FOLDED_KEY] = newFolded
    MWAFoldedModel(weapon, newFolded)
    SWMG_FoldingStock.FoldedStockAdjustStats(weapon)
end

function SWMG_FoldingStock.SetStockFolded(weapon, folded)
    if not weapon then return end
    if not SWMG_FoldingStock.HasFoldableStock(weapon) then return end

    weapon:getModData()[SWMG_FoldingStock.STOCK_FOLDED_KEY] = folded
    MWAFoldedModel(weapon, folded)
    SWMG_FoldingStock.FoldedStockAdjustStats(weapon)
end

function SWMG_FoldingStock.RestoreFoldedStockState(weapon)
    if not weapon then return end
    if not SWMG_FoldingStock.HasFoldableStock(weapon) then return end

    local isFolded = weapon:getModData()[SWMG_FoldingStock.STOCK_FOLDED_KEY]
    if isFolded then
        MWAFoldedModel(weapon, true)
        SWMG_FoldingStock.FoldedStockAdjustStats(weapon)
    end
end

return SWMG_FoldingStock
