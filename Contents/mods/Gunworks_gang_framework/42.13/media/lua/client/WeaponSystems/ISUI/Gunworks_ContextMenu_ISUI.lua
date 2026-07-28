require("ISUI/ISInventoryPaneContextMenu")
require("TimedActions/ISTimedActionQueue")
require("TimedActions/ISUpgradeWeapon")
require("TimedActions/ISRemoveWeaponUpgrade")

local FoldingStock = require("WeaponSystems/Utils/FoldingStock")
local FoldingBipod = require("WeaponSystems/Utils/FoldingBipod")
local Bayonet = require("WeaponSystems/Utils/Bayonet")
local Magazine = require("WeaponSystems/Utils/Magazine")
local Ammo = require("WeaponSystems/Utils/Ammo")
local DynamicAttachment = require("WeaponSystems/Utils/DynamicAttachment")
local Railing = require("WeaponSystems/Utils/Railing")
local UniversalAttachment = require("WeaponSystems/Utils/UniversalAttachment")
local PreventRemoval = require("WeaponSystems/Utils/PreventRemovals")
local Underbarrel = require("WeaponSystems/Utils/Underbarrel")
local UpgradeExclusives = require("WeaponSystems/Utils/UpgradeExclusives")
local RequiredAttachment = require("WeaponSystems/Utils/RequiredAttachment")

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
-- Integrated Bayonet Fold / Unfold Context Menu
-------------------------------------------------
local function addIntegratedBayonetOption(playerObj, item, context)
    if not Bayonet then return end
    if not instanceof(item, "HandWeapon") then return end
    if not item:isRanged() then return end
    if not Bayonet.HasIntegratedBayonet(item) then return end

    local isInInventory = item:getContainer() == playerObj:getInventory()
    local isDeployed = Bayonet.IsIntegratedBayonetDeployed(item)

    local actionString
    if isDeployed then
        actionString = getText("IGUI_FoldBayonet")
    else
        actionString = getText("IGUI_DeployBayonet")
    end

    local listEntry = context:addOption(actionString, playerObj, IntegratedBayonetContext.callAction, item)

    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip:setName(actionString)
    tooltip.texture = item:getTex()

    if isInInventory then
        if isDeployed then
            tooltip.description = getText("IGUI_FoldBayonetDesc")
        else
            tooltip.description = getText("IGUI_DeployBayonetDesc")
        end
    else
        listEntry.notAvailable = true
        tooltip.description = getText("IGUI_MoveToInventory")
    end

    listEntry.toolTip = tooltip
end

IntegratedBayonetContext = {}

IntegratedBayonetContext.callAction = function(player, weapon)
    if not player or not weapon then return end
    if player:getPrimaryHandItem() ~= weapon then
        ISTimedActionQueue.add(ISEquipWeaponAction:new(player, weapon, 50, true, true))
    end
    if weapon:getContainer() == player:getInventory() then
        ISTimedActionQueue.add(ISToggleIntegratedBayonet:new(player, weapon, CharacterActionAnims.Craft))
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
local function createRailingActionEntry(name, texture, description, callback, param1, param2)
    return {
        name = name,
        texture = texture,
        description = description,
        callback = callback,
        param1 = param1,
        param2 = param2,
    }
end

local function createRailingSubMenuEntry(name, texture, description, children)
    return {
        name = name,
        texture = texture,
        description = description,
        children = children,
    }
end

local function addRailingEntryToMenu(menu, playerObj, entry, isInInventory)
    local option
    if entry.children then
        option = menu:addOption(entry.name)
        local subMenu = menu:getNew(menu)
        menu:addSubMenu(option, subMenu)

        for _, childEntry in ipairs(entry.children) do
            addRailingEntryToMenu(subMenu, playerObj, childEntry, isInInventory)
        end
    else
        option = menu:addOption(entry.name, playerObj, entry.callback, entry.param1, entry.param2)
    end

    local needsTooltip = entry.texture or entry.description or not isInInventory
    if needsTooltip then
        local tooltip = ISInventoryPaneContextMenu.addToolTip()
        tooltip:setName(entry.name)
        tooltip.texture = entry.texture

        if isInInventory then
            tooltip.description = entry.description or ""
        else
            tooltip.description = getText("IGUI_MoveToInventory")
        end

        option.toolTip = tooltip
    end

    if not isInInventory then
        option.notAvailable = true
    end
