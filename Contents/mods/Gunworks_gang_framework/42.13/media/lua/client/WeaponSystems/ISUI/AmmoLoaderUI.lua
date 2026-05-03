require("ISUI/ISPanelJoypad")
require("ISUI/ISButton")
require("ISUI/ISLabel")
require("ISUI/ISScrollingListBox")
require("ISUI/ISItemDropBox")

local Ammo = require("WeaponSystems/Utils/Ammo")
local GunworksKeybinds = require("WeaponSystems/ISUI/GunworksKeybinds")

-----------------------------------------------------------
-- AmmoLoaderUI
-- Unified drag-and-drop ammo loading interface.
-- Accepts both firearms (non-magazine ranged) and
-- magazines in a single panel.
-----------------------------------------------------------

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local UI_BORDER_SPACING = 10
local BUTTON_HGT = FONT_HGT_SMALL + 6

-----------------------------------------------------------
-- Helpers: item type detection
-----------------------------------------------------------
local function isFirearm(item)
    if not item then return false end
    if not instanceof(item, "HandWeapon") then return false end
    if not item:isRanged() then return false end
    if item:getMagazineType() then return false end
    return true
end

local function isMagazine(item)
    if not item then return false end
    if instanceof(item, "HandWeapon") then return false end
    return item:getMaxAmmo() > 0
end

local function isAcceptedItem(item)
    if not item then return false end
    if not item:isInPlayerInventory() then return false end
    return isFirearm(item) or isMagazine(item)
end

-----------------------------------------------------------
-- Item Drop Panel
-----------------------------------------------------------
AmmoLoaderDropPanel = ISPanel:derive("AmmoLoaderDropPanel")

function AmmoLoaderDropPanel:initialise()
    ISPanel.initialise(self)
end

function AmmoLoaderDropPanel:createChildren()
    local y = UI_BORDER_SPACING

    self.titleLabel = ISLabel:new(self.width / 2, y, FONT_HGT_SMALL,
        getText("IGUI_AmmoLoader_DropLabel"), 1, 1, 1, 1, UIFont.Small, true)
    self.titleLabel.center = true
    self.titleLabel:initialise()
    self.titleLabel:instantiate()
    self:addChild(self.titleLabel)

    y = y + FONT_HGT_SMALL + UI_BORDER_SPACING

    local boxSize = 64
    self.itemDropBox = ISItemDropBox:new(
        (self.width - boxSize) / 2,
        y,
        boxSize,
        boxSize,
        true,
        self,
        AmmoLoaderDropPanel.onItemAdd,
        AmmoLoaderDropPanel.onItemRemove,
        AmmoLoaderDropPanel.onItemVerify,
        nil
    )
    self.itemDropBox.allowDropAlways = true
    self.itemDropBox.player = self.player
    self.itemDropBox:initialise()
    self.itemDropBox:setToolTip(true, getText("IGUI_AmmoLoader_DragTooltip"))
    self.itemDropBox.toolTipTextItem = getText("IGUI_ClickToRemove") or "Click to remove"
    self:addChild(self.itemDropBox)

    y = y + boxSize + UI_BORDER_SPACING

    self.itemNameLabel = ISLabel:new(self.width / 2, y, FONT_HGT_SMALL, "", 0.8, 0.8, 0.8, 1, UIFont.Small, true)
    self.itemNameLabel.center = true
    self.itemNameLabel:initialise()
    self.itemNameLabel:instantiate()
    self:addChild(self.itemNameLabel)

    y = y + FONT_HGT_SMALL + 5

    self.ammoCountLabel = ISLabel:new(self.width / 2, y, FONT_HGT_SMALL, "", 0.6, 0.8, 0.6, 1, UIFont.Small, true)
    self.ammoCountLabel.center = true
    self.ammoCountLabel:initialise()
    self.ammoCountLabel:instantiate()
    self:addChild(self.ammoCountLabel)
end

function AmmoLoaderDropPanel:onItemAdd(items)
    for _, item in ipairs(items) do
        if self:onItemVerify(item) then
            self.itemDropBox:setStoredItem(item)
            self:updateItemInfo(item)
            if self.onItemAddedCallback then
                self.onItemAddedCallback(self.funcTarget, item)
            end
            return
        end
    end
end

