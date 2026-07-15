local Bayonet = {}
local random = newrandom()

Bayonet.BayonetMountableWeapons = {}
Bayonet.BayonetKnives = {}
Bayonet.MountableWeapons = {}
Bayonet.PendingWeaponRestorations = {}
Bayonet.PendingHotbarRestorations = {}
Bayonet.PendingAttackContexts = {}

-------------------------------------------------
-- Integrated Bayonet Registry
-- weaponFullType -> spearFullType (melee substitute)
-------------------------------------------------
Bayonet.IntegratedBayonets = {}

-------------------------------------------------
-- Exclusives: bayonetAttachmentFullType -> { otherFullType = true, ... }
-- If any registered exclusive is already installed on the weapon,
-- that bayonet attachment cannot be mounted.
-------------------------------------------------
Bayonet.Exclusives = {}

local function IsAuthoritativeConditionContext()
    return not isClient()
end

local function CopyConditionState(targetItem, sourceItem)
    if not targetItem or not sourceItem then return false end

    local previousCondition = targetItem:getCondition()
    targetItem:copyConditionStatesFrom(sourceItem)
    return targetItem:getCondition() ~= previousCondition
end

local function RollConditionLoss(character, targetItem, referenceItem)
    if not targetItem then return false end
    if targetItem:getCondition() <= 0 then return false end

    local ref = referenceItem or targetItem
    local maintenanceMod = character and ref:getMaintenanceMod(character) or 0
    local oneIn = math.max(1, ref:getConditionLowerChance() + maintenanceMod)
    local chance = random:random(oneIn)
    if chance ~= 1 then return false end

    targetItem:setCondition(targetItem:getCondition() - 1)
    return true
end

local function ProcessAttachedBayonetHit(character, weapon)
    if not character or not weapon then return false end
    if Bayonet.HasIntegratedBayonet(weapon) then
        return RollConditionLoss(character, weapon)
    end

    local bayonetPart = Bayonet.GetAttachedBayonetPart(weapon)
    if not bayonetPart then return false end

    local knifeType = Bayonet.GetKnifeTypeFromAttachment(bayonetPart:getFullType())
    local knifeRef = knifeType and instanceItem(knifeType) or nil

    local needsWeaponSync = false
    if RollConditionLoss(character, bayonetPart, knifeRef) then
        needsWeaponSync = true
    end

    if bayonetPart:isBroken() then
        local success, returnedKnife = Bayonet.RemoveBayonet(weapon, character)
        if success then
            needsWeaponSync = true
            if isServer() and returnedKnife then
                sendAddItemToContainer(character:getInventory(), returnedKnife)
            end
        end
    end

    return needsWeaponSync
end

local function PrepareTemporaryBayonetWeapon(tempWeapon, sourceItem)
    if not tempWeapon then return end

    if sourceItem then
        CopyConditionState(tempWeapon, sourceItem)
        return
    end

    tempWeapon:setCondition(tempWeapon:getConditionMax())
    tempWeapon:applyMaxSharpness()
end

local function GetPendingAttackContext(character, tempWeapon)
    local context = Bayonet.PendingAttackContexts[character]
    if not context then return nil end
    if tempWeapon and context.tempWeapon ~= tempWeapon then return nil end
    return context
end

local function ClearPendingAttackContext(character)
    Bayonet.PendingAttackContexts[character] = nil
end

function Bayonet.ProcessMultiplayerHit(character, weapon)
    if not character or not weapon then return false end

    local needsWeaponSync = false
    if ProcessAttachedBayonetHit(character, weapon) then
        needsWeaponSync = true
    end

    if needsWeaponSync then
        syncHandWeaponFields(character, weapon)
    end

    return needsWeaponSync
end

local function ApplyBayonetWeaponWear(character, tempWeapon)
    local context = GetPendingAttackContext(character, tempWeapon)
    if not context or context.weaponWearProcessed then return false end

    context.weaponWearProcessed = true

    if isClient() then
        if instanceof(character, "IsoPlayer") and character:isLocalPlayer() then
            sendClientCommand(character, "SWMG", "bayonetHit", {
                itemId = context.originalWeapon:getID(),
            })
            return true
        end

        return false
    end

    if not IsAuthoritativeConditionContext() then return false end
    if ProcessAttachedBayonetHit(character, context.originalWeapon) then
        context.needsWeaponSync = true
    end

    return context.needsWeaponSync