end

local function addRailingOptions(playerObj, item, context)
    if not Railing then return end
    if not instanceof(item, "HandWeapon") then return end
    if not item:isRanged() then return end

    local railings = Railing.GetInstalledRailings(item)
    if #railings == 0 then return end

    local isInInventory = item:getContainer() == playerObj:getInventory()
    local railingMenus = {}

    for _, railInfo in ipairs(railings) do
        local railingType = railInfo.railingType
        local railName = railInfo.part:getDisplayName()
        local accList = Railing.AcceptedAccessories[railingType]

        if accList then
            local contextEntries = {}
            local mergedEntries = {}

            local acceptedSet = {}
            for _, acc in ipairs(accList) do
                acceptedSet[acc] = true
            end

            local parts = item:getAllWeaponParts()
            for i = 0, parts:size() - 1 do
                local part = parts:get(i)
                if part and acceptedSet[part:getFullType()] then
                    local partName = part:getDisplayName()
                    local entry = createRailingActionEntry(
                        getText("IGUI_RailingUnmount", partName, railName),
                        item:getTex(),
                        getText("IGUI_RailingUnmountDesc", partName, railName),
                        RailingContext.unmountAccessory,
                        item,
                        part
                    )
                    table.insert(contextEntries, entry)
                    table.insert(mergedEntries, entry)
                end
            end

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
                local entry = createRailingActionEntry(
                    getText("IGUI_RailingMount", accName, railName),
                    invItem:getTex(),
                    getText("IGUI_RailingMountDesc", accName, railName),
                    RailingContext.mountAccessory,
                    item,
                    invItem
                )
                table.insert(contextEntries, entry)
                table.insert(mergedEntries, entry)
            elseif #compatibleItems > 1 then
                local submenuEntries = {}

                for _, invItem in ipairs(compatibleItems) do
                    local accName = invItem:getDisplayName()
                    table.insert(submenuEntries, createRailingActionEntry(
                        accName,
                        invItem:getTex(),
                        getText("IGUI_RailingMountDesc", accName, railName),
                        RailingContext.mountAccessory,
                        item,
                        invItem
                    ))
                    table.insert(mergedEntries, createRailingActionEntry(
                        getText("IGUI_RailingMount", accName, railName),
                        invItem:getTex(),
                        getText("IGUI_RailingMountDesc", accName, railName),
                        RailingContext.mountAccessory,
                        item,
                        invItem
                    ))
                end

                table.insert(contextEntries, createRailingSubMenuEntry(
                    getText("IGUI_RailingMountMenu", railName),
                    item:getTex(),
                    nil,
                    submenuEntries
                ))
            end

            if #contextEntries > 0 then
                table.insert(railingMenus, {
                    railName = railName,
                    contextEntries = contextEntries,
                    mergedEntries = mergedEntries,
                })
            end
        end
    end

    if #railingMenus == 0 then return end

    local parentLabel = getText("IGUI_RailingOptions")
    local parentOption = context:addOption(parentLabel)
    local parentMenu = context:getNew(context)
    context:addSubMenu(parentOption, parentMenu)

    if not isInInventory then
        parentOption.notAvailable = true
        local tooltip = ISInventoryPaneContextMenu.addToolTip()
        tooltip:setName(parentLabel)
        tooltip.texture = item:getTex()
        tooltip.description = getText("IGUI_MoveToInventory")
        parentOption.toolTip = tooltip
    end

    if #railingMenus == 1 then
        for _, entry in ipairs(railingMenus[1].mergedEntries) do
            addRailingEntryToMenu(parentMenu, playerObj, entry, isInInventory)
        end
        return
    end

    for _, railMenuInfo in ipairs(railingMenus) do
        local railOption = parentMenu:addOption(railMenuInfo.railName)
        local railMenu = parentMenu:getNew(parentMenu)
        parentMenu:addSubMenu(railOption, railMenu)

        if not isInInventory then
            railOption.notAvailable = true
        end

        for _, entry in ipairs(railMenuInfo.mergedEntries) do
            addRailingEntryToMenu(railMenu, playerObj, entry, isInInventory)
        end
    end
