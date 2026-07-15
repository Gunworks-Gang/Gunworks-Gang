local RequiredAttachment = {}

-------------------------------------------------
-- Registry: childFullType -> { parentFullType = true, ... }
-- A child attachment cannot be installed without its parent(s).
-- A parent attachment cannot be removed if any of its children are installed.
-------------------------------------------------
RequiredAttachment.Dependencies = {}

-------------------------------------------------
-- Registry: childFullType -> { parentFullType = true, ... }
-- At least one of these parents must be installed.
-- Used when variants can satisfy the same requirement.
-------------------------------------------------
RequiredAttachment.AnyDependencies = {}

-------------------------------------------------
-- Reverse lookup: parentFullType -> { childFullType = true, ... }
-- Used for quick lookup of all children dependent on a parent
-------------------------------------------------
RequiredAttachment.Dependents = {}

local function hasEntries(tbl)
    if not tbl then return false end
    for _, _ in pairs(tbl) do
        return true
    end
    return false
end

-------------------------------------------------
-- Registration API
-------------------------------------------------

--- Register one or more parent attachments required by a child.
--- @param childType string|string[]  e.g. "Base.Handguard" or { "Base.Handguard", "Base.RIS" }
--- @param parentTypes string|string[]|table
--- string: one required parent
--- string[]: any-of parents (default behavior for arrays)
--- table: { all = { ... }, any = { ... } } for explicit mixed rules
function RequiredAttachment.RegisterRequired(childType, parentTypes)
    if not childType or not parentTypes then return end

    if type(childType) == "table" then
        for _, childTypeEntry in ipairs(childType) do
            if childTypeEntry then
                RequiredAttachment.RegisterRequired(childTypeEntry, parentTypes)
            end
        end
        return
    end

    if not RequiredAttachment.Dependencies[childType] then
        RequiredAttachment.Dependencies[childType] = {}
    end

    if not RequiredAttachment.AnyDependencies[childType] then
        RequiredAttachment.AnyDependencies[childType] = {}
    end

    local allParentsToAdd = {}
    local anyParentsToAdd = {}

    if type(parentTypes) == "string" then
        table.insert(allParentsToAdd, parentTypes)
    elseif type(parentTypes) == "table" then
        local hasExplicitGroups = parentTypes.all ~= nil or parentTypes.any ~= nil

        if hasExplicitGroups then
            if type(parentTypes.all) == "string" then
                table.insert(allParentsToAdd, parentTypes.all)
            elseif type(parentTypes.all) == "table" then
                for _, parentType in ipairs(parentTypes.all) do
                    table.insert(allParentsToAdd, parentType)
                end
            end

            if type(parentTypes.any) == "string" then
                table.insert(anyParentsToAdd, parentTypes.any)
            elseif type(parentTypes.any) == "table" then
                for _, parentType in ipairs(parentTypes.any) do
                    table.insert(anyParentsToAdd, parentType)
                end
            end
        else
            -- Backward-compatible default for array input:
            -- treat list entries as alternatives (any-of).
            for _, parentType in ipairs(parentTypes) do
                table.insert(anyParentsToAdd, parentType)
            end
        end
    end

    for _, parentType in ipairs(allParentsToAdd) do
        if parentType then
            RequiredAttachment.Dependencies[childType][parentType] = true

            -- Add to reverse lookup
            if not RequiredAttachment.Dependents[parentType] then
                RequiredAttachment.Dependents[parentType] = {}
            end
            RequiredAttachment.Dependents[parentType][childType] = true
        end
    end

    for _, parentType in ipairs(anyParentsToAdd) do
        if parentType then
            RequiredAttachment.AnyDependencies[childType][parentType] = true

            -- Add to reverse lookup
            if not RequiredAttachment.Dependents[parentType] then
                RequiredAttachment.Dependents[parentType] = {}
            end
            RequiredAttachment.Dependents[parentType][childType] = true
        end
    end

    if not hasEntries(RequiredAttachment.Dependencies[childType]) then
        RequiredAttachment.Dependencies[childType] = nil
    end
    if not hasEntries(RequiredAttachment.AnyDependencies[childType]) then
        RequiredAttachment.AnyDependencies[childType] = nil
    end
end

--- Convenience function to register multiple children with the same parent(s)
--- @param entriesTable table  e.g. { ["Base.Handguard"] = "Base.Barrel", ["Base.RIS"] = { "Base.Barrel", "Base.Receiver" } }
function RequiredAttachment.RegisterMultipleDependencies(entriesTable)
    if not entriesTable then return end

    for childType, parentTypes in pairs(entriesTable) do
        RequiredAttachment.RegisterRequired(childType, parentTypes)
    end
end

-------------------------------------------------
-- Query API: Check if attachment has required parents installed
-------------------------------------------------

--- Get all required parent fullTypes for a child attachment
--- @param childType string
--- @return table|nil  table of parent fullTypes, or nil if child has no dependencies
function RequiredAttachment.GetRequiredParents(childType)
    if not childType then return nil end
    local allParents = RequiredAttachment.Dependencies[childType]
    local anyParents = RequiredAttachment.AnyDependencies[childType]
    if not allParents and not anyParents then return nil end

    local parentsList = {}
    if allParents then
        for parentType, _ in pairs(allParents) do
            table.insert(parentsList, parentType)
        end
    end

    if anyParents then
        for parentType, _ in pairs(anyParents) do
            table.insert(parentsList, parentType)
        end
    end

    if #parentsList == 0 then
        return nil
    end

    local uniqueParents = {}
    local seen = {}
    for _, parentType in ipairs(parentsList) do
        if not seen[parentType] then
            table.insert(uniqueParents, parentType)
            seen[parentType] = true
        end
    end

    return uniqueParents
