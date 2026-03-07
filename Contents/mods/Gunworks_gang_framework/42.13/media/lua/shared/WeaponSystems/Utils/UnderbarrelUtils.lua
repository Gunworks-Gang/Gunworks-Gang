local Underbarrel = {}

Underbarrel.UnderbarrelAttachments = {}
Underbarrel.PendingWeaponRestorations = {}
Underbarrel.PendingHotbarRestorations = {}

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

-------------------------------------------------
-- Swap Utilities
-------------------------------------------------

function Underbarrel.CanSwapToUnderbarrel(weapon)
    if not weapon then return false end
    if not instanceof(weapon, "HandWeapon") then return false end
    if not weapon:isRanged() then return false end

    local attachment = weapon:getWeaponPart("Underbarrel")
    if not attachment then return false end

    return Underbarrel.UnderbarrelAttachments[attachment:getFullType()] ~= nil
end

function Underbarrel.IsUsingUnderbarrel(player)
    if not player then return false end
    local primaryHand = player:getPrimaryHandItem()
    if not primaryHand then return false end
    return primaryHand:getModData().GW_UnderbarrelOriginalWeapon ~= nil
end

function Underbarrel.SwapToUnderbarrel(weapon, player)
    if not weapon or not player then return end
    if not Underbarrel.CanSwapToUnderbarrel(weapon) then return end

    local attachment = weapon:getWeaponPart("Underbarrel")
    local underbarrelType = Underbarrel.UnderbarrelAttachments[attachment:getFullType()]

    local underbarrelWeapon = weapon:getModData().GW_CachedUnderbarrelWeapon
    if not underbarrelWeapon then
        underbarrelWeapon = instanceItem(underbarrelType)
        if not underbarrelWeapon then return end
        weapon:getModData().GW_CachedUnderbarrelWeapon = underbarrelWeapon

        local ammo = weapon:getModData().GW_UnderbarrelAmmo
        if ammo then
            underbarrelWeapon:setCurrentAmmoCount(ammo)
        end

        local chambered = weapon:getModData().GW_UnderbarrelChambered
        if chambered then
            underbarrelWeapon:setRoundChambered(chambered)
        end
    end

    underbarrelWeapon:setWeaponSprite(weapon:getWeaponSprite())
    underbarrelWeapon:setIcon(weapon:getIcon())
    underbarrelWeapon:getModData().GW_UnderbarrelOriginalWeapon = weapon

    local modelParts = weapon:getModelWeaponPart()
    if modelParts then
        underbarrelWeapon:setModelWeaponPart(modelParts)
    end

    local parts = weapon:getAllWeaponParts()
    if parts then
        for i = 0, parts:size() - 1 do
            local part = parts:get(i)
            if part then
                local partCopy = instanceItem(part:getFullType())
                if partCopy and instanceof(partCopy, "WeaponPart") then
                    underbarrelWeapon:attachWeaponPart(partCopy, true)
                end
            end
        end
    end

    local hotBar = getPlayerHotbar(player:getPlayerNum())
    if hotBar and hotBar:isInHotbar(weapon) then
        local itemSlot = weapon:getAttachedSlot()
        local slotDef = hotBar.availableSlot[itemSlot].def
        local attachmentSlot = slotDef.attachments[weapon:getAttachmentType()]

        hotBar:removeItem(weapon, false)
        hotBar.needsRefresh = true
        hotBar:update()

        Underbarrel.PendingHotbarRestorations[player] = {
            slotIndex = itemSlot,
            slotDef = slotDef,
            attachment = attachmentSlot
        }
    end

    player:setPrimaryHandItem(underbarrelWeapon)
    if underbarrelWeapon:isTwoHandWeapon() then
        player:setSecondaryHandItem(underbarrelWeapon)
    end
    player:resetEquippedHandsModels()

    Underbarrel.PendingWeaponRestorations[player] = weapon
end

function Underbarrel.RestoreOriginalWeapon(player)
    if not player then return end

    local weapon = Underbarrel.PendingWeaponRestorations[player]
    if not weapon then
        local primaryHand = player:getPrimaryHandItem()
        if primaryHand then
            weapon = primaryHand:getModData().GW_UnderbarrelOriginalWeapon
        end
    end
    if not weapon then return end

    local underbarrelWeapon = player:getPrimaryHandItem()
    if underbarrelWeapon then
        weapon:getModData().GW_UnderbarrelAmmo = underbarrelWeapon:getCurrentAmmoCount()
        weapon:getModData().GW_UnderbarrelChambered = underbarrelWeapon:isRoundChambered()
    end

    player:setPrimaryHandItem(weapon)
    if weapon:isTwoHandWeapon() then
        player:setSecondaryHandItem(weapon)
    end
    player:resetEquippedHandsModels()

    local hotbarInfo = Underbarrel.PendingHotbarRestorations[player]
    if hotbarInfo then
        local hotBar = getPlayerHotbar(player:getPlayerNum())
        if hotBar then
            hotBar:attachItem(weapon, hotbarInfo.attachment, hotbarInfo.slotIndex, hotbarInfo.slotDef, false)
            hotBar.needsRefresh = true
            hotBar:update()
        end
        Underbarrel.PendingHotbarRestorations[player] = nil
    end

    Underbarrel.PendingWeaponRestorations[player] = nil
end

-------------------------------------------------
-- Key Bindings
-------------------------------------------------
local function DisplayMessage(character, messageKey)
    character:Say(getText(messageKey), 0.55, 0.55, 0.55, UIFont.Dialogue, 0, "default")
end

local function onKeyPressed(key)
    local player = getSpecificPlayer(0)
    if not player then return end

    if key == Keyboard.KEY_U then
        if not Underbarrel.IsUsingUnderbarrel(player) then
            local primaryHand = player:getPrimaryHandItem()
            if primaryHand then
                Underbarrel.SwapToUnderbarrel(primaryHand, player)
                DisplayMessage(player, "Using underbarrel weapon")
            end
        end
    elseif key == Keyboard.KEY_Y then
        if Underbarrel.IsUsingUnderbarrel(player) then
            Underbarrel.RestoreOriginalWeapon(player)
            DisplayMessage(player, "Using main weapon")
        end
    end
end

Events.OnKeyPressed.Add(onKeyPressed)

return Underbarrel