end

-------------------------------------------------
-- Universal Attachment Context Menu
-------------------------------------------------
local UniversalAttachmentContext = {}

local function getUniversalDisplayName(fullType)
    local item = fullType and instanceItem(fullType) or nil
    return item and item:getDisplayName() or fullType
end

local function sortFullTypesByDisplayName(fullTypes)
    table.sort(fullTypes, function(left, right)
        return string.lower(getUniversalDisplayName(left)) < string.lower(getUniversalDisplayName(right))
    end)
end

UniversalAttachmentContext.installOutcome = function(weapon, outcomePart, genericItem, player)
    if not player or not weapon or not genericItem or not outcomePart then return end
    local outcomeFullType = outcomePart:getFullType()

    ISInventoryPaneContextMenu.transferIfNeeded(player, weapon)
    ISInventoryPaneContextMenu.transferIfNeeded(player, genericItem)

    local action = ISUpgradeWeapon:new(player, weapon, genericItem, outcomeFullType)
    ISTimedActionQueue.add(action)
end

UniversalAttachmentContext.removeOutcome = function(player, weapon, partType, genericItemType)
    if not player or not weapon or not partType then return end

    ISInventoryPaneContextMenu.transferIfNeeded(player, weapon)
    ISTimedActionQueue.add(ISRemoveWeaponUpgrade:new(player, weapon, partType))
end

-- Fetch the vanilla "Add Weapon Upgrade" submenu if it already exists this
-- menu-build pass, otherwise build it the same way vanilla does. Only called
-- once we know we have at least one outcome to add, so an empty heading is
-- never created.
local function getOrCreateAddWeaponUpgradeSubMenu(context, items)
    local optionName = getText("ContextMenu_Add_Weapon_Upgrade")
    local option = context:getOptionFromName(optionName)
    if option then
        local subMenu = option.subOption and context:getSubMenu(option.subOption)
        if subMenu then
            return subMenu
        end
        subMenu = context:getNew(context)
        context:addSubMenu(option, subMenu)
        return subMenu
    end

    local subMenu = context:getNew(context)
    local newOption = context:addOption(optionName, items, nil)
    context:addSubMenu(newOption, subMenu)
    return subMenu
end

local function addUniversalInstallEntry(menu, playerObj, weapon, genericItem, genericItemName, outcomeType, isInInventory)
    local outcomeName = getUniversalDisplayName(outcomeType)
    local outcomePart = instanceItem(outcomeType)
    local listEntry = menu:addOption(outcomeName, weapon, UniversalAttachmentContext.installOutcome,
        outcomePart, genericItem, playerObj)

    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip:setName(outcomeName)
    tooltip.texture = outcomePart and outcomePart:getTex() or weapon:getTex()

    if isInInventory then
        tooltip.description = "Install " .. outcomeName .. " using one " .. genericItemName .. "."
    else
        listEntry.notAvailable = true
        tooltip.description = getText("IGUI_MoveToInventory")
    end

    listEntry.toolTip = tooltip
end