function AmmoLoaderDropPanel:onItemRemove()
    self.itemDropBox:setStoredItem(nil)
    self:updateItemInfo(nil)
    if self.onItemRemovedCallback then
        self.onItemRemovedCallback(self.funcTarget)
    end
end

function AmmoLoaderDropPanel:onItemVerify(item)
    return isAcceptedItem(item)
end

function AmmoLoaderDropPanel:updateItemInfo(targetItem)
    if targetItem then
        local displayName = targetItem:getDisplayName() or targetItem:getName()
        local maxWidth = self.width - 10
        local nameWidth = getTextManager():MeasureStringX(UIFont.Small, displayName)
        if nameWidth > maxWidth then
            while string.len(displayName) > 1 do
                displayName = string.sub(displayName, 1, string.len(displayName) - 1)
                if getTextManager():MeasureStringX(UIFont.Small, displayName .. "...") <= maxWidth then
                    break
                end
            end
            displayName = displayName .. "..."
        end
        self.itemNameLabel:setName(displayName)
        local current = targetItem:getCurrentAmmoCount()
        local max = targetItem:getMaxAmmo()
        self.ammoCountLabel:setName(current .. " / " .. max)
    else
        self.itemNameLabel:setName("")
        self.ammoCountLabel:setName("")
    end
end

function AmmoLoaderDropPanel:getItem()
    return self.itemDropBox and self.itemDropBox.storedItem
end

function AmmoLoaderDropPanel:prerender()
    ISPanel.prerender(self)
    self:drawRect(0, 0, self.width, self.height, 0.8, 0.1, 0.1, 0.1)
    self:drawRectBorder(0, 0, self.width, self.height, 1, 0.4, 0.4, 0.4)
end

function AmmoLoaderDropPanel:new(x, y, width, height, player)
    local o = ISPanel.new(self, x, y, width, height)
    o.player = player
    o.backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.8 }
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    return o
end

-----------------------------------------------------------
-- AmmoSlider - Horizontal integer slider
-----------------------------------------------------------
AmmoSlider = ISPanel:derive("AmmoSlider")

function AmmoSlider:initialise()
    ISPanel.initialise(self)
end

function AmmoSlider:createChildren()
    self.valueLabel = ISLabel:new(self.width / 2, 0, FONT_HGT_SMALL, "0", 1, 1, 0.5, 1, UIFont.Small, true)
    self.valueLabel.center = true
    self.valueLabel:initialise()
    self.valueLabel:instantiate()
    self:addChild(self.valueLabel)
end

function AmmoSlider:setValues(currentVal, maxVal)
    self.currentValue = math.max(0, math.min(currentVal or 0, maxVal or 0))
    self.maxValue = maxVal or 0
    self:updateLabel()
end

function AmmoSlider:setValue(val)
    self.currentValue = math.max(0, math.min(val, self.maxValue))
    self:updateLabel()
end

function AmmoSlider:getValue()
    return self.currentValue
end

function AmmoSlider:updateLabel()
    self.valueLabel:setName(tostring(self.currentValue))
end

function AmmoSlider:getTrackBounds()
    local trackY = FONT_HGT_SMALL + 6
    local trackH = 8
    local trackX = 10
    local trackW = self.width - 20
    return trackX, trackY, trackW, trackH
end

function AmmoSlider:prerender()
    ISPanel.prerender(self)

    local trackX, trackY, trackW, trackH = self:getTrackBounds()

    -- Track background
    self:drawRect(trackX, trackY, trackW, trackH, 0.8, 0.15, 0.15, 0.15)
    self:drawRectBorder(trackX, trackY, trackW, trackH, 1, 0.4, 0.4, 0.4)

    -- Filled portion
    if self.maxValue > 0 then
        local fillW = (self.currentValue / self.maxValue) * trackW
        self:drawRect(trackX, trackY, fillW, trackH, 0.8, 0.3, 0.6, 0.3)
    end

    -- Thumb
    if self.maxValue > 0 then
        local thumbW = 8
        local thumbH = trackH + 8
        local thumbX = trackX + (self.currentValue / self.maxValue) * trackW - thumbW / 2
        local thumbY = trackY - 4
        self:drawRect(thumbX, thumbY, thumbW, thumbH, 1, 0.8, 0.8, 0.8)
        self:drawRectBorder(thumbX, thumbY, thumbW, thumbH, 1, 0.5, 0.5, 0.5)
    end
end

