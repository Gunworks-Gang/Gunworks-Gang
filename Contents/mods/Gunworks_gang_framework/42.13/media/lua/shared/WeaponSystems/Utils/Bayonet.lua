local Bayonet = {}

Bayonet.BayonetMountableWeapons = {}
Bayonet.BayonetKnives = {}
Bayonet.MountableWeapons = {}
Bayonet.PendingWeaponRestorations = {}
Bayonet.PendingHotbarRestorations = {}

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

-------------------------------------------------
-- Registration API
-------------------------------------------------

--- Register one or more weapons that can accept a bayonet.
---@param weaponTypes string|string[]  fullType or table of fullTypes e.g. {"MWA.M16A2", "MWA.ACR"}
---@param bayonetType string           the bayonet attachment fullType e.g. "MWA.M9_BAYONET"
function Bayonet.RegisterMountableWeapon(weaponTypes, bayonetType)
    if type(weaponTypes) == "table" then
        for _, weaponType in ipairs(weaponTypes) do
            if not Bayonet.BayonetMountableWeapons[weaponType] then
                Bayonet.BayonetMountableWeapons[weaponType] = {}
            end
            Bayonet.BayonetMountableWeapons[weaponType][bayonetType] = true
        end
    else
        if not Bayonet.BayonetMountableWeapons[weaponTypes] then
            Bayonet.BayonetMountableWeapons[weaponTypes] = {}
        end
        Bayonet.BayonetMountableWeapons[weaponTypes][bayonetType] = true
    end
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
---@param bayonetType string           e.g. "MWA.M9_BAYONET"
---@param itemB string|string[]        e.g. "Base.Scope" or { "Base.Scope", "Base.Sling" }
function Bayonet.SetExclusives(bayonetType, itemB)
    if not bayonetType or not itemB then return end

    if not Bayonet.Exclusives[bayonetType] then Bayonet.Exclusives[bayonetType] = {} end

    local itemsB = {}
    if type(itemB) == "table" then
        for _, exclusiveItem in ipairs(itemB) do
            table.insert(itemsB, exclusiveItem)
        end
    else
        table.insert(itemsB, itemB)
    end

    for _, exclusiveItem in ipairs(itemsB) do
        if exclusiveItem then
            if not Bayonet.Exclusives[exclusiveItem] then Bayonet.Exclusives[exclusiveItem] = {} end
            Bayonet.Exclusives[bayonetType][exclusiveItem] = true
            Bayonet.Exclusives[exclusiveItem][bayonetType] = true
        end
    end
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

    Bayonet.PendingWeaponRestorations[character] = nil
end

function Bayonet.BayonetAttack(character, chargeDelta, weapon, callback)
    -- Resolve spear type from integrated registry or attachable part
    local spearType
    local integratedEntry = Bayonet.IntegratedBayonets[weapon:getFullType()]
    if integratedEntry then
        spearType = integratedEntry.weaponRef
    else
        local bayonetPart = Bayonet.GetAttachedBayonetPart(weapon)
        if bayonetPart then
            spearType = Bayonet.GetSpearTypeFromAttachment(bayonetPart:getFullType())
        end
    end
    if not spearType then return end

    local bayonetTempWeapon = weapon:getModData().GW_CachedBayonetSpear
    if not bayonetTempWeapon then
        bayonetTempWeapon = instanceItem(spearType)
        if not bayonetTempWeapon then return end
        weapon:getModData().GW_CachedBayonetSpear = bayonetTempWeapon
    end

    bayonetTempWeapon:setWeaponSprite(weapon:getWeaponSprite())
    bayonetTempWeapon:setIcon(weapon:getIcon())
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
