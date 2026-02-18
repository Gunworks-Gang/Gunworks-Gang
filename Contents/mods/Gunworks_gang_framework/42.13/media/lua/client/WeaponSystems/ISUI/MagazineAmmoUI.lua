require("ISUI/ISPanelJoypad")
require("ISUI/ISButton")
require("ISUI/ISLabel")
require("ISUI/ISScrollingListBox")
require("ISUI/ISItemDropBox")

local Ammo = require("WeaponSystems/Utils/AmmoUtils")

-----------------------------------------------------------
-- Magazine Ammo UI
-- A drag-and-drop interface for loading ammo into magazines
-----------------------------------------------------------

MagazineAmmoUI = ISPanelJoypad:derive("MagazineAmmoUI")
MagazineAmmoUI.instance = nil

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local UI_BORDER_SPACING = 10
local BUTTON_HGT = FONT_HGT_SMALL + 6

-----------------------------------------------------------
-- Magazine Drop Panel - handles drag and drop of magazines
-----------------------------------------------------------
MagazineDropPanel = ISPanel:derive("MagazineDropPanel")

function MagazineDropPanel:initialise()
    ISPanel.initialise(self)
end

function MagazineDropPanel:createChildren()
    local y = UI_BORDER_SPACING

    self.titleLabel = ISLabel:new(self.width / 2, y, FONT_HGT_SMALL,
        getText("IGUI_DropMagazine") or "Drop Magazine Here", 1, 1, 1, 1, UIFont.Small, true)
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
        MagazineDropPanel.onItemAdd,
        MagazineDropPanel.onItemRemove,
        MagazineDropPanel.onItemVerify,
        nil
    )
    self.itemDropBox.allowDropAlways = true
    self.itemDropBox.player = self.player
    self.itemDropBox:initialise()
    self.itemDropBox:setToolTip(true, getText("IGUI_DragMagazineHere") or "Drag a magazine here")
    self.itemDropBox.toolTipTextItem = getText("IGUI_ClickToRemove") or "Click to remove"
    self:addChild(self.itemDropBox)

    y = y + boxSize + UI_BORDER_SPACING

    self.magazineNameLabel = ISLabel:new(self.width / 2, y, FONT_HGT_SMALL, "", 0.8, 0.8, 0.8, 1, UIFont.Small, true)
    self.magazineNameLabel.center = true
    self.magazineNameLabel:initialise()
    self.magazineNameLabel:instantiate()
    self:addChild(self.magazineNameLabel)

    y = y + FONT_HGT_SMALL + 5

    self.ammoCountLabel = ISLabel:new(self.width / 2, y, FONT_HGT_SMALL, "", 0.6, 0.8, 0.6, 1, UIFont.Small, true)
    self.ammoCountLabel.center = true
    self.ammoCountLabel:initialise()
    self.ammoCountLabel:instantiate()
    self:addChild(self.ammoCountLabel)
end

function MagazineDropPanel:onItemAdd(items)
    for _, item in ipairs(items) do
        if self:onItemVerify(item) then
            self.itemDropBox:setStoredItem(item)
            self:updateMagazineInfo(item)
            if self.onMagazineAdded then
                self.onMagazineAdded(self.funcTarget, item)
            end
            return
        end
    end
end

function MagazineDropPanel:onItemRemove()
    self.itemDropBox:setStoredItem(nil)
    self:updateMagazineInfo(nil)
    if self.onMagazineRemoved then
        self.onMagazineRemoved(self.funcTarget)
    end
end

function MagazineDropPanel:onItemVerify(item)
    return item:getMaxAmmo() > 0 and not instanceof(item, "HandWeapon")
end

function MagazineDropPanel:updateMagazineInfo(magazine)
    if magazine then
        self.magazineNameLabel:setName(magazine:getDisplayName() or magazine:getName())
        local current = magazine:getCurrentAmmoCount()
        local max = magazine:getMaxAmmo()
        self.ammoCountLabel:setName(current .. " / " .. max)
    else
        self.magazineNameLabel:setName("")
        self.ammoCountLabel:setName("")
    end
end

function MagazineDropPanel:getMagazine()
    return self.itemDropBox and self.itemDropBox.storedItem
end

function MagazineDropPanel:prerender()
    ISPanel.prerender(self)
    self:drawRect(0, 0, self.width, self.height, 0.8, 0.1, 0.1, 0.1)
    self:drawRectBorder(0, 0, self.width, self.height, 1, 0.4, 0.4, 0.4)
end

function MagazineDropPanel:new(x, y, width, height, player)
    local o = ISPanel.new(self, x, y, width, height)
    o.player = player
    o.backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.8 }
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    return o
end