function AmmoSlider:onMouseDown(x, y)
    self.dragging = true
    self:updateValueFromMouse(x)
    return true
end

function AmmoSlider:onMouseUp(x, y)
    self.dragging = false
    return true
end

function AmmoSlider:onMouseMove(dx, dy)
    if self.dragging then
        self:updateValueFromMouse(self:getMouseX())
    end
end

function AmmoSlider:onMouseMoveOutside(dx, dy)
    if self.dragging then
        self:updateValueFromMouse(self:getMouseX())
    end
end

function AmmoSlider:onMouseUpOutside(x, y)
    self.dragging = false
    return true
end

function AmmoSlider:updateValueFromMouse(mouseX)
    if self.maxValue <= 0 then return end
    local trackX, _, trackW, _ = self:getTrackBounds()
    local ratio = math.max(0, math.min(1, (mouseX - trackX) / trackW))
    local newValue = math.floor(ratio * self.maxValue + 0.5)
    if newValue ~= self.currentValue then
        self.currentValue = newValue
        self:updateLabel()
        if self.onValueChanged then
            self.onValueChanged(self.target, newValue)
        end
    end
end

function AmmoSlider:new(x, y, width, height)
    local o = ISPanel.new(self, x, y, width, height)
    o.currentValue = 0
    o.maxValue = 0
    o.dragging = false
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    return o
end

-----------------------------------------------------------
-- AmmoLoaderUI - Main Panel
-----------------------------------------------------------
AmmoLoaderUI = ISPanelJoypad:derive("AmmoLoaderUI")
AmmoLoaderUI.instance = nil

-----------------------------------------------------------
-- Static open / toggle
-----------------------------------------------------------
function AmmoLoaderUI.OpenPanel(player)
    if not player then return end

    if AmmoLoaderUI.instance then
        AmmoLoaderUI.instance:close()
    end

    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    local width = 450
    local height = 350

    local x = (screenW - width) / 2
    local y = (screenH - height) / 2

    local ui = AmmoLoaderUI:new(x, y, width, height, player)
    ui:initialise()
    ui:instantiate()
    ui:setVisible(true)
    ui:addToUIManager()

    AmmoLoaderUI.instance = ui

    local playerNum = player:getPlayerNum()
    if getJoypadData(playerNum) then
        setJoypadFocus(playerNum, ui)
    end
end

function AmmoLoaderUI.TogglePanel(player)
    if AmmoLoaderUI.instance then
        AmmoLoaderUI.instance:close()
    else
        AmmoLoaderUI.OpenPanel(player)
    end
end

-----------------------------------------------------------
-- Lifecycle
-----------------------------------------------------------
function AmmoLoaderUI:initialise()
    ISPanelJoypad.initialise(self)
end

