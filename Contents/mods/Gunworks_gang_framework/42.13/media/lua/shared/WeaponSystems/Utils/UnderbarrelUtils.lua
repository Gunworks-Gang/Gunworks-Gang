local StatsFactory = require("WeaponSystems/Utils/StatsFactory")

local Underbarrel = {}

Underbarrel.UnderbarrelAttachments = {}

-------------------------------------------------
-- Integrated Underbarrel Registry
-- weaponFullType -> underbarrelWeaponFullType
-------------------------------------------------
Underbarrel.IntegratedUnderbarrels = {}

-------------------------------------------------
-- Registration API
-------------------------------------------------

--- Register an underbarrel attachment and the weapon it swaps to.
---@param attachmentType string   fullType of the attachment part e.g. "MWA.MASTERKEY"
---@param underbarrelType string  fullType of the underbarrel weapon e.g. "MWA.MASTERKEY_Weapon"
function Underbarrel.RegisterUnderbarrelAttachment(attachmentType, underbarrelType)
    if not attachmentType or not underbarrelType then return end
    Underbarrel.UnderbarrelAttachments[attachmentType] = underbarrelType
end

--- Register a weapon with an integrated (built-in) underbarrel.
--- @param weaponType string|string[]  fullType or table of fullTypes e.g. "MWA.M4_M203"
--- @param underbarrelType string      fullType of the underbarrel weapon e.g. "MWA.M203"
function Underbarrel.RegisterIntegratedUnderbarrel(weaponType, underbarrelType)
    if type(weaponType) == "table" then
        for _, wt in ipairs(weaponType) do
            Underbarrel.IntegratedUnderbarrels[wt] = underbarrelType
        end
    else
        Underbarrel.IntegratedUnderbarrels[weaponType] = underbarrelType
    end
end

-------------------------------------------------
-- Swap Utilities  (stat-swap approach, no item swap)
-------------------------------------------------
local function DisplayMessage(character, messageKey)
    character:Say(getText(messageKey), 0.55, 0.55, 0.55, UIFont.Dialogue, 0, "default")
end

function Underbarrel.CanSwapToUnderbarrel(weapon)
    if not weapon then return false end
    if not instanceof(weapon, "HandWeapon") then return false end
    if not weapon:isRanged() then return false end

    local attachment = weapon:getWeaponPart("Underbarrel")
    if not attachment then return false end

    return Underbarrel.UnderbarrelAttachments[attachment:getFullType()] ~= nil
end

function Underbarrel.IsUsingUnderbarrel(weapon)
    if not weapon then return false end
    return weapon:getModData().GW_UB_Active == true
end

--- Swap the equipped weapon to underbarrel mode by applying
--- the underbarrel weapon's stats onto the original weapon in-place.
function Underbarrel.SwapToUnderbarrel(weapon, player)
    if not weapon or not player then return end
    if not Underbarrel.CanSwapToUnderbarrel(weapon) then return end
    if Underbarrel.IsUsingUnderbarrel(weapon) then return end

    local attachment = weapon:getWeaponPart("Underbarrel")
    local underbarrelType = Underbarrel.UnderbarrelAttachments[attachment:getFullType()]
    local md = weapon:getModData()

    -- 1. Snapshot the host weapon's current stats + operational state
    md.GW_UB_OriginalStats = StatsFactory.SnapshotStats(weapon)
    md.GW_UB_OriginalState = StatsFactory.SnapshotState(weapon)

    -- 2. Create a shadow of the underbarrel weapon to read its stats from
    local ubShadow = instanceItem(underbarrelType)
    if not ubShadow then return end

    -- 3. Read the underbarrel weapon stats and apply them onto the host weapon
    local ubStats = StatsFactory.SnapshotStats(ubShadow)
    StatsFactory.ApplySnapshot(weapon, ubStats)

    -- 4. Read the underbarrel weapon state and apply it
    local ubState = StatsFactory.SnapshotState(ubShadow)
    StatsFactory.ApplyState(weapon, ubState)

    -- 5. Restore cached underbarrel operational state if we were in UB mode before
    if md.GW_UB_SavedState then
        StatsFactory.ApplyState(weapon, md.GW_UB_SavedState)
    else
        -- First time: underbarrel starts empty
        weapon:setCurrentAmmoCount(0)
        weapon:setRoundChambered(false)
        weapon:setContainsClip(false)
    end

    -- 6. Mark as active
    md.GW_UB_Active = true
    md.GW_UB_Type = underbarrelType

    player:resetEquippedHandsModels()
    DisplayMessage(player, "Using underbarrel weapon")
end

--- Restore the weapon back to its original host-weapon stats.
function Underbarrel.RestoreOriginalWeapon(weapon, player)
    if not weapon or not player then return end
    if not Underbarrel.IsUsingUnderbarrel(weapon) then return end

    local md = weapon:getModData()

    -- 1. Save the current underbarrel operational state for next swap
    md.GW_UB_SavedState = StatsFactory.SnapshotState(weapon)

    -- 2. Restore original weapon stats
    if md.GW_UB_OriginalStats then
        StatsFactory.ApplySnapshot(weapon, md.GW_UB_OriginalStats)
    end

    -- 3. Restore original weapon operational state
    if md.GW_UB_OriginalState then
        StatsFactory.ApplyState(weapon, md.GW_UB_OriginalState)
    end

    -- 4. Clear active flag (keep saved state for next swap)
    md.GW_UB_Active = nil
    md.GW_UB_OriginalStats = nil
    md.GW_UB_OriginalState = nil

    player:resetEquippedHandsModels()
    DisplayMessage(player, "Using main weapon")
end

