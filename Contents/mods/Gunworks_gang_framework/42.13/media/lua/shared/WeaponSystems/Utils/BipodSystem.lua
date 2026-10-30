local BipodSystem = {}

BipodSystem.RegisteredBipods = {}

function BipodSystem.RegisterBipod(attachment)
    BipodSystem.RegisteredBipods[attachment] = true
end

function BipodSystem.RegisterMultipleBipods(entriesTable)
    if not entriesTable then return end

    for i = 1, #entriesTable do
        local attachment = entriesTable[i]
        BipodSystem.RegisterBipod(attachment)
    end
end

function BipodSystem.IsRegisterBipodDeployed(weapon)
    local parts = weapon:getAllWeaponParts()
    if not parts then return nil end
    for i = 0, parts:size() - 1 do
        local candidate = parts:get(i)
        if BipodSystem.RegisteredBipods[candidate:getFullType()] then return true end
    end
    return false
end

return BipodSystem