function AmmoLoaderUI:createChildren()
    ISPanelJoypad.createChildren(self)

    local y = UI_BORDER_SPACING

    self.titleLabel = ISLabel:new(self.width / 2, y, FONT_HGT_MEDIUM,
        getText("IGUI_AmmoLoader_Title"), 1, 1, 1, 1, UIFont.Medium, true)
    self.titleLabel.center = true
    self.titleLabel:initialise()
    self.titleLabel:instantiate()
    self:addChild(self.titleLabel)

    y = y + FONT_HGT_MEDIUM + UI_BORDER_SPACING

    local panelWidth = 150
    local panelHeight = 160

    self.dropPanel = AmmoLoaderDropPanel:new(UI_BORDER_SPACING, y, panelWidth, panelHeight, self.player)
    self.dropPanel.funcTarget = self
    self.dropPanel.onItemAddedCallback = self.onItemAdded
    self.dropPanel.onItemRemovedCallback = self.onItemRemoved
    self.dropPanel:initialise()
    self.dropPanel:instantiate()
    self:addChild(self.dropPanel)

    local rightX = self.dropPanel:getRight() + UI_BORDER_SPACING
    local rightWidth = self.width - rightX - UI_BORDER_SPACING

    self.rightPanel = ISPanel:new(rightX, y, rightWidth, panelHeight)
    self.rightPanel:initialise()
    self.rightPanel:instantiate()
    self.rightPanel.backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.8 }
    self.rightPanel.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    self:addChild(self.rightPanel)

    self.ammoTypeTitleLabel = ISLabel:new(rightWidth / 2, UI_BORDER_SPACING, FONT_HGT_SMALL,
        getText("IGUI_AmmoType") or "Ammo Type", 1, 1, 1, 1, UIFont.Small, true)
    self.ammoTypeTitleLabel.center = true
    self.ammoTypeTitleLabel:initialise()
    self.ammoTypeTitleLabel:instantiate()
    self.rightPanel:addChild(self.ammoTypeTitleLabel)

    self.ammoList = ISScrollingListBox:new(5, UI_BORDER_SPACING + FONT_HGT_SMALL + 5, rightWidth - 10,
        panelHeight - FONT_HGT_SMALL - UI_BORDER_SPACING * 2 - 5)
    self.ammoList:initialise()
    self.ammoList:instantiate()
    self.ammoList.itemheight = BUTTON_HGT
    self.ammoList.selected = 0
    self.ammoList.font = UIFont.Small
    self.ammoList.doDrawItem = AmmoLoaderUI.doDrawAmmoItem
    self.ammoList.target = self
    self.ammoList.onMouseDown = AmmoLoaderUI.onAmmoListMouseDown
    self.ammoList.backgroundColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.9 }
    self.ammoList.borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 1 }
    self.rightPanel:addChild(self.ammoList)

    y = self.dropPanel:getBottom() + UI_BORDER_SPACING

    -- Amount controls row: [-] slider [+]
    local controlX = UI_BORDER_SPACING
    local controlWidth = self.width - UI_BORDER_SPACING * 2
    local btnSize = BUTTON_HGT + 4

    self.btnMinus = ISButton:new(controlX, y, btnSize, btnSize, "-", self, AmmoLoaderUI.onAmountButton)
    self.btnMinus.internal = "MINUS"
    self.btnMinus:initialise()
    self.btnMinus:instantiate()
    self.btnMinus.borderColor = { r = 0.7, g = 0.7, b = 0.7, a = 0.5 }
    self:addChild(self.btnMinus)

    local sliderX = self.btnMinus:getRight() + 5
    local sliderEndX = controlX + controlWidth - btnSize - 5
    local sliderWidth = sliderEndX - sliderX
    local sliderHeight = FONT_HGT_SMALL + 20

    self.ammoSlider = AmmoSlider:new(sliderX, y + (btnSize - sliderHeight) / 2, sliderWidth, sliderHeight)
    self.ammoSlider.target = self
    self.ammoSlider.onValueChanged = AmmoLoaderUI.onSliderChanged
    self.ammoSlider:initialise()
    self.ammoSlider:instantiate()
    self:addChild(self.ammoSlider)

    self.btnPlus = ISButton:new(sliderEndX, y, btnSize, btnSize, "+", self, AmmoLoaderUI.onAmountButton)
    self.btnPlus.internal = "PLUS"
    self.btnPlus:initialise()
    self.btnPlus:instantiate()
    self.btnPlus.borderColor = { r = 0.7, g = 0.7, b = 0.7, a = 0.5 }
    self:addChild(self.btnPlus)

    y = y + math.max(btnSize, sliderHeight) + 5

    -- MAX button centered
    local maxBtnW = 60
    self.btnMax = ISButton:new((self.width - maxBtnW) / 2, y, maxBtnW, BUTTON_HGT, "MAX", self,
        AmmoLoaderUI.onAmountButton)
    self.btnMax.internal = "MAX"
    self.btnMax:initialise()
    self.btnMax:instantiate()
    self.btnMax.borderColor = { r = 0.7, g = 0.7, b = 0.7, a = 0.5 }
    self:addChild(self.btnMax)

    y = self.btnMax:getBottom() + UI_BORDER_SPACING

    local buttonWidth = (self.width - UI_BORDER_SPACING * 3) / 2

    self.btnLoad = ISButton:new(UI_BORDER_SPACING, y, buttonWidth, BUTTON_HGT, getText("IGUI_Load") or "Load", self,
        AmmoLoaderUI.onButton)
    self.btnLoad.internal = "LOAD"
    self.btnLoad:initialise()
    self.btnLoad:instantiate()
    self.btnLoad:enableAcceptColor()
    self:addChild(self.btnLoad)

    self.btnClose = ISButton:new(self.btnLoad:getRight() + UI_BORDER_SPACING, y, buttonWidth, BUTTON_HGT,
        getText("UI_Close") or "Close", self, AmmoLoaderUI.onButton)
    self.btnClose.internal = "CLOSE"
    self.btnClose:initialise()
    self.btnClose:instantiate()
    self.btnClose:enableCancelColor()
    self:addChild(self.btnClose)

    self:setHeight(self.btnLoad:getBottom() + UI_BORDER_SPACING)

    self.transferAmount = 0
    self.maxTransferAmount = 0
    self.selectedAmmoType = nil

    self.btnLoad:setEnable(false)
