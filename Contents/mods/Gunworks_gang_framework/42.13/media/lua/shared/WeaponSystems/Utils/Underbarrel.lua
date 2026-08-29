local StatsFactory                 = require("WeaponSystems/Utils/StatsFactory")
local Ammo                         = require("WeaponSystems/Utils/Ammo")

local Underbarrel                  = {}

-- [attachmentFullType] = entry   (public: read by the gun packs' context/radial menus)
Underbarrel.UnderbarrelAttachments = {}
-- array of { id, snapshot = fn(weapon), restore = fn(weapon, data) }
Underbarrel.StatePreservers        = {}

-- kept for API compatibility with old callers / GetModeState consumers
Underbarrel.MODE_SOURCE_ATTACHMENT = "attachment"
Underbarrel.MODEL_HOST             = "host"
Underbarrel.MODEL_SELF             = "self"

-------------------------------------------------
-- modData keys
-------------------------------------------------
local K_MODE                       = "GW_UBMode" -- true on a swapped-in underbarrel weapon
local K_WEAPON                     = "GW_UBWeaponType" -- underbarrel weapon fullType
local K_ATTACH                     = "GW_UBAttachment" -- attachment part fullType
local K_MODEL                      = "GW_UBModel" -- "host" | "self"
local K_HOST_SNAP                  = "GW_UBHostSnapshot" -- snapshot needed to rebuild the host
local K_HOST_SPRITE                = "GW_UBHostSprite" -- host WeaponSprite (for model == "host")
local K_HOST_TYPE                  = "GW_UBHostType" -- host fullType (for model == "host" re-mask on load)
local K_SELF_SNAP                  = "GW_UBSelfSnapshot" -- on the HOST: the underbarrel weapon's own state

-- Keys the host snapshot's wholesale modData copy must never carry.
local function IsReservedModDataKey(key)
    if type(key) ~= "string" then return true end
    return key:sub(1, 5) == "GW_UB"
end

-------------------------------------------------
-- Registration API
-------------------------------------------------

--- Register an underbarrel attachment and the weapon it swaps to.
---@param config table {
---   attachment = string,        attachment (or integrated) part fullType
---   weapon     = string,        standalone underbarrel weapon fullType
---   model      = "host"|"self", "host" (default) keeps the host weapon's model on
---                                the swapped-in weapon; "self" shows the underbarrel
---                                weapon's own script model
--- }
function Underbarrel.Register(config)
    if type(config) ~= "table" then return end
    if not config.attachment or not config.weapon then return end

    local model = config.model
    if model ~= Underbarrel.MODEL_SELF then model = Underbarrel.MODEL_HOST end

    Underbarrel.UnderbarrelAttachments[config.attachment] = {
        attachment = config.attachment,
        type       = config.weapon, -- ".type" name kept for existing consumers
        model      = model,
    }
end

--- Backwards-compatible shim for the old signature.
--- RegisterUnderbarrelAttachment(attachment, weapon)
function Underbarrel.RegisterUnderbarrelAttachment(attachmentType, underbarrelType)
    Underbarrel.Register({
        attachment = attachmentType,
        weapon     = underbarrelType,
        model      = Underbarrel.MODEL_HOST,
    })
end

--- Register a handler that snapshots / restores weapon state living OUTSIDE modData.
--- (modData is copied wholesale already, so most systems need nothing here.)
---@param id string
---@param handlers table { snapshot = fn(weapon)->any, restore = fn(weapon, data) }
function Underbarrel.RegisterStatePreserver(id, handlers)
    if not id or type(handlers) ~= "table" then return end
    if type(handlers.snapshot) ~= "function" or type(handlers.restore) ~= "function" then return end

    for i = 1, #Underbarrel.StatePreservers do
        if Underbarrel.StatePreservers[i].id == id then
            Underbarrel.StatePreservers[i].snapshot = handlers.snapshot
            Underbarrel.StatePreservers[i].restore  = handlers.restore
            return
        end
    end
    Underbarrel.StatePreservers[#Underbarrel.StatePreservers + 1] = {
        id = id, snapshot = handlers.snapshot, restore = handlers.restore,
    }
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

local function GetAttachmentPart(weapon)
    if not weapon then return nil end
    return weapon:getWeaponPart("Underbarrel") or weapon:getWeaponPart("UnderbarrelIntegrated")
end

local function GetAttachmentEntry(weapon)
    local part = GetAttachmentPart(weapon)
    if not part then return nil end
    return Underbarrel.UnderbarrelAttachments[part:getFullType()]
end

--- Deep copy of serialisable data only. Userdata / functions are dropped.
local function DeepCopyData(value)
    local t = type(value)
    if t == "number" or t == "string" or t == "boolean" then
        return value
    elseif t == "table" then
        local out = {}
        for k, v in pairs(value) do
            local kt = type(k)
            if kt == "string" or kt == "number" then
                local cv = DeepCopyData(v)
                if cv ~= nil then out[k] = cv end
            end
        end
        return out
    end
    return nil
end

--- Copy a modData table, skipping reserved top-level keys and any userdata.
local function CopyModData(modData)
    local out = {}
    for k, v in pairs(modData) do
        if not IsReservedModDataKey(k) then
            local cv = DeepCopyData(v)
            if cv ~= nil then out[k] = cv end
        end
    end
    return out
end

--- Resolve a bullet itemKey (e.g. "SWMG.556x45_Bullet") to its AmmoType enum.
--- Uses the Gunworks ammo-family registry; returns nil for unregistered bullets
--- (in which case the freshly instanced weapon keeps its correct script AmmoType).
local function AmmoEnumFromKey(key)
    if not key then return nil end
    return Ammo.GetEnumForBullet(key)
end

--- Strip every weapon part currently on a weapon (raw detach, ignores canDetach).
local function DetachAllParts(weapon)
    local parts = weapon:getAllWeaponParts()
    if not parts or parts:size() == 0 then return end
    local list = {}
    for i = 0, parts:size() - 1 do list[#list + 1] = parts:get(i) end
    for i = 1, #list do weapon:detachWeaponPart(list[i]) end
end

--- Make `target` render exactly like `hostWeapon`: copy the sprite, icon and
--- ModelWeaponPart list (the model mask), then clone every attached part one by
--- one. Mirrors Bayonet.BayonetAttack's temp-weapon setup.
local function ApplyHostAppearance(target, hostWeapon)
    if not target or not hostWeapon then return end

    target:setWeaponSprite(hostWeapon:getWeaponSprite())
    local icon = hostWeapon:getIcon()
    if icon then target:setIcon(icon) end
    local modelParts = hostWeapon:getModelWeaponPart()
    if modelParts then
        target:setModelWeaponPart(modelParts)
    end

    DetachAllParts(target)

    local hostParts = hostWeapon:getAllWeaponParts()
    if hostParts then
        for i = 0, hostParts:size() - 1 do
            local part = hostParts:get(i)
            if part then
                local partCopy = instanceItem(part:getFullType())
                if partCopy and instanceof(partCopy, "WeaponPart") then
                    target:attachWeaponPart(partCopy, true)
                end
            end
        end
    end
end

--- Re-apply the host's sprite / icon / ModelWeaponPart mask on a swapped-in
--- weapon after a load or re-equip (the host object is gone, so derive the
--- model mask from a throwaway instance of the host type). The cloned parts are
--- real WeaponParts and persist on their own.
local function ReassertHostAppearance(weapon)
    local md = weapon:getModData()
    if md[K_MODE] ~= true or md[K_MODEL] ~= Underbarrel.MODEL_HOST then return end

    if md[K_HOST_SPRITE] and weapon:getWeaponSprite() ~= md[K_HOST_SPRITE] then
        weapon:setWeaponSprite(md[K_HOST_SPRITE])
    end

    local hostType = md[K_HOST_TYPE]
    if not hostType then return end
    local shadow = instanceItem(hostType)
    if not shadow then return end

    local modelParts = shadow:getModelWeaponPart()
    if modelParts then weapon:setModelWeaponPart(modelParts) end
    local icon = shadow:getIcon()
    if icon then weapon:setIcon(icon) end
end

-------------------------------------------------
-- Snapshot
-------------------------------------------------

local function SnapshotAmmo(weapon)
    local at = weapon:getAmmoType()
    return {
        currentAmmoCount    = weapon:getCurrentAmmoCount(),
        roundChambered      = weapon:isRoundChambered(),
        spentRoundChambered = weapon:isSpentRoundChambered(),
        spentRoundCount     = weapon:getSpentRoundCount(),
        jammed              = weapon:isJammed(),
        containsClip        = weapon:isContainsClip(),
        magazineType        = weapon:getMagazineType(),
        maxAmmo             = weapon:getMaxAmmo(),
        ammoType            = at and at:getItemKey() or nil,
        fireMode            = weapon:getFireMode(),
        ammoList            = Ammo.CopyAmmoList(weapon:getModData().AmmoList),
    }
end

local function SnapshotParts(weapon)
    local out   = {}
    local parts = weapon:getAllWeaponParts()
    if parts then
        for i = 0, parts:size() - 1 do
            local p = parts:get(i)
            if p then
                out[#out + 1] = {
                    type      = p:getFullType(),
                    partType  = p:getPartType(),
                    condition = p:getCondition(),
                    modData   = DeepCopyData(p:getModData()),
                }
            end
        end
    end
    return out
end

--- Full serialisable snapshot of a weapon (used for both the host and the
--- underbarrel weapon's own retained state).
local function BuildSnapshot(weapon)
    local md   = weapon:getModData()
    local snap = {
        type             = weapon:getFullType(),
        condition        = weapon:getCondition(),
        conditionMax     = weapon:getConditionMax(),
        haveBeenRepaired = weapon:getHaveBeenRepaired(),
        weaponSprite     = weapon:getWeaponSprite(),
        customName       = (weapon:isCustomName() and md.customName ~= nil) and tostring(md.customName) or nil,
        ammo             = SnapshotAmmo(weapon),
        parts            = SnapshotParts(weapon),
        modData          = CopyModData(md),
        preservers       = {},
    }
    for i = 1, #Underbarrel.StatePreservers do
        local pv = Underbarrel.StatePreservers[i]
        local data = pv.snapshot(weapon)
        if data ~= nil then
            snap.preservers[pv.id] = DeepCopyData(data)
        end
    end
    return snap
end

-------------------------------------------------
-- Rebuild
-------------------------------------------------

--- Make the weapon's parts exactly match the snapshot. The fresh instance's
--- OnCreate may have attached its own (sometimes random) parts, so detach
--- everything first, then attach the snapshot's parts in order.
local function RestoreParts(weapon, parts)
    DetachAllParts(weapon)

    if not parts then return end
    for i = 1, #parts do
        local sp = parts[i]
        local pc = instanceItem(sp.type)
        if pc and instanceof(pc, "WeaponPart") then
            weapon:attachWeaponPart(pc)
            local attached = sp.partType and weapon:getWeaponPart(sp.partType) or nil
            if attached and attached:getFullType() == sp.type then
                if sp.condition ~= nil then attached:setCondition(sp.condition) end
                if sp.modData then
                    local pmd = attached:getModData()
                    for k, v in pairs(sp.modData) do pmd[k] = v end
                end
            end
        end
    end
end

local function RestoreAmmo(weapon, ammo)
    if not ammo then return end

    -- MagazineType before ContainsClip (Java guard: usesExternalMagazine() && value)
    if ammo.magazineType then
        weapon:setMagazineType(ammo.magazineType)
        local magInst = instanceItem(ammo.magazineType)
        if magInst then weapon:setMaxAmmo(magInst:getMaxAmmo()) end
    elseif ammo.maxAmmo then
        weapon:setMaxAmmo(ammo.maxAmmo)
    end

    local enum = AmmoEnumFromKey(ammo.ammoType)
    if enum then weapon:setAmmoType(enum) end

    weapon:setCurrentAmmoCount(ammo.currentAmmoCount or 0)
    weapon:setRoundChambered(ammo.roundChambered == true)
    weapon:setSpentRoundChambered(ammo.spentRoundChambered == true)
    weapon:setSpentRoundCount(ammo.spentRoundCount or 0)
    weapon:setJammed(ammo.jammed == true)
    if ammo.containsClip ~= nil then weapon:setContainsClip(ammo.containsClip == true) end

    weapon:getModData().AmmoList = Ammo.CopyAmmoList(ammo.ammoList)
end

--- Instantiate a weapon from a snapshot and restore all captured state.
local function RebuildFromSnapshot(snap)
    if not snap or not snap.type then return nil end

    local weapon = instanceItem(snap.type)
    if not weapon or not instanceof(weapon, "HandWeapon") then return nil end

    RestoreParts(weapon, snap.parts)

    if snap.modData then
        local md = weapon:getModData()
        for k, v in pairs(snap.modData) do
            if not IsReservedModDataKey(k) then md[k] = v end
        end
    end

    if snap.conditionMax and snap.conditionMax > 0 then weapon:setConditionMax(snap.conditionMax) end
    if snap.condition ~= nil then weapon:setCondition(snap.condition) end
    if snap.haveBeenRepaired then weapon:setHaveBeenRepaired(snap.haveBeenRepaired) end
    if snap.weaponSprite and snap.weaponSprite ~= "" and weapon:getWeaponSprite() ~= snap.weaponSprite then
        weapon:setWeaponSprite(snap.weaponSprite)
    end
    if snap.customName and snap.customName ~= "" then
        weapon:setName(snap.customName)
        weapon:setCustomName(true)
    end

    RestoreAmmo(weapon, snap.ammo)

    if snap.preservers then
        for i = 1, #Underbarrel.StatePreservers do
            local pv   = Underbarrel.StatePreservers[i]
            local data = snap.preservers[pv.id]
            if data ~= nil then pv.restore(weapon, data) end
        end
    end

    StatsFactory.ReapplyAllModifiers(weapon)

    -- fire mode last: custom RoF fire modes are only valid after the modifier
    -- layers have re-registered the weapon's fire-mode possibilities.
    if snap.ammo and snap.ammo.fireMode then
        weapon:setFireMode(snap.ammo.fireMode)
    end

    return weapon
end

-------------------------------------------------
-- Equipped-item replacement (server-authoritative pattern)
-------------------------------------------------

local function ReplaceEquipped(player, oldWeapon, newWeapon)
    local inv       = player:getInventory()
    local sourceInv = oldWeapon:getContainer() or inv

    player:removeFromHands(oldWeapon)
    sourceInv:Remove(oldWeapon)
    sendRemoveItemFromContainer(sourceInv, oldWeapon)

    local added = inv:AddItem(newWeapon) or newWeapon
    sendAddItemToContainer(inv, added)
    if isServer() then sendItemStats(added) end

    player:setPrimaryHandItem(added)
    if added:isTwoHandWeapon() then
        player:setSecondaryHandItem(added)
    else
        player:setSecondaryHandItem(nil)
    end
    player:resetEquippedHandsModels()

    syncHandWeaponFields(player, added)
    if isServer() then
        sendEquip(player)
    else
        local pInv = getPlayerInventory(player:getPlayerNum())
        if pInv then pInv:refreshBackpacks() end
    end

    return added
end

-------------------------------------------------
-- Ammo refund (attachment removed while a loaded underbarrel weapon is stashed)
-------------------------------------------------

local function RefundAmmo(player, underbarrelType, ammo)
    if not ammo then return end
    local inv = player:getInventory()

    local list = ammo.ammoList
    if list and #list > 0 then
        for i = 1, #list do
            local b = instanceItem(list[i])
            if b then
                inv:AddItem(b)
                sendAddItemToContainer(inv, b)
            end
        end
        return
    end

    local count = ammo.currentAmmoCount or 0
    if count <= 0 then return end

    local key = ammo.ammoType
    if not key then
        local ref = instanceItem(underbarrelType)
        local at  = ref and ref:getAmmoType()
        key       = at and at:getItemKey() or nil
    end
    if not key then return end

    for _ = 1, count do
        local b = instanceItem(key)
        if b then
            inv:AddItem(b)
            sendAddItemToContainer(inv, b)
        end
    end
end

-------------------------------------------------
-- Core swap
-------------------------------------------------

--- Perform the actual weapon swap. Runs on the server (MP) or directly (SP).
---@param oldWeapon HandWeapon   the weapon currently in the primary hand
---@param player    IsoPlayer
---@param entering  boolean      true = main -> underbarrel, false = underbarrel -> main
---@param silent    boolean|nil  suppress the character bark
---@return HandWeapon|nil newWeapon
function Underbarrel.PerformSwap(oldWeapon, player, entering, silent)
    if not IsWeaponValid(oldWeapon) or not player then return nil end
    if player:getPrimaryHandItem() ~= oldWeapon then return nil end

    local newWeapon

    if entering then
        if Underbarrel.IsWeaponInUnderbarrelMode(oldWeapon) then return nil end

        local entry = GetAttachmentEntry(oldWeapon)
        if not entry then return nil end

        local hostSnap = BuildSnapshot(oldWeapon)
        local selfSnap = oldWeapon:getModData()[K_SELF_SNAP]

        local restoredFromSelf = false
        if type(selfSnap) == "table" and selfSnap.type == entry.type then
            newWeapon = RebuildFromSnapshot(selfSnap)
            restoredFromSelf = newWeapon ~= nil
        end
        newWeapon = newWeapon or instanceItem(entry.type)
        if not newWeapon then return nil end

        if not restoredFromSelf then
            -- fresh instance: strip any OnCreate-randomised ammo so the
            -- underbarrel weapon starts empty the first time it is deployed.
            newWeapon:setCurrentAmmoCount(0)
            newWeapon:setRoundChambered(false)
            newWeapon:setSpentRoundChambered(false)
            newWeapon:setSpentRoundCount(0)
            newWeapon:setJammed(false)
            newWeapon:getModData().AmmoList = nil
        end

        local nmd          = newWeapon:getModData()
        nmd[K_MODE]        = true
        nmd[K_WEAPON]      = entry.type
        nmd[K_ATTACH]      = entry.attachment
        nmd[K_MODEL]       = entry.model
        nmd[K_HOST_SNAP]   = hostSnap
        nmd[K_HOST_SPRITE] = oldWeapon:getWeaponSprite()
        nmd[K_HOST_TYPE]   = oldWeapon:getFullType()

        if entry.model == Underbarrel.MODEL_HOST then
            ApplyHostAppearance(newWeapon, oldWeapon)
        end
    else
        if not Underbarrel.IsWeaponInUnderbarrelMode(oldWeapon) then return nil end

        local hostSnap = oldWeapon:getModData()[K_HOST_SNAP]
        local selfSnap = BuildSnapshot(oldWeapon) -- the underbarrel weapon's own state

        if type(hostSnap) == "table" then
            newWeapon = RebuildFromSnapshot(hostSnap)
            if not newWeapon and hostSnap.type then
                newWeapon = instanceItem(hostSnap.type)
            end
        end
        if not newWeapon then return nil end

        newWeapon:getModData()[K_SELF_SNAP] = selfSnap
    end

    local added = ReplaceEquipped(player, oldWeapon, newWeapon)

    local pmd = player:getModData()
    if entering then
        pmd[K_HOST_SNAP] = added:getModData()[K_HOST_SNAP]
    else
        pmd[K_HOST_SNAP] = nil
    end

    if not silent then
        DisplayMessage(player, entering and "Using underbarrel weapon" or "Using main weapon")
    end

    return added
end

-------------------------------------------------
-- Public API — queries
-------------------------------------------------

function Underbarrel.IsWeaponInUnderbarrelMode(weapon)
    if not weapon then return false end
    return weapon:getModData()[K_MODE] == true
end

function Underbarrel.CanSwapToUnderbarrel(weapon)
    if not IsWeaponValid(weapon) then return false end
    if Underbarrel.IsWeaponInUnderbarrelMode(weapon) then return false end
    return GetAttachmentEntry(weapon) ~= nil
end

function Underbarrel.CanToggleUnderbarrel(weapon)
    if not IsWeaponValid(weapon) then return false end
    if Underbarrel.IsWeaponInUnderbarrelMode(weapon) then return true end
    return Underbarrel.CanSwapToUnderbarrel(weapon)
end

function Underbarrel.IsUsingUnderbarrel(player)
    if not player then return false end
    local primary = player:getPrimaryHandItem()
    return primary ~= nil and Underbarrel.IsWeaponInUnderbarrelMode(primary)
end

function Underbarrel.GetModeUnderbarrelType(weapon)
    if not weapon then return nil end
    return weapon:getModData()[K_WEAPON]
end

function Underbarrel.IsUnderbarrelModeWeaponType(weapon, underbarrelType)
    if not weapon or not underbarrelType then return false end
    return Underbarrel.GetModeUnderbarrelType(weapon) == underbarrelType
end

function Underbarrel.GetAttachmentEntry(weapon)
    return GetAttachmentEntry(weapon)
end

--- Kept for consumers that read the old table shape.
function Underbarrel.GetModeState(weapon)
    if not weapon then
        return { isUnderbarrelMode = false, underbarrelType = nil, modeSource = nil }
    end
    local isMode = Underbarrel.IsWeaponInUnderbarrelMode(weapon)
    return {
        isUnderbarrelMode = isMode,
        underbarrelType   = weapon:getModData()[K_WEAPON],
        modeSource        = isMode and Underbarrel.MODE_SOURCE_ATTACHMENT or nil,
    }
end

-------------------------------------------------
-- Public API — actions
-------------------------------------------------

--- Toggle the weapon in the player's primary hand between main and underbarrel.
--- MP client: asks the server. SP / server: performs the swap directly.
function Underbarrel.ToggleUnderbarrel(weapon, player)
    if not weapon or not player then return false end
    if not Underbarrel.CanToggleUnderbarrel(weapon) then return false end
    if player:getPrimaryHandItem() ~= weapon then return false end

    local entering = not Underbarrel.IsWeaponInUnderbarrelMode(weapon)

    if isClient() then
        DisplayMessage(player, entering and "Using underbarrel weapon" or "Using main weapon")
        sendClientCommand(player, "SWMG", "underbarrelMode", {
            itemId = weapon:getID(),
            action = entering and "enter" or "exit",
        })
    else
        Underbarrel.PerformSwap(weapon, player, entering, false)
    end

    return true
end

--- Called by WeaponUpgradeHooks / ISRailingAction when a weapon part is removed.
--- No-op unless the removed part is a registered underbarrel attachment, in which
--- case the stashed underbarrel weapon's state is dropped and its loaded rounds
--- are refunded to the player.
---@param weapon      HandWeapon
---@param removedPart WeaponPart
---@param player      IsoPlayer|nil
function Underbarrel.HandleAttachmentRemoval(weapon, removedPart, player)
    if not weapon or not removedPart then return end

    local entry = Underbarrel.UnderbarrelAttachments[removedPart:getFullType()]
    if not entry then return end

    local md        = weapon:getModData()
    local selfSnap  = md[K_SELF_SNAP]
    md[K_SELF_SNAP] = nil

    if player and type(selfSnap) == "table" then
        RefundAmmo(player, entry.type, selfSnap.ammo)
    end
end

-------------------------------------------------
-- Load-time reconcile
-------------------------------------------------

--- Called by Init.lua for every ranged weapon at load / equip time.
--- A weapon legitimately stays swapped across save/load, so this re-applies the
--- host model mask (sprite / icon / ModelWeaponPart, which are not serialised).
---@param weapon HandWeapon
function Underbarrel.RestoreOnLoad(weapon)
    if not weapon then return end
    if not Underbarrel.IsWeaponInUnderbarrelMode(weapon) then return end

    ReassertHostAppearance(weapon)
end

--- MP: re-apply the model="host" mask on another player's copy of a swapped-in
--- weapon, from the fields carried by the SWMG "syncWeapon" broadcast (the native
--- weapon packet only reaches the owner, and ModelWeaponPart is never serialised).
---@param weapon      HandWeapon
---@param model       string|nil
---@param hostSprite  string|nil
---@param hostType    string|nil
function Underbarrel.ApplyRemoteModelMask(weapon, model, hostSprite, hostType)
    if not weapon or model ~= Underbarrel.MODEL_HOST then return end
    local md          = weapon:getModData()
    md[K_MODE]        = true
    md[K_MODEL]       = model
    md[K_HOST_SPRITE] = hostSprite
    md[K_HOST_TYPE]   = hostType
    ReassertHostAppearance(weapon)
end

local function ContainerHasUnderbarrelWeapon(container)
    if not container then return false end
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            if instanceof(item, "HandWeapon") and item:getModData()[K_MODE] == true then
                return true
            end
            if item.getInventory and item:getInventory() and ContainerHasUnderbarrelWeapon(item:getInventory()) then
                return true
            end
        end
    end
    return false
end

--- Safety net: if the player has a pending host snapshot but the swapped-in
--- underbarrel weapon is gone (broke, dropped, destroyed), rebuild the host.
---@param player IsoPlayer
function Underbarrel.RecoverLostHost(player)
    if not player then return end
    if isClient() then return end -- server / SP authoritative only

    local pmd  = player:getModData()
    local snap = pmd[K_HOST_SNAP]
    if type(snap) ~= "table" then
        pmd[K_HOST_SNAP] = nil
        return
    end

    if ContainerHasUnderbarrelWeapon(player:getInventory()) then return end

    local host = RebuildFromSnapshot(snap) or (snap.type and instanceItem(snap.type))
    if host then
        player:getInventory():AddItem(host)
        sendAddItemToContainer(player:getInventory(), host)
    end
    pmd[K_HOST_SNAP] = nil
end

-------------------------------------------------
-- Keep the host model on a model="host" swapped-in weapon.
-- StatsFactory layers (e.g. CustomStatsAttachments) list WeaponSprite as a
-- restore stat, so ReapplyAllModifiers resets the sprite to the underbarrel
-- weapon's script default. This restore handler runs last and puts it back.
-------------------------------------------------
StatsFactory.RegisterRestoreHandler("Underbarrel", function(weapon)
    if not weapon then return end
    local md = weapon:getModData()
    if md[K_MODE] == true and md[K_MODEL] == Underbarrel.MODEL_HOST and md[K_HOST_SPRITE]
        and weapon:getWeaponSprite() ~= md[K_HOST_SPRITE] then
        weapon:setWeaponSprite(md[K_HOST_SPRITE])
    end
end)

return Underbarrel
