require "ISUI/ISInventoryPaneContextMenu"
require "MWA_FoldStock"
require "MWA_FoldBipod"
require "MWA_BayonetAttachment"

-------------------------------------------------
-- Foldable Stock Context Menu
-------------------------------------------------
local function addFoldableStockOption(playerObj, item, context)
    if not MWA_Utils then return end
    if not instanceof(item, "HandWeapon") then return end
    if not item:isRanged() then return end
    if not MWA_Utils.HasFoldableStock(item) then return end

    local isInInventory = item:getContainer() == playerObj:getInventory()
    local isFolded = MWA_Utils.IsStockFolded(item)

    local actionString
    if isFolded then
        actionString = getText("IGUI_MWA_UnfoldStock")
    else
        actionString = getText("IGUI_MWA_FoldStock")
    end

    local listEntry = context:addOption(actionString, playerObj, MWA_FoldStockContext.callAction, item)

    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip:setName(actionString)
    tooltip.texture = item:getTex()

    if isInInventory then
        if isFolded then
            tooltip.description = getText("IGUI_MWA_UnfoldStockDesc")
        else
            tooltip.description = getText("IGUI_MWA_FoldStockDesc")
        end
    else
        listEntry.notAvailable = true
        tooltip.description = getText("IGUI_MWA_MoveToInventory")
    end

    listEntry.toolTip = tooltip
end

-------------------------------------------------
-- Foldable Bipod Context Menu
-------------------------------------------------
local function addFoldableBipodOption(playerObj, item, context)
    if not MWA_Utils then return end
    if not instanceof(item, "HandWeapon") then return end
    if not item:isRanged() then return end
    if not MWA_Utils.HasFoldableBipod(item) then return end

    local isInInventory = item:getContainer() == playerObj:getInventory()
    local isDeployed = MWA_Utils.IsBipodDeployed(item)

    local actionString
    if isDeployed then
        actionString = getText("IGUI_MWA_FoldBipod")
    else
        actionString = getText("IGUI_MWA_DeployBipod")
    end

    local listEntry = context:addOption(actionString, playerObj, MWA_FoldBipodContext.callAction, item)

    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip:setName(actionString)
    tooltip.texture = item:getTex()

    if isInInventory then
        if isDeployed then
            tooltip.description = getText("IGUI_MWA_FoldBipodDesc")
        else
            tooltip.description = getText("IGUI_MWA_DeployBipodDesc")
        end
    else
        listEntry.notAvailable = true
        tooltip.description = getText("IGUI_MWA_MoveToInventory")
    end

    listEntry.toolTip = tooltip
end

-------------------------------------------------
-- Bayonet Attachment Context Menu
-------------------------------------------------
local function addBayonetAttachmentOption(playerObj, item, context)
    if not MWA_Utils then return end
    if not instanceof(item, "HandWeapon") then return end
    if not item:isRanged() then return end

    local isInInventory = item:getContainer() == playerObj:getInventory()

    if MWA_Utils.CanRemoveBayonet(item) then
        local actionString = getText("IGUI_MWA_RemoveBayonet")
        local listEntry = context:addOption(actionString, playerObj, MWA_BayonetAttachmentContext.removeBayonet, item)

        local tooltip = ISInventoryPaneContextMenu.addToolTip()
        tooltip:setName(actionString)
        tooltip.texture = item:getTex()

        if isInInventory then
            tooltip.description = getText("IGUI_MWA_RemoveBayonetDesc")
        else
            listEntry.notAvailable = true
            tooltip.description = getText("IGUI_MWA_MoveToInventory")
        end

        listEntry.toolTip = tooltip
    else
        local inventory = playerObj:getInventory():getItems()
        for i = 0, inventory:size() - 1 do
            local invItem = inventory:get(i)
            if invItem:getModData().BayonetAttachment and MWA_Utils.CanAttachBayonet(item, invItem) then
                local actionString = getText("IGUI_MWA_AttachBayonet")
                local listEntry = context:addOption(actionString, playerObj, MWA_BayonetAttachmentContext.attachBayonet, item, invItem)

                local tooltip = ISInventoryPaneContextMenu.addToolTip()
                tooltip:setName(actionString)
                tooltip.texture = item:getTex()

                if isInInventory then
                    tooltip.description = getText("IGUI_MWA_AttachBayonetDesc")
                else
                    listEntry.notAvailable = true
                    tooltip.description = getText("IGUI_MWA_MoveToInventory")
                end

                listEntry.toolTip = tooltip
                break
            end
        end
    end
end

local MWA_onFillInventoryObjectContextMenu = function(playerid, context, items)
    local player = getSpecificPlayer(playerid)
    for _, v in ipairs(items) do
        local item = v
        if not instanceof(v, "InventoryItem") then
            item = v.items[1]
        end
        if instanceof(item, "HandWeapon") then
            addFoldableStockOption(player, item, context)
            addFoldableBipodOption(player, item, context)
            addBayonetAttachmentOption(player, item, context)
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(MWA_onFillInventoryObjectContextMenu)

