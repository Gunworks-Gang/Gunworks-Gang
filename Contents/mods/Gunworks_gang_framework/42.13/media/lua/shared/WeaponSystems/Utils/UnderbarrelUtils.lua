local StatsFactory = require("WeaponSystems/Utils/StatsFactory")

local Underbarrel = {}

Underbarrel.UnderbarrelAttachments = {}
Underbarrel.ActiveWeaponSnapshots = {}

-------------------------------------------------
-- Integrated Underbarrel Registry
-- weaponFullType -> underbarrelWeaponFullType
-------------------------------------------------
Underbarrel.IntegratedUnderbarrels = {}

-------------------------------------------------
-- Registration API
-------------------------------------------------

--- Register an underbarrel attachment and the weapon it swaps to.
---@param attachmentType string   fullType of the attachment part e.g. "MWA.M203_Attachment"
---@param underbarrelType string  fullType of the underbarrel weapon e.g. "MWA.M203"
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
-- Swap Utilities
-------------------------------------------------
local function DisplayMessage(character, messageKey)
    character:Say(getText(messageKey), 0.55, 0.55, 0.55, UIFont.Dialogue, 0, "default")
end

local function IsWeaponValid(weapon)
    if not weapon then return false end
    if not instanceof(weapon, "HandWeapon") then return false end
    return weapon:isRanged()
end

local function BuildRuntimeKeys(prefix)
    return {
        cacheWeapon = "GW_Cached" .. prefix,
        ammo = "GW_" .. prefix .. "Ammo",
        ammoList = "GW_" .. prefix .. "AmmoList",
        chambered = "GW_" .. prefix .. "Chambered",
        spentRound = "GW_" .. prefix .. "SpentRoundChambered",
        spentRoundCount = "GW_" .. prefix .. "SpentRoundCount",
        jammed = "GW_" .. prefix .. "Jammed",
        containsClip = "GW_" .. prefix .. "ContainsClip",
        magazineType = "GW_" .. prefix .. "MagazineType",
    }
end

local ATTACHMENT_KEYS = BuildRuntimeKeys("Underbarrel")
local INTEGRATED_KEYS = BuildRuntimeKeys("IntegratedUnderbarrel")

local function CopyArray(source)
    if not source then return nil end
    local copy = {}
    for i = 1, #source do
        copy[i] = source[i]
    end
    return copy
end

local function SaveMainAmmoListForModeSwitch(weapon)
    local modData = weapon:getModData()
    modData.GW_MainWeaponAmmoListBeforeUnderbarrel = CopyArray(modData.AmmoList)
    modData.AmmoList = nil
end

local function RestoreMainAmmoListAfterModeSwitch(weapon)
    local modData = weapon:getModData()
    modData.AmmoList = CopyArray(modData.GW_MainWeaponAmmoListBeforeUnderbarrel)
    modData.GW_MainWeaponAmmoListBeforeUnderbarrel = nil
end

local function RestoreModeAmmoList(weapon, keys)
    local modData = weapon:getModData()
    modData.AmmoList = CopyArray(modData[keys.ammoList])
end

local function SaveCurrentModeAmmoList(weapon, keys)
    local modData = weapon:getModData()
    modData[keys.ammoList] = CopyArray(modData.AmmoList)
end

local function ApplySavedRuntimeToUnderbarrel(weapon, underbarrelWeapon, keys)
    local modData = weapon:getModData()

    if modData[keys.ammo] ~= nil then
        underbarrelWeapon:setCurrentAmmoCount(modData[keys.ammo])
    end
    if modData[keys.chambered] ~= nil then
        underbarrelWeapon:setRoundChambered(modData[keys.chambered])
    end
    if modData[keys.spentRound] ~= nil then
        underbarrelWeapon:setSpentRoundChambered(modData[keys.spentRound])
    end
    if modData[keys.spentRoundCount] ~= nil then
        underbarrelWeapon:setSpentRoundCount(modData[keys.spentRoundCount])
    end
    if modData[keys.jammed] ~= nil then
        underbarrelWeapon:setJammed(modData[keys.jammed])
    end
    if modData[keys.containsClip] ~= nil then
        underbarrelWeapon:setContainsClip(modData[keys.containsClip])
    end
    if modData[keys.magazineType] ~= nil then
        underbarrelWeapon:setMagazineType(modData[keys.magazineType])
    end
