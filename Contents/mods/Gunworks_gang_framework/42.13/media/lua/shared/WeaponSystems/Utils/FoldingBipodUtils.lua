local FoldingBipod = {}

FoldingBipod.WeaponsWithFoldableBipod = {
    "MWA.BAR",
}
FoldingBipod.DeployedBipodStats = {}

function FoldingBipod.DeployedBipodAdjustStats(weapon)
    if not weapon then return end

    local weaponType = weapon:getFullType()
    local bipodStats = FoldingBipod.DeployedBipodStats[weaponType]
    if not bipodStats then return end

    local isDeployed                      = FoldingBipod.IsBipodDeployed(weapon)
    local deployedMod                     = isDeployed and 1 or 0
    local weaponBaseStats                 = instanceItem(weaponType)

    local baseAimingPerkCritModifier      = weaponBaseStats:getAimingPerkCritModifier()
    local baseAimingPerkHitChanceModifier = weaponBaseStats:getAimingPerkHitChanceModifier()
    local baseAimingTime                  = weaponBaseStats:getAimingTime()
    local baseRecoilDelay                 = weaponBaseStats:getRecoilDelay()

    weapon:setAimingPerkCritModifier(baseAimingPerkCritModifier + (bipodStats.AimingPerkCritModifier or 0) * deployedMod)
    weapon:setAimingPerkHitChanceModifier(baseAimingPerkHitChanceModifier + (bipodStats.AimingPerkHitChanceModifier or 0) * deployedMod)
    weapon:setAimingTime(baseAimingTime + (bipodStats.AimingTime or 0) * deployedMod)
    weapon:setRecoilDelay(baseRecoilDelay + (bipodStats.RecoilDelay or 0) * deployedMod)
end

function FoldingBipod.HasFoldableBipod(weapon)
    if not weapon then return false end
    local weaponType = weapon:getFullType()
    for _, entry in ipairs(FoldingBipod.WeaponsWithFoldableBipod) do
        if entry == weaponType then return true end
    end
    return false
end

function FoldingBipod.IsBipodDeployed(weapon)
    if not weapon then return false end
    return weapon:getModData().BipodDeployed
end

function FoldingBipod.ToggleDeployBipod(weapon)
    if not weapon then return end
    if not FoldingBipod.HasFoldableBipod(weapon) then return end

    local isDeployed = FoldingBipod.IsBipodDeployed(weapon)
    local newDeployed = not isDeployed

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

function FoldingBipod.SwapBipodModel(weapon, deployed)
    if not weapon then return end

    local currentSprite = weapon:getWeaponSprite()
    local baseSprite = currentSprite:gsub("_DEPLOYED$", "")

    local newSprite = baseSprite
    if deployed then
        newSprite = newSprite .. "_DEPLOYED"
    end

    weapon:setWeaponSprite(newSprite)
end

return FoldingBipod
