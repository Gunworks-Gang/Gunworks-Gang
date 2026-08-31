local StatsFactory                 = require("WeaponSystems/Utils/StatsFactory")
local Ammo                         = require("WeaponSystems/Utils/Ammo")

local Underbarrel                  = {}

Underbarrel.UnderbarrelAttachments = {}
Underbarrel.StatePreservers        = {}

Underbarrel.MODE_SOURCE_ATTACHMENT = "attachment"
Underbarrel.MODEL_HOST             = "host"
Underbarrel.MODEL_SELF             = "self"

local KEY_MODE                     = "GW_UBMode"         -- true while this weapon is a deployed underbarrel weapon
local KEY_WEAPON_TYPE              = "GW_UBWeaponType"   -- underbarrel weapon fullType
local KEY_ATTACHMENT               = "GW_UBAttachment"   -- attachment part fullType
local KEY_MODEL                    = "GW_UBModel"        -- "host" | "self"
local KEY_HOST_SNAPSHOT            = "GW_UBHostSnapshot" -- everything needed to rebuild the host weapon
local KEY_HOST_SPRITE              = "GW_UBHostSprite"   -- host WeaponSprite         (model == "host")
local KEY_HOST_TYPE                = "GW_UBHostType"     -- host fullType, to re-derive the model mask on load
local KEY_SELF_SNAPSHOT            = "GW_UBSelfSnapshot" -- on the HOST: the underbarrel weapon's own retained state

-- Keys the host snapshot's wholesale modData copy must never carry.
local function IsReservedModDataKey(key)
    if type(key) ~= "string" then return true end
    return key:sub(1, 5) == "GW_UB"
end

-------------------------------------------------
-- Registration
-------------------------------------------------

--- Register an underbarrel attachment and the weapon it swaps to.
--- config = {
---   attachment = string,          attachment (or integrated) part fullType
---   weapon     = string,          standalone underbarrel weapon fullType
---   model      = "host" | "self"  "host" (default) keeps the host weapon's model/sprite on
---                                 the swapped-in weapon; "self" shows its own script model.
---                                 The host's attached parts are cloned onto the swapped-in
---                                 weapon in BOTH modes.
--- }
function Underbarrel.Register(config)
    if type(config) ~= "table" then return end
    if not config.attachment or not config.weapon then return end

    local model = config.model
    if model ~= Underbarrel.MODEL_SELF then model = Underbarrel.MODEL_HOST end

    Underbarrel.UnderbarrelAttachments[config.attachment] = {
        attachment = config.attachment,
        type       = config.weapon,
        model      = model,
    }
end

--- Backwards-compatible shim for the old RegisterUnderbarrelAttachment(attachment, weapon).
function Underbarrel.RegisterUnderbarrelAttachment(attachmentType, underbarrelType)
    Underbarrel.Register({ attachment = attachmentType, weapon = underbarrelType, model = Underbarrel.MODEL_HOST })
end

--- Register handlers for weapon state that does NOT live in modData (modData is copied
--- wholesale already, so most systems need nothing here).
--- handlers = { snapshot = fn(weapon) -> any, restore = fn(weapon, data) }
function Underbarrel.RegisterStatePreserver(id, handlers)
    if not id or type(handlers) ~= "table" then return end
    if type(handlers.snapshot) ~= "function" or type(handlers.restore) ~= "function" then return end

    for i = 1, #Underbarrel.StatePreservers do
        local preserver = Underbarrel.StatePreservers[i]
        if preserver.id == id then
            preserver.snapshot = handlers.snapshot
            preserver.restore  = handlers.restore
            return
        end
    end

    Underbarrel.StatePreservers[#Underbarrel.StatePreservers + 1] = {
        id = id, snapshot = handlers.snapshot, restore = handlers.restore,
    }
end

-------------------------------------------------
-- Small helpers
-------------------------------------------------

local function DisplayMessage(character, messageKey)
    character:Say(getText(messageKey), 0.55, 0.55, 0.55, UIFont.Dialogue, 0, "default")
end

local function IsRangedWeapon(weapon)
    return weapon ~= nil and instanceof(weapon, "HandWeapon") and weapon:isRanged()
end