end

-----------------------------------------------------------
-- Item added/removed callbacks
-----------------------------------------------------------
function AmmoLoaderUI:onItemAdded(targetItem)
    self:populateAmmoList()
    self:updateMaxAmount()
end

function AmmoLoaderUI:onItemRemoved()
    self.ammoList:clear()
    self.selectedAmmoType = nil
    self.transferAmount = 0
    self.maxTransferAmount = 0
    self.ammoSlider:setValues(0, 0)
    self.btnLoad:setEnable(false)
end

-----------------------------------------------------------
-- Populate ammo list
-----------------------------------------------------------
function AmmoLoaderUI:populateAmmoList()
    self.ammoList:clear()
    self.selectedAmmoType = nil

    local targetItem = self.dropPanel:getItem()
    if not targetItem then return end

    local ammoTypes = self:getAvailableAmmoTypes(targetItem)

    for _, ammoData in ipairs(ammoTypes) do
        self.ammoList:addItem(ammoData.name, ammoData)
    end

    if #self.ammoList.items > 0 then
        self.ammoList.selected = 1
        self.selectedAmmoType = self.ammoList.items[1].item.ammoTypeKey
    end
end

function AmmoLoaderUI:getAvailableAmmoTypes(targetItem)
    local result = {}
    local inventory = self.player:getInventory()

    local ammoProfile = Ammo.ItemAmmoFamily[targetItem:getFullType()]
    local bulletTypes = ammoProfile and Ammo.GetBulletTypesForFamily(ammoProfile)
    if bulletTypes then
        for _, ammoTypeKey in ipairs(bulletTypes) do
            local count = inventory:getCountTypeRecurse(ammoTypeKey)
            local script = getScriptManager():FindItem(ammoTypeKey)
            local name = script and script:getDisplayName() or ammoTypeKey
            local tex = script and script:getNormalTexture() or nil
            table.insert(result, {
                ammoTypeKey = ammoTypeKey,
                name = name,
                count = count,
                texture = tex
            })
        end
    else
        local defaultAmmoType = targetItem:getAmmoType()
        if defaultAmmoType then
            local ammoTypeKey = defaultAmmoType:getItemKey()
            local count = inventory:getCountTypeRecurse(ammoTypeKey)
            local script = getScriptManager():FindItem(ammoTypeKey)
            local name = script and script:getDisplayName() or ammoTypeKey
            local tex = script and script:getNormalTexture() or nil
            table.insert(result, {
                ammoTypeKey = ammoTypeKey,
                name = name,
                count = count,
                texture = tex
            })
        end
    end

    return result
end

-----------------------------------------------------------
-- Draw ammo list item
-----------------------------------------------------------
function AmmoLoaderUI.doDrawAmmoItem(self, y, item, alt)
    local ammoData = item.item
    local isSelected = self.selected == item.index

    if isSelected then
        self:drawRect(0, y, self.width, self.itemheight, 0.3, 0.3, 0.5, 0.8)
    elseif alt then
        self:drawRect(0, y, self.width, self.itemheight, 0.1, 0.1, 0.1, 0.1)
    end

    local textY = y + (self.itemheight - FONT_HGT_SMALL) / 2
    local textX = 5
    local rightPadding = 5
    local scrollbarWidth = self.vscroll and self.vscroll:getWidth() or 0

    if ammoData.texture then
        local iconSize = self.itemheight - 4
        self:drawTextureScaled(ammoData.texture, textX, y + 2, iconSize, iconSize, 1, 1, 1, 1)
        textX = textX + iconSize + 4
    end

    local countText = "x" .. ammoData.count
    local countWidth = getTextManager():MeasureStringX(UIFont.Small, countText)
    local countX = self.width - scrollbarWidth - countWidth - rightPadding
    local countColor = ammoData.count > 0 and { r = 0.5, g = 1, b = 0.5 } or { r = 1, g = 0.4, b = 0.4 }
    self:drawText(countText, countX, textY, countColor.r, countColor.g, countColor.b, 1,
        UIFont.Small)

    local availableNameWidth = math.max(0, countX - textX - 6)
    local displayName = ammoData.name
    if getTextManager():MeasureStringX(UIFont.Small, displayName) > availableNameWidth then
        while string.len(displayName) > 1 do
            displayName = string.sub(displayName, 1, string.len(displayName) - 1)
            if getTextManager():MeasureStringX(UIFont.Small, displayName .. "...") <= availableNameWidth then
                displayName = displayName .. "..."
                break
            end
        end
    end

    local nameColor = ammoData.count > 0 and { r = 1, g = 1, b = 1 } or { r = 1, g = 0.4, b = 0.4 }
    self:drawText(displayName, textX, textY, nameColor.r, nameColor.g, nameColor.b, 1, UIFont.Small)

    return y + self.itemheight