--- Clear all cached underbarrel data from a weapon.
--- Call this when the underbarrel attachment is physically removed.
function Underbarrel.ClearUnderbarrelData(weapon)
    if not weapon then return end
    local md = weapon:getModData()
    md.GW_UB_Active = nil
    md.GW_UB_Type = nil
    md.GW_UB_OriginalStats = nil
    md.GW_UB_OriginalState = nil
    md.GW_UB_SavedState = nil
end

-------------------------------------------------
-- Integrated Underbarrel Helpers
-------------------------------------------------

--- Check if a weapon has an integrated underbarrel registered.
--- @param weapon HandWeapon
--- @return boolean
function Underbarrel.HasIntegratedUnderbarrel(weapon)
    if not weapon then return false end
    return Underbarrel.IntegratedUnderbarrels[weapon:getFullType()] ~= nil
end

--- Check if the integrated underbarrel is currently deployed.
--- @param weapon HandWeapon
--- @return boolean
function Underbarrel.IsIntegratedUnderbarrelDeployed(weapon)
    if not weapon then return false end
    return weapon:getModData().GW_IntegratedUnderbarrelDeployed == true
end

--- Toggle the integrated underbarrel between deployed and stowed.
--- @param weapon HandWeapon
function Underbarrel.ToggleIntegratedUnderbarrel(weapon)
    if not weapon then return end
    if not Underbarrel.HasIntegratedUnderbarrel(weapon) then return end
    weapon:getModData().GW_IntegratedUnderbarrelDeployed = not Underbarrel.IsIntegratedUnderbarrelDeployed(weapon)
end

--- Swap to the integrated underbarrel weapon via stat-swap.
--- @param weapon HandWeapon
--- @param player IsoPlayer
function Underbarrel.SwapToIntegratedUnderbarrel(weapon, player)
    if not weapon or not player then return end
    if not Underbarrel.HasIntegratedUnderbarrel(weapon) then return end
    if not Underbarrel.IsIntegratedUnderbarrelDeployed(weapon) then return end
    if Underbarrel.IsUsingUnderbarrel(weapon) then return end

    local underbarrelType = Underbarrel.IntegratedUnderbarrels[weapon:getFullType()]
    local md = weapon:getModData()

    -- 1. Snapshot the host weapon's current stats + operational state
    md.GW_UB_OriginalStats = StatsFactory.SnapshotStats(weapon)
    md.GW_UB_OriginalState = StatsFactory.SnapshotState(weapon)

    -- 2. Create a shadow of the underbarrel weapon to read its stats from
    local ubShadow = instanceItem(underbarrelType)
    if not ubShadow then return end

    -- 3. Apply underbarrel stats onto the host weapon
    local ubStats = StatsFactory.SnapshotStats(ubShadow)
    StatsFactory.ApplySnapshot(weapon, ubStats)

    -- 4. Apply underbarrel state
    local ubState = StatsFactory.SnapshotState(ubShadow)
    StatsFactory.ApplyState(weapon, ubState)

    -- 5. Restore cached integrated underbarrel state if available
    if md.GW_UB_IntegratedSavedState then
        StatsFactory.ApplyState(weapon, md.GW_UB_IntegratedSavedState)
    else
        weapon:setCurrentAmmoCount(0)
        weapon:setRoundChambered(false)
        weapon:setContainsClip(false)
    end

    -- 6. Mark as active
    md.GW_UB_Active = true
    md.GW_UB_Type = underbarrelType

    player:resetEquippedHandsModels()
    DisplayMessage(player, "Using underbarrel weapon")
end

--- Restore from integrated underbarrel mode back to the host weapon.
--- @param weapon HandWeapon
--- @param player IsoPlayer
function Underbarrel.RestoreIntegratedUnderbarrel(weapon, player)
    if not weapon or not player then return end
    if not Underbarrel.IsUsingUnderbarrel(weapon) then return end

    local md = weapon:getModData()

    -- 1. Save the current integrated underbarrel operational state
    md.GW_UB_IntegratedSavedState = StatsFactory.SnapshotState(weapon)

    -- 2. Restore original stats and state
    if md.GW_UB_OriginalStats then
        StatsFactory.ApplySnapshot(weapon, md.GW_UB_OriginalStats)
    end
    if md.GW_UB_OriginalState then
        StatsFactory.ApplyState(weapon, md.GW_UB_OriginalState)
    end

    -- 3. Clear active flag
    md.GW_UB_Active = nil
    md.GW_UB_OriginalStats = nil
    md.GW_UB_OriginalState = nil

    player:resetEquippedHandsModels()
    DisplayMessage(player, "Using main weapon")
end

-------------------------------------------------
-- Key Bindings
-------------------------------------------------

local function onKeyPressed(key)
    local player = getSpecificPlayer(0)
    if not player then return end

    local weapon = player:getPrimaryHandItem()
    if not weapon then return end

    if key == Keyboard.KEY_U then
        if not Underbarrel.IsUsingUnderbarrel(weapon) then
            if Underbarrel.CanSwapToUnderbarrel(weapon) then
                Underbarrel.SwapToUnderbarrel(weapon, player)
            elseif Underbarrel.HasIntegratedUnderbarrel(weapon) and Underbarrel.IsIntegratedUnderbarrelDeployed(weapon) then
                Underbarrel.SwapToIntegratedUnderbarrel(weapon, player)
            end
        end
    elseif key == Keyboard.KEY_Y then
        if Underbarrel.IsUsingUnderbarrel(weapon) then
            -- Determine which restore path: attachment-based or integrated
            if Underbarrel.HasIntegratedUnderbarrel(weapon) then
                Underbarrel.RestoreIntegratedUnderbarrel(weapon, player)
            else
                Underbarrel.RestoreOriginalWeapon(weapon, player)
            end
        end
    end
end

Events.OnKeyPressed.Add(onKeyPressed)

return Underbarrel
