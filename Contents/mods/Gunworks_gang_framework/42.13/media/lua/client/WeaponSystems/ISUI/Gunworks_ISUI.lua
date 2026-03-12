require("ISUI/ISInventoryPaneContextMenu")

local FoldingStock = require("WeaponSystems/Utils/FoldingStockUtils")
local FoldingBipod = require("WeaponSystems/Utils/FoldingBipodUtils")
local Bayonet = require("WeaponSystems/Utils/BayonetUtils")
local Magazine = require("WeaponSystems/Utils/MagazineUtils")
local Ammo = require("WeaponSystems/Utils/AmmoUtils")
local DynamicAttachment = require("WeaponSystems/Utils/DynamicAttachmentUtils")
local Railing = require("WeaponSystems/Utils/RailingUtils")
local PreventRemoval = require("WeaponSystems/Utils/PreventRemovalsUtil")

-------------------------------------------------
-- Foldable Stock Context Menu
-------------------------------------------------
local function addFoldableStockOption(playerObj, item, context)
    if not FoldingStock then return end
    if not instanceof(item, "HandWeapon") then return end
    if not item:isRanged() then return end
    if not FoldingStock.HasFoldableStock(item) then return end

    local isInInventory = item:getContainer() == playerObj:getInventory()
    local isFolded = FoldingStock.IsStockFolded(item)

    local actionString
    if isFolded then
        actionString = getText("IGUI_UnfoldStock")
    else
        actionString = getText("IGUI_FoldStock")
    end

    local listEntry = context:addOption(actionString, playerObj, FoldStockContext.callAction, item)

    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip:setName(actionString)
    tooltip.texture = item:getTex()

    if isInInventory then
        if isFolded then
            tooltip.description = getText("IGUI_UnfoldStockDesc")
        else
            tooltip.description = getText("IGUI_FoldStockDesc")
        end
    else
        listEntry.notAvailable = true
        tooltip.description = getText("IGUI_MoveToInventory")
    end

    listEntry.toolTip = tooltip
end

-------------------------------------------------
-- Foldable Bipod Context Menu
-------------------------------------------------
local function addFoldableBipodOption(playerObj, item, context)
    if not FoldingBipod then return end
    if not instanceof(item, "HandWeapon") then return end
    if not item:isRanged() then return end
    if not FoldingBipod.HasFoldableBipod(item) then return end

    local isInInventory = item:getContainer() == playerObj:getInventory()
    local isDeployed = FoldingBipod.IsBipodDeployed(item)

    local actionString
    if isDeployed then
        actionString = getText("IGUI_FoldBipod")
    else
        actionString = getText("IGUI_DeployBipod")
    end

    local listEntry = context:addOption(actionString, playerObj, FoldBipodContext.callAction, item)

    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip:setName(actionString)
    tooltip.texture = item:getTex()

    if isInInventory then
        if isDeployed then
            tooltip.description = getText("IGUI_FoldBipodDesc")
        else
            tooltip.description = getText("IGUI_DeployBipodDesc")
        end
    else
        listEntry.notAvailable = true
        tooltip.description = getText("IGUI_MoveToInventory")
    end

    listEntry.toolTip = tooltip
end

-------------------------------------------------
-- Bayonet Attachment Context Menu
-------------------------------------------------
local function addBayonetAttachmentOption(playerObj, item, context)
    if not Bayonet then return end
    if not instanceof(item, "HandWeapon") then return end
    if not item:isRanged() then return end

    local isInInventory = item:getContainer() == playerObj:getInventory()

    if Bayonet.CanRemoveBayonet(item) then
        local actionString = getText("IGUI_RemoveBayonet")
        local listEntry = context:addOption(actionString, playerObj, BayonetAttachmentContext.removeBayonet, item)

        local tooltip = ISInventoryPaneContextMenu.addToolTip()
        tooltip:setName(actionString)
        tooltip.texture = item:getTex()

        if isInInventory then
            tooltip.description = getText("IGUI_RemoveBayonetDesc")
        else
            listEntry.notAvailable = true
            tooltip.description = getText("IGUI_MoveToInventory")
        end

        listEntry.toolTip = tooltip
    else
        local compatibleKnives = {}
        local seen = {}
        local inventory = playerObj:getInventory():getItems()
        for i = 0, inventory:size() - 1 do
            local invItem = inventory:get(i)
            local knifeFullType = invItem:getFullType()
            if not seen[knifeFullType] and Bayonet.BayonetKnives[knifeFullType] and Bayonet.CanAttachBayonet(item, invItem) then
                table.insert(compatibleKnives, invItem)
                seen[knifeFullType] = true
            end
        end

        if #compatibleKnives == 1 then
            local invItem = compatibleKnives[1]
            local actionString = getText("IGUI_AttachBayonet")
            local listEntry = context:addOption(actionString, playerObj, BayonetAttachmentContext.attachBayonet, item, invItem)

            local tooltip = ISInventoryPaneContextMenu.addToolTip()
            tooltip:setName(actionString)
            tooltip.texture = item:getTex()

            if isInInventory then
                tooltip.description = getText("IGUI_AttachBayonetDesc")
            else
                listEntry.notAvailable = true
                tooltip.description = getText("IGUI_MoveToInventory")
            end

            listEntry.toolTip = tooltip
        elseif #compatibleKnives > 1 then
            local actionString = getText("IGUI_AttachBayonet")
            local bayonetOption = context:addOption(actionString)
            local subMenu = context:getNew(context)
            context:addSubMenu(bayonetOption, subMenu)

            for _, invItem in ipairs(compatibleKnives) do
                local knifeName = invItem:getDisplayName()
                local subEntry = subMenu:addOption(knifeName, playerObj, BayonetAttachmentContext.attachBayonet, item, invItem)

                local tooltip = ISInventoryPaneContextMenu.addToolTip()
                tooltip:setName(knifeName)
                tooltip.texture = invItem:getTex()

                if isInInventory then
                    tooltip.description = getText("IGUI_AttachBayonetDesc")
                else
                    subEntry.notAvailable = true
                    tooltip.description = getText("IGUI_MoveToInventory")
                end

                subEntry.toolTip = tooltip
            end
        end
    end