end

-------------------------------------------------
-- Registration API
-------------------------------------------------

--- Register one or more weapons that can accept a bayonet.
---@param bayonetType string|string[]  the bayonet attachment fullType e.g. "MWA.M9_BAYONET" or { "MWA.M9_BAYONET", "MWA.M5_BAYONET" }
---@param weaponTypes string|string[]  fullType or table of fullTypes e.g. "MWA.M16A2" or { "MWA.M16A2", "MWA.ACR" }
function Bayonet.RegisterMountableWeapon(bayonetType, weaponTypes)
    if not bayonetType or not weaponTypes then return end

    if type(bayonetType) == "table" then
        for _, currentBayonetType in ipairs(bayonetType) do
            if currentBayonetType then
                Bayonet.RegisterMountableWeapon(currentBayonetType, weaponTypes)
            end
        end
        return
    end

    if type(weaponTypes) == "table" then
        for _, weaponType in ipairs(weaponTypes) do
            if weaponType then
                Bayonet.RegisterMountableWeapon(bayonetType, weaponType)
            end
        end
        return
    end

    if not Bayonet.BayonetMountableWeapons[weaponTypes] then
        Bayonet.BayonetMountableWeapons[weaponTypes] = {}
    end
    Bayonet.BayonetMountableWeapons[weaponTypes][bayonetType] = true
end

--- Register a knife item, its bayonet attachment, and the spear substitute used during melee.
---@param knifeType string    fullType of the knife item e.g. "MWA.M9_BAYONET_KNIFE"
---@param bayonetType string  fullType of the bayonet attachment e.g. "MWA.M9_BAYONET"
---@param spearType string    fullType of the spear substitute item e.g. "MWA.M9_BAYONET_SPEAR"
function Bayonet.RegisterBayonetKnife(knifeType, bayonetType, spearType)
    Bayonet.BayonetKnives[knifeType] = { bayonetType = bayonetType, spearType = spearType }
end

--- Register one or more weapon parts as exclusive with a bayonet attachment.
--- If one of the exclusive parts is installed, the bayonet cannot be mounted.
---@param bayonetType string|string[]  e.g. "MWA.M9_BAYONET" or { "MWA.M9_BAYONET", "MWA.M5_BAYONET" }
---@param itemB string|string[]        e.g. "Base.Scope" or { "Base.Scope", "Base.Sling" }
function Bayonet.SetExclusives(bayonetType, itemB)
    if not bayonetType or not itemB then return end

    if type(bayonetType) == "table" then
        for _, currentBayonetType in ipairs(bayonetType) do
            if currentBayonetType then
                Bayonet.SetExclusives(currentBayonetType, itemB)
            end
        end
        return
    end

    if type(itemB) == "table" then
        for _, exclusiveItem in ipairs(itemB) do
            if exclusiveItem then
                Bayonet.SetExclusives(bayonetType, exclusiveItem)
            end
        end
        return
    end

    if not Bayonet.Exclusives[bayonetType] then Bayonet.Exclusives[bayonetType] = {} end

    if not Bayonet.Exclusives[itemB] then Bayonet.Exclusives[itemB] = {} end
    Bayonet.Exclusives[bayonetType][itemB] = true
    Bayonet.Exclusives[itemB][bayonetType] = true
end

--- Register a weapon with an integrated (non-removable) bayonet.
--- @param weaponType string|string[]  fullType or table of fullTypes e.g. "MWA.SKS"
--- @param entry table|string          entry table or plain spearType string (legacy).
---   entry = {
---     weaponRef    = string,                 -- fullType of the melee substitute spear
---     initialState = "folded"|"deployed"?,  -- default: "folded"
---     -- Visual mode (pick ONE):
---     attachments  = { partType = string?, deployed = string, folded = string }?,
---     models       = { deployed = string, folded = string }?,
---   }
function Bayonet.RegisterIntegratedBayonet(weaponType, entry)
    -- normalize legacy plain-string form
    if type(entry) == "string" then
        entry = { weaponRef = entry }
    end
    if type(weaponType) == "table" then
        for _, wt in ipairs(weaponType) do
            Bayonet.IntegratedBayonets[wt] = entry
        end
    else
        Bayonet.IntegratedBayonets[weaponType] = entry
    end
end

-------------------------------------------------
-- Bayonet Attachment/Removal Utilities
-------------------------------------------------