end

function AmmoLoaderUI.onAmmoListMouseDown(self, x, y)
    if #self.items == 0 then return end

    local row = self:rowAt(x, y)
    if row > 0 and row <= #self.items then
        self.selected = row
        local parent = self.target
        parent.selectedAmmoType = self.items[row].item.ammoTypeKey
        parent:updateMaxAmount()
    end
end

-----------------------------------------------------------
-- Update max amount
-----------------------------------------------------------
function AmmoLoaderUI:updateMaxAmount()
    local targetItem = self.dropPanel:getItem()
    if not targetItem or not self.selectedAmmoType then
        self.maxTransferAmount = 0
        self.transferAmount = 0
        self.ammoSlider:setValues(0, 0)
        self.btnLoad:setEnable(false)
        return
    end

    local inventory = self.player:getInventory()
    local availableAmmo = inventory:getCountTypeRecurse(self.selectedAmmoType)
    local currentAmmo = targetItem:getCurrentAmmoCount()
    local maxAmmo = targetItem:getMaxAmmo()
    local freeSpace = maxAmmo - currentAmmo

    self.maxTransferAmount = math.min(availableAmmo, freeSpace)

    if self.transferAmount > self.maxTransferAmount then
        self.transferAmount = self.maxTransferAmount
    end

    self.ammoSlider:setValues(self.transferAmount, self.maxTransferAmount)
    self.btnLoad:setEnable(self.transferAmount > 0)
end

-----------------------------------------------------------
-- Slider callback
-----------------------------------------------------------
function AmmoLoaderUI:onSliderChanged(newValue)
    self.transferAmount = newValue
    self.btnLoad:setEnable(self.transferAmount > 0)
end

-----------------------------------------------------------
-- Amount button handlers (fine-tuning)
-----------------------------------------------------------
function AmmoLoaderUI:onAmountButton(button)
    if button.internal == "PLUS" then
        if self.transferAmount < self.maxTransferAmount then
            self.transferAmount = self.transferAmount + 1
        end
    elseif button.internal == "MINUS" then
        if self.transferAmount > 0 then
            self.transferAmount = self.transferAmount - 1
        end
    elseif button.internal == "MAX" then
        self.transferAmount = self.maxTransferAmount
    end

    self.ammoSlider:setValue(self.transferAmount)
    self.btnLoad:setEnable(self.transferAmount > 0)
end

-----------------------------------------------------------
-- Main button handlers
-----------------------------------------------------------
function AmmoLoaderUI:onButton(button)
    if button.internal == "LOAD" then
        self:performLoad()
    elseif button.internal == "CLOSE" then
        self:close()
    end
end

-----------------------------------------------------------
-- Perform load – detects item type automatically
-----------------------------------------------------------
function AmmoLoaderUI:performLoad()
    local targetItem = self.dropPanel:getItem()
    if not targetItem then return end
    if self.transferAmount <= 0 then return end
    if not self.selectedAmmoType then return end

    ISInventoryPaneContextMenu.transferIfNeeded(self.player, targetItem)
    ISInventoryPaneContextMenu.transferBullets(self.player, self.selectedAmmoType,
        targetItem:getCurrentAmmoCount(),
        targetItem:getCurrentAmmoCount() + self.transferAmount)

    if isFirearm(targetItem) then
        Ammo.AmmoProfileSetter(targetItem, self.selectedAmmoType)
        ISInventoryPaneContextMenu.equipWeapon(targetItem, true, false, self.player:getPlayerNum())
        ISTimedActionQueue.add(ISReloadWeaponAction:new(self.player, targetItem, self.transferAmount))
    else
        Ammo.MagazineAmmoProfileSetter(targetItem, self.selectedAmmoType)
        ISTimedActionQueue.add(ISLoadBulletsInMagazine:new(self.player, targetItem, self.transferAmount, self.transferAmount))
    end

    self.ammoSlider:setValues(self.transferAmount, self.maxTransferAmount)