local function injectUniversalAttachmentInstallOptions(playerObj, item, context, items)
    if not UniversalAttachment then return end
    if not instanceof(item, "HandWeapon") then return end
    if not item:isRanged() then return end

    local genericItemTypes = UniversalAttachment.GetGenericItemTypes(item)
    if not genericItemTypes then return end

    sortFullTypesByDisplayName(genericItemTypes)

    local isInInventory = item:getContainer() == playerObj:getInventory()
    local addUpgradeSubMenu = nil

    for _, genericItemType in ipairs(genericItemTypes) do
        local genericItem = playerObj:getInventory():getFirstTypeRecurse(genericItemType)
        if genericItem then
            local availableOutcomes = UniversalAttachment.GetAvailableOutcomes(item, genericItemType, playerObj)
            if availableOutcomes then
                sortFullTypesByDisplayName(availableOutcomes)

                if not addUpgradeSubMenu then
                    addUpgradeSubMenu = getOrCreateAddWeaponUpgradeSubMenu(context, items)
                end

                local genericItemName = getUniversalDisplayName(genericItemType)

                if #availableOutcomes == 1 then
                    addUniversalInstallEntry(addUpgradeSubMenu, playerObj, item, genericItem,
                        genericItemName, availableOutcomes[1], isInInventory)
                else
                    local genericItemInstance = instanceItem(genericItemType)
                    local groupOption = addUpgradeSubMenu:addOption(genericItemName)
                    local groupMenu = addUpgradeSubMenu:getNew(addUpgradeSubMenu)
                    addUpgradeSubMenu:addSubMenu(groupOption, groupMenu)

                    local tooltip = ISInventoryPaneContextMenu.addToolTip()
                    tooltip:setName(genericItemName)
                    tooltip.texture = genericItemInstance and genericItemInstance:getTex() or item:getTex()

                    if isInInventory then
                        tooltip.description = "Select an installation outcome for " .. genericItemName .. "."
                    else
                        groupOption.notAvailable = true
                        tooltip.description = getText("IGUI_MoveToInventory")
                    end

                    groupOption.toolTip = tooltip

                    for _, outcomeType in ipairs(availableOutcomes) do
                        addUniversalInstallEntry(groupMenu, playerObj, item, genericItem,
                            genericItemName, outcomeType, isInInventory)
                    end
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
            addIntegratedBayonetOption(player, item, context)
            addSwapAttachmentOption(player, item, context)
            addRailingOptions(player, item, context)
            injectUniversalAttachmentInstallOptions(player, item, context, items)
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

    -- Resolve the weapon from the first submenu entry's target
    local weapon = nil
    for i = 0, #subMenu.options do
        local v = subMenu.options[i]
        if v and v.target and instanceof(v.target, "HandWeapon") then
            weapon = v.target
            break
        end
    end
    local isUnderbarrelMode = weapon and Underbarrel.IsWeaponInUnderbarrelMode(weapon)

    for i = #subMenu.options, 0, -1 do
        local v = subMenu.options[i]
        if v and v.param1 and instanceof(v.param1, "WeaponPart") then
            local partType = v.param1:getFullType()
            if PreventRemoval.IsPermanent(partType) then
                subMenu:removeOptionByName(v.name)
            elseif isUnderbarrelMode and Underbarrel.UnderbarrelAttachments[partType] then
                subMenu:removeOptionByName(v.name)
            elseif weapon and Railing.HasMountedAccessoryOnRailing(weapon, v.param1) then
                subMenu:removeOptionByName(v.name)
            end
        end
    end

    if #subMenu.options <= 0 then
        context:removeOptionByName(optionName)
    end
end

Events.OnFillInventoryObjectContextMenu.Add(filterPermanentParts)

-------------------------------------------------
-- Upgrade Exclusives: hide vanilla "Upgrade" options
-- for parts blocked by an exclusive already on the weapon
-------------------------------------------------
local function filterExclusiveUpgrades(playerid, context, items)
    local optionName = getText("ContextMenu_Add_Weapon_Upgrade")
    local option = context:getOptionFromName(optionName)
    if not option then return end

    local subMenu = option.subOption and context:getSubMenu(option.subOption)
    if not subMenu then return end

    for i = #subMenu.options, 0, -1 do
        local v = subMenu.options[i]
        if v and v.target and instanceof(v.target, "HandWeapon") and v.param1 then
            if UpgradeExclusives.IsBlockedByExclusive(v.target, v.param1:getFullType()) then
                subMenu:removeOptionByName(v.name)
            end
        end
    end

    if #subMenu.options <= 0 then
        context:removeOptionByName(optionName)
    end