--- Returns the first weapon part that is registered as a bayonet attachment, or nil.
--- @param weapon HandWeapon
--- @return WeaponPart|nil
function Bayonet.GetAttachedBayonetPart(weapon)
    if not weapon then return nil end
    local allParts = weapon:getAllWeaponParts()
    if not allParts then return nil end
    for i = 0, allParts:size() - 1 do
        local part = allParts:get(i)
        if part and Bayonet.GetSpearTypeFromAttachment(part:getFullType()) then
            return part
        end
    end
    return nil
end

--- Check if a bayonet attachment is blocked by an exclusive already installed on the weapon.
---@param weapon HandWeapon
---@param bayonetType string
---@return boolean
function Bayonet.IsBlockedByExclusive(weapon, bayonetType)
    if not weapon or not bayonetType then return false end

    local exclusives = Bayonet.Exclusives[bayonetType]
    if not exclusives then return false end

    local parts = weapon:getAllWeaponParts()
    if not parts then return false end

    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part and exclusives[part:getFullType()] then
            return true
        end
    end

    return false
end

function Bayonet.CanAttachBayonet(weapon, bayonetKnife)
    if not weapon or not bayonetKnife then return false end
    if not instanceof(weapon, "HandWeapon") then return false end
    if not weapon:isRanged() then return false end
    if bayonetKnife:isBroken() then return false end
    if Bayonet.GetAttachedBayonetPart(weapon) then return false end

    local acceptedBayonets = Bayonet.BayonetMountableWeapons[weapon:getFullType()]
    if not acceptedBayonets then return false end

    local knifeEntry = Bayonet.BayonetKnives[bayonetKnife:getFullType()]
    if not knifeEntry then return false end

    if not acceptedBayonets[knifeEntry.bayonetType] then return false end
    if Bayonet.IsBlockedByExclusive(weapon, knifeEntry.bayonetType) then return false end

    return true
end

function Bayonet.CanRemoveBayonet(weapon)
    if not weapon then return false end
    if not instanceof(weapon, "HandWeapon") then return false end
    if not weapon:isRanged() then return false end

    return Bayonet.GetAttachedBayonetPart(weapon) ~= nil
end

function Bayonet.AttachBayonet(weapon, bayonetKnife, player)
    if not Bayonet.CanAttachBayonet(weapon, bayonetKnife) then return false end

    local knifeEntry = Bayonet.BayonetKnives[bayonetKnife:getFullType()]
    local bayonetAttachment = instanceItem(knifeEntry.bayonetType)

    if bayonetAttachment and instanceof(bayonetAttachment, "WeaponPart") then
        CopyConditionState(bayonetAttachment, bayonetKnife)
        weapon:attachWeaponPart(bayonetAttachment, true)
        player:getInventory():Remove(bayonetKnife)
        weapon:getModData().GW_BayonetDeployed = true
        return true
    end

    return false
end

function Bayonet.GetKnifeTypeFromAttachment(attachmentType)
    for knifeType, entry in pairs(Bayonet.BayonetKnives) do
        if entry.bayonetType == attachmentType then
            return knifeType
        end
    end
    return nil
end

function Bayonet.GetSpearTypeFromAttachment(attachmentType)
    for _, entry in pairs(Bayonet.BayonetKnives) do
        if entry.bayonetType == attachmentType then
            return entry.spearType
        end
    end
    return nil
end

function Bayonet.RemoveBayonet(weapon, player)
    if not Bayonet.CanRemoveBayonet(weapon) then return false end

    local bayonetPart = Bayonet.GetAttachedBayonetPart(weapon)
    if not bayonetPart then return false end

    local bayonetKnifeType = Bayonet.GetKnifeTypeFromAttachment(bayonetPart:getFullType())

    weapon:detachWeaponPart(bayonetPart)
    weapon:getModData().GW_BayonetDeployed = false

    local returnedKnife
    if bayonetKnifeType then
        returnedKnife = instanceItem(bayonetKnifeType)
        if returnedKnife then
            CopyConditionState(returnedKnife, bayonetPart)
            player:getInventory():AddItem(returnedKnife)
        end
    end

    return true, returnedKnife
end

-------------------------------------------------
-- Bayonet Attack (Melee with spear substitute)
-------------------------------------------------