end

-----------------------------------------------------------
-- Update loop
-----------------------------------------------------------
function AmmoLoaderUI:update()
    ISPanelJoypad.update(self)

    for _, listItem in ipairs(self.ammoList.items) do
        local ammoData = listItem.item
        ammoData.count = self.player:getInventory():getCountTypeRecurse(ammoData.ammoTypeKey)
    end

    local targetItem = self.dropPanel:getItem()
    if targetItem then
        self.dropPanel:updateItemInfo(targetItem)
        self:updateMaxAmount()
    end

    if targetItem and not self.player:getInventory():containsID(targetItem:getID()) then
        self.dropPanel:onItemRemove()
    end
end

-----------------------------------------------------------
-- Render
-----------------------------------------------------------
function AmmoLoaderUI:prerender()
    ISPanelJoypad.prerender(self)
    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g,
        self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g,
        self.borderColor.b)
end

-----------------------------------------------------------
-- Close
-----------------------------------------------------------
function AmmoLoaderUI:close()
    AmmoLoaderUI.instance = nil

    local playerNum = self.player:getPlayerNum()
    if JoypadState.players[playerNum + 1] then
        setJoypadFocus(playerNum, nil)
    end

    self:setVisible(false)
    self:removeFromUIManager()
end

-----------------------------------------------------------
-- Joypad support
-----------------------------------------------------------
function AmmoLoaderUI:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData)
    self:setISButtonForA(self.btnLoad)
    self:setISButtonForB(self.btnClose)
end

function AmmoLoaderUI:onJoypadDown(button, joypadData)
    if button == Joypad.DPadUp then
        if self.transferAmount < self.maxTransferAmount then
            self.transferAmount = self.transferAmount + 1
            self.ammoSlider:setValue(self.transferAmount)
            self.btnLoad:setEnable(self.transferAmount > 0)
        end
    elseif button == Joypad.DPadDown then
        if self.transferAmount > 0 then
            self.transferAmount = self.transferAmount - 1
            self.ammoSlider:setValue(self.transferAmount)
            self.btnLoad:setEnable(self.transferAmount > 0)
        end
    elseif button == Joypad.DPadLeft then
        if self.ammoList.selected > 1 then
            self.ammoList.selected = self.ammoList.selected - 1
            self.selectedAmmoType = self.ammoList.items[self.ammoList.selected].item.ammoTypeKey
            self:updateMaxAmount()
        end
    elseif button == Joypad.DPadRight then
        if self.ammoList.selected < #self.ammoList.items then
            self.ammoList.selected = self.ammoList.selected + 1
            self.selectedAmmoType = self.ammoList.items[self.ammoList.selected].item.ammoTypeKey
            self:updateMaxAmount()
        end
    else
        ISPanelJoypad.onJoypadDown(self, button, joypadData)
    end
end

-----------------------------------------------------------
-- Constructor
-----------------------------------------------------------
function AmmoLoaderUI:new(x, y, width, height, player)
    local o = ISPanelJoypad.new(self, x, y, width, height)
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.9 }
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    o.moveWithMouse = true
    o.player = player
    o.playerNum = player:getPlayerNum()
    o.transferAmount = 0
    o.maxTransferAmount = 0
    o.selectedAmmoType = nil
    return o
end

-----------------------------------------------------------
-- Keyboard handler – P key
-----------------------------------------------------------

local KEYBIND_OPEN_LOADER_UI = "Gunworks_OpenLoaderUI"
local function onKeyPressed(key)
    local player = getSpecificPlayer(0)
    if not player then return end

    if key == GunworksKeybinds.GetBoundKey(KEYBIND_OPEN_LOADER_UI, Keyboard.KEY_O) then
        if player and not player:isDead() then
            if UIManager.getSpeedControls() and UIManager.getSpeedControls():getCurrentGameSpeed() == 0 then
                return
            end
            AmmoLoaderUI.TogglePanel(player)
        end
    end
end

Events.OnKeyPressed.Add(onKeyPressed)