end

Events.OnFillInventoryObjectContextMenu.Add(filterExclusiveUpgrades)

-------------------------------------------------
-- Required Attachment: hide vanilla "Upgrade" options
-- for child attachments missing required parents
-------------------------------------------------
local function filterRequiredAttachmentUpgrades(playerid, context, items)
    local optionName = getText("ContextMenu_Add_Weapon_Upgrade")
    local option = context:getOptionFromName(optionName)
    if not option then return end

    local subMenu = option.subOption and context:getSubMenu(option.subOption)
    if not subMenu then return end

    for i = #subMenu.options, 0, -1 do
        local v = subMenu.options[i]
        if v and v.target and instanceof(v.target, "HandWeapon") and v.param1 then
            if RequiredAttachment.IsInstallationBlocked(v.target, v.param1:getFullType()) then
                subMenu:removeOptionByName(v.name)
            end
        end
    end

    if #subMenu.options <= 0 then
        context:removeOptionByName(optionName)
    end
end

Events.OnFillInventoryObjectContextMenu.Add(filterRequiredAttachmentUpgrades)

-------------------------------------------------
-- Required Attachment: filter removals of parent
-- attachments that have installed children
-------------------------------------------------
local function filterRequiredAttachmentRemovals(playerid, context, items)
    local optionName = getText("ContextMenu_Remove_Weapon_Upgrade")
    local option = context:getOptionFromName(optionName)
    if not option then return end

    local subMenu = option.subOption and context:getSubMenu(option.subOption)
    if not subMenu then return end

    -- Resolve the weapon from the first submenu entry's target
    local weapon = nil
    for i = 0, #subMenu.options do
        local v = subMenu.options[i]
        if v and v.target and instanceof(v.target, "HandWeapon") then
            weapon = v.target
            break
        end
    end

    for i = #subMenu.options, 0, -1 do
        local v = subMenu.options[i]
        if v and v.param1 and instanceof(v.param1, "WeaponPart") then
            local partType = v.param1:getFullType()
            if weapon and RequiredAttachment.IsRemovalBlocked(weapon, partType) then
                subMenu:removeOptionByName(v.name)
            end
        end
    end

    if #subMenu.options <= 0 then
        context:removeOptionByName(optionName)
    end
end

Events.OnFillInventoryObjectContextMenu.Add(filterRequiredAttachmentRemovals)

