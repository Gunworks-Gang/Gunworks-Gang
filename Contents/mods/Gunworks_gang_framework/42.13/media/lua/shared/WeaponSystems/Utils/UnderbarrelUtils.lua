-------------------------------------------------
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
--                   Managed by the keys mechanism (GW_Underbarrel*/GW_IntegratedUnderbarrel*)
--                   for the underbarrel side, and GW_MainWeapon* for the main side.
--   AmmoList      — custom mixed-ammo array, saved/restored per mode separately.
-------------------------------------------------
local StatsFactory = require("WeaponSystems/Utils/StatsFactory")

local Underbarrel = {}

Underbarrel.UnderbarrelAttachments  = {}
Underbarrel.IntegratedUnderbarrels  = {}

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
    "MaxAmmo", "ClipSize",
    "WeaponReloadType", "FireMode",
    "RackAfterShot",
    "MinDamage", "MaxDamage",
    "MaxRange", "MinRange", "MinRangeRanged",
    "MaxSightRange", "MinSightRange",
    "MaxAngle", "MinAngle",
    "ReloadTime", "AimingTime",
    "JamGunChance", "RecoilDelay",
    "ProjectileCount", "ProjectileSpread", "ProjectileWeightCenter",
    "SoundRadius", "SoundVolume", "SoundGain",
    "SwingSound", "ClickSound", "RackSound", "BreakSound",
    "ShellFallSound", "ImpactSound", "DoorHitSound", "HitFloorSound", "BulletOutSound",
    "MuzzleFlashModelKey",
    "HitChance", "ToHitModifier",
    "CriticalChance", "CritDmgMultiplier",
    "PiercingBullets",
    "PushBackMod", "KnockdownMod", "KnockBackOnNoDeath",
    "SplatNumber", "SplatBloodOnNoDeath", "MultipleHitConditionAffected",
    "RangeFalloff", "AngleFalloff",
    "ConditionLowerChanceOneIn", "ConditionMax",
    "MaxHitCount",
    "AimingPerkCritModifier", "AimingPerkHitChanceModifier",
    "AimingPerkMinAngleModifier", "AimingPerkRangeModifier",
    "DoorDamage", "TreeDamage",
    "BaseSpeed", "SwingTime", "EnduranceMod",
}

-- Runtime ammo stats applied from the cached underbarrel weapon when entering mode.
-- Never included in the modData script-stat snapshot (they are handled by the keys).
--
-- ContainsClip and MagazineType are intentionally excluded here: they are set
-- explicitly in EnterUnderbarrelMode (always false/nil for direct-load underbarrels)
-- rather than copied from the cached instance, and restored from MAIN_AMMO_KEYS on
-- exit so the main weapon's magazine state is never lost.
local RUNTIME_AMMO_STAT_NAMES = {
    "CurrentAmmoCount", "RoundChambered", "SpentRoundChambered",
    "SpentRoundCount", "Jammed",
}

