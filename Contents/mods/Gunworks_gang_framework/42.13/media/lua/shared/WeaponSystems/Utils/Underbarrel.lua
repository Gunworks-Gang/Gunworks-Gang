-------------------------------------------------
-- This system cost me my sanity.
-- UnderbarrelUtils.lua
-- Manages swapping between main weapon mode and underbarrel mode by
-- applying/restoring per-mode stats and ammo state on a single weapon object.
--
-- Persistence: all state is stored in the weapon's modData so it survives
-- game save/load. Init.lua calls Underbarrel.RestoreOnLoad() for every
-- weapon at load time to force it back to main-weapon mode before
-- StatsFactory.ReapplyAllModifiers runs.
--
-- Stat categories:
--   Script stats  — defined by the weapon script (AmmoType, MaxAmmo, etc.)
--                   Saved to GW_MainWeaponSavedStats in modData on enter,
--                   restored on exit or load. All serialisable primitives.
--   Runtime ammo  — live per-mode state (CurrentAmmoCount, RoundChambered…)
--                   Managed by the keys mechanism (GW_Underbarrel*)
--                   for the underbarrel side, and GW_MainWeapon* for the main side.
--   AmmoList      — custom mixed-ammo array, saved/restored per mode separately.
-------------------------------------------------
local StatsFactory                   = require("WeaponSystems/Utils/StatsFactory")

local Underbarrel                    = {}

Underbarrel.UnderbarrelAttachments   = {}
Underbarrel.MODE_SOURCE_ATTACHMENT   = "attachment"

Underbarrel.ACTION_ENTER_ATTACHMENT  = "enterAttachment"
Underbarrel.ACTION_RESTORE           = "restore"