local function GetAttachmentPart(weapon)
    if not weapon then return nil end

    local part = weapon:getWeaponPart("Underbarrel") or weapon:getWeaponPart("UnderbarrelIntegrated")
    if part and Underbarrel.UnderbarrelAttachments[part:getFullType()] then return part end

    local parts = weapon:getAllWeaponParts()
    if not parts then return nil end
    for i = 0, parts:size() - 1 do
        local candidate = parts:get(i)
        if candidate and Underbarrel.UnderbarrelAttachments[candidate:getFullType()] then
            return candidate
        end
    end
    return nil
end

local function GetAttachmentEntry(weapon)
    local part = GetAttachmentPart(weapon)
    if not part then return nil end
    return Underbarrel.UnderbarrelAttachments[part:getFullType()]
end

--- Resolve a bullet itemKey (e.g. "SWMG.556x45_Bullet") to its AmmoType enum via the
--- Gunworks ammo-family registry. nil for unregistered bullets, in which case the fresh
--- weapon instance keeps its correct script AmmoType.
local function AmmoEnumFromKey(bulletKey)
    if not bulletKey then return nil end
    return Ammo.GetEnumForBullet(bulletKey)
end

--- Recursive copy of serialisable data only; userdata and functions are dropped.
local function DeepCopyData(value)
    local valueType = type(value)
    if valueType == "number" or valueType == "string" or valueType == "boolean" then
        return value
    end
    if valueType ~= "table" then return nil end

    local copy = {}
    for key, item in pairs(value) do
        local keyType = type(key)
        if keyType == "string" or keyType == "number" then
            local copiedItem = DeepCopyData(item)
            if copiedItem ~= nil then copy[key] = copiedItem end
        end
    end
    return copy
end

--- Copy a modData table, skipping this system's own keys and any userdata.
local function CopyModData(modData)
    local copy = {}
    for key, value in pairs(modData) do
        if not IsReservedModDataKey(key) then
            local copiedValue = DeepCopyData(value)
            if copiedValue ~= nil then copy[key] = copiedValue end
        end
    end
    return copy
end