-----------------------------------------------------------
-- Main Magazine Ammo UI
-----------------------------------------------------------
function MagazineAmmoUI.OpenPanel(player)
    if not player then return end

    if MagazineAmmoUI.instance then
        MagazineAmmoUI.instance:close()
    end

    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    local width = 450
    local height = 350

    local x = (screenW - width) / 2
    local y = (screenH - height) / 2

    local ui = MagazineAmmoUI:new(x, y, width, height, player)
    ui:initialise()
    ui:instantiate()
    ui:setVisible(true)
    ui:addToUIManager()

    MagazineAmmoUI.instance = ui

    local playerNum = player:getPlayerNum()
    if getJoypadData(playerNum) then
        setJoypadFocus(playerNum, ui)
    end
end

function MagazineAmmoUI.TogglePanel(player)
    if MagazineAmmoUI.instance then
        MagazineAmmoUI.instance:close()
    else
        MagazineAmmoUI.OpenPanel(player)
    end
end

function MagazineAmmoUI:initialise()
    ISPanelJoypad.initialise(self)
end

function MagazineAmmoUI:createChildren()
    ISPanelJoypad.createChildren(self)

    local y = UI_BORDER_SPACING

    self.titleLabel = ISLabel:new(self.width / 2, y, FONT_HGT_MEDIUM,
        getText("IGUI_MagazineAmmo_Title") or "Magazine Ammo", 1, 1, 1, 1, UIFont.Medium, true)
    self.titleLabel.center = true
    self.titleLabel:initialise()
    self.titleLabel:instantiate()
    self:addChild(self.titleLabel)

    y = y + FONT_HGT_MEDIUM + UI_BORDER_SPACING

    local panelWidth = 150
    local panelHeight = 160

    self.magazinePanel = MagazineDropPanel:new(UI_BORDER_SPACING, y, panelWidth, panelHeight, self.player)
    self.magazinePanel.funcTarget = self
    self.magazinePanel.onMagazineAdded = self.onMagazineAdded
    self.magazinePanel.onMagazineRemoved = self.onMagazineRemoved
    self.magazinePanel:initialise()
    self.magazinePanel:instantiate()
    self:addChild(self.magazinePanel)

    local middleWidth = 80
    local middleX = self.magazinePanel:getRight() + UI_BORDER_SPACING

    self.middlePanel = ISPanel:new(middleX, y, middleWidth, panelHeight)
    self.middlePanel:noBackground()
    self.middlePanel:initialise()
    self.middlePanel:instantiate()
    self:addChild(self.middlePanel)

    local midY = UI_BORDER_SPACING

    self.amountTitleLabel = ISLabel:new(middleWidth / 2, midY, FONT_HGT_SMALL, getText("IGUI_Amount") or "Amount", 1,
        1, 1, 1, UIFont.Small, true)
    self.amountTitleLabel.center = true
    self.amountTitleLabel:initialise()
    self.amountTitleLabel:instantiate()
    self.middlePanel:addChild(self.amountTitleLabel)

    midY = midY + FONT_HGT_SMALL + UI_BORDER_SPACING

    self.btnPlus = ISButton:new((middleWidth - BUTTON_HGT) / 2, midY, BUTTON_HGT, BUTTON_HGT, "+", self,
        MagazineAmmoUI.onAmountButton)
    self.btnPlus.internal = "PLUS"
    self.btnPlus:initialise()
    self.btnPlus:instantiate()
    self.btnPlus.borderColor = { r = 0.7, g = 0.7, b = 0.7, a = 0.5 }
    self.middlePanel:addChild(self.btnPlus)

    midY = self.btnPlus:getBottom() + 5

    self.amountLabel = ISLabel:new(middleWidth / 2, midY, FONT_HGT_MEDIUM, "0", 1, 1, 0.5, 1, UIFont.Medium, true)
    self.amountLabel.center = true
    self.amountLabel:initialise()
    self.amountLabel:instantiate()
    self.middlePanel:addChild(self.amountLabel)

    midY = self.amountLabel:getBottom() + 5

    self.btnMinus = ISButton:new((middleWidth - BUTTON_HGT) / 2, midY, BUTTON_HGT, BUTTON_HGT, "-", self,
        MagazineAmmoUI.onAmountButton)
    self.btnMinus.internal = "MINUS"
    self.btnMinus:initialise()
    self.btnMinus:instantiate()
    self.btnMinus.borderColor = { r = 0.7, g = 0.7, b = 0.7, a = 0.5 }
    self.middlePanel:addChild(self.btnMinus)

    midY = self.btnMinus:getBottom() + UI_BORDER_SPACING

    self.btnMax = ISButton:new((middleWidth - 50) / 2, midY, 50, BUTTON_HGT, "MAX", self,
        MagazineAmmoUI.onAmountButton)
    self.btnMax.internal = "MAX"
    self.btnMax:initialise()
    self.btnMax:instantiate()
    self.btnMax.borderColor = { r = 0.7, g = 0.7, b = 0.7, a = 0.5 }
    self.middlePanel:addChild(self.btnMax)

    local rightX = self.middlePanel:getRight() + UI_BORDER_SPACING
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
    self.ammoList.doDrawItem = MagazineAmmoUI.doDrawAmmoItem
    self.ammoList.target = self
    self.ammoList.onMouseDown = MagazineAmmoUI.onAmmoListMouseDown
    self.ammoList.backgroundColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.9 }
    self.ammoList.borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 1 }
    self.rightPanel:addChild(self.ammoList)

    y = self.magazinePanel:getBottom() + UI_BORDER_SPACING

    local buttonWidth = (self.width - UI_BORDER_SPACING * 3) / 2

    self.btnLoad = ISButton:new(UI_BORDER_SPACING, y, buttonWidth, BUTTON_HGT, getText("IGUI_Load") or "Load", self,
        MagazineAmmoUI.onButton)
    self.btnLoad.internal = "LOAD"
    self.btnLoad:initialise()
    self.btnLoad:instantiate()
    self.btnLoad:enableAcceptColor()
    self:addChild(self.btnLoad)

    self.btnClose = ISButton:new(self.btnLoad:getRight() + UI_BORDER_SPACING, y, buttonWidth, BUTTON_HGT,
        getText("UI_Close") or "Close", self, MagazineAmmoUI.onButton)
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
-- Magazine added/removed callbacks
-----------------------------------------------------------
function MagazineAmmoUI:onMagazineAdded(magazine)
    self:populateAmmoList()
    self:updateMaxAmount()
