require("ISUI/ISInventoryPaneContextMenu")

local FoldingStock = require("WeaponSystems/Utils/FoldingStockUtils")
local FoldingBipod = require("WeaponSystems/Utils/FoldingBipodUtils")
local Bayonet = require("WeaponSystems/Utils/BayonetUtils")
local Magazine = require("WeaponSystems/Utils/MagazineUtils")
local Ammo = require("WeaponSystems/Utils/AmmoUtils")

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
        actionString = getText("IGUI_MWA_UnfoldStock")
    else
        actionString = getText("IGUI_MWA_FoldStock")
    end

    local listEntry = context:addOption(actionString, playerObj, FoldStockContext.callAction, item)

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
    if not FoldingBipod then return end
    if not instanceof(item, "HandWeapon") then return end
    if not item:isRanged() then return end
    if not FoldingBipod.HasFoldableBipod(item) then return end

    local isInInventory = item:getContainer() == playerObj:getInventory()
    local isDeployed = FoldingBipod.IsBipodDeployed(item)

    local actionString
    if isDeployed then
        actionString = getText("IGUI_MWA_FoldBipod")
    else
        actionString = getText("IGUI_MWA_DeployBipod")
    end

    local listEntry = context:addOption(actionString, playerObj, FoldBipodContext.callAction, item)

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
    if not Bayonet then return end
    if not instanceof(item, "HandWeapon") then return end
    if not item:isRanged() then return end

    local isInInventory = item:getContainer() == playerObj:getInventory()

    if Bayonet.CanRemoveBayonet(item) then
        local actionString = getText("IGUI_MWA_RemoveBayonet")
        local listEntry = context:addOption(actionString, playerObj, BayonetAttachmentContext.removeBayonet, item)

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
            if Bayonet.BayonetKnives[invItem:getFullType()] and Bayonet.CanAttachBayonet(item, invItem) then
                local actionString = getText("IGUI_MWA_AttachBayonet")
                local listEntry = context:addOption(actionString, playerObj, BayonetAttachmentContext.attachBayonet, item, invItem)

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
            local profileName = Magazine.WeaponMagazineProfile[weapon:getFullType()]
            if profileName and Magazine.MagazineProfileList[profileName] then
                if Magazine.isMagazineInProfile(magType, Magazine.MagazineProfileList[profileName]) then
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
    if Ammo.MagazineAmmoProfile[magazine:getFullType()] then
        if magazine:getCurrentAmmoCount() < magazine:getMaxAmmo() then
            local typeList = Ammo.AmmoProfilesList[Ammo.MagazineAmmoProfile[magazine:getFullType()]]
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
    if Ammo.WeaponAmmoProfile[weapon:getFullType()] then
        local typeList = Ammo.AmmoProfilesList[Ammo.WeaponAmmoProfile[weapon:getFullType()]]
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