end

local function SaveRuntimeFromActiveUnderbarrel(weapon, keys)
    local modData = weapon:getModData()
    modData[keys.ammo] = weapon:getCurrentAmmoCount()
    modData[keys.chambered] = weapon:isRoundChambered()
    modData[keys.spentRound] = weapon:isSpentRoundChambered()
    modData[keys.spentRoundCount] = weapon:getSpentRoundCount()
    modData[keys.jammed] = weapon:isJammed()
    modData[keys.containsClip] = weapon:isContainsClip()
    modData[keys.magazineType] = weapon:getMagazineType()
end

local function GetOrCreateCachedUnderbarrelWeapon(weapon, underbarrelType, keys)
    local modData = weapon:getModData()
    local underbarrelWeapon = modData[keys.cacheWeapon]

    if underbarrelWeapon and underbarrelWeapon:getFullType() ~= underbarrelType then
        underbarrelWeapon = nil
        modData[keys.cacheWeapon] = nil
        modData[keys.ammo] = nil
        modData[keys.ammoList] = nil
        modData[keys.chambered] = nil
        modData[keys.spentRound] = nil
        modData[keys.spentRoundCount] = nil
        modData[keys.jammed] = nil
        modData[keys.containsClip] = nil
        modData[keys.magazineType] = nil
    end

    if not underbarrelWeapon then
        underbarrelWeapon = instanceItem(underbarrelType)
        if not underbarrelWeapon then return nil end
        modData[keys.cacheWeapon] = underbarrelWeapon
    end

    ApplySavedRuntimeToUnderbarrel(weapon, underbarrelWeapon, keys)
    return underbarrelWeapon
end

local function SnapshotCurrentWeaponAsFallback(weapon)
    local baseShadow = StatsFactory.GetBaseStatsWithAttachments(weapon)
    return StatsFactory.Snapshot(baseShadow)
end

local function EnterUnderbarrelMode(weapon, player, underbarrelType, keys)
    if not weapon or not player or not underbarrelType then return end
    if Underbarrel.IsWeaponInUnderbarrelMode(weapon) then return end

    local originalSnapshot = StatsFactory.Snapshot(weapon)
    local underbarrelWeapon = GetOrCreateCachedUnderbarrelWeapon(weapon, underbarrelType, keys)
    if not underbarrelWeapon then return end

    underbarrelWeapon:setWeaponSprite(weapon:getWeaponSprite())

    local underbarrelSnapshot = StatsFactory.Snapshot(underbarrelWeapon)
    StatsFactory.Apply(weapon, underbarrelSnapshot)

    Underbarrel.ActiveWeaponSnapshots[weapon] = originalSnapshot

    local modData = weapon:getModData()
    SaveMainAmmoListForModeSwitch(weapon)
    RestoreModeAmmoList(weapon, keys)

    modData.GW_IsUnderbarrelMode = true
    modData.GW_UnderbarrelModeWeaponType = underbarrelType

    player:setPrimaryHandItem(weapon)
    if weapon:isTwoHandWeapon() then
        player:setSecondaryHandItem(weapon)
    else
        player:setSecondaryHandItem(nil)
    end
    player:resetEquippedHandsModels()

    DisplayMessage(player, "Using underbarrel weapon")
end

function Underbarrel.CanSwapToUnderbarrel(weapon)
    if not IsWeaponValid(weapon) then return false end

    local attachment = weapon:getWeaponPart("Underbarrel")
    if not attachment then return false end

    return Underbarrel.UnderbarrelAttachments[attachment:getFullType()] ~= nil
end

function Underbarrel.IsUsingUnderbarrel(player)
    if not player then return false end
    local primaryHand = player:getPrimaryHandItem()
    if not primaryHand then return false end
    return Underbarrel.IsWeaponInUnderbarrelMode(primaryHand)
end

function Underbarrel.IsWeaponInUnderbarrelMode(weapon)
    if not weapon then return false end
    return weapon:getModData().GW_IsUnderbarrelMode == true
end