end

function MagazineAmmoUI:onMagazineRemoved()
    self.ammoList:clear()
    self.selectedAmmoType = nil
    self.transferAmount = 0
    self.maxTransferAmount = 0
    self:updateAmountLabel()
    self.btnLoad:setEnable(false)
end

-----------------------------------------------------------
-- Populate ammo list based on magazine's AmmoProfile
-----------------------------------------------------------
function MagazineAmmoUI:populateAmmoList()
    self.ammoList:clear()
    self.selectedAmmoType = nil

    local magazine = self.magazinePanel:getMagazine()
    if not magazine then return end

    local ammoTypes = self:getAvailableAmmoTypes(magazine)

    for _, ammoData in ipairs(ammoTypes) do
        self.ammoList:addItem(ammoData.name, ammoData)
    end

    if #self.ammoList.items > 0 then
        self.ammoList.selected = 1
        self.selectedAmmoType = self.ammoList.items[1].item.ammoTypeKey
    end
end

function MagazineAmmoUI:getAvailableAmmoTypes(magazine)
    local result = {}
    local inventory = self.player:getInventory()

    local ammoProfile = Ammo.MagazineAmmoProfile[magazine:getFullType()]
    if ammoProfile and Ammo and Ammo.AmmoProfilesList and Ammo.AmmoProfilesList[ammoProfile] then
        for _, ammoTypeKey in ipairs(Ammo.AmmoProfilesList[ammoProfile]) do
            local count = inventory:getCountTypeRecurse(ammoTypeKey)
            local script = getScriptManager():FindItem(ammoTypeKey)
            local name = script and script:getDisplayName() or ammoTypeKey
            table.insert(result, {
                ammoTypeKey = ammoTypeKey,
                name = name,
                count = count
            })
        end
    else
        local defaultAmmoType = magazine:getAmmoType()
        if defaultAmmoType then
            local ammoTypeKey = defaultAmmoType:getItemKey()
            local count = inventory:getCountTypeRecurse(ammoTypeKey)
            local script = getScriptManager():FindItem(ammoTypeKey)
            local name = script and script:getDisplayName() or ammoTypeKey
            table.insert(result, {
                ammoTypeKey = ammoTypeKey,
                name = name,
                count = count
            })
        end
    end

    return result
end

-----------------------------------------------------------
-- Draw ammo list item
-----------------------------------------------------------
function MagazineAmmoUI.doDrawAmmoItem(self, y, item, alt)
    local ammoData = item.item
    local isSelected = self.selected == item.index

    if isSelected then
        self:drawRect(0, y, self.width, self.itemheight, 0.3, 0.3, 0.5, 0.8)
    elseif alt then
        self:drawRect(0, y, self.width, self.itemheight, 0.1, 0.1, 0.1, 0.1)
    end

    local textY = y + (self.itemheight - FONT_HGT_SMALL) / 2
    self:drawText(ammoData.name, 5, textY, 1, 1, 1, 1, UIFont.Small)

    local countText = "x" .. ammoData.count
    local countWidth = getTextManager():MeasureStringX(UIFont.Small, countText)
    local countColor = ammoData.count > 0 and { r = 0.5, g = 1, b = 0.5 } or { r = 1, g = 0.5, b = 0.5 }
    self:drawText(countText, self.width - countWidth - 5, textY, countColor.r, countColor.g, countColor.b, 1,
        UIFont.Small)

    return y + self.itemheight