function Bayonet.RestoreWeaponAfterBayonet(character, weapon)
    if not character or not weapon then return end

    local attackContext = GetPendingAttackContext(character)
    if attackContext and attackContext.originalWeapon == weapon then
        if attackContext.tempWeapon then
            attackContext.tempWeapon:getModData().MWA_BayonetOriginalWeapon = nil
        end
    end

    character:setPrimaryHandItem(weapon)
    if weapon:isTwoHandWeapon() then
        character:setSecondaryHandItem(weapon)
    end
    character:resetEquippedHandsModels()

    local hotbarInfo = Bayonet.PendingHotbarRestorations[character]
    if hotbarInfo then
        local hotBar = getPlayerHotbar(character:getPlayerNum())
        if hotBar then
            hotBar:attachItem(weapon, hotbarInfo.attachment, hotbarInfo.slotIndex, hotbarInfo.slotDef, false)
            hotBar.needsRefresh = true
            hotBar:update()
        end
        Bayonet.PendingHotbarRestorations[character] = nil
    end

    if IsAuthoritativeConditionContext() and attackContext and attackContext.needsWeaponSync then
        syncHandWeaponFields(character, weapon)
    end

    Bayonet.PendingWeaponRestorations[character] = nil
    ClearPendingAttackContext(character)
end

function Bayonet.BayonetAttack(character, chargeDelta, weapon, callback)
    -- Resolve spear type from integrated registry or attachable part
    local spearType
    local isIntegrated = false
    local bayonetConditionSource
    local integratedEntry = Bayonet.IntegratedBayonets[weapon:getFullType()]
    if integratedEntry then
        spearType = integratedEntry.weaponRef
        isIntegrated = true
    else
        local bayonetPart = Bayonet.GetAttachedBayonetPart(weapon)
        if bayonetPart then
            spearType = Bayonet.GetSpearTypeFromAttachment(bayonetPart:getFullType())
            bayonetConditionSource = bayonetPart
        end
    end
    if not spearType then return end

    local bayonetTempWeapon = weapon:getModData().GW_CachedBayonetSpear
    if not bayonetTempWeapon then
        bayonetTempWeapon = instanceItem(spearType)
        if not bayonetTempWeapon then return end
        weapon:getModData().GW_CachedBayonetSpear = bayonetTempWeapon
    end

    PrepareTemporaryBayonetWeapon(bayonetTempWeapon, bayonetConditionSource)
    bayonetTempWeapon:setWeaponSprite(weapon:getWeaponSprite())
    bayonetTempWeapon:setIcon(weapon:getIcon())
    bayonetTempWeapon:setBloodLevel(weapon:getBloodLevel())
    bayonetTempWeapon:getModData().MWA_BayonetOriginalWeapon = weapon

    local modelParts = weapon:getModelWeaponPart()
    if modelParts then
        bayonetTempWeapon:setModelWeaponPart(modelParts)
    end

    local parts = weapon:getAllWeaponParts()
    if parts then
        for i = 0, parts:size() - 1 do
            local part = parts:get(i)
            if part then
                local partCopy = instanceItem(part:getFullType())
                if partCopy and instanceof(partCopy, "WeaponPart") then
                    bayonetTempWeapon:attachWeaponPart(partCopy, true)
                end
            end
        end
    end

    local hotBar = getPlayerHotbar(character:getPlayerNum())
    if hotBar and hotBar:isInHotbar(weapon) then
        local itemSlot = weapon:getAttachedSlot()
        local slotDef = hotBar.availableSlot[itemSlot].def
        local attachment = slotDef.attachments[weapon:getAttachmentType()]

        hotBar:removeItem(weapon, false)
        hotBar.needsRefresh = true
        hotBar:update()

        Bayonet.PendingHotbarRestorations[character] = {
            slotIndex = itemSlot,
            slotDef = slotDef,
            attachment = attachment
        }
    end

    local wasDoingShove = character:isDoShove()

    character:setPrimaryHandItem(bayonetTempWeapon)
    character:setSecondaryHandItem(bayonetTempWeapon)
    character:resetEquippedHandsModels()

    if wasDoingShove then
        character:setDoShove(false)
    end

    Bayonet.PendingWeaponRestorations[character] = weapon
    Bayonet.PendingAttackContexts[character] = {
        originalWeapon = weapon,
        tempWeapon = bayonetTempWeapon,
        isIntegrated = isIntegrated,
        weaponWearProcessed = false,
        needsWeaponSync = false,
    }
    callback(character, chargeDelta, bayonetTempWeapon)
