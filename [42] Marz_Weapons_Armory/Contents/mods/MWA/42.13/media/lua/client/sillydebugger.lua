local function sillydebugger()
    local character = getPlayer()
    if not character then return end

    local weapon = character:getPrimaryHandItem()
    if not weapon or not instanceof(weapon, "HandWeapon") then return end
    if weapon:getSubCategory() ~= "Firearm" then return end

    if character:isAiming() then
        -- MWA_DebugAmmoList(getPlayer():getPrimaryHandItem(), "Current Weapon")

        print("AimingPerkCritModifier: ", weapon:getAimingPerkCritModifier())
        print("AimingPerkHitChanceModifier: ", weapon:getAimingPerkHitChanceModifier())
        print("AimingTime: ", weapon:getAimingTime())
    end
end

-- Events.OnPlayerUpdate.Add(sillydebugger)
