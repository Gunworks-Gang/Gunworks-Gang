Gunworks_AttachAndDetach                       = {}
Gunworks_AttachAndDetach.weaponPartToolMapping = Gunworks_AttachAndDetach.weaponPartToolMapping or {}

local Underbarrel                              = require("WeaponSystems/Utils/Underbarrel")

local function predicateNotBroken(item)
    return not item:isBroken()
end

Gunworks_AttachAndDetach.Check = Gunworks_AttachAndDetach.Check or {}

function Gunworks_AttachAndDetach.Check.Screwdriver(character)
    return character:getInventory():getFirstTagEvalRecurse(ItemTag.SCREWDRIVER, predicateNotBroken)
end

function Gunworks_AttachAndDetach.Check.Wrench(character)
    return character:getInventory():getFirstTagEvalRecurse(ItemTag.WRENCH, predicateNotBroken)
        or character:getInventory():getFirstTagEvalRecurse(ItemTag.PIPE_WRENCH, predicateNotBroken)
end

--- Register the tool check(s) needed to attach/detach parts of a given PartType.
--- @param partType string       weapon-part PartType, e.g. "Scope", "Barrel"
--- @param toolChecks table|nil   array of fn(character)->item|nil; {} or nil = no tool needed
function Gunworks_AttachAndDetach.RegisterPartTool(partType, toolChecks)
    Gunworks_AttachAndDetach.weaponPartToolMapping[partType] = toolChecks or {}
end

--- Bulk form of RegisterPartTool. `mapping` is { [partType] = toolChecks }.
--- Last registration for a PartType wins, so keep the tool for a shared PartType
--- (e.g. "Scope") consistent across packs.
--- @param mapping table<string, table>
function Gunworks_AttachAndDetach.RegisterPartTools(mapping)
    if not mapping then return end
    for partType, toolChecks in pairs(mapping) do
        Gunworks_AttachAndDetach.RegisterPartTool(partType, toolChecks)
    end
end

function Gunworks_AttachAndDetach.getPrimaryTool(character, partType)
    local toolChecks = Gunworks_AttachAndDetach.weaponPartToolMapping[partType]
    if not toolChecks or not toolChecks[1] then
        return nil
    end

    return toolChecks[1](character)
end

function Gunworks_AttachAndDetach.requiredTools(character, weapon, weaponPart)
    if not character or not weapon or not weaponPart then
        return false
    end

    if Underbarrel.IsWeaponInUnderbarrelMode(weapon) then return false end

    local toolChecks = Gunworks_AttachAndDetach.weaponPartToolMapping[weaponPart:getPartType()]
    if not toolChecks then
        return true
    end

    for _, toolCheck in ipairs(toolChecks) do
        if not toolCheck(character) then
            return false
        end
    end

    return true
end

function Gunworks_AttachAndDetach.IsMagazine()
    return false
end

function Gunworks_AttachAndDetach.CannotBeRemoved()
    return false
end
