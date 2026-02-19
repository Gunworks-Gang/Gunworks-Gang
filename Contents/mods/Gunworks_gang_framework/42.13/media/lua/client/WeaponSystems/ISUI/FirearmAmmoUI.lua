require("ISUI/ISPanelJoypad")
require("ISUI/ISButton")
require("ISUI/ISLabel")
require("ISUI/ISScrollingListBox")
require("ISUI/ISItemDropBox")

local Ammo = require("WeaponSystems/Utils/AmmoUtils")

-----------------------------------------------------------
-- Firearm Ammo UI
-- A drag-and-drop interface for loading ammo into firearms (non-magazine)
-----------------------------------------------------------

FirearmAmmoUI = ISPanelJoypad:derive("FirearmAmmoUI")
FirearmAmmoUI.instance = nil

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local UI_BORDER_SPACING = 10
local BUTTON_HGT = FONT_HGT_SMALL + 6

-----------------------------------------------------------
-- Firearm Drop Panel - handles drag and drop of firearms
-----------------------------------------------------------
FirearmDropPanel = ISPanel:derive("FirearmDropPanel")

function FirearmDropPanel:initialise()
    ISPanel.initialise(self)
end

function FirearmDropPanel:createChildren()
    local y = UI_BORDER_SPACING

    self.titleLabel = ISLabel:new(self.width / 2, y, FONT_HGT_SMALL,
        getText("IGUI_DropFirearm") or "Drop Firearm Here", 1, 1, 1, 1, UIFont.Small, true)
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
        FirearmDropPanel.onItemAdd,
        FirearmDropPanel.onItemRemove,
        FirearmDropPanel.onItemVerify,
        nil
    )
    self.itemDropBox.allowDropAlways = true
    self.itemDropBox.player = self.player
    self.itemDropBox:initialise()
    self.itemDropBox:setToolTip(true, getText("IGUI_DragFirearmHere") or "Drag a firearm here")
    self.itemDropBox.toolTipTextItem = getText("IGUI_ClickToRemove") or "Click to remove"
    self:addChild(self.itemDropBox)

    y = y + boxSize + UI_BORDER_SPACING

    self.weaponNameLabel = ISLabel:new(self.width / 2, y, FONT_HGT_SMALL, "", 0.8, 0.8, 0.8, 1, UIFont.Small, true)
    self.weaponNameLabel.center = true
    self.weaponNameLabel:initialise()
    self.weaponNameLabel:instantiate()
    self:addChild(self.weaponNameLabel)

    y = y + FONT_HGT_SMALL + 5

    self.ammoCountLabel = ISLabel:new(self.width / 2, y, FONT_HGT_SMALL, "", 0.6, 0.8, 0.6, 1, UIFont.Small, true)
    self.ammoCountLabel.center = true
    self.ammoCountLabel:initialise()
    self.ammoCountLabel:instantiate()
    self:addChild(self.ammoCountLabel)
end

function FirearmDropPanel:onItemAdd(items)
    for _, item in ipairs(items) do
        if self:onItemVerify(item) then
            self.itemDropBox:setStoredItem(item)
            self:updateWeaponInfo(item)
            if self.onWeaponAdded then
                self.onWeaponAdded(self.funcTarget, item)
            end
            return
        end
    end
end

function FirearmDropPanel:onItemRemove()
    self.itemDropBox:setStoredItem(nil)
    self:updateWeaponInfo(nil)
    if self.onWeaponRemoved then
        self.onWeaponRemoved(self.funcTarget)
    end
end

function FirearmDropPanel:onItemVerify(item)
    if not item then return false end
    if not item:isInPlayerInventory() then return false end
    if not instanceof(item, "HandWeapon") then return false end
    if not item:isRanged() then return false end
    if item:getMagazineType() then return false end
    return true
end

function FirearmDropPanel:updateWeaponInfo(weapon)
    if weapon then
        self.weaponNameLabel:setName(weapon:getDisplayName() or weapon:getName())
        local current = weapon:getCurrentAmmoCount()
        local max = weapon:getMaxAmmo()
        self.ammoCountLabel:setName(current .. " / " .. max)
    else
        self.weaponNameLabel:setName("")
        self.ammoCountLabel:setName("")
    end
end

function FirearmDropPanel:getWeapon()
    return self.itemDropBox and self.itemDropBox.storedItem
end

function FirearmDropPanel:prerender()
    ISPanel.prerender(self)
    self:drawRect(0, 0, self.width, self.height, 0.8, 0.1, 0.1, 0.1)
    self:drawRectBorder(0, 0, self.width, self.height, 1, 0.4, 0.4, 0.4)
end

function FirearmDropPanel:new(x, y, width, height, player)
    local o = ISPanel.new(self, x, y, width, height)
    o.player = player
    o.backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.8 }
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    return o
end