local _onRemoveUpgradeWeapon_Original = ISInventoryPaneContextMenu.onRemoveUpgradeWeapon
ISInventoryPaneContextMenu.onRemoveUpgradeWeapon = function(weapon, part, player)
    if part and PreventRemoval.IsPermanent(part:getFullType()) then
        return
    end
    if weapon and part and Underbarrel.IsWeaponInUnderbarrelMode(weapon)
        and Underbarrel.UnderbarrelAttachments[part:getFullType()] then
        return
    end
    if weapon and part and Railing.HasMountedAccessoryOnRailing(weapon, part) then
        return
    end
    if weapon and part and RequiredAttachment.IsRemovalBlocked(weapon, part:getFullType()) then
        return
    end
    if weapon and part and UniversalAttachment.IsRegisteredOutcome(weapon, part) then
        if not UniversalAttachment.CanRemoveInstalledPart(weapon, part) then
            return
        end
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
            local freeSpace = magazine:getMaxAmmo() - magazine:getCurrentAmmoCount()

            -- Build entries and count how many have ammo available
            local entries = {}
            local availableCount = 0
            for _, typeName in ipairs(typeList) do
                local script = getScriptManager():FindItem(typeName)
                local bulletName = script and script:getDisplayName() or typeName
                local ammoCount = playerObj:getInventory():getItemCountRecurse(typeName)
                if ammoCount > magazine:getMaxAmmo() then ammoCount = magazine:getMaxAmmo() end
                if ammoCount > freeSpace then ammoCount = freeSpace end
                table.insert(entries, { itemKey = typeName, bulletName = bulletName, ammoCount = ammoCount })
                if ammoCount > 0 then availableCount = availableCount + 1 end
            end

            local targetMenu = context
            if availableCount == 0 then
                local option = context:addOption(getText("ContextMenu_NoBullets", 0))
                option.notAvailable = true
            elseif availableCount > 1 then
                local parentOption = context:addOption(getText("IGUI_LoadAmmo") or "Load Ammo")
                local subMenu = ISContextMenu:getNew(context)
                context:addSubMenu(parentOption, subMenu)
                targetMenu = subMenu

                for _, entry in ipairs(entries) do
                    if entry.ammoCount > 0 then
                        targetMenu:addOption(
                            getText("IGUI_ContextMenu_InsertAltBulletsInMagazine", entry.ammoCount, entry.bulletName),
                            playerObj,
                            ISInventoryPaneContextMenu.onLoadBulletsInMagazineFromDiffAmmoType, magazine, entry.ammoCount,
                            entry.itemKey)
                    end
                end
            else
                for _, entry in ipairs(entries) do
                    if entry.ammoCount > 0 then
                        context:addOption(
                            getText("IGUI_ContextMenu_InsertAltBulletsInMagazine", entry.ammoCount, entry.bulletName),
                            playerObj,
                            ISInventoryPaneContextMenu.onLoadBulletsInMagazineFromDiffAmmoType, magazine, entry.ammoCount,
                            entry.itemKey)
                    end
                end
            end
        end

        if magazine:getCurrentAmmoCount() > 0 then
            context:addOption(getText("ContextMenu_UnloadMagazine"), playerObj,
                ISInventoryPaneContextMenu.onUnloadBulletsFromMagazine, magazine)
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
        local freeSpace = weapon:getMaxAmmo() - weapon:getCurrentAmmoCount()

        -- Build entries and count how many have ammo available
        local entries = {}
        local availableCount = 0
        for _, typeName in ipairs(typeList) do
            local script = getScriptManager():FindItem(typeName)
            local bulletName = script and script:getDisplayName() or typeName
            local bulletAvail = playerObj:getInventory():getItemCountRecurse(typeName)
            local bulletNeeded = freeSpace
            if bulletNeeded > bulletAvail then bulletNeeded = bulletAvail end
            table.insert(entries, { itemKey = typeName, bulletName = bulletName, bulletNeeded = bulletNeeded })
            if bulletNeeded > 0 then availableCount = availableCount + 1 end
        end

        local targetMenu = context
        if availableCount == 0 then
            local option = context:addOption(getText("ContextMenu_NoBullets", 0))
            option.notAvailable = true
        elseif availableCount > 1 then
            local parentOption = context:addOption(getText("IGUI_LoadAmmo") or "Load Ammo")
            local subMenu = ISContextMenu:getNew(context)
            context:addSubMenu(parentOption, subMenu)
            targetMenu = subMenu

            for _, entry in ipairs(entries) do
                if entry.bulletNeeded > 0 then
                    targetMenu:addOption(
                        getText("ContextMenu_InsertBullets", entry.bulletNeeded, entry.bulletName, weapon:getDisplayName()),
                        playerObj,
                        ISInventoryPaneContextMenu.onLoadBulletsIntoFirearmFromDiffAmmoType, weapon, entry.itemKey)
                end
            end
        else
            for _, entry in ipairs(entries) do
                if entry.bulletNeeded > 0 then
                    context:addOption(
                        getText("ContextMenu_InsertBullets", entry.bulletNeeded, entry.bulletName, weapon:getDisplayName()),
                        playerObj,
                        ISInventoryPaneContextMenu.onLoadBulletsIntoFirearmFromDiffAmmoType, weapon, entry.itemKey)
                end
            end
        end

        if weapon:getCurrentAmmoCount() > 0 then
            context:addOption(getText("ContextMenu_UnloadRounds", weapon:getDisplayName()), playerObj,
                ISInventoryPaneContextMenu.onUnloadBulletsFromFirearm, weapon)
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