--- Remove every weapon part currently on a weapon (raw detach, ignores canDetach).
local function DetachAllParts(weapon)
    local attached = weapon:getAllWeaponParts()
    if not attached or attached:size() == 0 then return end

    local parts = {}
    for i = 0, attached:size() - 1 do parts[#parts + 1] = attached:get(i) end
    for i = 1, #parts do weapon:detachWeaponPart(parts[i]) end
end

-------------------------------------------------
-- Host parts + model mask
-------------------------------------------------

--- Replace every WeaponPart on `target` with a clone of each part attached to `host`, so the
--- swapped-in weapon carries the same optic / grip / laser / sling / integrated parts. The
--- clones are real WeaponParts and persist on their own. Runs for BOTH model modes. Mirrors
--- the temporary weapon built in Bayonet.BayonetAttack.
local function CloneHostParts(target, host)
    if not target or not host then return end

    DetachAllParts(target)

    local hostParts = host:getAllWeaponParts()
    if not hostParts then return end
    for i = 0, hostParts:size() - 1 do
        local part = hostParts:get(i)
        if part then
            local clone = instanceItem(part:getFullType())
            if clone and instanceof(clone, "WeaponPart") then
                target:attachWeaponPart(clone, true)
            end
        end
    end
end

--- Copy the host's sprite, icon and ModelWeaponPart list (the model mask) onto `target`, so
--- a model="host" weapon still renders as the rifle. Not used for model="self".
local function ApplyHostModelMask(target, host)
    if not target or not host then return end

    target:setWeaponSprite(host:getWeaponSprite())

    local icon = host:getIcon()
    if icon then target:setIcon(icon) end

    local modelParts = host:getModelWeaponPart()
    if modelParts then target:setModelWeaponPart(modelParts) end
end

--- Re-apply the host's sprite / icon / ModelWeaponPart mask on a swapped-in weapon after a
--- load or re-equip. The host object is gone, so the model mask is re-derived from a
--- throwaway instance of the host type. The cloned parts are real WeaponParts and persist.
local function ReassertHostAppearance(weapon)
    local modData = weapon:getModData()
    if modData[KEY_MODE] ~= true or modData[KEY_MODEL] ~= Underbarrel.MODEL_HOST then return end

    local hostSprite = modData[KEY_HOST_SPRITE]
    if hostSprite and weapon:getWeaponSprite() ~= hostSprite then
        weapon:setWeaponSprite(hostSprite)
    end

    local hostType = modData[KEY_HOST_TYPE]
    if not hostType then return end
    local template = instanceItem(hostType)
    if not template then return end

    local modelParts = template:getModelWeaponPart()
    if modelParts then weapon:setModelWeaponPart(modelParts) end

    local icon = template:getIcon()
    if icon then weapon:setIcon(icon) end
end

-------------------------------------------------
-- Snapshot
-------------------------------------------------

local function SnapshotAmmo(weapon)
    local ammoType = weapon:getAmmoType()
    return {
        currentAmmoCount    = weapon:getCurrentAmmoCount(),
        roundChambered      = weapon:isRoundChambered(),
        spentRoundChambered = weapon:isSpentRoundChambered(),
        spentRoundCount     = weapon:getSpentRoundCount(),
        jammed              = weapon:isJammed(),
        containsClip        = weapon:isContainsClip(),
        magazineType        = weapon:getMagazineType(),
        maxAmmo             = weapon:getMaxAmmo(),
        ammoType            = ammoType and ammoType:getItemKey() or nil,
        fireMode            = weapon:getFireMode(),
        ammoList            = Ammo.CopyAmmoList(weapon:getModData().AmmoList),
    }
end

local function SnapshotParts(weapon)
    local snapshot = {}
    local parts = weapon:getAllWeaponParts()
    if not parts then return snapshot end

    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part then
            snapshot[#snapshot + 1] = {
                type      = part:getFullType(),
                partType  = part:getPartType(),
                condition = part:getCondition(),
                modData   = DeepCopyData(part:getModData()),
            }
        end
    end
    return snapshot
end

--- Full serialisable snapshot of a weapon. Used for both the host weapon and the
--- underbarrel weapon's own retained state.
local function BuildSnapshot(weapon)
    local modData       = weapon:getModData()
    local hasCustomName = weapon:isCustomName() and modData.customName ~= nil

    local snapshot      = {
        type             = weapon:getFullType(),
        condition        = weapon:getCondition(),
        conditionMax     = weapon:getConditionMax(),
        haveBeenRepaired = weapon:getHaveBeenRepaired(),
        weaponSprite     = weapon:getWeaponSprite(),
        customName       = hasCustomName and tostring(modData.customName) or nil,
        ammo             = SnapshotAmmo(weapon),
        parts            = SnapshotParts(weapon),
        modData          = CopyModData(modData),
        preservers       = {},
    }

    for i = 1, #Underbarrel.StatePreservers do
        local preserver = Underbarrel.StatePreservers[i]
        local data = preserver.snapshot(weapon)
        if data ~= nil then
            snapshot.preservers[preserver.id] = DeepCopyData(data)
        end
    end
    return snapshot
end

-------------------------------------------------
-- Rebuild
-------------------------------------------------

--- Rebuild the weapon's parts to exactly match the snapshot. A fresh instance's OnCreate may
--- have attached its own (sometimes random) parts, so detach everything first.
local function RestoreParts(weapon, parts)
    DetachAllParts(weapon)
    if not parts then return end

    for i = 1, #parts do
        local saved    = parts[i]
        local partItem = instanceItem(saved.type)
        if partItem and instanceof(partItem, "WeaponPart") then
            weapon:attachWeaponPart(partItem)

            local attached = saved.partType and weapon:getWeaponPart(saved.partType) or nil
            if attached and attached:getFullType() == saved.type then
                if saved.condition ~= nil then attached:setCondition(saved.condition) end
                if saved.modData then
                    local partModData = attached:getModData()
                    for key, value in pairs(saved.modData) do partModData[key] = value end
                end
            end
        end
    end
end

local function RestoreAmmo(weapon, ammo)
    if not ammo then return end

    -- MagazineType must be set before ContainsClip (Java guards ContainsClip on
    -- usesExternalMagazine()).
    if ammo.magazineType then
        weapon:setMagazineType(ammo.magazineType)
        local magazine = instanceItem(ammo.magazineType)
        if magazine then weapon:setMaxAmmo(magazine:getMaxAmmo()) end
    elseif ammo.maxAmmo then
        weapon:setMaxAmmo(ammo.maxAmmo)
    end

    local ammoEnum = AmmoEnumFromKey(ammo.ammoType)
    if ammoEnum then weapon:setAmmoType(ammoEnum) end

    weapon:setCurrentAmmoCount(ammo.currentAmmoCount or 0)
    weapon:setRoundChambered(ammo.roundChambered == true)
    weapon:setSpentRoundChambered(ammo.spentRoundChambered == true)
    weapon:setSpentRoundCount(ammo.spentRoundCount or 0)
    weapon:setJammed(ammo.jammed == true)
    if ammo.containsClip ~= nil then weapon:setContainsClip(ammo.containsClip == true) end

    weapon:getModData().AmmoList = Ammo.CopyAmmoList(ammo.ammoList)
end

--- Instantiate a weapon from a snapshot and restore every captured field.
local function RebuildFromSnapshot(snapshot)
    if not snapshot or not snapshot.type then return nil end

    local weapon = instanceItem(snapshot.type)
    if not weapon or not instanceof(weapon, "HandWeapon") then return nil end

    RestoreParts(weapon, snapshot.parts)

    if snapshot.modData then
        local modData = weapon:getModData()
        for key, value in pairs(snapshot.modData) do
            if not IsReservedModDataKey(key) then modData[key] = value end
        end
    end

    if snapshot.conditionMax and snapshot.conditionMax > 0 then
        weapon:setConditionMax(snapshot.conditionMax)
    end
    if snapshot.condition ~= nil then weapon:setCondition(snapshot.condition) end
    if snapshot.haveBeenRepaired then weapon:setHaveBeenRepaired(snapshot.haveBeenRepaired) end
    if snapshot.weaponSprite and snapshot.weaponSprite ~= ""
        and weapon:getWeaponSprite() ~= snapshot.weaponSprite then
        weapon:setWeaponSprite(snapshot.weaponSprite)
    end
    if snapshot.customName and snapshot.customName ~= "" then
        weapon:setName(snapshot.customName)
        weapon:setCustomName(true)
    end

    RestoreAmmo(weapon, snapshot.ammo)

    if snapshot.preservers then
        for i = 1, #Underbarrel.StatePreservers do
            local preserver = Underbarrel.StatePreservers[i]
            local data = snapshot.preservers[preserver.id]
            if data ~= nil then preserver.restore(weapon, data) end
        end
    end

    StatsFactory.ReapplyAllModifiers(weapon)

    if snapshot.ammo and snapshot.ammo.fireMode then
        weapon:setFireMode(snapshot.ammo.fireMode)
    end

    return weapon
end

-------------------------------------------------
-- Hotbar slot preservation
-------------------------------------------------

local function CaptureHotbarSlot(player, weapon)
    if not getPlayerHotbar then return nil end
    local hotBar = getPlayerHotbar(player:getPlayerNum())
    if not hotBar or not hotBar:isInHotbar(weapon) then return nil end

    local slotIndex = weapon:getAttachedSlot()
    local available = hotBar.availableSlot[slotIndex]
    if not available or not available.def then return nil end

    return {
        slotIndex  = slotIndex,
        slotDef    = available.def,
        attachment = available.def.attachments[weapon:getAttachmentType()],
    }
end

local function RestoreHotbarSlot(player, weapon, slot)
    if not slot or not weapon or not getPlayerHotbar then return end
    local hotBar = getPlayerHotbar(player:getPlayerNum())
    if not hotBar then return end

    local attachment = slot.slotDef.attachments[weapon:getAttachmentType()] or slot.attachment
    hotBar:attachItem(weapon, attachment, slot.slotIndex, slot.slotDef, false)
    hotBar.needsRefresh = true
    hotBar:update()
end

-------------------------------------------------
-- Equipped-item replacement (base-game server-authoritative sequence)
-------------------------------------------------

local function ReplaceEquipped(player, oldWeapon, newWeapon)
    local inventory       = player:getInventory()
    local sourceContainer = oldWeapon:getContainer() or inventory

    player:removeFromHands(oldWeapon)
    sourceContainer:Remove(oldWeapon)
    sendRemoveItemFromContainer(sourceContainer, oldWeapon)

    local equipped = inventory:AddItem(newWeapon) or newWeapon
    sendAddItemToContainer(inventory, equipped)
    if isServer() then sendItemStats(equipped) end

    player:setPrimaryHandItem(equipped)
    if equipped:isTwoHandWeapon() then
        player:setSecondaryHandItem(equipped)
    else
        player:setSecondaryHandItem(nil)
    end
    player:resetEquippedHandsModels()

    syncHandWeaponFields(player, equipped)
    if isServer() then
        sendEquip(player)
    else
        local playerInv = getPlayerInventory(player:getPlayerNum())
        if playerInv then playerInv:refreshBackpacks() end
    end

    return equipped
end

-------------------------------------------------
-- Ammo refund (attachment removed while a loaded underbarrel weapon was stashed)
-------------------------------------------------

local function RefundAmmo(player, underbarrelType, ammo)
    if not ammo then return end
    local inventory = player:getInventory()

    local function give(bulletKey)
        local bullet = instanceItem(bulletKey)
        if bullet then
            inventory:AddItem(bullet)
            sendAddItemToContainer(inventory, bullet)
        end
    end

    local bulletKeys = ammo.ammoList
    if bulletKeys and #bulletKeys > 0 then
        for i = 1, #bulletKeys do give(bulletKeys[i]) end
        return
    end

    local count = ammo.currentAmmoCount or 0
    if count <= 0 then return end

    local bulletKey = ammo.ammoType
    if not bulletKey then
        local template = instanceItem(underbarrelType)
        local ammoType = template and template:getAmmoType()
        bulletKey = ammoType and ammoType:getItemKey() or nil
    end
    if not bulletKey then return end

    for _ = 1, count do give(bulletKey) end
end

-------------------------------------------------
-- Core swap
-------------------------------------------------

--- Perform the weapon swap. Runs on the server (MP) or directly (SP / listen server).
---@param oldWeapon HandWeapon  the weapon currently in the primary hand
---@param player    IsoPlayer
---@param entering  boolean     true = main -> underbarrel, false = underbarrel -> main
---@param silent    boolean|nil suppress the character bark
---@return HandWeapon|nil equipped
function Underbarrel.PerformSwap(oldWeapon, player, entering, silent)
    if not IsRangedWeapon(oldWeapon) or not player then return nil end
    if player:getPrimaryHandItem() ~= oldWeapon then return nil end

    local newWeapon

    if entering then
        if Underbarrel.IsWeaponInUnderbarrelMode(oldWeapon) then return nil end

        local entry = GetAttachmentEntry(oldWeapon)
        if not entry then return nil end

        local hostSnapshot = BuildSnapshot(oldWeapon)
        local selfSnapshot = oldWeapon:getModData()[KEY_SELF_SNAPSHOT]

        if type(selfSnapshot) == "table" and selfSnapshot.type == entry.type then
            newWeapon = RebuildFromSnapshot(selfSnapshot)
        end
        newWeapon = newWeapon or instanceItem(entry.type)
        if not newWeapon then return nil end

        local newModData              = newWeapon:getModData()
        newModData[KEY_MODE]          = true
        newModData[KEY_WEAPON_TYPE]   = entry.type
        newModData[KEY_ATTACHMENT]    = entry.attachment
        newModData[KEY_MODEL]         = entry.model
        newModData[KEY_HOST_SNAPSHOT] = hostSnapshot
        newModData[KEY_HOST_SPRITE]   = oldWeapon:getWeaponSprite()
        newModData[KEY_HOST_TYPE]     = oldWeapon:getFullType()

        CloneHostParts(newWeapon, oldWeapon)
        if entry.model == Underbarrel.MODEL_HOST then
            ApplyHostModelMask(newWeapon, oldWeapon)
        end
    else
        if not Underbarrel.IsWeaponInUnderbarrelMode(oldWeapon) then return nil end

        local hostSnapshot = oldWeapon:getModData()[KEY_HOST_SNAPSHOT]
        local selfSnapshot = BuildSnapshot(oldWeapon) -- the underbarrel weapon's own state

        if type(hostSnapshot) == "table" then
            newWeapon = RebuildFromSnapshot(hostSnapshot)
            if not newWeapon and hostSnapshot.type then
                newWeapon = instanceItem(hostSnapshot.type)
            end
        end
        if not newWeapon then return nil end

        newWeapon:getModData()[KEY_SELF_SNAPSHOT] = selfSnapshot
    end

    local hotbarSlot = CaptureHotbarSlot(player, oldWeapon)
    local equipped   = ReplaceEquipped(player, oldWeapon, newWeapon)
    RestoreHotbarSlot(player, equipped, hotbarSlot)

    -- Keep the host snapshot on the player too, as a recovery net (see RecoverLostHost).
    local playerModData = player:getModData()
    if entering then
        playerModData[KEY_HOST_SNAPSHOT] = equipped:getModData()[KEY_HOST_SNAPSHOT]
    else
        playerModData[KEY_HOST_SNAPSHOT] = nil
    end

    if not silent then
        DisplayMessage(player, entering and "Using underbarrel weapon" or "Using main weapon")
    end

    return equipped
end

-------------------------------------------------
-- Queries
-------------------------------------------------

function Underbarrel.IsWeaponInUnderbarrelMode(weapon)
    return weapon ~= nil and weapon:getModData()[KEY_MODE] == true
end

function Underbarrel.CanSwapToUnderbarrel(weapon)
    if not IsRangedWeapon(weapon) then return false end
    if Underbarrel.IsWeaponInUnderbarrelMode(weapon) then return false end
    return GetAttachmentEntry(weapon) ~= nil
end

function Underbarrel.CanToggleUnderbarrel(weapon)
    if not IsRangedWeapon(weapon) then return false end
    if Underbarrel.IsWeaponInUnderbarrelMode(weapon) then return true end
    return Underbarrel.CanSwapToUnderbarrel(weapon)
end

function Underbarrel.IsUsingUnderbarrel(player)
    if not player then return false end
    return Underbarrel.IsWeaponInUnderbarrelMode(player:getPrimaryHandItem())
end

function Underbarrel.GetModeUnderbarrelType(weapon)
    if not weapon then return nil end
    return weapon:getModData()[KEY_WEAPON_TYPE]
end

function Underbarrel.IsUnderbarrelModeWeaponType(weapon, underbarrelType)
    if not weapon or not underbarrelType then return false end
    return Underbarrel.GetModeUnderbarrelType(weapon) == underbarrelType
end

function Underbarrel.GetAttachmentEntry(weapon)
    return GetAttachmentEntry(weapon)
end

function Underbarrel.GetModeState(weapon)
    if not weapon then
        return { isUnderbarrelMode = false, underbarrelType = nil, modeSource = nil }
    end

    local inMode = Underbarrel.IsWeaponInUnderbarrelMode(weapon)
    return {
        isUnderbarrelMode = inMode,
        underbarrelType   = weapon:getModData()[KEY_WEAPON_TYPE],
        modeSource        = inMode and Underbarrel.MODE_SOURCE_ATTACHMENT or nil,
    }
end

-------------------------------------------------
-- Actions
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

--- Drop a removed part from a stored snapshot's parts list, so a later rebuild does not
--- re-create it. Matches on slot (partType) or exact item type.
local function PruneSnapshotPart(snapshot, removedPart)
    if type(snapshot) ~= "table" or type(snapshot.parts) ~= "table" then return end

    local fullType = removedPart:getFullType()
    local partType = removedPart:getPartType()

    local kept = {}
    for i = 1, #snapshot.parts do
        local saved = snapshot.parts[i]
        local removed = saved and (saved.type == fullType or (partType and saved.partType == partType))
        if not removed then kept[#kept + 1] = saved end
    end
    snapshot.parts = kept
end

--- Called when a weapon part is removed (WeaponUpgradeHooks / ISRailingAction).
---  * weapon is a deployed underbarrel weapon: the part also lives in the stored host
---    snapshot, so drop it there too or toggling back would duplicate it.
---  * weapon is in main mode and the removed part is the underbarrel attachment: drop the
---    stashed underbarrel weapon's retained state and refund its loaded rounds.
function Underbarrel.HandleAttachmentRemoval(weapon, removedPart, player)
    if not weapon or not removedPart then return end

    local modData = weapon:getModData()

    if modData[KEY_MODE] == true then
        PruneSnapshotPart(modData[KEY_HOST_SNAPSHOT], removedPart)
        if player then
            PruneSnapshotPart(player:getModData()[KEY_HOST_SNAPSHOT], removedPart)
        end
        return
    end

    local entry = Underbarrel.UnderbarrelAttachments[removedPart:getFullType()]
    if not entry then return end

    local selfSnapshot = modData[KEY_SELF_SNAPSHOT]
    modData[KEY_SELF_SNAPSHOT] = nil

    if player and type(selfSnapshot) == "table" then
        RefundAmmo(player, entry.type, selfSnapshot.ammo)
    end
end

-------------------------------------------------
-- Load-time reconcile
-------------------------------------------------

--- Called by Init.lua for every ranged weapon at load / equip. A weapon legitimately stays
--- swapped across save/load, so this only re-applies the host model mask (sprite / icon /
--- ModelWeaponPart are not serialised).
function Underbarrel.RestoreOnLoad(weapon)
    if not weapon then return end
    if not Underbarrel.IsWeaponInUnderbarrelMode(weapon) then return end
    ReassertHostAppearance(weapon)
end

--- MP: re-apply the model="host" mask on another player's copy of a swapped-in weapon, from
--- the fields carried by the SWMG "syncWeapon" broadcast (the native weapon packet only
--- reaches the owner, and ModelWeaponPart is never serialised).
function Underbarrel.ApplyRemoteModelMask(weapon, model, hostSprite, hostType)
    if not weapon or model ~= Underbarrel.MODEL_HOST then return end

    local modData            = weapon:getModData()
    modData[KEY_MODE]        = true
    modData[KEY_MODEL]       = model
    modData[KEY_HOST_SPRITE] = hostSprite
    modData[KEY_HOST_TYPE]   = hostType
    ReassertHostAppearance(weapon)
end

local function ContainerHasUnderbarrelWeapon(container)
    if not container then return false end

    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            if instanceof(item, "HandWeapon") and item:getModData()[KEY_MODE] == true then
                return true
            end
            if item.getInventory and item:getInventory()
                and ContainerHasUnderbarrelWeapon(item:getInventory()) then
                return true
            end
        end
    end
    return false
end

--- Safety net: if the player has a pending host snapshot but the swapped-in underbarrel
--- weapon is gone (broke, dropped, destroyed), rebuild the host into their inventory.
function Underbarrel.RecoverLostHost(player)
    if not player then return end
    if isClient() then return end

    local playerModData = player:getModData()
    local snapshot = playerModData[KEY_HOST_SNAPSHOT]
    if type(snapshot) ~= "table" then
        playerModData[KEY_HOST_SNAPSHOT] = nil
        return
    end

    if ContainerHasUnderbarrelWeapon(player:getInventory()) then return end

    local host = RebuildFromSnapshot(snapshot) or (snapshot.type and instanceItem(snapshot.type))
    if host then
        local inventory = player:getInventory()
        inventory:AddItem(host)
        sendAddItemToContainer(inventory, host)
    end
    playerModData[KEY_HOST_SNAPSHOT] = nil
end

-------------------------------------------------
-- StatsFactory layers (e.g. CustomStatsAttachments) list WeaponSprite as a restore stat, so
-- ReapplyAllModifiers resets the sprite to the underbarrel weapon's script default. This
-- handler runs last and puts the host sprite back on a model="host" swapped-in weapon.
-------------------------------------------------
StatsFactory.RegisterRestoreHandler("Underbarrel", function(weapon)
    if not weapon then return end

    local modData = weapon:getModData()
    if modData[KEY_MODE] == true
        and modData[KEY_MODEL] == Underbarrel.MODEL_HOST
        and modData[KEY_HOST_SPRITE]
        and weapon:getWeaponSprite() ~= modData[KEY_HOST_SPRITE] then
        weapon:setWeaponSprite(modData[KEY_HOST_SPRITE])
    end
end)

return Underbarrel