-----------------------------------------------------------
-- Main Firearm Ammo UI
-----------------------------------------------------------
function FirearmAmmoUI.OpenPanel(player)
    if not player then return end

    if FirearmAmmoUI.instance then
        FirearmAmmoUI.instance:close()
    end

    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    local width = 450
    local height = 350

    local x = (screenW - width) / 2
    local y = (screenH - height) / 2

    local ui = FirearmAmmoUI:new(x, y, width, height, player)
    ui:initialise()
    ui:instantiate()
    ui:setVisible(true)
    ui:addToUIManager()

    FirearmAmmoUI.instance = ui

    local playerNum = player:getPlayerNum()
    if getJoypadData(playerNum) then
        setJoypadFocus(playerNum, ui)
    end
end

function FirearmAmmoUI.TogglePanel(player)
    if FirearmAmmoUI.instance then
        FirearmAmmoUI.instance:close()
    else
        FirearmAmmoUI.OpenPanel(player)
    end
end

function FirearmAmmoUI:initialise()
    ISPanelJoypad.initialise(self)
end

function FirearmAmmoUI:createChildren()
    ISPanelJoypad.createChildren(self)

    local y = UI_BORDER_SPACING

    self.titleLabel = ISLabel:new(self.width / 2, y, FONT_HGT_MEDIUM,
        getText("IGUI_FirearmAmmo_Title") or "Firearm Ammo", 1, 1, 1, 1, UIFont.Medium, true)
    self.titleLabel.center = true
    self.titleLabel:initialise()
    self.titleLabel:instantiate()
    self:addChild(self.titleLabel)

    y = y + FONT_HGT_MEDIUM + UI_BORDER_SPACING

    local panelWidth = 150
    local panelHeight = 160

    self.weaponPanel = FirearmDropPanel:new(UI_BORDER_SPACING, y, panelWidth, panelHeight, self.player)
    self.weaponPanel.funcTarget = self
    self.weaponPanel.onWeaponAdded = self.onWeaponAdded
    self.weaponPanel.onWeaponRemoved = self.onWeaponRemoved
    self.weaponPanel:initialise()
    self.weaponPanel:instantiate()
    self:addChild(self.weaponPanel)

    local middleWidth = 80
    local middleX = self.weaponPanel:getRight() + UI_BORDER_SPACING

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
        FirearmAmmoUI.onAmountButton)
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
        FirearmAmmoUI.onAmountButton)
    self.btnMinus.internal = "MINUS"
    self.btnMinus:initialise()
    self.btnMinus:instantiate()
    self.btnMinus.borderColor = { r = 0.7, g = 0.7, b = 0.7, a = 0.5 }
    self.middlePanel:addChild(self.btnMinus)

    midY = self.btnMinus:getBottom() + UI_BORDER_SPACING

    self.btnMax = ISButton:new((middleWidth - 50) / 2, midY, 50, BUTTON_HGT, "MAX", self,
        FirearmAmmoUI.onAmountButton)
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
    self.ammoList.doDrawItem = FirearmAmmoUI.doDrawAmmoItem
    self.ammoList.target = self
    self.ammoList.onMouseDown = FirearmAmmoUI.onAmmoListMouseDown
    self.ammoList.backgroundColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.9 }
    self.ammoList.borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 1 }
    self.rightPanel:addChild(self.ammoList)

    y = self.weaponPanel:getBottom() + UI_BORDER_SPACING

    local buttonWidth = (self.width - UI_BORDER_SPACING * 3) / 2

    self.btnLoad = ISButton:new(UI_BORDER_SPACING, y, buttonWidth, BUTTON_HGT, getText("IGUI_Load") or "Load", self,
        FirearmAmmoUI.onButton)
    self.btnLoad.internal = "LOAD"
    self.btnLoad:initialise()
    self.btnLoad:instantiate()
    self.btnLoad:enableAcceptColor()
    self:addChild(self.btnLoad)

    self.btnClose = ISButton:new(self.btnLoad:getRight() + UI_BORDER_SPACING, y, buttonWidth, BUTTON_HGT,
        getText("UI_Close") or "Close", self, FirearmAmmoUI.onButton)
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
-- Weapon added/removed callbacks
-----------------------------------------------------------
function FirearmAmmoUI:onWeaponAdded(weapon)
    self:populateAmmoList()
    self:updateMaxAmount()
end

function FirearmAmmoUI:onWeaponRemoved()
    self.ammoList:clear()
    self.selectedAmmoType = nil
    self.transferAmount = 0
    self.maxTransferAmount = 0
    self:updateAmountLabel()
    self.btnLoad:setEnable(false)
end

-----------------------------------------------------------
-- Populate ammo list based on weapon's AmmoProfile
-----------------------------------------------------------
function FirearmAmmoUI:populateAmmoList()
    self.ammoList:clear()
    self.selectedAmmoType = nil

    local weapon = self.weaponPanel:getWeapon()
    if not weapon then return end

    local ammoTypes = self:getAvailableAmmoTypes(weapon)

    for _, ammoData in ipairs(ammoTypes) do
        self.ammoList:addItem(ammoData.name, ammoData)
    end

    if #self.ammoList.items > 0 then
        self.ammoList.selected = 1
        self.selectedAmmoType = self.ammoList.items[1].item.ammoTypeKey
    end
