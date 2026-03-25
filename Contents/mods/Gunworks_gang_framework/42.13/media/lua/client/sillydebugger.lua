local function debugAmmoList(item, label)
    if not item then return end
    local modData = item:getModData()
    local name = item:getDisplayName() or item:getFullType()
    label = label or ""

    print("[MWA DEBUG] " .. label .. " - " .. name)

    if modData.AmmoList and #modData.AmmoList > 0 then
        print("  AmmoList (" .. #modData.AmmoList .. " rounds):")
        for i, ammo in ipairs(modData.AmmoList) do
            local marker = (i == #modData.AmmoList) and " <- CHAMBERED" or ""
            print("    [" .. i .. "] " .. tostring(ammo) .. marker)
        end
    else
        print("  AmmoList: empty/nil")
    end

    -- if modData.SpentAmmoList and #modData.SpentAmmoList > 0 then
    --     print("  SpentAmmoList (" .. #modData.SpentAmmoList .. " rounds):")
    --     for i, ammo in ipairs(modData.SpentAmmoList) do
    --         local marker = (i == #modData.SpentAmmoList) and " <- Spent in CHAMBERED" or ""
    --         print("    [" .. i .. "] " .. tostring(ammo) .. marker)
    --     end
    -- else
    --     print("  SpentAmmoList: empty/nil")
    -- end
end

MWA_DebugAmmoList = debugAmmoList

local function sillydebugger()
    local character = getPlayer()
    if not character then return end

    local weapon = character:getPrimaryHandItem()
    if not weapon or not instanceof(weapon, "HandWeapon") then return end
    if weapon:getSubCategory() ~= "Firearm" then return end

    if character:isAiming() then
        MWA_DebugAmmoList(getPlayer():getPrimaryHandItem(), "Current Weapon")
    end
end

Events.OnPlayerUpdate.Add(sillydebugger)