end

-------------------------------------------------
-- Integrated Bayonet Helpers
-------------------------------------------------

--- Check if a weapon has an integrated bayonet registered.
--- @param weapon HandWeapon
--- @return boolean
function Bayonet.HasIntegratedBayonet(weapon)
    if not weapon then return false end
    return Bayonet.IntegratedBayonets[weapon:getFullType()] ~= nil
end

--- Check if the bayonet (integrated or attachable) is currently deployed.
--- @param weapon HandWeapon
--- @return boolean
function Bayonet.IsBayonetDeployed(weapon)
    if not weapon then return false end
    return weapon:getModData().GW_BayonetDeployed == true
end

--- @deprecated Use Bayonet.IsBayonetDeployed instead.
Bayonet.IsIntegratedBayonetDeployed = Bayonet.IsBayonetDeployed

--- Swap the integrated bayonet visual to match the current deployed/folded state.
--- @param weapon HandWeapon
function Bayonet.SwapIntegratedBayonetVisual(weapon)
    if not weapon then return end
    local entry = Bayonet.IntegratedBayonets[weapon:getFullType()]
    if not entry then return end

    local deployed = Bayonet.IsBayonetDeployed(weapon)

    if entry.attachments then
        local att = entry.attachments
        local partType = att.partType or "Bayonet"
        local itemType = deployed and att.deployed or att.folded
        if itemType then
            local currentPart = weapon:getWeaponPart(partType)
            if currentPart then
                weapon:detachWeaponPart(currentPart)
            end
            local newPart = instanceItem(itemType)
            if newPart and instanceof(newPart, "WeaponPart") then
                weapon:attachWeaponPart(newPart, true)
            end
        end
    elseif entry.models then
        local newSprite = deployed and entry.models.deployed or entry.models.folded
        if newSprite then
            weapon:setWeaponSprite(newSprite)
        end
    end
end

--- Toggle the integrated bayonet between deployed and folded.
--- @param weapon HandWeapon
function Bayonet.ToggleIntegratedBayonet(weapon)
    if not weapon then return end
    if not Bayonet.HasIntegratedBayonet(weapon) then return end
    weapon:getModData().GW_BayonetDeployed = not Bayonet.IsBayonetDeployed(weapon)
    Bayonet.SwapIntegratedBayonetVisual(weapon)
end

--- Restore the integrated bayonet visual state on load/equip.
--- If no state has been saved yet, defaults to the entry's initialState (or "folded").
--- @param weapon HandWeapon
function Bayonet.RestoreIntegratedBayonetState(weapon)
    if not weapon then return end
    if not Bayonet.HasIntegratedBayonet(weapon) then return end
    local entry = Bayonet.IntegratedBayonets[weapon:getFullType()]
    local md = weapon:getModData()
    if md.GW_BayonetDeployed == nil then
        local initial = entry and entry.initialState or "folded"
        md.GW_BayonetDeployed = (initial == "deployed")
    end
    Bayonet.SwapIntegratedBayonetVisual(weapon)
end

Events.OnWeaponHitTree.Add(function(character, weapon)
    ApplyBayonetWeaponWear(character, weapon)
end)

Events.OnWeaponHitCharacter.Add(function(character, target, weapon)
    ApplyBayonetWeaponWear(character, weapon)
end)

Events.OnHitZombie.Add(function(zombie, character, bodyPart, weapon)
    ApplyBayonetWeaponWear(character, weapon)
end)

Events.OnPlayerUpdate.Add(function(playerObj)
    if not playerObj then return end

    local primaryHand = playerObj:getPrimaryHandItem()

    if primaryHand then
        local originalWeapon = primaryHand:getModData().MWA_BayonetOriginalWeapon
        if originalWeapon then
            if not playerObj:isAttacking() and not playerObj:isAttackStarted() then
                Bayonet.RestoreWeaponAfterBayonet(playerObj, originalWeapon)
                Bayonet.PendingWeaponRestorations[playerObj] = nil
            end
        end
    end

    local weaponToRestore = Bayonet.PendingWeaponRestorations[playerObj]
    if weaponToRestore then
        if not playerObj:isAttacking() and not playerObj:isAttackStarted() then
            Bayonet.RestoreWeaponAfterBayonet(playerObj, weaponToRestore)
        end
    end
end)

return Bayonet