end

-------------------------------------------------
-- Dynamic Attachment Swap Context Menu
-------------------------------------------------
local function addSwapAttachmentOption(playerObj, item, context)
    if not DynamicAttachment then return end
    if not instanceof(item, "HandWeapon") then return end
    if not item:isRanged() then return end
    if not DynamicAttachment.HasSwappableAttachment(item) then return end

    local isInInventory = item:getContainer() == playerObj:getInventory()

    local partnerType, _, currentPart = DynamicAttachment.GetSwappableAttachment(item)
    if not partnerType or not currentPart then return end

    -- Build a display name from the partner item's script
    local partnerScript = ScriptManager.instance:getItem(partnerType)
    local partnerName = partnerScript and partnerScript:getDisplayName() or partnerType
    local actionString = getText("IGUI_SwapAttachment", partnerName)

    local listEntry = context:addOption(actionString, playerObj, SwapAttachmentContext.callAction, item)

    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip:setName(actionString)
    tooltip.texture = item:getTex()

    if isInInventory then
        tooltip.description = getText("IGUI_SwapAttachmentDesc", currentPart:getDisplayName(), partnerName)
    else
        listEntry.notAvailable = true
        tooltip.description = getText("IGUI_MoveToInventory")
    end

    listEntry.toolTip = tooltip
end

-------------------------------------------------
-- Railing Mount / Unmount Context Menu
-------------------------------------------------
local function addRailingOptions(playerObj, item, context)
    if not Railing then return end
    if not instanceof(item, "HandWeapon") then return end
    if not item:isRanged() then return end

    local railings = Railing.GetInstalledRailings(item)
    if #railings == 0 then return end

    local isInInventory = item:getContainer() == playerObj:getInventory()

    for _, railInfo in ipairs(railings) do
        local railingType = railInfo.railingType
        local railName = railInfo.part:getDisplayName()
        local accList = Railing.AcceptedAccessories[railingType]
        if accList then
            -- Build accepted set for this specific railing
            local acceptedSet = {}
            for _, acc in ipairs(accList) do
                acceptedSet[acc] = true
            end

            -- Unmount: show options for accessories mounted via THIS railing
            local parts = item:getAllWeaponParts()
            for i = 0, parts:size() - 1 do
                local part = parts:get(i)
                if part and acceptedSet[part:getFullType()] then
                    local partName = part:getDisplayName()
                    local actionString = getText("IGUI_RailingUnmount", partName, railName)
                    local listEntry = context:addOption(actionString, playerObj, RailingContext.unmountAccessory, item, part)

                    local tooltip = ISInventoryPaneContextMenu.addToolTip()
                    tooltip:setName(actionString)
                    tooltip.texture = item:getTex()

                    if isInInventory then
                        tooltip.description = getText("IGUI_RailingUnmountDesc", partName, railName)
                    else
                        listEntry.notAvailable = true
                        tooltip.description = getText("IGUI_MoveToInventory")
                    end

                    listEntry.toolTip = tooltip
                end
            end

            -- Mount: scan inventory for compatible accessories this railing accepts
            local compatibleItems = {}
            local seen = {}
            local inventory = playerObj:getInventory():getItems()
            for i = 0, inventory:size() - 1 do
                local invItem = inventory:get(i)
                local invFullType = invItem:getFullType()
                if not seen[invFullType] and acceptedSet[invFullType] and instanceof(invItem, "WeaponPart") and Railing.CanMountAccessory(item, invFullType) then
                    table.insert(compatibleItems, invItem)
                    seen[invFullType] = true
                end
            end

            if #compatibleItems == 1 then
                local invItem = compatibleItems[1]
                local accName = invItem:getDisplayName()
                local actionString = getText("IGUI_RailingMount", accName, railName)
                local listEntry = context:addOption(actionString, playerObj, RailingContext.mountAccessory, item, invItem)

                local tooltip = ISInventoryPaneContextMenu.addToolTip()
                tooltip:setName(actionString)
                tooltip.texture = invItem:getTex()

                if isInInventory then
                    tooltip.description = getText("IGUI_RailingMountDesc", accName, railName)
                else
                    listEntry.notAvailable = true
                    tooltip.description = getText("IGUI_MoveToInventory")
                end

                listEntry.toolTip = tooltip
            elseif #compatibleItems > 1 then
                local actionString = getText("IGUI_RailingMountMenu", railName)
                local mountOption = context:addOption(actionString)
                local subMenu = context:getNew(context)
                context:addSubMenu(mountOption, subMenu)

                for _, invItem in ipairs(compatibleItems) do
                    local accName = invItem:getDisplayName()
                    local subEntry = subMenu:addOption(accName, playerObj, RailingContext.mountAccessory, item, invItem)

                    local tooltip = ISInventoryPaneContextMenu.addToolTip()
                    tooltip:setName(accName)
                    tooltip.texture = invItem:getTex()

                    if isInInventory then
                        tooltip.description = getText("IGUI_RailingMountDesc", accName, railName)
                    else
                        subEntry.notAvailable = true
                        tooltip.description = getText("IGUI_MoveToInventory")
                    end

                    subEntry.toolTip = tooltip
                end
            end
        end
    end