end

function MagazineAmmoUI.onAmmoListMouseDown(self, x, y)
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
function MagazineAmmoUI:updateMaxAmount()
    local magazine = self.magazinePanel:getMagazine()
    if not magazine or not self.selectedAmmoType then
        self.maxTransferAmount = 0
        self.transferAmount = 0
        self:updateAmountLabel()
        self.btnLoad:setEnable(false)
        return
    end

    local inventory = self.player:getInventory()
    local availableAmmo = inventory:getCountTypeRecurse(self.selectedAmmoType)
    local currentAmmo = magazine:getCurrentAmmoCount()
    local maxAmmo = magazine:getMaxAmmo()
    local freeSpace = maxAmmo - currentAmmo

    self.maxTransferAmount = math.min(availableAmmo, freeSpace)

    if self.transferAmount > self.maxTransferAmount then
        self.transferAmount = self.maxTransferAmount
    end

    self:updateAmountLabel()
    self.btnLoad:setEnable(self.transferAmount > 0)
end

function MagazineAmmoUI:updateAmountLabel()
    self.amountLabel:setName(tostring(self.transferAmount))
end

-----------------------------------------------------------
-- Amount button handlers
-----------------------------------------------------------
function MagazineAmmoUI:onAmountButton(button)
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

    self:updateAmountLabel()
    self.btnLoad:setEnable(self.transferAmount > 0)
end

-----------------------------------------------------------
-- Main button handlers
-----------------------------------------------------------
function MagazineAmmoUI:onButton(button)
    if button.internal == "LOAD" then
        self:performLoad()
    elseif button.internal == "CLOSE" then
        self:close()
    end
end

function MagazineAmmoUI:performLoad()
    local magazine = self.magazinePanel:getMagazine()
    if not magazine then return end
    if self.transferAmount <= 0 then return end
    if not self.selectedAmmoType then return end

    ISInventoryPaneContextMenu.transferIfNeeded(self.player, magazine)

    ISInventoryPaneContextMenu.transferBullets(self.player, self.selectedAmmoType, magazine:getCurrentAmmoCount(),
        magazine:getCurrentAmmoCount() + self.transferAmount)

    Ammo.MagazineAmmoProfileSetter(magazine, self.selectedAmmoType)

    ISTimedActionQueue.add(ISLoadBulletsInMagazine:new(self.player, magazine, self.transferAmount, self.transferAmount))

    self:updateAmountLabel()
end

-----------------------------------------------------------
-- Update loop
-----------------------------------------------------------
function MagazineAmmoUI:update()
    ISPanelJoypad.update(self)

    for _, listItem in ipairs(self.ammoList.items) do
        local ammoData = listItem.item
        ammoData.count = self.player:getInventory():getCountTypeRecurse(ammoData.ammoTypeKey)
    end

    local magazine = self.magazinePanel:getMagazine()
    if magazine then
        self.magazinePanel:updateMagazineInfo(magazine)
        self:updateMaxAmount()
    end

    if magazine and not self.player:getInventory():containsID(magazine:getID()) then
        self.magazinePanel:onItemRemove()
    end
end

-----------------------------------------------------------
-- Render
-----------------------------------------------------------
function MagazineAmmoUI:prerender()
    ISPanelJoypad.prerender(self)
    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g,
        self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g,
        self.borderColor.b)
end

-----------------------------------------------------------
-- Close
-----------------------------------------------------------
function MagazineAmmoUI:close()
    MagazineAmmoUI.instance = nil

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
function MagazineAmmoUI:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData)
    self:setISButtonForA(self.btnLoad)
    self:setISButtonForB(self.btnClose)
end

function MagazineAmmoUI:onJoypadDown(button, joypadData)
    if button == Joypad.DPadUp then
        self:onAmountButton({ internal = "PLUS" })
    elseif button == Joypad.DPadDown then
        self:onAmountButton({ internal = "MINUS" })
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
function MagazineAmmoUI:new(x, y, width, height, player)
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
-- Keyboard handler - Opens with O key
-----------------------------------------------------------
local function onKeyPressed(key)
    if key == Keyboard.KEY_O then
        local player = getSpecificPlayer(0)
        if player and not player:isDead() then
            if UIManager.getSpeedControls() and UIManager.getSpeedControls():getCurrentGameSpeed() == 0 then
                return
            end
            MagazineAmmoUI.TogglePanel(player)
        end
    end
end

Events.OnKeyPressed.Add(onKeyPressed)
