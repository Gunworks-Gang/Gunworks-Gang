local SWMG_Bayonet = {}

SWMG_Bayonet.BayonetMauntableWeapons = {
    ["MWA.M16A1"] = "MWA.M9_BAYONET",
}

SWMG_Bayonet.BayonetKnives = {
    ["MWA.M9_BAYONET_KNIFE"] = "MWA.M9_BAYONET",
}

SWMG_Bayonet.MountableWeapons = {}
SWMG_Bayonet.PendingWeaponRestorations = {}
SWMG_Bayonet.PendingHotbarRestorations = {}
-------------------------------------------------
-- Bayonet Attachment/Removal Utilities
-------------------------------------------------

function SWMG_Bayonet.CanAttachBayonet(weapon, bayonetKnife)
    if not weapon or not bayonetKnife then return false end
    if not instanceof(weapon, "HandWeapon") then return false end
    if not weapon:isRanged() then return false end
    if weapon:getWeaponPart("Bayonet") then return false end

    local weaponBayonetType = SWMG_Bayonet.BayonetMauntableWeapons[weapon:getFullType()]
    if not weaponBayonetType then return false end

    local knifeBayonetType = SWMG_Bayonet.BayonetKnives[bayonetKnife:getFullType()]
    if not knifeBayonetType then return false end

    if weaponBayonetType ~= knifeBayonetType then return false end

    return true
end

function SWMG_Bayonet.CanRemoveBayonet(weapon)
    if not weapon then return false end
    if not instanceof(weapon, "HandWeapon") then return false end
    if not weapon:isRanged() then return false end

    return weapon:getWeaponPart("Bayonet") ~= nil
end

function SWMG_Bayonet.AttachBayonet(weapon, bayonetKnife, player)
    if not SWMG_Bayonet.CanAttachBayonet(weapon, bayonetKnife) then return false end

    local bayonetAttachmentType = SWMG_Bayonet.BayonetKnives[bayonetKnife:getFullType()]
    local bayonetAttachment = instanceItem(bayonetAttachmentType)

    if bayonetAttachment and instanceof(bayonetAttachment, "WeaponPart") then
        weapon:attachWeaponPart(bayonetAttachment, true)
        player:getInventory():Remove(bayonetKnife)
        return true
    end

    return false
end

function SWMG_Bayonet.GetKnifeTypeFromAttachment(attachmentType)
    for knifeType, bayonetType in pairs(SWMG_Bayonet.BayonetKnives) do
        if bayonetType == attachmentType then
            return knifeType
        end
    end
    return nil
end

function SWMG_Bayonet.RemoveBayonet(weapon, player)
    if not SWMG_Bayonet.CanRemoveBayonet(weapon) then return false end

    local bayonetPart = weapon:getWeaponPart("Bayonet")
    if not bayonetPart then return false end

    local bayonetKnifeType = SWMG_Bayonet.GetKnifeTypeFromAttachment(bayonetPart:getFullType())

    weapon:detachWeaponPart(bayonetPart)

    if bayonetKnifeType then
        local bayonetKnife = instanceItem(bayonetKnifeType)
        if bayonetKnife then
            player:getInventory():AddItem(bayonetKnife)
        end
    end

    return true
end

-------------------------------------------------
-- Bayonet Attack (Melee with spear substitute)
-------------------------------------------------

function SWMG_Bayonet.RestoreWeaponAfterBayonet(character, weapon)
    if not character or not weapon then return end

    character:setPrimaryHandItem(weapon)
    if weapon:isTwoHandWeapon() then
        character:setSecondaryHandItem(weapon)
    end
    character:resetEquippedHandsModels()

    local hotbarInfo = SWMG_Bayonet.PendingHotbarRestorations[character]
    if hotbarInfo then
        local hotBar = getPlayerHotbar(character:getPlayerNum())
        if hotBar then
            hotBar:attachItem(weapon, hotbarInfo.attachment, hotbarInfo.slotIndex, hotbarInfo.slotDef, false)
            hotBar.needsRefresh = true
            hotBar:update()
        end
        SWMG_Bayonet.PendingHotbarRestorations[character] = nil
    end

    SWMG_Bayonet.PendingWeaponRestorations[character] = nil
end

function SWMG_Bayonet.BayonetAttack(character, chargeDelta, weapon, callback)
    local bayonet = weapon:getWeaponPart("Bayonet"):getFullType()
    local bayonetTempWeapon = instanceItem(bayonet .. "_SPEAR")
    if not bayonetTempWeapon then return end

    bayonetTempWeapon:setWeaponSprite(weapon:getWeaponSprite())
    bayonetTempWeapon:setIcon(weapon:getIcon())
    bayonetTempWeapon:getModData().MWA_BayonetOriginalWeapon = weapon

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

        SWMG_Bayonet.PendingHotbarRestorations[character] = {
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

    SWMG_Bayonet.PendingWeaponRestorations[character] = weapon
    callback(character, chargeDelta, bayonetTempWeapon)
end

Events.OnPlayerUpdate.Add(function(playerObj)
    if not playerObj then return end

    local primaryHand = playerObj:getPrimaryHandItem()

    if primaryHand then
        local originalWeapon = primaryHand:getModData().MWA_BayonetOriginalWeapon
        if originalWeapon then
            if not playerObj:isAttacking() and not playerObj:isAttackStarted() then
                SWMG_Bayonet.RestoreWeaponAfterBayonet(playerObj, originalWeapon)
                SWMG_Bayonet.PendingWeaponRestorations[playerObj] = nil
            end
        end
    end

    local weaponToRestore = SWMG_Bayonet.PendingWeaponRestorations[playerObj]
    if weaponToRestore then
        if not playerObj:isAttacking() and not playerObj:isAttackStarted() then
            SWMG_Bayonet.RestoreWeaponAfterBayonet(playerObj, weaponToRestore)
        end
    end
end)

return SWMG_Bayonet