end

local onFillInventoryObjectContextMenu = function(playerid, context, items)
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
            addSwapAttachmentOption(player, item, context)
            addRailingOptions(player, item, context)
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)

-------------------------------------------------
-- Prevent Removal: filter permanent parts from
-- the vanilla "Remove Weapon Upgrade" submenu
-------------------------------------------------
local function filterPermanentParts(playerid, context, items)
    local optionName = getText("ContextMenu_Remove_Weapon_Upgrade")
    local option = context:getOptionFromName(optionName)
    if not option then return end

    local subMenu = option.subOption and context:getSubMenu(option.subOption)
    if not subMenu then return end

    for i = #subMenu.options, 0, -1 do
        local v = subMenu.options[i]
        if v and v.param1 and instanceof(v.param1, "WeaponPart") then
            if PreventRemoval.IsPermanent(v.param1:getFullType()) then
                subMenu:removeOptionByName(v.name)
            end
        end
    end

    if #subMenu.options <= 0 then
        context:removeOptionByName(optionName)
    end
end

Events.OnFillInventoryObjectContextMenu.Add(filterPermanentParts)

-- Safety net: block the action itself in case another mod re-adds the option
local _onRemoveUpgradeWeapon_Original = ISInventoryPaneContextMenu.onRemoveUpgradeWeapon
ISInventoryPaneContextMenu.onRemoveUpgradeWeapon = function(weapon, part, player)
    if part and PreventRemoval.IsPermanent(part:getFullType()) then
        return
    end
    _onRemoveUpgradeWeapon_Original(weapon, part, player)
end

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
            local profileName = Magazine.GetProfileForGun(weapon)
            if profileName then
                if Magazine.IsMagazineInProfile(magType, profileName) then
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
    if Ammo.ItemAmmoFamily[magazine:getFullType()] then
        if magazine:getCurrentAmmoCount() < magazine:getMaxAmmo() then
            local typeList = Ammo.GetBulletTypesForFamily(Ammo.ItemAmmoFamily[magazine:getFullType()])
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
    Ammo.MagazineAmmoProfileSetter(magazine, itemKey)
    if ammoCount > 0 then
        ISTimedActionQueue.add(ISLoadBulletsInMagazine:new(playerObj, magazine, ammoCount))
    end
end

local ISInventoryPaneContextMenu_doBulletMenu_Original = ISInventoryPaneContextMenu.doBulletMenu
ISInventoryPaneContextMenu.doBulletMenu = function(playerObj, weapon, context)
    if Ammo.ItemAmmoFamily[weapon:getFullType()] then
        local typeList = Ammo.GetBulletTypesForFamily(Ammo.ItemAmmoFamily[weapon:getFullType()])
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
    Ammo.AmmoProfileSetter(weapon, itemKey)
    ISTimedActionQueue.add(ISReloadWeaponAction:new(playerObj, weapon));
end
