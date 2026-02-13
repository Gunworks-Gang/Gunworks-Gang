require "MWA_Core"

function MWA_Utils.DeployedBipodAdjustStats(weapon)
    if not weapon then return end

    local weaponType = weapon:getFullType()
    local bipodStats = MWA_Utils.DeployedBipodStats[weaponType]
    if not bipodStats then return end

    local isDeployed                      = MWA_Utils.IsBipodDeployed(weapon)
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

function MWA_Utils.HasFoldableBipod(weapon)
    if not weapon then return false end
    local modData = weapon:getModData()
    return modData and modData.FoldableBipod == "true"
end

function MWA_Utils.IsBipodDeployed(weapon)
    if not weapon then return false end
    local modData = weapon:getModData()
    return modData[MWA_Utils.BIPOD_DEPLOYED_KEY] == true
end

function MWA_Utils.ToggleDeployBipod(weapon)
    if not weapon then return end
    if not MWA_Utils.HasFoldableBipod(weapon) then return end

    local isDeployed = MWA_Utils.IsBipodDeployed(weapon)
    local newDeployed = not isDeployed

    weapon:getModData()[MWA_Utils.BIPOD_DEPLOYED_KEY] = newDeployed
    MWABipodModel(weapon, newDeployed)
    MWA_Utils.DeployedBipodAdjustStats(weapon)
end

function MWA_Utils.SetBipodDeployed(weapon, deployed)
    if not weapon then return end
    if not MWA_Utils.HasFoldableBipod(weapon) then return end

    weapon:getModData()[MWA_Utils.BIPOD_DEPLOYED_KEY] = deployed
    MWABipodModel(weapon, deployed)
    MWA_Utils.DeployedBipodAdjustStats(weapon)
end

function MWA_Utils.RestoreDeployedBipodState(weapon)
    if not weapon then return end
    if not MWA_Utils.HasFoldableBipod(weapon) then return end

    local isDeployed = weapon:getModData()[MWA_Utils.BIPOD_DEPLOYED_KEY]
    if isDeployed then
        MWABipodModel(weapon, true)
        MWA_Utils.DeployedBipodAdjustStats(weapon)
    end
end
