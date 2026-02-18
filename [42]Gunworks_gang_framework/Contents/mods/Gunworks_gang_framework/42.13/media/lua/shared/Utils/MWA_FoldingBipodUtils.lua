local SWMG_FoldingBipod = {}

SWMG_FoldingBipod.WeaponsWithFoldableBipod = {
    ["MWA.BAR"] = true,
}
SWMG_FoldingBipod.DeployedBipodStats = {}

function SWMG_FoldingBipod.DeployedBipodAdjustStats(weapon)
    if not weapon then return end

    local weaponType = weapon:getFullType()
    local bipodStats = SWMG_FoldingBipod.DeployedBipodStats[weaponType]
    if not bipodStats then return end

    local isDeployed                      = SWMG_FoldingBipod.IsBipodDeployed(weapon)
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

function SWMG_FoldingBipod.HasFoldableBipod(weapon)
    return SWMG_FoldingBipod.WeaponsWithFoldableBipod[weapon:getFullType()]
end

function SWMG_FoldingBipod.IsBipodDeployed(weapon)
    if not weapon then return false end
    return weapon:getModData().BipodDeployed
end

function SWMG_FoldingBipod.ToggleDeployBipod(weapon)
    if not weapon then return end
    if not SWMG_FoldingBipod.HasFoldableBipod(weapon) then return end

    local isDeployed = SWMG_FoldingBipod.IsBipodDeployed(weapon)
    local newDeployed = not isDeployed

    weapon:getModData().BipodDeployed = newDeployed
    SWMG_FoldingBipod.SwapBipodModel(weapon, newDeployed)
    SWMG_FoldingBipod.DeployedBipodAdjustStats(weapon)
end

function SWMG_FoldingBipod.SetBipodDeployed(weapon, deployed)
    if not weapon then return end
    if not SWMG_FoldingBipod.HasFoldableBipod(weapon) then return end

    weapon:getModData().BipodDeployed = deployed
    SWMG_FoldingBipod.SwapBipodModel(weapon, deployed)
    SWMG_FoldingBipod.DeployedBipodAdjustStats(weapon)
end

function SWMG_FoldingBipod.RestoreDeployedBipodState(weapon)
    if not weapon then return end
    if not SWMG_FoldingBipod.HasFoldableBipod(weapon) then return end

    local isDeployed = SWMG_FoldingBipod.IsBipodDeployed(weapon)
    if isDeployed then
        SWMG_FoldingBipod.SwapBipodModel(weapon, true)
        SWMG_FoldingBipod.DeployedBipodAdjustStats(weapon)
    end
end

function SWMG_FoldingBipod.SwapBipodModel(weapon, deployed)
    if not weapon then return end

    local currentSprite = weapon:getWeaponSprite()
    local baseSprite = currentSprite:gsub("_DEPLOYED$", "")

    local newSprite = baseSprite
    if deployed then
        newSprite = newSprite .. "_DEPLOYED"
    end

    weapon:setWeaponSprite(newSprite)
end

return SWMG_FoldingBipod
