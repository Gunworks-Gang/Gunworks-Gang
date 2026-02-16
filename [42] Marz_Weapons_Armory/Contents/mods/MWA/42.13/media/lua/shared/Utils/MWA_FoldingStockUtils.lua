local SWMG_FoldingStock = {}

SWMG_FoldingStock.WeaponsWithFoldableStock = {
    ["MWA.M16A3"] = true,
}
SWMG_FoldingStock.FoldedStockStats = {}

function SWMG_FoldingStock.FoldedStockAdjustStats(weapon)
    if not weapon then return end

    local weaponType = weapon:getFullType()
    local stockStats = SWMG_FoldingStock.FoldedStockStats[weaponType]
    if not stockStats then return end

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
    return SWMG_FoldingStock.WeaponsWithFoldableStock[weapon:getFullType()]
end

function SWMG_FoldingStock.IsStockFolded(weapon)
    if not weapon then return false end
    return weapon:getModData().StockFolded
end

function SWMG_FoldingStock.ToggleFoldStock(weapon)
    if not weapon then return end
    if not SWMG_FoldingStock.HasFoldableStock(weapon) then return end

    local isFolded = SWMG_FoldingStock.IsStockFolded(weapon)
    local newFolded = not isFolded

    weapon:getModData().StockFolded = newFolded
    SWMG_FoldingStock.MWAFoldedModel(weapon, newFolded)
    SWMG_FoldingStock.FoldedStockAdjustStats(weapon)
end

function SWMG_FoldingStock.SetStockFolded(weapon, folded)
    if not weapon then return end
    if not SWMG_FoldingStock.HasFoldableStock(weapon) then return end

    weapon:getModData().StockFolded = not folded
    SWMG_FoldingStock.MWAFoldedModel(weapon, folded)
    SWMG_FoldingStock.FoldedStockAdjustStats(weapon)
end

function SWMG_FoldingStock.RestoreFoldedStockState(weapon)
    if not weapon then return end
    if not SWMG_FoldingStock.HasFoldableStock(weapon) then return end

    local isFolded = weapon:getModData().StockFolded
    if isFolded then
        SWMG_FoldingStock.MWAFoldedModel(weapon, true)
        SWMG_FoldingStock.FoldedStockAdjustStats(weapon)
    end
end

function SWMG_FoldingStock.MWAFoldedModel(weapon, folded)
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

return SWMG_FoldingStock