function Underbarrel.SwapToUnderbarrel(weapon, player)
    if not weapon or not player then return end
    if not Underbarrel.CanSwapToUnderbarrel(weapon) then return end


    local attachment = weapon:getWeaponPart("Underbarrel")
    local underbarrelType = Underbarrel.UnderbarrelAttachments[attachment:getFullType()]
    EnterUnderbarrelMode(weapon, player, underbarrelType, ATTACHMENT_KEYS)
end

function Underbarrel.RestoreOriginalWeapon(player)
    if not player then return end

    local weapon = player:getPrimaryHandItem()
    if not weapon then return end
    if not Underbarrel.IsWeaponInUnderbarrelMode(weapon) then return end

    local modData = weapon:getModData()
    local keys = ATTACHMENT_KEYS
    if Underbarrel.HasIntegratedUnderbarrel(weapon)
        and modData.GW_UnderbarrelModeWeaponType
        and modData.GW_UnderbarrelModeWeaponType == Underbarrel.IntegratedUnderbarrels[weapon:getFullType()] then
        keys = INTEGRATED_KEYS
    end

    SaveRuntimeFromActiveUnderbarrel(weapon, keys)
    SaveCurrentModeAmmoList(weapon, keys)

    local originalSnapshot = Underbarrel.ActiveWeaponSnapshots[weapon]
    if not originalSnapshot then
        originalSnapshot = SnapshotCurrentWeaponAsFallback(weapon)
    end

    StatsFactory.Apply(weapon, originalSnapshot)
    RestoreMainAmmoListAfterModeSwitch(weapon)

    Underbarrel.ActiveWeaponSnapshots[weapon] = nil

    modData.GW_IsUnderbarrelMode = nil
    modData.GW_UnderbarrelModeWeaponType = nil

    player:setPrimaryHandItem(weapon)
    if weapon:isTwoHandWeapon() then
        player:setSecondaryHandItem(weapon)
    else
        player:setSecondaryHandItem(nil)
    end
    player:resetEquippedHandsModels()

    DisplayMessage(player, "Using main weapon")
end

function Underbarrel.IsUnderbarrelModeWeaponType(weapon, underbarrelType)
    if not weapon or not underbarrelType then return false end
    if not Underbarrel.IsWeaponInUnderbarrelMode(weapon) then return false end
    return weapon:getModData().GW_UnderbarrelModeWeaponType == underbarrelType
end

function Underbarrel.GetModeUnderbarrelType(weapon)
    if not weapon then return end
    return weapon:getModData().GW_UnderbarrelModeWeaponType
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

--- Swap to the integrated underbarrel weapon.
--- @param weapon HandWeapon
--- @param player IsoPlayer
function Underbarrel.SwapToIntegratedUnderbarrel(weapon, player)
    if not weapon or not player then return end
    if not Underbarrel.HasIntegratedUnderbarrel(weapon) then return end
    if not Underbarrel.IsIntegratedUnderbarrelDeployed(weapon) then return end


    local underbarrelType = Underbarrel.IntegratedUnderbarrels[weapon:getFullType()]
    EnterUnderbarrelMode(weapon, player, underbarrelType, INTEGRATED_KEYS)
end

-------------------------------------------------
-- Key Bindings
-------------------------------------------------

local function onKeyPressed(key)
    local player = getSpecificPlayer(0)
    if not player then return end




    if key == Keyboard.KEY_U then
        if not Underbarrel.IsUsingUnderbarrel(player) then
            local primaryHand = player:getPrimaryHandItem()
            if primaryHand then
                if Underbarrel.CanSwapToUnderbarrel(primaryHand) then
                    Underbarrel.SwapToUnderbarrel(primaryHand, player)
                elseif Underbarrel.HasIntegratedUnderbarrel(primaryHand) and Underbarrel.IsIntegratedUnderbarrelDeployed(primaryHand) then
                    Underbarrel.SwapToIntegratedUnderbarrel(primaryHand, player)
                end
            end
        end
    elseif key == Keyboard.KEY_Y then
        if Underbarrel.IsUsingUnderbarrel(player) then
            Underbarrel.RestoreOriginalWeapon(player)
        end
    end
end

Events.OnKeyPressed.Add(onKeyPressed)

return Underbarrel