end

function FirearmAmmoUI:getAvailableAmmoTypes(weapon)
    local result = {}
    local inventory = self.player:getInventory()

    local ammoProfile = Ammo.ItemAmmoFamily[weapon:getFullType()]
    local bulletTypes = ammoProfile and Ammo and Ammo.GetBulletTypesForFamily(ammoProfile)
    if bulletTypes then
        for _, ammoTypeKey in ipairs(bulletTypes) do
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
        local defaultAmmoType = weapon:getAmmoType()
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
function FirearmAmmoUI.doDrawAmmoItem(self, y, item, alt)
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

function FirearmAmmoUI.onAmmoListMouseDown(self, x, y)
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
function FirearmAmmoUI:updateMaxAmount()
    local weapon = self.weaponPanel:getWeapon()
    if not weapon or not self.selectedAmmoType then
        self.maxTransferAmount = 0
        self.transferAmount = 0
        self:updateAmountLabel()
        self.btnLoad:setEnable(false)
        return
    end

    local inventory = self.player:getInventory()
    local availableAmmo = inventory:getCountTypeRecurse(self.selectedAmmoType)
    local currentAmmo = weapon:getCurrentAmmoCount()
    local maxAmmo = weapon:getMaxAmmo()
    local freeSpace = maxAmmo - currentAmmo

    self.maxTransferAmount = math.min(availableAmmo, freeSpace)

    if self.transferAmount > self.maxTransferAmount then
        self.transferAmount = self.maxTransferAmount
    end

    self:updateAmountLabel()
    self.btnLoad:setEnable(self.transferAmount > 0)
end

function FirearmAmmoUI:updateAmountLabel()
    self.amountLabel:setName(tostring(self.transferAmount))
end

-----------------------------------------------------------
-- Amount button handlers
-----------------------------------------------------------
function FirearmAmmoUI:onAmountButton(button)
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
function FirearmAmmoUI:onButton(button)
    if button.internal == "LOAD" then
        self:performLoad()
    elseif button.internal == "CLOSE" then
        self:close()
    end
end

function FirearmAmmoUI:performLoad()
    local weapon = self.weaponPanel:getWeapon()
    if not weapon then return end
    if self.transferAmount <= 0 then return end
    if not self.selectedAmmoType then return end

    ISInventoryPaneContextMenu.transferIfNeeded(self.player, weapon)

    ISInventoryPaneContextMenu.transferBullets(self.player, self.selectedAmmoType, weapon:getCurrentAmmoCount(),
        weapon:getCurrentAmmoCount() + self.transferAmount)

    Ammo.AmmoProfileSetter(weapon, self.selectedAmmoType)

    ISInventoryPaneContextMenu.equipWeapon(weapon, true, false, self.player:getPlayerNum())
    ISTimedActionQueue.add(ISReloadWeaponAction:new(self.player, weapon, self.transferAmount))

    self:updateAmountLabel()
end

-----------------------------------------------------------
-- Update loop
-----------------------------------------------------------
function FirearmAmmoUI:update()
    ISPanelJoypad.update(self)

    for _, listItem in ipairs(self.ammoList.items) do
        local ammoData = listItem.item
        ammoData.count = self.player:getInventory():getCountTypeRecurse(ammoData.ammoTypeKey)
    end

    local weapon = self.weaponPanel:getWeapon()
    if weapon then
        self.weaponPanel:updateWeaponInfo(weapon)
        self:updateMaxAmount()
    end

    if weapon and not self.player:getInventory():containsID(weapon:getID()) then
        self.weaponPanel:onItemRemove()
    end
end

-----------------------------------------------------------
-- Render
-----------------------------------------------------------
function FirearmAmmoUI:prerender()
    ISPanelJoypad.prerender(self)
    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g,
        self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g,
        self.borderColor.b)
end

-----------------------------------------------------------
-- Close
-----------------------------------------------------------
function FirearmAmmoUI:close()
    FirearmAmmoUI.instance = nil

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
function FirearmAmmoUI:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData)
    self:setISButtonForA(self.btnLoad)
    self:setISButtonForB(self.btnClose)
end

function FirearmAmmoUI:onJoypadDown(button, joypadData)
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
function FirearmAmmoUI:new(x, y, width, height, player)
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
-- Keyboard handler - Opens with P key
-----------------------------------------------------------
local function onKeyPressed(key)
    if key == Keyboard.KEY_P then
        local player = getSpecificPlayer(0)
        if player and not player:isDead() then
            if UIManager.getSpeedControls() and UIManager.getSpeedControls():getCurrentGameSpeed() == 0 then
                return
            end
            FirearmAmmoUI.TogglePanel(player)
        end
    end
end

Events.OnKeyPressed.Add(onKeyPressed)