end

--- Check if a child attachment requires a specific parent
--- @param childType string
--- @param parentType string
--- @return boolean
function RequiredAttachment.RequiresParent(childType, parentType)
    if not childType or not parentType then return false end
    local inAll = RequiredAttachment.Dependencies[childType] and
        RequiredAttachment.Dependencies[childType][parentType] == true
    local inAny = RequiredAttachment.AnyDependencies[childType] and
        RequiredAttachment.AnyDependencies[childType][parentType] == true
    return inAll or inAny
end

--- Check if a child attachment has all its required parents installed on a weapon
--- @param weapon HandWeapon
--- @param childType string
--- @return boolean  true if all required parents are installed
function RequiredAttachment.HasAllRequiredParents(weapon, childType)
    if not weapon or not childType then return false end

    local requiredAll = RequiredAttachment.Dependencies[childType]
    local requiredAny = RequiredAttachment.AnyDependencies[childType]

    if not requiredAll and not requiredAny then return true end -- No requirements = can install

    if requiredAll then
        for parentType, _ in pairs(requiredAll) do
            if not RequiredAttachment.IsPartInstalledOnWeapon(weapon, parentType) then
                return false
            end
        end
    end

    if requiredAny then
        local hasAnyParent = false
        for parentType, _ in pairs(requiredAny) do
            if RequiredAttachment.IsPartInstalledOnWeapon(weapon, parentType) then
                hasAnyParent = true
                break
            end
        end

        if not hasAnyParent then
            return false
        end
    end

    return true
end

-------------------------------------------------
-- Query API: Check for installed children
-------------------------------------------------

--- Get all installed children of a parent part on a weapon
--- @param weapon HandWeapon
--- @param parentType string
--- @return table|nil  table of { fullType, partType, part }, or nil if no children installed
function RequiredAttachment.GetInstalledChildren(weapon, parentType)
    if not weapon or not parentType then return nil end

    local children = RequiredAttachment.Dependents[parentType]
    if not children then return nil end

    local installedChildren = {}
    local parts = weapon:getAllWeaponParts()
    if not parts then return nil end

    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part then
            local partFullType = part:getFullType()
            if children[partFullType] then
                table.insert(installedChildren, {
                    fullType = partFullType,
                    partType = part:getPartType(),
                    part = part,
                })
            end
        end
    end

    return #installedChildren > 0 and installedChildren or nil
end

--- Check if a parent has any installed children on the weapon
--- @param weapon HandWeapon
--- @param parentType string
--- @return boolean
function RequiredAttachment.HasInstalledChildren(weapon, parentType)
    return RequiredAttachment.GetInstalledChildren(weapon, parentType) ~= nil
end

--- Get all fullTypes of installed children for a parent
--- @param weapon HandWeapon
--- @param parentType string
--- @return table|nil  table of child fullTypes, or nil if none installed
function RequiredAttachment.GetInstalledChildrenTypes(weapon, parentType)
    local children = RequiredAttachment.GetInstalledChildren(weapon, parentType)
    if not children then return nil end

    local childTypes = {}
    for _, childData in ipairs(children) do
        table.insert(childTypes, childData.fullType)
    end
    return childTypes
end

-------------------------------------------------
-- Helper functions
-------------------------------------------------

--- Check if a specific part fullType is installed on the weapon
--- @param weapon HandWeapon
--- @param partFullType string
--- @return boolean
function RequiredAttachment.IsPartInstalledOnWeapon(weapon, partFullType)
    if not weapon or not partFullType then return false end

    local parts = weapon:getAllWeaponParts()
    if not parts then return false end

    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part and part:getFullType() == partFullType then
            return true
        end
    end

    return false
end

--- Check if a child can be installed (has all required parents)
--- @param weapon HandWeapon
--- @param childType string
--- @return boolean
function RequiredAttachment.CanInstallChild(weapon, childType)
    if not weapon or not childType then return true end
    return RequiredAttachment.HasAllRequiredParents(weapon, childType)
end

--- Check if a parent can be removed (no children installed)
--- @param weapon HandWeapon
--- @param parentType string
--- @return boolean
function RequiredAttachment.CanRemoveParent(weapon, parentType)
    if not weapon or not parentType then return true end
    return not RequiredAttachment.HasInstalledChildren(weapon, parentType)
end

-------------------------------------------------
-- Validation functions for integration hooks
-------------------------------------------------

--- Check if attachment installation should be blocked due to missing required parent
--- @param weapon HandWeapon
--- @param attachmentType string
--- @return boolean  true if blocked, false if allowed
function RequiredAttachment.IsInstallationBlocked(weapon, attachmentType)
    if not weapon or not attachmentType then return false end
    return not RequiredAttachment.CanInstallChild(weapon, attachmentType)
end

--- Check if attachment removal should be blocked due to dependent children
--- @param weapon HandWeapon
--- @param attachmentType string
--- @return boolean  true if blocked, false if allowed
function RequiredAttachment.IsRemovalBlocked(weapon, attachmentType)
    if not weapon or not attachmentType then return false end
    return not RequiredAttachment.CanRemoveParent(weapon, attachmentType)
end

return RequiredAttachment
