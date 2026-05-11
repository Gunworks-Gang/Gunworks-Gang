require("ISUI/ISPanelJoypad")
require("ISUI/ISButton")
require("ISUI/ISLabel")
require("ISUI/ISScrollingListBox")
require("ISUI/ISInventoryPaneContextMenu")
require("TimedActions/ISTimedActionQueue")
require("TimedActions/ISUpgradeWeapon")
require("WeaponSystems/TimedActions/ISRailingAction")
require("WeaponSystems/TimedActions/ISBayonetAttach")
require("WeaponSystems/TimedActions/ISSwapAttachment")
require("WeaponSystems/TimedActions/ISUniversalAttachment")

local Bayonet = require("WeaponSystems/Utils/Bayonet")
local DynamicAttachment = require("WeaponSystems/Utils/DynamicAttachment")
local PreventRemoval = require("WeaponSystems/Utils/PreventRemovals")
local Railing = require("WeaponSystems/Utils/Railing")
local Underbarrel = require("WeaponSystems/Utils/Underbarrel")
local UniversalAttachment = require("WeaponSystems/Utils/UniversalAttachment")
local UpgradeExclusives = require("WeaponSystems/Utils/UpgradeExclusives")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local PADDING = 10
local LIST_ITEM_HGT = FONT_HGT_SMALL * 2 + 10
local BUTTON_HGT = FONT_HGT_SMALL + 8
local REFRESH_INTERVAL = 20

WeaponUpgradeUI = ISPanelJoypad:derive("WeaponUpgradeUI")
WeaponUpgradeUI.instance = nil

local function isManagedWeapon(item)
    if not item then return false end
    if not instanceof(item, "HandWeapon") then return false end
    return item:isRanged()
end

local function safeLower(value)
    return string.lower(value or "")
end

local function getDisplayNameFromType(fullType)
    local script = fullType and getScriptManager():FindItem(fullType) or nil
    return script and script:getDisplayName() or fullType
end

local function getTextureFromType(fullType)
    local item = fullType and instanceItem(fullType) or nil
    return item and item:getTex() or nil
end

local function fitText(font, text, maxWidth)
    if not text then return "" end
    if getTextManager():MeasureStringX(font, text) <= maxWidth then
        return text
    end

    local trimmed = text
    while string.len(trimmed) > 1 do
        trimmed = string.sub(trimmed, 1, string.len(trimmed) - 1)
        if getTextManager():MeasureStringX(font, trimmed .. "...") <= maxWidth then
            return trimmed .. "..."
        end
    end

    return "..."
end

local function buildCountSuffix(count)
    if count and count > 1 then
        return " x" .. tostring(count)
    end
    return ""
end

local function getInstalledStatus(name)
    return getText("IGUI_WeaponUpgradeUI_Installed", name or getText("IGUI_WeaponUpgradeUI_Empty"))
end