-------------------------------------------------
-- Per-mode runtime ammo keys (stored in the main weapon's modData)
-------------------------------------------------
local function BuildRuntimeKeys(prefix)
    return {
        cacheWeapon     = "GW_Cached"          .. prefix,
        ammo            = "GW_"                .. prefix .. "Ammo",
        ammoList        = "GW_"                .. prefix .. "AmmoList",
        chambered       = "GW_"                .. prefix .. "Chambered",
        spentRound      = "GW_"                .. prefix .. "SpentRoundChambered",
        spentRoundCount = "GW_"                .. prefix .. "SpentRoundCount",
        jammed          = "GW_"                .. prefix .. "Jammed",
        containsClip    = "GW_"                .. prefix .. "ContainsClip",
        magazineType    = "GW_"                .. prefix .. "MagazineType",
    }
end

local ATTACHMENT_KEYS = BuildRuntimeKeys("Underbarrel")
local INTEGRATED_KEYS = BuildRuntimeKeys("IntegratedUnderbarrel")

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
---@param swapStats string[]|nil  stat names to swap between modes; defaults to UNDERBARREL_DEFAULT_SWAP_STATS
function Underbarrel.RegisterUnderbarrelAttachment(attachmentType, underbarrelType, swapStats)
    if not attachmentType or not underbarrelType then return end
    Underbarrel.UnderbarrelAttachments[attachmentType] = {
        type      = underbarrelType,
        swapStats = swapStats or UNDERBARREL_DEFAULT_SWAP_STATS,
    }
end

--- Register a weapon with an integrated (built-in) underbarrel.
---@param weaponType string|string[]  fullType or list of fullTypes e.g. "MWA.M4_M203"
---@param underbarrelType string      fullType of the underbarrel weapon e.g. "MWA.M203"
---@param swapStats string[]|nil      stat names to swap; defaults to UNDERBARREL_DEFAULT_SWAP_STATS
function Underbarrel.RegisterIntegratedUnderbarrel(weaponType, underbarrelType, swapStats)
    local entry = {
        type      = underbarrelType,
        swapStats = swapStats or UNDERBARREL_DEFAULT_SWAP_STATS,
    }
    if type(weaponType) == "table" then
        for _, wt in ipairs(weaponType) do
            Underbarrel.IntegratedUnderbarrels[wt] = entry
        end
    else
        Underbarrel.IntegratedUnderbarrels[weaponType] = entry
    end
end

-------------------------------------------------
-- Internal helpers
-------------------------------------------------

local function DisplayMessage(character, messageKey)
    character:Say(getText(messageKey), 0.55, 0.55, 0.55, UIFont.Dialogue, 0, "default")
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
    local modData = weapon:getModData()
    local entry   = Underbarrel.IntegratedUnderbarrels[weapon:getFullType()]
    if entry and modData.GW_UnderbarrelModeWeaponType == entry.type then
        return INTEGRATED_KEYS
    end
    return ATTACHMENT_KEYS
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

-------------------------------------------------
-- Underbarrel-side runtime ammo (the keys mechanism)
-------------------------------------------------

local function SaveRuntimeFromActiveUnderbarrel(weapon, keys)
    local modData = weapon:getModData()
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
    if modData[keys.ammo]            ~= nil then underbarrelWeapon:setCurrentAmmoCount(modData[keys.ammo]) end
    if modData[keys.chambered]       ~= nil then underbarrelWeapon:setRoundChambered(modData[keys.chambered]) end
    if modData[keys.spentRound]      ~= nil then underbarrelWeapon:setSpentRoundChambered(modData[keys.spentRound]) end
    if modData[keys.spentRoundCount] ~= nil then underbarrelWeapon:setSpentRoundCount(modData[keys.spentRoundCount]) end
    if modData[keys.jammed]          ~= nil then underbarrelWeapon:setJammed(modData[keys.jammed]) end
    if modData[keys.containsClip]    ~= nil then underbarrelWeapon:setContainsClip(modData[keys.containsClip]) end
    if modData[keys.magazineType]    ~= nil then underbarrelWeapon:setMagazineType(modData[keys.magazineType]) end
end

-------------------------------------------------
-- Main-weapon-side runtime ammo (MAIN_AMMO_KEYS)
-- Written on enter, read+cleared on exit or load.
-------------------------------------------------

local function SaveMainWeaponRuntimeState(weapon)
    local modData = weapon:getModData()
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
    if modData[MAIN_AMMO_KEYS.ammo]            ~= nil then weapon:setCurrentAmmoCount(modData[MAIN_AMMO_KEYS.ammo]) end
    if modData[MAIN_AMMO_KEYS.chambered]       ~= nil then weapon:setRoundChambered(modData[MAIN_AMMO_KEYS.chambered]) end
    if modData[MAIN_AMMO_KEYS.spentRound]      ~= nil then weapon:setSpentRoundChambered(modData[MAIN_AMMO_KEYS.spentRound]) end
    if modData[MAIN_AMMO_KEYS.spentRoundCount] ~= nil then weapon:setSpentRoundCount(modData[MAIN_AMMO_KEYS.spentRoundCount]) end
    if modData[MAIN_AMMO_KEYS.jammed]          ~= nil then weapon:setJammed(modData[MAIN_AMMO_KEYS.jammed]) end
    if modData[MAIN_AMMO_KEYS.containsClip]    ~= nil then weapon:setContainsClip(modData[MAIN_AMMO_KEYS.containsClip]) end
    if modData[MAIN_AMMO_KEYS.magazineType]    ~= nil then weapon:setMagazineType(modData[MAIN_AMMO_KEYS.magazineType]) end
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
        -- Fallback: fresh instance from script definition with current parts attached.
        -- instanceItem always returns original script stats so this is always correct
        -- regardless of what is currently applied to the live weapon object.
        local baseShadow    = StatsFactory.GetBaseStatsWithAttachments(weapon)
        local fallbackSnap  = StatsFactory.Snapshot(baseShadow, UNDERBARREL_DEFAULT_SWAP_STATS)
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
    local modData           = weapon:getModData()
    local underbarrelWeapon = modData[keys.cacheWeapon]

    -- Invalidate cache if the registered type changed.
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

    -- Rehydrate the cached object with whatever ammo state is saved in modData.
    ApplySavedRuntimeToUnderbarrel(weapon, underbarrelWeapon, keys)
    return underbarrelWeapon
end

-------------------------------------------------
-- Core enter / exit logic
-------------------------------------------------

local function EnterUnderbarrelMode(weapon, player, underbarrelType, keys, swapStats)
    if not weapon or not player or not underbarrelType then return end
    if Underbarrel.IsWeaponInUnderbarrelMode(weapon) then return end

    -- Persist the main weapon's entire state to modData before touching anything.
    SaveScriptStatsToModData(weapon, swapStats)
    SaveMainWeaponRuntimeState(weapon)
    SaveMainAmmoListForModeSwitch(weapon)

    -- Get (or recreate) the underbarrel weapon with its saved ammo state.
    local underbarrelWeapon = GetOrCreateCachedUnderbarrelWeapon(weapon, underbarrelType, keys)
    if not underbarrelWeapon then
        -- Abort cleanly: undo the saves above.
        weapon:getModData().GW_MainWeaponSavedStats = nil
        RestoreMainWeaponRuntimeState(weapon)
        RestoreMainAmmoListAfterModeSwitch(weapon)
        return
    end

    -- The physical weapon object never changes; keep its sprite.
    underbarrelWeapon:setWeaponSprite(weapon:getWeaponSprite())

    -- Apply underbarrel script stats (AmmoType, damage, range, sounds…).
    local scriptSnap  = StatsFactory.Snapshot(underbarrelWeapon, swapStats)
    StatsFactory.Apply(weapon, scriptSnap)

    -- Apply underbarrel runtime ammo state (count, chambered, jammed…).
    local runtimeSnap = StatsFactory.Snapshot(underbarrelWeapon, RUNTIME_AMMO_STAT_NAMES)
    StatsFactory.Apply(weapon, runtimeSnap)

    -- Force direct-load state for the underbarrel.
    -- ContainsClip must be false so the vanilla reload system treats this as a
    -- direct-load weapon instead of routing through ISInsertMagazine/ISEjectMagazine.
    -- MagazineType must be nil for the same reason.
    -- The main weapon's original values are already captured in MAIN_AMMO_KEYS above
    -- and will be restored by RestoreMainWeaponRuntimeState when we exit the mode.
    weapon:setContainsClip(false)
    weapon:setMagazineType(nil)

    -- Restore the underbarrel's custom AmmoList if one was saved.
    RestoreModeAmmoList(weapon, keys)

    local modData = weapon:getModData()
    modData.GW_IsUnderbarrelMode         = true
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

-------------------------------------------------
-- Public API — queries
-------------------------------------------------

function Underbarrel.CanSwapToUnderbarrel(weapon)
    if not IsWeaponValid(weapon) then return false end
    local attachment = weapon:getWeaponPart("Underbarrel") or weapon:getWeaponPart("UnderbarrelIntegrated")
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
-- Public API — actions
-------------------------------------------------

function Underbarrel.SwapToUnderbarrel(weapon, player)
    if not weapon or not player then return end
    if not Underbarrel.CanSwapToUnderbarrel(weapon) then return end

    local attachment = weapon:getWeaponPart("Underbarrel") or weapon:getWeaponPart("UnderbarrelIntegrated")
    local entry      = Underbarrel.UnderbarrelAttachments[attachment:getFullType()]
    EnterUnderbarrelMode(weapon, player, entry.type, ATTACHMENT_KEYS, entry.swapStats)
end

function Underbarrel.RestoreOriginalWeapon(player)
    if not player then return end

    local weapon = player:getPrimaryHandItem()
    if not weapon then return end
    if not Underbarrel.IsWeaponInUnderbarrelMode(weapon) then return end

    local keys = GetActiveKeys(weapon)

    -- Persist the current (underbarrel) ammo state before reverting.
    SaveRuntimeFromActiveUnderbarrel(weapon, keys)
    SaveCurrentModeAmmoList(weapon, keys)

    -- Restore main weapon script stats.
    RestoreScriptStatsFromModData(weapon)

    -- Restore main weapon runtime ammo state (ammo count, chambered, jammed…).
    RestoreMainWeaponRuntimeState(weapon)

    -- Restore main weapon custom AmmoList.
    RestoreMainAmmoListAfterModeSwitch(weapon)

    local modData = weapon:getModData()
    modData.GW_IsUnderbarrelMode         = nil
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

--- Called by Init.lua for every ranged weapon at game load time.
--- If the weapon was saved while in underbarrel mode this forces it back to
--- main-weapon mode so StatsFactory.ReapplyAllModifiers starts from a clean base.
--- The underbarrel's ammo state (GW_Underbarrel*/GW_IntegratedUnderbarrel*) is
--- intentionally preserved so the next toggle restores it correctly.
---@param weapon HandWeapon
function Underbarrel.RestoreOnLoad(weapon)
    if not weapon then return end
    if not Underbarrel.IsWeaponInUnderbarrelMode(weapon) then return end

    -- Restore main weapon script stats (from modData, or fallback from script def).
    RestoreScriptStatsFromModData(weapon)

    -- Restore main weapon runtime ammo state.
    RestoreMainWeaponRuntimeState(weapon)

    -- Restore main weapon custom AmmoList.
    RestoreMainAmmoListAfterModeSwitch(weapon)

    local modData = weapon:getModData()
    modData.GW_IsUnderbarrelMode         = nil
    modData.GW_UnderbarrelModeWeaponType = nil
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

    -- If currently in underbarrel mode for this attachment, force back to main weapon.
    if Underbarrel.IsWeaponInUnderbarrelMode(weapon)
        and modData.GW_UnderbarrelModeWeaponType == entry.type then

        -- Save the live underbarrel ammo state so we can return it to the player below.
        SaveRuntimeFromActiveUnderbarrel(weapon, ATTACHMENT_KEYS)
        SaveCurrentModeAmmoList(weapon, ATTACHMENT_KEYS)

        RestoreScriptStatsFromModData(weapon)
        RestoreMainWeaponRuntimeState(weapon)
        RestoreMainAmmoListAfterModeSwitch(weapon)

        modData.GW_IsUnderbarrelMode         = nil
        modData.GW_UnderbarrelModeWeaponType = nil

        if player then
            player:setPrimaryHandItem(weapon)
            if weapon:isTwoHandWeapon() then
                player:setSecondaryHandItem(weapon)
            else
                player:setSecondaryHandItem(nil)
            end
            player:resetEquippedHandsModels()
        end
    end

    -- Return any loaded underbarrel ammo to the player's inventory.
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
            -- No per-type list; fall back to count + default ammo type from the script.
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
    modData[ATTACHMENT_KEYS.cacheWeapon]     = nil
    modData[ATTACHMENT_KEYS.ammo]            = nil
    modData[ATTACHMENT_KEYS.ammoList]        = nil
    modData[ATTACHMENT_KEYS.chambered]       = nil
    modData[ATTACHMENT_KEYS.spentRound]      = nil
    modData[ATTACHMENT_KEYS.spentRoundCount] = nil
    modData[ATTACHMENT_KEYS.jammed]          = nil
    modData[ATTACHMENT_KEYS.containsClip]    = nil
    modData[ATTACHMENT_KEYS.magazineType]    = nil
    modData.GW_MainWeaponSavedStats          = nil
end

-------------------------------------------------
-- Integrated Underbarrel Helpers
-------------------------------------------------

--- Check if a weapon has an integrated underbarrel registered.
---@param weapon HandWeapon
---@return boolean
function Underbarrel.HasIntegratedUnderbarrel(weapon)
    if not weapon then return false end
    return Underbarrel.IntegratedUnderbarrels[weapon:getFullType()] ~= nil
end

--- Check if the integrated underbarrel is currently deployed.
---@param weapon HandWeapon
---@return boolean
function Underbarrel.IsIntegratedUnderbarrelDeployed(weapon)
    if not weapon then return false end
    return weapon:getModData().GW_IntegratedUnderbarrelDeployed == true
end

--- Toggle the integrated underbarrel between deployed and stowed.
---@param weapon HandWeapon
function Underbarrel.ToggleIntegratedUnderbarrel(weapon)
    if not weapon then return end
    if not Underbarrel.HasIntegratedUnderbarrel(weapon) then return end
    weapon:getModData().GW_IntegratedUnderbarrelDeployed = not Underbarrel.IsIntegratedUnderbarrelDeployed(weapon)
end

--- Swap to the integrated underbarrel weapon.
---@param weapon HandWeapon
---@param player IsoPlayer
function Underbarrel.SwapToIntegratedUnderbarrel(weapon, player)
    if not weapon or not player then return end
    if not Underbarrel.HasIntegratedUnderbarrel(weapon) then return end
    if not Underbarrel.IsIntegratedUnderbarrelDeployed(weapon) then return end

    local entry = Underbarrel.IntegratedUnderbarrels[weapon:getFullType()]
    EnterUnderbarrelMode(weapon, player, entry.type, INTEGRATED_KEYS, entry.swapStats)
end

return Underbarrel