-------------------------------------------------
-- Original Magazine Profile Menu Overrides
-------------------------------------------------
local ISInventoryPaneContextMenu_doReloadMenuForMagazine_Original = ISInventoryPaneContextMenu.doReloadMenuForMagazine
ISInventoryPaneContextMenu.doReloadMenuForMagazine = function(playerObj, magazine, context)
    local magType = magazine:getFullType()
    local weapons = playerObj:getInventory():getItemsFromCategory("Weapon")
    local handledByProfile = false

    for i = 1, weapons:size() do
        local weapon = weapons:get(i - 1)
        if not weapon:isContainsClip() then
            local profileName = weapon:getModData().MagazineProfile
            if profileName and MWA_Utils.MagazineProfileList[profileName] then
                if MWA_Utils.isMagazineInProfile(magType, MWA_Utils.MagazineProfileList[profileName]) then
                    local insertOption = context:addOption(getText("ContextMenu_InsertMagazine"), playerObj,
                        ISInventoryPaneContextMenu.onInsertMagazine, weapon, magazine)
                    local tooltip = ISInventoryPaneContextMenu.addToolTip()
                    tooltip.description = getText("ContextMenu_GunType") .. ": " .. getText(weapon:getDisplayName())
                    insertOption.toolTip = tooltip
                    handledByProfile = true
                end
            end
        end
    end

    if not handledByProfile then
        ISInventoryPaneContextMenu_doReloadMenuForMagazine_Original(playerObj, magazine, context)
    end
end

local ISInventoryPaneContextMenu_doMagazineMenu_Original = ISInventoryPaneContextMenu.doMagazineMenu
ISInventoryPaneContextMenu.doMagazineMenu = function(playerObj, magazine, context)
    if magazine:getModData().AmmoProfile then
        if magazine:getCurrentAmmoCount() < magazine:getMaxAmmo() then
            local typeList = MWA_Utils.AmmoProfilesList[magazine:getModData().AmmoProfile]
            for _, typeName in ipairs(typeList) do
                local itemKey = typeName;
                local bulletName = getScriptManager():FindItem(itemKey):getDisplayName();
                local ammoCount = playerObj:getInventory():getItemCountRecurse(itemKey);
                if ammoCount > magazine:getMaxAmmo() then
                    ammoCount = magazine:getMaxAmmo();
                end
                if ammoCount > magazine:getMaxAmmo() - magazine:getCurrentAmmoCount() then
                    ammoCount = magazine:getMaxAmmo() - magazine:getCurrentAmmoCount();
                end
                if ammoCount == 0 then
                    local option = context:addOption(getText("ContextMenu_NoBullets", ammoCount));
                    option.notAvailable = true;
                else
                    context:addOption(getText("IGUI_ContextMenu_InsertAltBulletsInMagazine", ammoCount, bulletName),
                        playerObj,
                        ISInventoryPaneContextMenu.onLoadBulletsInMagazineFromDiffAmmoType, magazine, ammoCount, itemKey);
                end
            end
        end

        if magazine:getCurrentAmmoCount() > 0 then
            context:addOption(getText("ContextMenu_UnloadMagazine"), playerObj,
                ISInventoryPaneContextMenu.onUnloadBulletsFromMagazine, magazine);
        end
    else
        ISInventoryPaneContextMenu_doMagazineMenu_Original(playerObj, magazine, context)
    end
end

ISInventoryPaneContextMenu.onLoadBulletsInMagazineFromDiffAmmoType = function(playerObj, magazine, ammoCount, itemKey)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, magazine)
    local items = playerObj:getInventory():getSomeTypeRecurse(itemKey, ammoCount)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, items)
    MWA_Utils.MagazineAmmoProfileSetter(magazine, itemKey)
    if ammoCount > 0 then
        ISTimedActionQueue.add(ISLoadBulletsInMagazine:new(playerObj, magazine, ammoCount))
    end
end

local ISInventoryPaneContextMenu_doBulletMenu_Original = ISInventoryPaneContextMenu.doBulletMenu
ISInventoryPaneContextMenu.doBulletMenu = function(playerObj, weapon, context)
    if weapon:getModData().AmmoProfile then
        local typeList = MWA_Utils.AmmoProfilesList[weapon:getModData().AmmoProfile]
        for _, typeName in ipairs(typeList) do
            local itemKey = typeName;
            local bulletAvail = playerObj:getInventory():getItemCountRecurse(itemKey);
            local bulletNeeded = weapon:getMaxAmmo() - weapon:getCurrentAmmoCount();
            local bulletName = getScriptManager():FindItem(itemKey):getDisplayName();
            if bulletNeeded > bulletAvail then
                bulletNeeded = bulletAvail;
            end
            local insertOption = context:addOption(
                getText("ContextMenu_InsertBullets", bulletNeeded, bulletName, weapon:getDisplayName()), playerObj,
                ISInventoryPaneContextMenu.onLoadBulletsIntoFirearmFromDiffAmmoType, weapon, itemKey);
            if bulletNeeded <= 0 then
                insertOption.notAvailable = true;
            end

            if weapon:getCurrentAmmoCount() > 0 then
                context:addOption(getText("ContextMenu_UnloadRounds", weapon:getDisplayName()), playerObj,
                    ISInventoryPaneContextMenu.onUnloadBulletsFromFirearm, weapon);
            end
        end
    else
        ISInventoryPaneContextMenu_doBulletMenu_Original(playerObj, weapon, context)
    end