local function summarizeNames(names)
    if not names or #names == 0 then
        return getText("IGUI_WeaponUpgradeUI_Empty")
    end
    if #names == 1 then
        return names[1]
    end
    return names[1] .. " +" .. tostring(#names - 1)
end

local function sortEntriesByLabel(entries)
    table.sort(entries, function(left, right)
        return safeLower(left.label or left.title) < safeLower(right.label or right.title)
    end)
end

local function sortFullTypesByDisplayName(fullTypes)
    table.sort(fullTypes, function(left, right)
        return safeLower(getDisplayNameFromType(left)) < safeLower(getDisplayNameFromType(right))
    end)
end

local function isBayonetAttachmentType(fullType)
    return fullType and Bayonet.GetKnifeTypeFromAttachment(fullType) ~= nil
end

local function getInstalledBayonetPart(weapon)
    if not weapon then return nil end

    local parts = weapon:getAllWeaponParts()
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part and isBayonetAttachmentType(part:getFullType()) then
            return part
        end
    end

    return nil
end

local function isCustomManagedInstallPart(weapon, fullType)
    if not fullType then return false end
    if Railing.KnownAccessories[fullType] then return true end
    if isBayonetAttachmentType(fullType) then return true end
    return UniversalAttachment.IsRegisteredOutcome(weapon, fullType)
end

local function isCustomManagedRemovePart(weapon, part)
    if not weapon or not part then return false end

    local fullType = part:getFullType()
    if PreventRemoval.IsPermanent(fullType) then
        return true
    end
    if Underbarrel.IsWeaponInUnderbarrelMode(weapon) and Underbarrel.UnderbarrelAttachments[fullType] then
        return true
    end
    if Railing.HasMountedAccessoryOnRailing(weapon, part) then
        return true
    end
    if UniversalAttachment.IsRegisteredOutcome(weapon, part) then
        return true
    end
    if isBayonetAttachmentType(fullType) then
        return true
    end

    return false
end

local function newCategory(key, title, status, texture)
    return {
        key = key,
        title = title,
        status = status or getInstalledStatus(getText("IGUI_WeaponUpgradeUI_Empty")),
        texture = texture,
        actions = {},
    }
end

local function addAction(category, action)
    table.insert(category.actions, action)
end

local function addCategoryIfRelevant(categories, category)
    if #category.actions > 0 or category.status ~= getInstalledStatus(getText("IGUI_WeaponUpgradeUI_Empty")) then
        sortEntriesByLabel(category.actions)
        table.insert(categories, category)
    end
end

local function buildStandardCategories(player, weapon, categories)
    local categoryMap = {}
    local categoryOrder = {}

    local function getCategory(partType, texture)
        local key = "standard:" .. tostring(partType or "Unknown")
        local category = categoryMap[key]
        if not category then
            category = newCategory(
                key,
                getText("IGUI_WeaponUpgradeUI_StandardPrefix", tostring(partType or "Unknown")),
                nil,
                texture
            )
            categoryMap[key] = category
            table.insert(categoryOrder, category)
        elseif texture and not category.texture then
            category.texture = texture
        end
        return category
    end

    local parts = weapon:getAllWeaponParts()
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part then
            local fullType = part:getFullType()
            if not Railing.KnownAccessories[fullType]
                and not UniversalAttachment.IsRegisteredOutcome(weapon, part)
                and not isBayonetAttachmentType(fullType) then
                local category = getCategory(part:getPartType() or part:getDisplayName(), part:getTex())
                category.status = getInstalledStatus(part:getDisplayName())
            end
        end
    end

    local removable = weapon:getDetachableWeaponParts(player)
    for i = 0, removable:size() - 1 do
        local part = removable:get(i)
        if part and not isCustomManagedRemovePart(weapon, part) then
            local partType = part:getPartType() or part:getDisplayName()
            local category = getCategory(partType, part:getTex())
            addAction(category, {
                key = "standard-remove:" .. tostring(partType),
                kind = "standard-remove",
                partType = partType,
                label = getText("IGUI_WeaponUpgradeUI_Remove", part:getDisplayName()),
                description = category.title,
                texture = part:getTex(),
            })
        end
    end

    local weaponParts = player:getInventory():getItemsFromCategory("WeaponPart")
    local seenFullTypes = {}
    for i = 0, weaponParts:size() - 1 do
        local part = weaponParts:get(i)
        local fullType = part:getFullType()
        local partType = part:getPartType()
        if part
            and not seenFullTypes[fullType]
            and not part:isBroken()
            and not isCustomManagedInstallPart(weapon, fullType)
            and part:canAttach(player, weapon)
            and not weapon:getWeaponPart(partType)
            and not UpgradeExclusives.IsBlockedByExclusive(weapon, fullType) then
            seenFullTypes[fullType] = true

            local count = player:getInventory():getItemCountRecurse(fullType)
            local category = getCategory(partType or part:getDisplayName(), part:getTex())
            addAction(category, {
                key = "standard-install:" .. fullType,
                kind = "standard-install",
                fullType = fullType,
                partType = partType,
                label = getText("IGUI_WeaponUpgradeUI_Install", part:getDisplayName()) .. buildCountSuffix(count),
                description = category.title,
                texture = part:getTex(),
            })
        end
    end

    sortEntriesByLabel(categoryOrder)
    for _, category in ipairs(categoryOrder) do
        addCategoryIfRelevant(categories, category)
    end
end

local function buildRailingCategories(player, weapon, categories)
    local railings = Railing.GetInstalledRailings(weapon)
    for _, railInfo in ipairs(railings) do
        local railName = railInfo.part:getDisplayName()
        local category = newCategory(
            "rail:" .. railInfo.railingType,
            getText("IGUI_WeaponUpgradeUI_RailPrefix", railName),
            getInstalledStatus(railName),
            railInfo.part:getTex()
        )

        local acceptedSet = {}
        local acceptedList = Railing.AcceptedAccessories[railInfo.railingType] or {}
        for _, accessoryType in ipairs(acceptedList) do
            acceptedSet[accessoryType] = true
        end

        local parts = weapon:getAllWeaponParts()
        for i = 0, parts:size() - 1 do
            local part = parts:get(i)
            if part and acceptedSet[part:getFullType()] then
                addAction(category, {
                    key = "rail-remove:" .. tostring(part:getPartType()),
                    kind = "rail-remove",
                    partType = part:getPartType(),
                    label = getText("IGUI_WeaponUpgradeUI_Remove", part:getDisplayName()),
                    description = category.title,
                    texture = part:getTex(),
                })
            end
        end

        local seen = {}
        local inventory = player:getInventory():getItems()
        for i = 0, inventory:size() - 1 do
            local invItem = inventory:get(i)
            local fullType = invItem:getFullType()
            if not seen[fullType]
                and acceptedSet[fullType]
                and instanceof(invItem, "WeaponPart")
                and Railing.CanMountAccessory(weapon, fullType) then
                seen[fullType] = true
                local count = player:getInventory():getItemCountRecurse(fullType)
                addAction(category, {
                    key = "rail-install:" .. fullType,
                    kind = "rail-install",
                    fullType = fullType,
                    label = getText("IGUI_WeaponUpgradeUI_Install", invItem:getDisplayName()) .. buildCountSuffix(count),
                    description = category.title,
                    texture = invItem:getTex(),
                })
            end
        end

        addCategoryIfRelevant(categories, category)
    end
end

local function buildBayonetCategory(player, weapon, categories)
    local category = newCategory(
        "bayonet",
        getText("IGUI_WeaponUpgradeUI_Bayonet"),
        getInstalledStatus(getText("IGUI_WeaponUpgradeUI_Empty")),
        weapon:getTex()
    )

    local currentBayonet = getInstalledBayonetPart(weapon)
    if currentBayonet then
        category.status = getInstalledStatus(currentBayonet:getDisplayName())
        category.texture = currentBayonet:getTex() or category.texture
    end

    if Bayonet.CanRemoveBayonet(weapon) then
        addAction(category, {
            key = "bayonet-remove",
            kind = "bayonet-remove",
            label = getText("IGUI_WeaponUpgradeUI_Remove", currentBayonet and currentBayonet:getDisplayName() or getText("IGUI_WeaponUpgradeUI_Bayonet")),
            description = category.title,
            texture = currentBayonet and currentBayonet:getTex() or weapon:getTex(),
        })
    else
        local seen = {}
        local inventory = player:getInventory():getItems()
        for i = 0, inventory:size() - 1 do
            local invItem = inventory:get(i)
            local fullType = invItem:getFullType()
            if not seen[fullType] and Bayonet.BayonetKnives[fullType] and Bayonet.CanAttachBayonet(weapon, invItem) then
                seen[fullType] = true
                local count = player:getInventory():getItemCountRecurse(fullType)
                addAction(category, {
                    key = "bayonet-install:" .. fullType,
                    kind = "bayonet-install",
                    fullType = fullType,
                    label = getText("IGUI_WeaponUpgradeUI_Install", invItem:getDisplayName()) .. buildCountSuffix(count),
                    description = category.title,
                    texture = invItem:getTex(),
                })
            end
        end
    end

    addCategoryIfRelevant(categories, category)
end

local function buildDynamicCategory(weapon, categories)
    local partnerType, _, currentPart = DynamicAttachment.GetSwappableAttachment(weapon)
    if not partnerType or not currentPart then return end

    local partnerName = getDisplayNameFromType(partnerType)
    local category = newCategory(
        "dynamic",
        getText("IGUI_WeaponUpgradeUI_Dynamic"),
        getInstalledStatus(currentPart:getDisplayName()),
        currentPart:getTex()
    )

    addAction(category, {
        key = "dynamic-swap:" .. partnerType,
        kind = "dynamic-swap",
        partnerType = partnerType,
        label = getText("IGUI_WeaponUpgradeUI_SwapTo", partnerName),
        description = category.title,
        texture = getTextureFromType(partnerType) or currentPart:getTex(),
    })

    addCategoryIfRelevant(categories, category)
end

local function buildUniversalCategories(player, weapon, categories)
    local genericItemTypes = UniversalAttachment.GetGenericItemTypes(weapon)
    if not genericItemTypes then return end

    sortFullTypesByDisplayName(genericItemTypes)

    for _, genericItemType in ipairs(genericItemTypes) do
        local genericItemName = getDisplayNameFromType(genericItemType)
        local installedOutcomes = UniversalAttachment.GetInstalledOutcomes(weapon, genericItemType)
        local installedNames = {}
        if installedOutcomes then
            for _, outcomeInfo in ipairs(installedOutcomes) do
                table.insert(installedNames, getDisplayNameFromType(outcomeInfo.fullType))
            end
            table.sort(installedNames, function(left, right)
                return safeLower(left) < safeLower(right)
            end)
        end

        local category = newCategory(
            "universal:" .. genericItemType,
            getText("IGUI_WeaponUpgradeUI_UniversalPrefix", genericItemName),
            getInstalledStatus(summarizeNames(installedNames)),
            getTextureFromType(genericItemType)
        )

        local genericCount = player:getInventory():getItemCountRecurse(genericItemType)
        local availableOutcomes = genericCount > 0 and UniversalAttachment.GetAvailableOutcomes(weapon, genericItemType) or nil
        if availableOutcomes then
            sortFullTypesByDisplayName(availableOutcomes)
            for _, outcomeType in ipairs(availableOutcomes) do
                addAction(category, {
                    key = "universal-install:" .. genericItemType .. ":" .. outcomeType,
                    kind = "universal-install",
                    genericItemType = genericItemType,
                    outcomeType = outcomeType,
                    label = getText("IGUI_WeaponUpgradeUI_Install", getDisplayNameFromType(outcomeType)) .. buildCountSuffix(genericCount),
                    description = category.title,
                    texture = getTextureFromType(outcomeType) or getTextureFromType(genericItemType),
                })
            end
        end

        if installedOutcomes then
            for _, outcomeInfo in ipairs(installedOutcomes) do
                if UniversalAttachment.CanRemoveInstalledPart(weapon, outcomeInfo.part) then
                    addAction(category, {
                        key = "universal-remove:" .. genericItemType .. ":" .. outcomeInfo.partType,
                        kind = "universal-remove",
                        genericItemType = genericItemType,
                        partType = outcomeInfo.partType,
                        label = getText("IGUI_WeaponUpgradeUI_Remove", getDisplayNameFromType(outcomeInfo.fullType)),
                        description = category.title,
                        texture = outcomeInfo.part and outcomeInfo.part:getTex() or getTextureFromType(genericItemType),
                    })
                end
            end
        end

        addCategoryIfRelevant(categories, category)
    end
end

function WeaponUpgradeUI.OpenPanel(player, weapon)
    if not player or not isManagedWeapon(weapon) then return end

    if WeaponUpgradeUI.instance then
        WeaponUpgradeUI.instance:close()
    end

    local width = 720
    local height = 470
    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    local x = (screenW - width) / 2
    local y = (screenH - height) / 2

    local ui = WeaponUpgradeUI:new(x, y, width, height, player, weapon)
    ui:initialise()
    ui:instantiate()
    ui:addToUIManager()
    ui:setVisible(true)
    WeaponUpgradeUI.instance = ui
end

function WeaponUpgradeUI:initialise()
    ISPanelJoypad.initialise(self)
end

function WeaponUpgradeUI:createChildren()
    ISPanelJoypad.createChildren(self)

    local y = PADDING
    self.titleLabel = ISLabel:new(self.width / 2, y, FONT_HGT_MEDIUM, getText("IGUI_WeaponUpgradeUI_Title"), 1, 1, 1, 1,
        UIFont.Medium, true)
    self.titleLabel.center = true
    self.titleLabel:initialise()
    self.titleLabel:instantiate()
    self:addChild(self.titleLabel)

    y = y + FONT_HGT_MEDIUM + 4
    self.weaponLabel = ISLabel:new(self.width / 2, y, FONT_HGT_SMALL, "", 0.9, 0.9, 0.9, 1, UIFont.Small, true)
    self.weaponLabel.center = true
    self.weaponLabel:initialise()
    self.weaponLabel:instantiate()
    self:addChild(self.weaponLabel)

    y = y + FONT_HGT_SMALL + PADDING

    local listTop = y + FONT_HGT_SMALL + 4
    local listHeight = 270
    local leftWidth = 260
    local rightX = PADDING + leftWidth + PADDING
    local rightWidth = self.width - rightX - PADDING

    self.categoryTitle = ISLabel:new(PADDING, y, FONT_HGT_SMALL, getText("IGUI_WeaponUpgradeUI_Categories"), 1, 1, 1, 1,
        UIFont.Small, false)
    self.categoryTitle:initialise()
    self.categoryTitle:instantiate()
    self:addChild(self.categoryTitle)

    self.actionTitle = ISLabel:new(rightX, y, FONT_HGT_SMALL, getText("IGUI_WeaponUpgradeUI_Actions"), 1, 1, 1, 1,
        UIFont.Small, false)
    self.actionTitle:initialise()
    self.actionTitle:instantiate()
    self:addChild(self.actionTitle)

    self.categoryList = ISScrollingListBox:new(PADDING, listTop, leftWidth, listHeight)
    self.categoryList:initialise()
    self.categoryList:instantiate()
    self.categoryList.font = UIFont.Small
    self.categoryList.itemheight = LIST_ITEM_HGT
    self.categoryList.doDrawItem = WeaponUpgradeUI.doDrawCategoryItem
    self.categoryList.onMouseDown = WeaponUpgradeUI.onCategoryListMouseDown
    self.categoryList.target = self
    self.categoryList.selected = 0
    self:addChild(self.categoryList)

    self.actionList = ISScrollingListBox:new(rightX, listTop, rightWidth, listHeight)
    self.actionList:initialise()
    self.actionList:instantiate()
    self.actionList.font = UIFont.Small
    self.actionList.itemheight = LIST_ITEM_HGT
    self.actionList.doDrawItem = WeaponUpgradeUI.doDrawActionItem
    self.actionList.onMouseDown = WeaponUpgradeUI.onActionListMouseDown
    self.actionList.target = self
    self.actionList.selected = 0
    self:addChild(self.actionList)

    y = listTop + listHeight + PADDING
    self.infoLabel = ISLabel:new(PADDING, y, FONT_HGT_SMALL, "", 0.8, 0.8, 0.8, 1, UIFont.Small, false)
    self.infoLabel:initialise()
    self.infoLabel:instantiate()
    self:addChild(self.infoLabel)

    y = y + FONT_HGT_SMALL + PADDING
    local buttonWidth = 120
    local closeWidth = 140
    local closeX = self.width - PADDING - closeWidth
    local applyX = closeX - PADDING - buttonWidth
    local refreshX = applyX - PADDING - buttonWidth

    self.btnRefresh = ISButton:new(refreshX, y, buttonWidth, BUTTON_HGT, getText("IGUI_WeaponUpgradeUI_Refresh"), self,
        WeaponUpgradeUI.onButton)
    self.btnRefresh.internal = "REFRESH"
    self.btnRefresh:initialise()
    self.btnRefresh:instantiate()
    self:addChild(self.btnRefresh)

    self.btnApply = ISButton:new(applyX, y, buttonWidth, BUTTON_HGT, getText("IGUI_WeaponUpgradeUI_Apply"), self,
        WeaponUpgradeUI.onButton)
    self.btnApply.internal = "APPLY"
    self.btnApply:initialise()
    self.btnApply:instantiate()
    self.btnApply:enableAcceptColor()
    self:addChild(self.btnApply)

    self.btnClose = ISButton:new(closeX, y, closeWidth, BUTTON_HGT, getText("UI_Close") or "Close", self,
        WeaponUpgradeUI.onButton)
    self.btnClose.internal = "CLOSE"
    self.btnClose:initialise()
    self.btnClose:instantiate()
    self.btnClose:enableCancelColor()
    self:addChild(self.btnClose)

    self.btnApply:setEnable(false)
    self:refreshUpgradeData()
end

function WeaponUpgradeUI:getWeapon()
    if not self.weapon then return nil end

    local inventory = self.player and self.player:getInventory() or nil
    if not inventory then return self.weapon end

    local resolved = inventory:getItemById(self.weapon:getID())
    if resolved then
        self.weapon = resolved
    end
    return resolved
end

function WeaponUpgradeUI:getSelectedCategory()
    if self.categoryList.selected <= 0 then return nil end
    local row = self.categoryList.items[self.categoryList.selected]
    return row and row.item or nil
end

function WeaponUpgradeUI:getSelectedAction()
    if self.actionList.selected <= 0 then return nil end
    local row = self.actionList.items[self.actionList.selected]
    return row and row.item or nil
end

function WeaponUpgradeUI:setInfoText(text)
    self.infoLabel:setName(fitText(UIFont.Small, text or "", self.width - PADDING * 2))
end

function WeaponUpgradeUI:populateActionList(selectedActionKey)
    self.actionList:clear()
    self.actionList.selected = 0

    local category = self:getSelectedCategory()
    if not category then
        self.btnApply:setEnable(false)
        self:setInfoText(getText("IGUI_WeaponUpgradeUI_NoCategories"))
        return
    end

    for _, action in ipairs(category.actions) do
        self.actionList:addItem(action.label, action)
    end

    if #self.actionList.items > 0 then
        local selectedIndex = 1
        if selectedActionKey then
            for index, listItem in ipairs(self.actionList.items) do
                if listItem.item.key == selectedActionKey then
                    selectedIndex = index
                    break
                end
            end
        end
        self.actionList.selected = selectedIndex
        self.btnApply:setEnable(true)
        self:setInfoText(self.actionList.items[selectedIndex].item.description)
    else
        self.btnApply:setEnable(false)
        self:setInfoText(getText("IGUI_WeaponUpgradeUI_NoActions"))
    end
end

function WeaponUpgradeUI:refreshUpgradeData(selectedCategoryKey, selectedActionKey)
    local weapon = self:getWeapon()
    self.categoryList:clear()
    self.actionList:clear()
    self.categoryList.selected = 0
    self.actionList.selected = 0
    self.btnApply:setEnable(false)

    if not weapon then
        self.weaponLabel:setName(getText("IGUI_WeaponUpgradeUI_NoWeapon"))
        self:setInfoText(getText("IGUI_WeaponUpgradeUI_NoWeapon"))
        return
    end

    self.weaponLabel:setName(weapon:getDisplayName())

    local categories = {}
    buildStandardCategories(self.player, weapon, categories)
    buildRailingCategories(self.player, weapon, categories)
    buildBayonetCategory(self.player, weapon, categories)
    buildDynamicCategory(weapon, categories)
    buildUniversalCategories(self.player, weapon, categories)
    sortEntriesByLabel(categories)

    for _, category in ipairs(categories) do
        self.categoryList:addItem(category.title, category)
    end

    if #self.categoryList.items == 0 then
        self:setInfoText(getText("IGUI_WeaponUpgradeUI_NoCategories"))
        return
    end

    local selectedIndex = 1
    if selectedCategoryKey then
        for index, listItem in ipairs(self.categoryList.items) do
            if listItem.item.key == selectedCategoryKey then
                selectedIndex = index
                break
            end
        end
    end

    self.categoryList.selected = selectedIndex
    self:populateActionList(selectedActionKey)
end

function WeaponUpgradeUI:performSelectedAction()
    local action = self:getSelectedAction()
    local weapon = self:getWeapon()
    if not action or not weapon then return end

    local player = self.player
    if action.kind == "standard-install" then
        local part = player:getInventory():getFirstTypeRecurse(action.fullType)
        if part and not weapon:getWeaponPart(action.partType) and part:canAttach(player, weapon)
            and not UpgradeExclusives.IsBlockedByExclusive(weapon, action.fullType) then
            ISInventoryPaneContextMenu.onUpgradeWeapon(weapon, part, player)
        end
    elseif action.kind == "standard-remove" then
        local part = weapon:getWeaponPart(action.partType)
        if part and not isCustomManagedRemovePart(weapon, part) then
            ISInventoryPaneContextMenu.onRemoveUpgradeWeapon(weapon, part, player)
        end
    elseif action.kind == "rail-install" then
        local accessory = player:getInventory():getFirstTypeRecurse(action.fullType)
        if accessory and Railing.CanMountAccessory(weapon, action.fullType) then
            RailingContext.mountAccessory(player, weapon, accessory)
        end
    elseif action.kind == "rail-remove" then
        local accessoryPart = weapon:getWeaponPart(action.partType)
        if accessoryPart then
            RailingContext.unmountAccessory(player, weapon, accessoryPart)
        end
    elseif action.kind == "bayonet-install" then
        local knife = player:getInventory():getFirstTypeRecurse(action.fullType)
        if knife and Bayonet.CanAttachBayonet(weapon, knife) then
            BayonetAttachmentContext.attachBayonet(player, weapon, knife)
        end
    elseif action.kind == "bayonet-remove" then
        if Bayonet.CanRemoveBayonet(weapon) then
            BayonetAttachmentContext.removeBayonet(player, weapon)
        end
    elseif action.kind == "dynamic-swap" then
        if DynamicAttachment.HasSwappableAttachment(weapon) then
            SwapAttachmentContext.callAction(player, weapon)
        end
    elseif action.kind == "universal-install" then
        local genericItem = player:getInventory():getFirstTypeRecurse(action.genericItemType)
        if genericItem and UniversalAttachment.CanInstallOutcome(weapon, action.outcomeType) then
            ISInventoryPaneContextMenu.transferIfNeeded(player, weapon)
            ISInventoryPaneContextMenu.transferIfNeeded(player, genericItem)
            if player:getPrimaryHandItem() ~= weapon then
                ISTimedActionQueue.add(ISEquipWeaponAction:new(player, weapon, 50, true, true))
            end
            ISTimedActionQueue.add(ISUniversalAttachmentInstall:new(player, weapon, genericItem, action.outcomeType))
        end
    elseif action.kind == "universal-remove" then
        local installedPart = weapon:getWeaponPart(action.partType)
        if installedPart and UniversalAttachment.CanRemoveInstalledPart(weapon, installedPart) then
            ISInventoryPaneContextMenu.transferIfNeeded(player, weapon)
            if player:getPrimaryHandItem() ~= weapon then
                ISTimedActionQueue.add(ISEquipWeaponAction:new(player, weapon, 50, true, true))
            end
            ISTimedActionQueue.add(ISUniversalAttachmentRemove:new(player, weapon, action.partType, action.genericItemType))
        end
    end
end

function WeaponUpgradeUI.onButton(self, button)
    if button.internal == "APPLY" then
        self:performSelectedAction()
    elseif button.internal == "REFRESH" then
        self:refreshUpgradeData(self:getSelectedCategory() and self:getSelectedCategory().key or nil,
            self:getSelectedAction() and self:getSelectedAction().key or nil)
    elseif button.internal == "CLOSE" then
        self:close()
    end
end

function WeaponUpgradeUI.onCategoryListMouseDown(self, x, y)
    if #self.items == 0 then return end

    local row = self:rowAt(x, y)
    if row > 0 and row <= #self.items then
        self.selected = row
        self.target:populateActionList()
    end
end

function WeaponUpgradeUI.onActionListMouseDown(self, x, y)
    if #self.items == 0 then return end

    local row = self:rowAt(x, y)
    if row > 0 and row <= #self.items then
        self.selected = row
        local action = self.items[row].item
        self.target.btnApply:setEnable(action ~= nil)
        self.target:setInfoText(action and action.description or getText("IGUI_WeaponUpgradeUI_NoActions"))
    end
end

function WeaponUpgradeUI.doDrawCategoryItem(self, y, item, alt)
    local category = item.item
    local isSelected = self.selected == item.index
    if isSelected then
        self:drawRect(0, y, self.width, self.itemheight, 0.35, 0.25, 0.35, 0.55)
    elseif alt then
        self:drawRect(0, y, self.width, self.itemheight, 0.08, 0.08, 0.08, 0.12)
    end

    local iconSize = self.itemheight - 8
    local textX = 6
    if category.texture then
        self:drawTextureScaled(category.texture, textX, y + 4, iconSize, iconSize, 1, 1, 1, 1)
        textX = textX + iconSize + 6
    end

    local scrollbarWidth = self.vscroll and self.vscroll:getWidth() or 0
    local maxTextWidth = self.width - textX - scrollbarWidth - 8
    local title = fitText(UIFont.Small, category.title, maxTextWidth)
    local status = fitText(UIFont.Small, category.status, maxTextWidth)
    self:drawText(title, textX, y + 3, 1, 1, 1, 1, UIFont.Small)
    self:drawText(status, textX, y + FONT_HGT_SMALL + 4, 0.7, 0.7, 0.7, 1, UIFont.Small)
    return y + self.itemheight
end

function WeaponUpgradeUI.doDrawActionItem(self, y, item, alt)
    local action = item.item
    local isSelected = self.selected == item.index
    if isSelected then
        self:drawRect(0, y, self.width, self.itemheight, 0.35, 0.25, 0.35, 0.55)
    elseif alt then
        self:drawRect(0, y, self.width, self.itemheight, 0.08, 0.08, 0.08, 0.12)
    end

    local iconSize = self.itemheight - 8
    local textX = 6
    if action.texture then
        self:drawTextureScaled(action.texture, textX, y + 4, iconSize, iconSize, 1, 1, 1, 1)
        textX = textX + iconSize + 6
    end

    local scrollbarWidth = self.vscroll and self.vscroll:getWidth() or 0
    local maxTextWidth = self.width - textX - scrollbarWidth - 8
    local label = fitText(UIFont.Small, action.label, maxTextWidth)
    local description = fitText(UIFont.Small, action.description, maxTextWidth)
    self:drawText(label, textX, y + 3, 1, 1, 1, 1, UIFont.Small)
    self:drawText(description, textX, y + FONT_HGT_SMALL + 4, 0.7, 0.7, 0.7, 1, UIFont.Small)
    return y + self.itemheight
end

function WeaponUpgradeUI:update()
    ISPanelJoypad.update(self)

    local weapon = self:getWeapon()
    if not weapon then
        self:close()
        return
    end

    self.refreshTicks = self.refreshTicks + 1
    if self.refreshTicks >= REFRESH_INTERVAL then
        self.refreshTicks = 0
        local selectedCategory = self:getSelectedCategory()
        local selectedAction = self:getSelectedAction()
        self:refreshUpgradeData(selectedCategory and selectedCategory.key or nil,
            selectedAction and selectedAction.key or nil)
    end
end

function WeaponUpgradeUI:prerender()
    ISPanelJoypad.prerender(self)
    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g,
        self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g,
        self.borderColor.b)
end

function WeaponUpgradeUI:close()
    WeaponUpgradeUI.instance = nil
    self:setVisible(false)
    self:removeFromUIManager()
end

function WeaponUpgradeUI:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData)
    self:setISButtonForA(self.btnApply)
    self:setISButtonForB(self.btnClose)
end

function WeaponUpgradeUI:new(x, y, width, height, player, weapon)
    local o = ISPanelJoypad.new(self, x, y, width, height)
    o.player = player
    o.weapon = weapon
    o.refreshTicks = 0
    o.backgroundColor = { r = 0.06, g = 0.06, b = 0.07, a = 0.94 }
    o.borderColor = { r = 0.35, g = 0.35, b = 0.38, a = 1 }
    o.moveWithMouse = true
    return o
end

return WeaponUpgradeUI