-------------------------------------------------
-- Default stat set swapped between modes.
-- Covers every script-defined property that can differ between the primary
-- weapon and its underbarrel weapon.
--
-- Excluded intentionally:
--   Condition              (runtime wear — don't swap)
--   WeaponSprite           (handled explicitly, physical model stays the same)
--   FireModePossibilities  (Java ArrayList — not safely serialisable)
--   CurrentAmmoCount, RoundChambered, SpentRoundChambered, SpentRoundCount,
--   Jammed, ContainsClip, MagazineType  (runtime ammo — managed by keys)
-------------------------------------------------
local UNDERBARREL_DEFAULT_SWAP_STATS = {
    "AmmoType",
    "MaxAmmo",
    "ClipSize",
    "WeaponReloadType",
    "FireMode",
    "HaveChamber",
    "RackAfterShot",
    "MinDamage",
    "MaxDamage",
    "MaxRange",
    "MinRange",
    "MinRangeRanged",
    "MaxSightRange",
    "MinSightRange",
    "MaxAngle",
    "MinAngle",
    "ReloadTime",
    "AimingTime",
    "JamGunChance",
    "RecoilDelay",
    "ProjectileCount",
    "ProjectileSpread",
    "ProjectileWeightCenter",
    "SoundRadius",
    "SoundVolume",
    "SoundGain",
    "SwingSound",
    "ClickSound",
    "RackSound",
    "BreakSound",
    "ShellFallSound",
    "ImpactSound",
    "DoorHitSound",
    "HitFloorSound",
    "BulletOutSound",
    "MuzzleFlashModelKey",
    "HitChance",
    "ToHitModifier",
    "CriticalChance",
    "CritDmgMultiplier",
    "PiercingBullets",
    "PushBackMod",
    "KnockdownMod",
    "KnockBackOnNoDeath",
    "SplatNumber",
    "SplatBloodOnNoDeath",
    "MultipleHitConditionAffected",
    "RangeFalloff",
    "AngleFalloff",
    "ConditionLowerChanceOneIn",
    "ConditionMax",
    "MaxHitCount",
    "AimingPerkCritModifier",
    "AimingPerkHitChanceModifier",
    "AimingPerkMinAngleModifier",
    "AimingPerkRangeModifier",
    "DoorDamage",
    "TreeDamage",
    "BaseSpeed",
    "SwingTime",
    "EnduranceMod",
}

-- Runtime ammo stats applied from the cached underbarrel weapon when entering mode.
-- Never included in the modData script-stat snapshot (they are handled by the keys).
--
-- ContainsClip and MagazineType are intentionally excluded here: they are set
-- explicitly in EnterUnderbarrelMode (always false/nil for direct-load underbarrels)
-- rather than copied from the cached instance, and restored from MAIN_AMMO_KEYS on
-- exit so the main weapon's magazine state is never lost.
local RUNTIME_AMMO_STAT_NAMES        = {
    "CurrentAmmoCount", "RoundChambered", "SpentRoundChambered",
    "SpentRoundCount", "Jammed",
}

-------------------------------------------------
-- Per-mode runtime ammo keys (stored in the main weapon's modData)
-------------------------------------------------
local function BuildRuntimeKeys(prefix)
    return {
        cacheWeapon     = "GW_Cached" .. prefix,
        ammo            = "GW_" .. prefix .. "Ammo",
        ammoList        = "GW_" .. prefix .. "AmmoList",
        chambered       = "GW_" .. prefix .. "Chambered",
        spentRound      = "GW_" .. prefix .. "SpentRoundChambered",
        spentRoundCount = "GW_" .. prefix .. "SpentRoundCount",
        jammed          = "GW_" .. prefix .. "Jammed",
        containsClip    = "GW_" .. prefix .. "ContainsClip",
        magazineType    = "GW_" .. prefix .. "MagazineType",
    }
end

local ATTACHMENT_KEYS = BuildRuntimeKeys("Underbarrel")
local LEGACY_INTEGRATED_KEYS = BuildRuntimeKeys("IntegratedUnderbarrel")

-- modData keys for the main weapon's runtime ammo state.
-- Written on enter, read+cleared on exit or load.
local MAIN_AMMO_KEYS = {
    ammo            = "GW_MainWeaponAmmo",
    chambered       = "GW_MainWeaponChambered",
    spentRound      = "GW_MainWeaponSpentRound",
    spentRoundCount = "GW_MainWeaponSpentRoundCount",
    jammed          = "GW_MainWeaponJammed",
    containsClip    = "GW_MainWeaponContainsClip",
    magazineType    = "GW_MainWeaponMagazineType",
}

-------------------------------------------------
-- Registration API
-------------------------------------------------

--- Register an underbarrel attachment and the weapon it swaps to.
---@param attachmentType string    fullType of the attachment part e.g. "MWA.M203_Attachment"
---@param underbarrelType string   fullType of the underbarrel weapon e.g. "MWA.M203"
---@param willRequiredManualRemovalOfAmmo boolean|string[]|nil  optional flag for underbarrels that manually remove spent rounds; old third-arg swapStats calls are still accepted
---@param swapStats string[]|nil  stat names to swap between modes; defaults to UNDERBARREL_DEFAULT_SWAP_STATS
function Underbarrel.RegisterUnderbarrelAttachment(attachmentType, underbarrelType, willRequiredManualRemovalOfAmmo, swapStats)
    if not attachmentType or not underbarrelType then return end

    local manualRemoval = false
    local resolvedSwapStats = swapStats

    if type(willRequiredManualRemovalOfAmmo) == "table" and swapStats == nil then
        resolvedSwapStats = willRequiredManualRemovalOfAmmo
    else
        manualRemoval = willRequiredManualRemovalOfAmmo == true
    end

    Underbarrel.UnderbarrelAttachments[attachmentType] = {
        type                            = underbarrelType,
        willRequiredManualRemovalOfAmmo = manualRemoval,
        swapStats                       = resolvedSwapStats or UNDERBARREL_DEFAULT_SWAP_STATS,
    }
end

-------------------------------------------------
-- Internal helpers
-------------------------------------------------

local function DisplayMessage(character, messageKey)
    character:Say(getText(messageKey), 0.55, 0.55, 0.55, UIFont.Dialogue, 0, "default")
end

local function RefreshEquippedWeapon(player, weapon)
    if not player or not weapon then return end
    player:setPrimaryHandItem(weapon)
    if weapon:isTwoHandWeapon() then
        player:setSecondaryHandItem(weapon)
    else
        player:setSecondaryHandItem(nil)
    end
    player:resetEquippedHandsModels()
end

local function IsWeaponValid(weapon)
    if not weapon then return false end
    if not instanceof(weapon, "HandWeapon") then return false end
    return weapon:isRanged()
end

local function CopyArray(source)
    if not source then return nil end
    local copy = {}
    for i = 1, #source do copy[i] = source[i] end
    return copy
end

--- Return the active key-set for a weapon currently in underbarrel mode.
local function GetActiveKeys(weapon)
    return ATTACHMENT_KEYS
end

local function GetAttachmentEntry(weapon)
    if not weapon then return nil end
    local attachment = weapon:getWeaponPart("Underbarrel") or weapon:getWeaponPart("UnderbarrelIntegrated")
    if not attachment then return nil end
    return Underbarrel.UnderbarrelAttachments[attachment:getFullType()]
end

local function ResolveModeConfig(weapon, modeSource, underbarrelType)
    if modeSource and modeSource ~= Underbarrel.MODE_SOURCE_ATTACHMENT then return nil end
    local entry = GetAttachmentEntry(weapon)
    if not entry then return nil end
    if underbarrelType and entry.type ~= underbarrelType then return nil end

    return entry.type, ATTACHMENT_KEYS, entry.swapStats, entry.willRequiredManualRemovalOfAmmo == true
end

local function SendModeRequest(player, weapon, action, underbarrelType, modeSource)
    if not isClient() or not player or not weapon then return end
    sendClientCommand(player, "SWMG", "underbarrelMode", {
        onlineID = player:getOnlineID(),
        itemId = weapon:getID(),
        action = action,
        underbarrelType = underbarrelType,
        modeSource = modeSource,
    })
end

-------------------------------------------------
-- AmmoList helpers
-------------------------------------------------

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

local function SaveCurrentModeAmmoList(weapon, keys)
    local modData = weapon:getModData()
    modData[keys.ammoList] = CopyArray(modData.AmmoList)
end

local function RestoreModeAmmoList(weapon, keys)
    local modData = weapon:getModData()
    modData.AmmoList = CopyArray(modData[keys.ammoList])
end

local function MigrateLegacyIntegratedValue(modData, keyName)
    local currentKey = ATTACHMENT_KEYS[keyName]
    local legacyKey = LEGACY_INTEGRATED_KEYS[keyName]
    if modData[currentKey] == nil and modData[legacyKey] ~= nil then
        modData[currentKey] = modData[legacyKey]
    end
    modData[legacyKey] = nil
end

-- Old integrated-underbarrel registrations used a separate key namespace.
-- Move any persisted ammo state onto the attachment keys before it is used.
local function MigrateLegacyIntegratedState(weapon)
    if not weapon then return end
    if not weapon:getWeaponPart("UnderbarrelIntegrated") then return end

    local modData = weapon:getModData()
    MigrateLegacyIntegratedValue(modData, "cacheWeapon")
    MigrateLegacyIntegratedValue(modData, "ammo")
    MigrateLegacyIntegratedValue(modData, "ammoList")
    MigrateLegacyIntegratedValue(modData, "chambered")
    MigrateLegacyIntegratedValue(modData, "spentRound")
    MigrateLegacyIntegratedValue(modData, "spentRoundCount")
    MigrateLegacyIntegratedValue(modData, "jammed")
    MigrateLegacyIntegratedValue(modData, "containsClip")
    MigrateLegacyIntegratedValue(modData, "magazineType")

    if modData.GW_UnderbarrelModeSource ~= nil then
        modData.GW_UnderbarrelModeSource = Underbarrel.MODE_SOURCE_ATTACHMENT
    end
    modData.GW_IntegratedUnderbarrelDeployed = nil
end

-------------------------------------------------
-- Underbarrel-side runtime ammo (the keys mechanism)
-------------------------------------------------

local function SaveRuntimeFromActiveUnderbarrel(weapon, keys)
    local modData                 = weapon:getModData()
    modData[keys.ammo]            = weapon:getCurrentAmmoCount()
    modData[keys.chambered]       = weapon:isRoundChambered()
    modData[keys.spentRound]      = weapon:isSpentRoundChambered()
    modData[keys.spentRoundCount] = weapon:getSpentRoundCount()
    modData[keys.jammed]          = weapon:isJammed()
    modData[keys.containsClip]    = weapon:isContainsClip()
    modData[keys.magazineType]    = weapon:getMagazineType()
end

local function ApplySavedRuntimeToUnderbarrel(weapon, underbarrelWeapon, keys)
    local modData = weapon:getModData()
    if modData[keys.ammo] ~= nil then underbarrelWeapon:setCurrentAmmoCount(modData[keys.ammo]) end
    if modData[keys.chambered] ~= nil then underbarrelWeapon:setRoundChambered(modData[keys.chambered]) end
    if modData[keys.spentRound] ~= nil then underbarrelWeapon:setSpentRoundChambered(modData[keys.spentRound]) end
    if modData[keys.spentRoundCount] ~= nil then underbarrelWeapon:setSpentRoundCount(modData[keys.spentRoundCount]) end
    if modData[keys.jammed] ~= nil then underbarrelWeapon:setJammed(modData[keys.jammed]) end
    -- MagazineType before ContainsClip (Java guard: usesExternalMagazine() && value)
    if modData[keys.magazineType] ~= nil then underbarrelWeapon:setMagazineType(modData[keys.magazineType]) end
    if modData[keys.containsClip] ~= nil then underbarrelWeapon:setContainsClip(modData[keys.containsClip]) end

    if not underbarrelWeapon:haveChamber() then
        local ammoCount = underbarrelWeapon:getCurrentAmmoCount()
        local ammoList = modData[keys.ammoList]

        if ammoList and #ammoList > ammoCount then
            ammoCount = #ammoList
        end

        if underbarrelWeapon:isRoundChambered() or underbarrelWeapon:isSpentRoundChambered() then
            ammoCount = math.max(ammoCount, 1)
        end

        underbarrelWeapon:setCurrentAmmoCount(ammoCount)
        underbarrelWeapon:setRoundChambered(false)
        underbarrelWeapon:setSpentRoundChambered(false)
    end
end

-------------------------------------------------
-- Main-weapon-side runtime ammo (MAIN_AMMO_KEYS)
-- Written on enter, read+cleared on exit or load.
-------------------------------------------------

local function SaveMainWeaponRuntimeState(weapon)
    local modData                           = weapon:getModData()
    modData[MAIN_AMMO_KEYS.ammo]            = weapon:getCurrentAmmoCount()
    modData[MAIN_AMMO_KEYS.chambered]       = weapon:isRoundChambered()
    modData[MAIN_AMMO_KEYS.spentRound]      = weapon:isSpentRoundChambered()
    modData[MAIN_AMMO_KEYS.spentRoundCount] = weapon:getSpentRoundCount()
    modData[MAIN_AMMO_KEYS.jammed]          = weapon:isJammed()
    modData[MAIN_AMMO_KEYS.containsClip]    = weapon:isContainsClip()
    modData[MAIN_AMMO_KEYS.magazineType]    = weapon:getMagazineType()
end

local function RestoreMainWeaponRuntimeState(weapon)
    local modData = weapon:getModData()
    if modData[MAIN_AMMO_KEYS.ammo] ~= nil then weapon:setCurrentAmmoCount(modData[MAIN_AMMO_KEYS.ammo]) end
    if modData[MAIN_AMMO_KEYS.chambered] ~= nil then weapon:setRoundChambered(modData[MAIN_AMMO_KEYS.chambered]) end
    if modData[MAIN_AMMO_KEYS.spentRound] ~= nil then weapon:setSpentRoundChambered(modData[MAIN_AMMO_KEYS.spentRound]) end
    if modData[MAIN_AMMO_KEYS.spentRoundCount] ~= nil then weapon:setSpentRoundCount(modData[MAIN_AMMO_KEYS.spentRoundCount]) end
    if modData[MAIN_AMMO_KEYS.jammed] ~= nil then weapon:setJammed(modData[MAIN_AMMO_KEYS.jammed]) end
    if modData[MAIN_AMMO_KEYS.magazineType] ~= nil then weapon:setMagazineType(modData[MAIN_AMMO_KEYS.magazineType]) end
    if modData[MAIN_AMMO_KEYS.containsClip] ~= nil then weapon:setContainsClip(modData[MAIN_AMMO_KEYS.containsClip]) end
    modData[MAIN_AMMO_KEYS.ammo]            = nil
    modData[MAIN_AMMO_KEYS.chambered]       = nil
    modData[MAIN_AMMO_KEYS.spentRound]      = nil
    modData[MAIN_AMMO_KEYS.spentRoundCount] = nil
    modData[MAIN_AMMO_KEYS.jammed]          = nil
    modData[MAIN_AMMO_KEYS.containsClip]    = nil
    modData[MAIN_AMMO_KEYS.magazineType]    = nil
end

-------------------------------------------------
-- Script stats — serialisable snapshot in modData
-------------------------------------------------

--- Capture the weapon's current values for each stat in swapStats and store
--- them in modData.GW_MainWeaponSavedStats. All values are primitives/strings
--- and survive the save/load cycle.
local function SaveScriptStatsToModData(weapon, swapStats)
    local modData = weapon:getModData()
    local saved = {}
    for _, statName in ipairs(swapStats) do
        local reg = StatsFactory.Registry[statName]
        if reg then
            saved[statName] = weapon[reg.get](weapon)
        end
    end
    modData.GW_MainWeaponSavedStats = saved
end

--- Apply modData.GW_MainWeaponSavedStats back onto the weapon, then clear it.
--- Falls back to reconstructing from the weapon's script definition + current
--- attachments if no snapshot is found (handles saves predating this system).
local function RestoreScriptStatsFromModData(weapon)
    local modData = weapon:getModData()
    local saved = modData.GW_MainWeaponSavedStats
    if not saved then
        local baseShadow   = StatsFactory.GetBaseStatsWithAttachments(weapon)
        local fallbackSnap = StatsFactory.Snapshot(baseShadow, UNDERBARREL_DEFAULT_SWAP_STATS)
        StatsFactory.Apply(weapon, fallbackSnap)
        return
    end
    for statName, value in pairs(saved) do
        local reg = StatsFactory.Registry[statName]
        if reg then
            weapon[reg.set](weapon, value)
        end
    end
    modData.GW_MainWeaponSavedStats = nil
end

-------------------------------------------------
-- Underbarrel weapon cache
-- The cached object is Java userdata and cannot be serialised.
-- On load it will be nil and is recreated via instanceItem.
-- The ammo state (primitive keys) persists and is re-applied each time.
-------------------------------------------------
local function GetOrCreateCachedUnderbarrelWeapon(weapon, underbarrelType, keys)
    MigrateLegacyIntegratedState(weapon)

    local modData           = weapon:getModData()
    local underbarrelWeapon = modData[keys.cacheWeapon]

    if underbarrelWeapon and underbarrelWeapon:getFullType() ~= underbarrelType then
        underbarrelWeapon             = nil
        modData[keys.cacheWeapon]     = nil
        modData[keys.ammo]            = nil
        modData[keys.ammoList]        = nil
        modData[keys.chambered]       = nil
        modData[keys.spentRound]      = nil
        modData[keys.spentRoundCount] = nil
        modData[keys.jammed]          = nil
        modData[keys.containsClip]    = nil
        modData[keys.magazineType]    = nil
    end

    if not underbarrelWeapon then
        underbarrelWeapon = instanceItem(underbarrelType)
        if not underbarrelWeapon then return nil end
        modData[keys.cacheWeapon] = underbarrelWeapon
    end

    ApplySavedRuntimeToUnderbarrel(weapon, underbarrelWeapon, keys)
    return underbarrelWeapon
end

-------------------------------------------------
-- Core enter / exit logic
-------------------------------------------------

local function EnterUnderbarrelMode(weapon, player, underbarrelType, keys, swapStats, willRequiredManualRemovalOfAmmo, modeSource, silent)
    if not weapon or not player or not underbarrelType then return false end
    if Underbarrel.IsWeaponInUnderbarrelMode(weapon) then return false end

    SaveScriptStatsToModData(weapon, swapStats)
    SaveMainWeaponRuntimeState(weapon)
    SaveMainAmmoListForModeSwitch(weapon)

    local underbarrelWeapon = GetOrCreateCachedUnderbarrelWeapon(weapon, underbarrelType, keys)
    if not underbarrelWeapon then
        weapon:getModData().GW_MainWeaponSavedStats = nil
        RestoreMainWeaponRuntimeState(weapon)
        RestoreMainAmmoListAfterModeSwitch(weapon)
        return false
    end

    underbarrelWeapon:setWeaponSprite(weapon:getWeaponSprite())

    local scriptSnap = StatsFactory.Snapshot(underbarrelWeapon, swapStats)
    StatsFactory.Apply(weapon, scriptSnap)

    local runtimeSnap = StatsFactory.Snapshot(underbarrelWeapon, RUNTIME_AMMO_STAT_NAMES)
    StatsFactory.Apply(weapon, runtimeSnap)

    weapon:setContainsClip(false)
    weapon:setMagazineType(nil)

    RestoreModeAmmoList(weapon, keys)

    local modData                           = weapon:getModData()
    modData.GW_IsUnderbarrelMode            = true
    modData.GW_UnderbarrelModeWeaponType    = underbarrelType
    modData.GW_UnderbarrelModeSource        = modeSource
    modData.WillRequiredManualRemovalOfAmmo = willRequiredManualRemovalOfAmmo == true

    RefreshEquippedWeapon(player, weapon)

    if not silent then
        DisplayMessage(player, "Using underbarrel weapon")
    end

    return true
end

local function ExitUnderbarrelMode(weapon, player, silent)
    if not weapon or not player then return false end
    if not Underbarrel.IsWeaponInUnderbarrelMode(weapon) then return false end

    local keys = GetActiveKeys(weapon)

    SaveRuntimeFromActiveUnderbarrel(weapon, keys)
    SaveCurrentModeAmmoList(weapon, keys)

    RestoreScriptStatsFromModData(weapon)
    RestoreMainWeaponRuntimeState(weapon)
    RestoreMainAmmoListAfterModeSwitch(weapon)

    local modData                           = weapon:getModData()
    modData.GW_IsUnderbarrelMode            = nil
    modData.GW_UnderbarrelModeWeaponType    = nil
    modData.GW_UnderbarrelModeSource        = nil
    modData.WillRequiredManualRemovalOfAmmo = nil

    RefreshEquippedWeapon(player, weapon)

    if not silent then
        DisplayMessage(player, "Using main weapon")
    end

    return true
end

-------------------------------------------------
-- Public API — queries
-------------------------------------------------

function Underbarrel.CanSwapToUnderbarrel(weapon)
    if not IsWeaponValid(weapon) then return false end
    return GetAttachmentEntry(weapon) ~= nil
end

function Underbarrel.CanToggleUnderbarrel(weapon)
    if not IsWeaponValid(weapon) then return false end
    if Underbarrel.IsWeaponInUnderbarrelMode(weapon) then return true end
    return Underbarrel.CanSwapToUnderbarrel(weapon)
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

function Underbarrel.IsUnderbarrelModeWeaponType(weapon, underbarrelType)
    if not weapon or not underbarrelType then return false end
    if not Underbarrel.IsWeaponInUnderbarrelMode(weapon) then return false end
    return weapon:getModData().GW_UnderbarrelModeWeaponType == underbarrelType
end

function Underbarrel.GetModeUnderbarrelType(weapon)
    if not weapon then return end
    return weapon:getModData().GW_UnderbarrelModeWeaponType
end

function Underbarrel.GetModeSource(weapon)
    if not weapon then return end
    if not Underbarrel.IsWeaponInUnderbarrelMode(weapon) then return end
    return Underbarrel.MODE_SOURCE_ATTACHMENT
end

function Underbarrel.GetModeState(weapon)
    if not weapon then
        return {
            isUnderbarrelMode = false,
            underbarrelType = nil,
            modeSource = nil,
        }
    end

    local modData = weapon:getModData()
    local isUnderbarrelMode = modData.GW_IsUnderbarrelMode == true

    return {
        isUnderbarrelMode = isUnderbarrelMode,
        underbarrelType = modData.GW_UnderbarrelModeWeaponType,
        modeSource = isUnderbarrelMode and Underbarrel.MODE_SOURCE_ATTACHMENT or nil,
    }
end

function Underbarrel.GetAttachmentEntry(weapon)
    return GetAttachmentEntry(weapon)
end

function Underbarrel.ReconcileModeState(weapon, player, isUnderbarrelMode, modeSource, underbarrelType, silent)
    if not weapon or not player then return false end

    if not isUnderbarrelMode then
        if not Underbarrel.IsWeaponInUnderbarrelMode(weapon) then return true end
        return ExitUnderbarrelMode(weapon, player, silent)
    end

    local currentState = Underbarrel.GetModeState(weapon)
    if currentState.isUnderbarrelMode
        and currentState.underbarrelType == underbarrelType
        and currentState.modeSource == modeSource then
        return true
    end

    if currentState.isUnderbarrelMode then
        if not ExitUnderbarrelMode(weapon, player, true) then
            return false
        end
    end

    local resolvedType, keys, swapStats, willRequiredManualRemovalOfAmmo = ResolveModeConfig(weapon, modeSource, underbarrelType)
    if not resolvedType then return false end

    return EnterUnderbarrelMode(weapon, player, resolvedType, keys, swapStats, willRequiredManualRemovalOfAmmo, modeSource, silent)
end

-------------------------------------------------
-- Public API — actions
-------------------------------------------------

function Underbarrel.SwapToUnderbarrel(weapon, player)
    if not weapon or not player then return end
    if not Underbarrel.CanSwapToUnderbarrel(weapon) then return end

    local entry = GetAttachmentEntry(weapon)
    if not entry then return end

    if not Underbarrel.ReconcileModeState(weapon, player, true, Underbarrel.MODE_SOURCE_ATTACHMENT, entry.type, false) then
        return
    end

    SendModeRequest(player, weapon, Underbarrel.ACTION_ENTER_ATTACHMENT, entry.type, Underbarrel.MODE_SOURCE_ATTACHMENT)
end

function Underbarrel.RestoreOriginalWeapon(player)
    if not player then return false end

    local weapon = player:getPrimaryHandItem()
    if not weapon then return false end
    if not Underbarrel.IsWeaponInUnderbarrelMode(weapon) then return false end

    local currentState = Underbarrel.GetModeState(weapon)
    if not Underbarrel.ReconcileModeState(weapon, player, false, nil, nil, false) then
        return false
    end

    SendModeRequest(player, weapon, Underbarrel.ACTION_RESTORE, currentState.underbarrelType, currentState.modeSource)

    return true
end

function Underbarrel.ToggleUnderbarrel(weapon, player)
    if not weapon or not player then return false end

    if Underbarrel.IsWeaponInUnderbarrelMode(weapon) then
        return Underbarrel.RestoreOriginalWeapon(player)
    end

    if Underbarrel.CanSwapToUnderbarrel(weapon) then
        Underbarrel.SwapToUnderbarrel(weapon, player)
        return true
    end

    return false
end

--- Called by Init.lua for every ranged weapon at game load time.
--- If the weapon was saved while in underbarrel mode this forces it back to
--- main-weapon mode so StatsFactory.ReapplyAllModifiers starts from a clean base.
-- The underbarrel's ammo state (GW_Underbarrel*) is intentionally preserved so
-- the next toggle restores it correctly.
---@param weapon HandWeapon
function Underbarrel.RestoreOnLoad(weapon)
    if not weapon then return end
    MigrateLegacyIntegratedState(weapon)
    if not Underbarrel.IsWeaponInUnderbarrelMode(weapon) then return end

    local keys = GetActiveKeys(weapon)
    SaveRuntimeFromActiveUnderbarrel(weapon, keys)
    SaveCurrentModeAmmoList(weapon, keys)

    RestoreScriptStatsFromModData(weapon)
    RestoreMainWeaponRuntimeState(weapon)
    RestoreMainAmmoListAfterModeSwitch(weapon)

    local modData                            = weapon:getModData()
    modData.GW_IsUnderbarrelMode             = nil
    modData.GW_UnderbarrelModeWeaponType     = nil
    modData.GW_UnderbarrelModeSource         = nil
    modData.GW_IntegratedUnderbarrelDeployed = nil
    modData.WillRequiredManualRemovalOfAmmo  = nil
end

--- Called by WeaponUpgradeHooks when an underbarrel attachment is removed.
--- Forces restore to main mode if active, returns any loaded ammo to the player,
--- and clears all per-attachment state from modData.
---@param weapon      HandWeapon
---@param removedPart WeaponPart  the part item that was just detached
---@param player      IsoPlayer|nil
function Underbarrel.HandleAttachmentRemoval(weapon, removedPart, player)
    if not weapon or not removedPart then return end

    local entry = Underbarrel.UnderbarrelAttachments[removedPart:getFullType()]
    if not entry then return end

    local modData = weapon:getModData()

    if Underbarrel.IsWeaponInUnderbarrelMode(weapon)
        and modData.GW_UnderbarrelModeWeaponType == entry.type then
        SaveRuntimeFromActiveUnderbarrel(weapon, ATTACHMENT_KEYS)
        SaveCurrentModeAmmoList(weapon, ATTACHMENT_KEYS)

        RestoreScriptStatsFromModData(weapon)
        RestoreMainWeaponRuntimeState(weapon)
        RestoreMainAmmoListAfterModeSwitch(weapon)

        modData.GW_IsUnderbarrelMode            = nil
        modData.GW_UnderbarrelModeWeaponType    = nil
        modData.GW_UnderbarrelModeSource        = nil
        modData.WillRequiredManualRemovalOfAmmo = nil

        if player then
            RefreshEquippedWeapon(player, weapon)
        end
    end

    if player then
        local ammoList = modData[ATTACHMENT_KEYS.ammoList]
        if ammoList and #ammoList > 0 then
            for _, bulletType in ipairs(ammoList) do
                local bullet = instanceItem(bulletType)
                if bullet then
                    player:getInventory():AddItem(bullet)
                    sendAddItemToContainer(player:getInventory(), bullet)
                end
            end
        else
            local ammoCount = modData[ATTACHMENT_KEYS.ammo]
            if ammoCount and ammoCount > 0 then
                local underbarrelRef = instanceItem(entry.type)
                if underbarrelRef then
                    local ammoTypeObj = underbarrelRef:getAmmoType()
                    local ammoKey = ammoTypeObj
                        and (ammoTypeObj.getItemKey and ammoTypeObj:getItemKey() or tostring(ammoTypeObj))
                    if ammoKey then
                        for _ = 1, ammoCount do
                            local bullet = instanceItem(ammoKey)
                            if bullet then
                                player:getInventory():AddItem(bullet)
                                sendAddItemToContainer(player:getInventory(), bullet)
                            end
                        end
                    end
                end
            end
        end
    end

    -- Clear all per-attachment state.
    modData[ATTACHMENT_KEYS.cacheWeapon]            = nil
    modData[ATTACHMENT_KEYS.ammo]                   = nil
    modData[ATTACHMENT_KEYS.ammoList]               = nil
    modData[ATTACHMENT_KEYS.chambered]              = nil
    modData[ATTACHMENT_KEYS.spentRound]             = nil
    modData[ATTACHMENT_KEYS.spentRoundCount]        = nil
    modData[ATTACHMENT_KEYS.jammed]                 = nil
    modData[ATTACHMENT_KEYS.containsClip]           = nil
    modData[ATTACHMENT_KEYS.magazineType]           = nil
    modData[LEGACY_INTEGRATED_KEYS.cacheWeapon]     = nil
    modData[LEGACY_INTEGRATED_KEYS.ammo]            = nil
    modData[LEGACY_INTEGRATED_KEYS.ammoList]        = nil
    modData[LEGACY_INTEGRATED_KEYS.chambered]       = nil
    modData[LEGACY_INTEGRATED_KEYS.spentRound]      = nil
    modData[LEGACY_INTEGRATED_KEYS.spentRoundCount] = nil
    modData[LEGACY_INTEGRATED_KEYS.jammed]          = nil
    modData[LEGACY_INTEGRATED_KEYS.containsClip]    = nil
    modData[LEGACY_INTEGRATED_KEYS.magazineType]    = nil
    modData.GW_MainWeaponSavedStats                 = nil
    modData.GW_UnderbarrelModeSource                = nil
    modData.GW_IntegratedUnderbarrelDeployed        = nil
    modData.WillRequiredManualRemovalOfAmmo         = nil
end

--- Temporary solution to this issue
local _ReapplyAllModifiers_orig         = StatsFactory.ReapplyAllModifiers
local _GetBaseStatsWithAttachments_orig = StatsFactory.GetBaseStatsWithAttachments

StatsFactory.ReapplyAllModifiers        = function(weapon)
    if not Underbarrel.IsWeaponInUnderbarrelMode(weapon) then
        return _ReapplyAllModifiers_orig(weapon)
    end

    local modData           = weapon:getModData()
    local underbarrelWeapon = modData[ATTACHMENT_KEYS.cacheWeapon]
    if not underbarrelWeapon then
        return _ReapplyAllModifiers_orig(weapon)
    end

    StatsFactory.GetBaseStatsWithAttachments = function()
        return underbarrelWeapon
    end
    _ReapplyAllModifiers_orig(weapon)
    StatsFactory.GetBaseStatsWithAttachments = _GetBaseStatsWithAttachments_orig
end


return Underbarrel