end

ISInventoryPaneContextMenu.onLoadBulletsIntoFirearmFromDiffAmmoType = function(playerObj, weapon, itemKey)
    ISInventoryPaneContextMenu.transferBullets(playerObj, itemKey, weapon:getCurrentAmmoCount(), weapon:getMaxAmmo())
    ISInventoryPaneContextMenu.equipWeapon(weapon, true, false, playerObj:getPlayerNum())
    MWA_Utils.AmmoProfileSetter(weapon, itemKey)
    ISTimedActionQueue.add(ISReloadWeaponAction:new(playerObj, weapon));
end

-- local ISInventoryPaneContextMenu_doReloadMenuForBullets_Original = ISInventoryPaneContextMenu.doReloadMenuForBullets
-- ISInventoryPaneContextMenu.doReloadMenuForBullets = function(playerObj, bullet, context)
--     local bulletType = bullet:getFullType()

--     for i = 0, playerObj:getInventory():getItems():size() - 1 do
--         local item = playerObj:getInventory():getItems():get(i)
--         local ammoType = item:getAmmoType()
--         if ammoType then
--             local baseAmmoKey = ammoType:getItemKey()

--             if not instanceof(item, "HandWeapon") then
--                 local ammoProfile = item:getModData().AmmoProfile
--                 if ammoProfile and MWA_Utils.AmmoProfilesList[ammoProfile] then
--                     if bulletType ~= baseAmmoKey and MWA_Utils.isAmmoInProfile(bulletType, MWA_Utils.AmmoProfilesList[ammoProfile]) then
--                         if item:getCurrentAmmoCount() < item:getMaxAmmo() then
--                             local bulletName = bullet:getDisplayName()
--                             local ammoCount = playerObj:getInventory():getItemCountRecurse(bulletType)
--                             if ammoCount > item:getMaxAmmo() then
--                                 ammoCount = item:getMaxAmmo()
--                             end
--                             if ammoCount > item:getMaxAmmo() - item:getCurrentAmmoCount() then
--                                 ammoCount = item:getMaxAmmo() - item:getCurrentAmmoCount()
--                             end
--                             local insertOption = context:addOption(
--                                 getText("IGUI_ContextMenu_InsertAltBulletsInMagazine", ammoCount, bulletName),
--                                 playerObj,
--                                 ISInventoryPaneContextMenu.onLoadBulletsInMagazineFromDiffAmmoType, item, ammoCount,
--                                 bulletType)
--                             local tooltip = ISInventoryPaneContextMenu.addToolTip()
--                             tooltip.description =
--                                 (getText("ContextMenu_Magazine") .. ": " .. getText(item:getDisplayName()) .. "\n" ..
--                                     getText("ContextMenu_GunType") .. ": " .. getText(getItemDisplayName(item:getGunType())) .. "\n" ..
--                                     getText("Tooltip_weapon_AmmoCount") .. ": " .. item:getCurrentAmmoCount() .. "/" .. item:getMaxAmmo())
--                             insertOption.toolTip = tooltip
--                         end
--                     end
--                 end
--             elseif instanceof(item, "HandWeapon") and not item:getMagazineType() then
--                 local ammoProfile = item:getModData().AmmoProfile
--                 if ammoProfile and MWA_Utils.AmmoProfilesList[ammoProfile] then
--                     if bulletType ~= baseAmmoKey and MWA_Utils.isAmmoInProfile(bulletType, MWA_Utils.AmmoProfilesList[ammoProfile]) then
--                         local bulletAvail = playerObj:getInventory():getItemCountRecurse(bulletType)
--                         local bulletNeeded = item:getMaxAmmo() - item:getCurrentAmmoCount()
--                         local bulletName = bullet:getDisplayName()
--                         if bulletNeeded > bulletAvail then
--                             bulletNeeded = bulletAvail
--                         end
--                         local insertOption = context:addOption(
--                             getText("ContextMenu_InsertBullets", bulletNeeded, bulletName, item:getDisplayName()),
--                             playerObj,
--                             ISInventoryPaneContextMenu.onLoadBulletsIntoFirearmFromDiffAmmoType, item, bulletType)
--                         if bulletNeeded <= 0 then
--                             insertOption.notAvailable = true
--                         end
--                     end
--                 end
--             end
--         end
--     end

--     ISInventoryPaneContextMenu_doReloadMenuForBullets_Original(playerObj, bullet, context)
-- end
