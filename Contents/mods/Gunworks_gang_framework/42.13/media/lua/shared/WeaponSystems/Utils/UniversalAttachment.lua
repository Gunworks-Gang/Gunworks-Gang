local Railing = require("WeaponSystems/Utils/Railing")
local RequiredAttachment = require("WeaponSystems/Utils/RequiredAttachment")
local UpgradeExclusives = require("WeaponSystems/Utils/UpgradeExclusives")

local UniversalAttachment = {}

-------------------------------------------------
-- Registry: weaponFullType -> { genericItemFullType -> { outcomeFullType, ... } }
-------------------------------------------------
UniversalAttachment.Registry = {}

-------------------------------------------------
-- Reverse lookup: outcomeFullType -> { [weaponFullType] = genericItemFullType }
-------------------------------------------------
UniversalAttachment.OutcomeIndex = {}

-------------------------------------------------
-- Registration API
-------------------------------------------------

local function normalizeWeaponType(weaponOrWeaponType)
    if not weaponOrWeaponType then return nil end
    if type(weaponOrWeaponType) == "string" then
        return weaponOrWeaponType
    end
    return weaponOrWeaponType:getFullType()
end

local function normalizeOutcomeType(partOrOutcomeType)
    if not partOrOutcomeType then return nil end
    if type(partOrOutcomeType) == "string" then
        return partOrOutcomeType
    end
    return partOrOutcomeType:getFullType()
end

function UniversalAttachment.RegisterOutcomes(weaponType, genericItemType, outcomes)
    if not weaponType or not genericItemType or not outcomes then return end

    if not UniversalAttachment.Registry[weaponType] then
        UniversalAttachment.Registry[weaponType] = {}
    end

    UniversalAttachment.Registry[weaponType][genericItemType] = outcomes

    for _, outcomeType in ipairs(outcomes) do
        if not UniversalAttachment.OutcomeIndex[outcomeType] then
            UniversalAttachment.OutcomeIndex[outcomeType] = {}
        end
        UniversalAttachment.OutcomeIndex[outcomeType][weaponType] = genericItemType
    end
end

function UniversalAttachment.RegisterWeapon(weaponType, entries)
    if not weaponType or not entries then return end

    for genericItemType, outcomes in pairs(entries) do
        UniversalAttachment.RegisterOutcomes(weaponType, genericItemType, outcomes)
    end
end

function UniversalAttachment.RegisterWeapons(entriesTable)
    if not entriesTable then return end

    for weaponType, entries in pairs(entriesTable) do
        UniversalAttachment.RegisterWeapon(weaponType, entries)
    end
end

-------------------------------------------------
-- Query helpers
-------------------------------------------------

function UniversalAttachment.GetEntries(weaponOrWeaponType)
    local weaponType = normalizeWeaponType(weaponOrWeaponType)
    if not weaponType then return nil end
    return UniversalAttachment.Registry[weaponType]
end

function UniversalAttachment.GetGenericItemTypes(weaponOrWeaponType)
    local entries = UniversalAttachment.GetEntries(weaponOrWeaponType)
    if not entries then return nil end

    local genericItemTypes = {}
    for genericItemType, _ in pairs(entries) do
        table.insert(genericItemTypes, genericItemType)
    end

    if #genericItemTypes == 0 then return nil end
    return genericItemTypes
end

function UniversalAttachment.GetOutcomes(weaponOrWeaponType, genericItemType)
    local entries = UniversalAttachment.GetEntries(weaponOrWeaponType)
    if not entries or not genericItemType then return nil end
    return entries[genericItemType]
end

function UniversalAttachment.GetGenericItemTypeForOutcome(weaponOrWeaponType, outcomeType)
    local weaponType = normalizeWeaponType(weaponOrWeaponType)
    local normalizedOutcomeType = normalizeOutcomeType(outcomeType)
    if not weaponType or not normalizedOutcomeType then return nil end

    local outcomeIndex = UniversalAttachment.OutcomeIndex[normalizedOutcomeType]
    if outcomeIndex then
        return outcomeIndex[weaponType]
    end

    return nil
end

function UniversalAttachment.IsRegisteredOutcome(weaponOrWeaponType, partOrOutcomeType)
    return UniversalAttachment.GetGenericItemTypeForOutcome(weaponOrWeaponType, partOrOutcomeType) ~= nil
end

function UniversalAttachment.CanInstallOutcome(weapon, outcomeType, character)
    if not weapon or not outcomeType then return false end
    if not UniversalAttachment.IsRegisteredOutcome(weapon, outcomeType) then return false end

    local outcomePart = instanceItem(outcomeType)
    if not outcomePart or not instanceof(outcomePart, "WeaponPart") then return false end

    local partType = outcomePart:getPartType()
    if not partType then return false end

    if character and not outcomePart:canAttach(character, weapon) then return false end

    if weapon:getWeaponPart(partType) ~= nil then return false end

    if RequiredAttachment.IsInstallationBlocked(weapon, outcomeType) then return false end

    if UpgradeExclusives.IsBlockedByExclusive(weapon, outcomeType) then return false end

    return true
end

function UniversalAttachment.GetAvailableOutcomes(weapon, genericItemType, character)
    if not weapon or not genericItemType then return nil end

    local outcomes = UniversalAttachment.GetOutcomes(weapon, genericItemType)
    if not outcomes then return nil end

    local availableOutcomes = {}
    for _, outcomeType in ipairs(outcomes) do
        if UniversalAttachment.CanInstallOutcome(weapon, outcomeType, character) then
            table.insert(availableOutcomes, outcomeType)
        end
    end

    if #availableOutcomes == 0 then return nil end
    return availableOutcomes
end

function UniversalAttachment.GetInstalledOutcomes(weapon, genericItemType)
    if not weapon or not genericItemType then return nil end

    local outcomes = UniversalAttachment.GetOutcomes(weapon, genericItemType)
    if not outcomes then return nil end

    local installedOutcomes = {}
    for _, outcomeType in ipairs(outcomes) do
        local outcomePart = instanceItem(outcomeType)
        if outcomePart and instanceof(outcomePart, "WeaponPart") then
            local partType = outcomePart:getPartType()
            if partType then
                local installedPart = weapon:getWeaponPart(partType)
                if installedPart and installedPart:getFullType() == outcomeType then
                    table.insert(installedOutcomes, {
                        fullType = outcomeType,
                        partType = partType,
                        part = installedPart,
                    })
                end
            end
        end
    end

    if #installedOutcomes == 0 then return nil end
    return installedOutcomes
end

function UniversalAttachment.CanRemoveInstalledPart(weapon, part)
    if not weapon or not part then return false end

    local installedPart = part
    if type(part) == "string" then
        installedPart = nil
        local parts = weapon:getAllWeaponParts()
        for i = 0, parts:size() - 1 do
            local currentPart = parts:get(i)
            if currentPart and currentPart:getFullType() == part then
                installedPart = currentPart
                break
            end
        end
    end

    if not installedPart or not UniversalAttachment.IsRegisteredOutcome(weapon, installedPart) then
        return false
    end

    if Railing.HasMountedAccessoryOnRailing(weapon, installedPart) then
        return false
    end

    if RequiredAttachment.IsRemovalBlocked(weapon, installedPart:getFullType()) then
        return false
    end

    return true
end

return UniversalAttachment
