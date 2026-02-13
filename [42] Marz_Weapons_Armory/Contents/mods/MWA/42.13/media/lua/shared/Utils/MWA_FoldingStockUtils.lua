require "MWA_Core"

function MWA_Utils.FoldedStockAdjustStats(weapon)
    if not weapon then return end

    local weaponType                      = weapon:getFullType()
    local stockStats                      = MWA_Utils.FoldedStockStats[weaponType]
    local isFolded                        = MWA_Utils.IsStockFolded(weapon)
    local foldedMod                       = isFolded and 1 or 0
    local weaponBaseStats                 = instanceItem(weaponType)

    local baseAimingPerkCritModifier      = weaponBaseStats:getAimingPerkCritModifier()
    local baseAimingPerkHitChanceModifier = weaponBaseStats:getAimingPerkHitChanceModifier()
    local baseAimingTime                  = weaponBaseStats:getAimingTime()

    weapon:setAimingPerkCritModifier(baseAimingPerkCritModifier + (stockStats.AimingPerkCritModifier or 0) * foldedMod)
    weapon:setAimingPerkHitChanceModifier(baseAimingPerkHitChanceModifier + (stockStats.AimingPerkHitChanceModifier or 0) * foldedMod)
    weapon:setAimingTime(baseAimingTime + (stockStats.AimingTime or 0) * foldedMod)
end

function MWA_Utils.HasFoldableStock(weapon)
    if not weapon then return false end
    local modData = weapon:getModData()
    return modData and modData.FoldableStock == "true"
end

function MWA_Utils.IsStockFolded(weapon)
    if not weapon then return false end
    local modData = weapon:getModData()
    return modData[MWA_Utils.STOCK_FOLDED_KEY] == true
end

function MWA_Utils.ToggleFoldStock(weapon)
    if not weapon then return end
    if not MWA_Utils.HasFoldableStock(weapon) then return end

    local isFolded = MWA_Utils.IsStockFolded(weapon)
    local newFolded = not isFolded

    weapon:getModData()[MWA_Utils.STOCK_FOLDED_KEY] = newFolded
    MWAFoldedModel(weapon, newFolded)
    MWA_Utils.FoldedStockAdjustStats(weapon)
end

function MWA_Utils.SetStockFolded(weapon, folded)
    if not weapon then return end
    if not MWA_Utils.HasFoldableStock(weapon) then return end

    weapon:getModData()[MWA_Utils.STOCK_FOLDED_KEY] = folded
    MWAFoldedModel(weapon, folded)
    MWA_Utils.FoldedStockAdjustStats(weapon)
end

function MWA_Utils.RestoreFoldedStockState(weapon)
    if not weapon then return end
    if not MWA_Utils.HasFoldableStock(weapon) then return end

    local isFolded = weapon:getModData()[MWA_Utils.STOCK_FOLDED_KEY]
    if isFolded then
        MWAFoldedModel(weapon, true)
        MWA_Utils.FoldedStockAdjustStats(weapon)
    end
end
