require("ISUI/ISPanel")
require("ISUI/ISButton")
require("ISUI/ISLabel")
require("ISUI/ISTextEntryBox")
local DurationOptions = require("AnimatedReloads/DurationOptions")
local AnimatedReloadsAction = require("AnimatedReloads/hooks/AnimatedReloadsAction")

---@class AnimatedReloadsDurationEditorRow
---@field handler AnimatedReloadsHandler
---@field loadEntry ISTextEntryBox
---@field loadShortEntry ISTextEntryBox
---@field unloadEntry ISTextEntryBox
---@field rackEntry ISTextEntryBox

---@class AnimatedReloadsDurationEditor : ISPanel
---@field instance AnimatedReloadsDurationEditor|nil
---@field handlers AnimatedReloadsHandler[]
---@field rows AnimatedReloadsDurationEditorRow[]
AnimatedReloadsDurationEditor = ISPanel:derive("AnimatedReloadsDurationEditor")

---@return nil
function AnimatedReloadsDurationEditor.open()
    if not getDebug() then
        return
    end

    DurationOptions.applyModDataToHandlers()

    if AnimatedReloadsDurationEditor.instance then
        AnimatedReloadsDurationEditor.instance:setVisible(true)
        AnimatedReloadsDurationEditor.instance:bringToTop()
        return
    end

    ---@type AnimatedReloadsHandler[]
    local handlers = {}
    local __list = AnimatedReloadsAction.handlers or {}
    for i = 1, #__list do
        local handler = __list[i]
        if handler.reloadType then
            table.insert(handlers, handler)
        end
    end

    local rowHeight = 28
    local headerHeight = 30
    local buttonHeight = 24
    local width = 600
    local height = headerHeight + (#handlers * rowHeight) + buttonHeight + 30
    local x = (getCore():getScreenWidth() - width) / 2
    local y = (getCore():getScreenHeight() - height) / 2

    local ui = AnimatedReloadsDurationEditor:new(x, y, width, height, handlers)
    ui:initialise()
    ui:addToUIManager()
    AnimatedReloadsDurationEditor.instance = ui
end

---@param x number
---@param y number
---@param width number
---@param height number
---@param handlers AnimatedReloadsHandler[]|nil
---@return AnimatedReloadsDurationEditor
function AnimatedReloadsDurationEditor:new(x, y, width, height, handlers)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.handlers = handlers or {}
    o.rows = {}
    o.borderColor = { r = 1, g = 1, b = 1, a = 0.7 }
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.8 }
    return o
end

---@return nil
function AnimatedReloadsDurationEditor:initialise()
    ISPanel.initialise(self)
    self:setMoveWithMouse(true)
end

---@return nil
function AnimatedReloadsDurationEditor:createChildren()
    ISPanel.createChildren(self)

    local font = UIFont.Small
    local fontHgt = getTextManager():getFontHeight(font)
    local y = 10

    self:addChild(ISLabel:new(10, y, fontHgt, "Reload Type", 1, 1, 1, 1, font, true))
    self:addChild(ISLabel:new(220, y, fontHgt, "Load", 1, 1, 1, 1, font, true))
    self:addChild(ISLabel:new(300, y, fontHgt, "Load Short", 1, 1, 1, 1, font, true))
    self:addChild(ISLabel:new(380, y, fontHgt, "Unload", 1, 1, 1, 1, font, true))
    self:addChild(ISLabel:new(460, y, fontHgt, "Rack", 1, 1, 1, 1, font, true))

    y = y + fontHgt + 8

    local entryHeight = 22
    local __list = self.handlers
    for i = 1, #__list do
        local handler = __list[i]
        ---@type AnimatedReloadsDurationEditorRow
        local row = { handler = handler }

        self:addChild(ISLabel:new(10, y + 4, fontHgt, handler.reloadType or "unknown", 1, 1, 1, 1, font, true))

        local loadEntry = ISTextEntryBox:new(tostring(handler.loadDuration or 1), 220, y, 60, entryHeight)
        loadEntry:initialise()
        self:addChild(loadEntry)

        local loadShortEntry = ISTextEntryBox:new(tostring(handler.loadShortDuration or handler.loadDuration or 1), 300, y, 60, entryHeight)
        loadShortEntry:initialise()
        self:addChild(loadShortEntry)

        local unloadEntry = ISTextEntryBox:new(tostring(handler.unloadDuration or 1), 380, y, 60, entryHeight)
        unloadEntry:initialise()
        self:addChild(unloadEntry)

        local rackEntry = ISTextEntryBox:new(tostring(handler.rackDuration or 1), 460, y, 60, entryHeight)
        rackEntry:initialise()
        self:addChild(rackEntry)

        row.loadEntry = loadEntry
        row.loadShortEntry = loadShortEntry
        row.unloadEntry = unloadEntry
        row.rackEntry = rackEntry
        table.insert(self.rows, row)

        y = y + 28
    end

    local buttonY = self.height - 30
    local applyButton = ISButton:new(10, buttonY, 120, 24, "Apply", self, self.onApply)
    applyButton:initialise()
    self:addChild(applyButton)

    local closeButton = ISButton:new(140, buttonY, 120, 24, "Close", self, self.onClose)
    closeButton:initialise()
    self:addChild(closeButton)
end

---@nodiscard
---@param text string
---@param fallback number
---@return number
function AnimatedReloadsDurationEditor:parseDuration(text, fallback)
    local value = tonumber(text)
    if value == nil then
        return fallback
    end

    return value
end

---@return nil
function AnimatedReloadsDurationEditor:onApply()
    local __list = self.rows
    for i = 1, #__list do
        local row = __list[i]
        local handler = row.handler
        local load = self:parseDuration(row.loadEntry:getText(), handler.loadDuration or 1)
        local loadShort = self:parseDuration(row.loadShortEntry:getText(), handler.loadShortDuration or load)
        local unload = self:parseDuration(row.unloadEntry:getText(), handler.unloadDuration or 1)
        local rack = self:parseDuration(row.rackEntry:getText(), handler.rackDuration or 1)

        DurationOptions.updateFromUI(handler.reloadType, load, loadShort, unload, rack, true)
    end
end

---@return nil
function AnimatedReloadsDurationEditor:onClose()
    self:setVisible(false)
    self:removeFromUIManager()
    AnimatedReloadsDurationEditor.instance = nil
end

return AnimatedReloadsDurationEditor
