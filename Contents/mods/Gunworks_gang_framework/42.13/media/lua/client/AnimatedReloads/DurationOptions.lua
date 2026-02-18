---@class AnimatedReloadsDurationDataEntry
---@field load number|nil
---@field loadShort number|nil
---@field unload number|nil
---@field rack number|nil

---@class AnimatedReloadsDurationOptionsEntry
---@field load PZAPI.ModOptions.Slider|nil
---@field loadShort PZAPI.ModOptions.Slider|nil
---@field unload PZAPI.ModOptions.Slider|nil
---@field rack PZAPI.ModOptions.Slider|nil

---@class AnimatedReloadsDurationOptionsClient
---@field modOptionsId string
---@field modDataKey string
---@field byReloadType table<string,AnimatedReloadsDurationOptionsEntry>|nil
---@field _handlersProvider fun():AnimatedReloadsHandler[]|nil
---@field _watching boolean
local DurationOptions = {}
DurationOptions.modOptionsId = "AnimatedReloads"
DurationOptions.modDataKey = "AnimatedReloads_ReloadDurations"
DurationOptions.byReloadType = nil
DurationOptions._handlersProvider = nil
DurationOptions._watching = false

local DURATION_FIELDS = { "load", "loadShort", "unload", "rack" }
local HANDLER_DURATION_KEYS = {
    load = "loadDuration",
    loadShort = "loadShortDuration",
    unload = "unloadDuration",
    rack = "rackDuration",
}

local OPTION_SUFFIX = {
    load = "LoadDuration",
    loadShort = "LoadShortDuration",
    unload = "UnloadDuration",
    rack = "RackDuration",
}

local OPTION_LABEL = {
    load = "load duration",
    loadShort = "load short duration",
    unload = "unload duration",
    rack = "rack duration",
}

---@nodiscard
---@return boolean
local function canSyncToServer()
    return isClient() and sendClientCommand
end

---@nodiscard
---@return boolean
local function isServerAuthority()
    if isServer() then
        return true
    end

    if isClient() then
        return false
    end

    return true
end

---@nodiscard
---@return AnimatedReloadsHandler[]
local function getHandlers()
    if DurationOptions._handlersProvider then
        return DurationOptions._handlersProvider() or {}
    end
    return {}
end

---@param fn fun(handler:AnimatedReloadsHandler, reloadType:string):nil
local function forEachHandler(fn)
    local handlers = getHandlers()
    for i = 1, #handlers do
        local handler = handlers[i]
        if handler.reloadType then
            fn(handler, handler.reloadType)
        end
    end
end

---@param table table<any,any>|nil
---@nodiscard
---@return boolean
local function hasAnyKey(table)
    if not table then
        return false
    end

    for _ in pairs(table) do
        return true
    end

    return false
end

---@param handler AnimatedReloadsHandler
---@return AnimatedReloadsDurationDataEntry
local function buildDurationEntry(handler)
    return {
        load = handler.loadDuration,
        loadShort = handler.loadShortDuration,
        unload = handler.unloadDuration,
        rack = handler.rackDuration,
    }
end

---@nodiscard
---@return table<string,AnimatedReloadsDurationDataEntry>
local function buildDurationsFromHandlers()
    ---@type table<string,AnimatedReloadsDurationDataEntry>
    local durations = {}

    forEachHandler(function(handler, reloadType)
        durations[reloadType] = buildDurationEntry(handler)
    end)

    return durations
end

---@param handler AnimatedReloadsHandler
---@param field string
---@return number
local function getDefaultDurationValue(handler, field)
    if field == "load" then
        return handler.loadDuration or 1
    end
    if field == "loadShort" then
        return handler.loadShortDuration or handler.loadDuration or 1
    end
    if field == "unload" then
        return handler.unloadDuration or 1
    end
    return handler.rackDuration or 1
end

---@param options any
---@param reloadType string
---@param field string
---@param defaultValue number
---@return PZAPI.ModOptions.Slider|nil
local function getOrCreateSlider(options, reloadType, field, defaultValue)
    local optionId = "Reload_" .. reloadType .. "_" .. OPTION_SUFFIX[field]
    local option = options:getOption(optionId)
    if option then
        return option
    end

    return options:addSlider(
        optionId,
        reloadType .. " " .. OPTION_LABEL[field],
        0.1,
        5,
        0.1,
        defaultValue,
        "Seconds"
    )
end

---@param handler AnimatedReloadsHandler
---@param entry AnimatedReloadsDurationOptionsEntry
local function applyOptionEntryToHandler(handler, entry)
    for i = 1, #DURATION_FIELDS do
        local field = DURATION_FIELDS[i]
        local option = entry[field]
        if option then
            handler[HANDLER_DURATION_KEYS[field]] = option:getValue()
        end
    end
end

---@param reloadType string
---@param values AnimatedReloadsDurationDataEntry
local function applyValuesToOptionsEntry(reloadType, values)
    if not DurationOptions.byReloadType then
        return
    end

    local entry = DurationOptions.byReloadType[reloadType]
    if not entry then
        return
    end

    for i = 1, #DURATION_FIELDS do
        local field = DURATION_FIELDS[i]
        local option = entry[field]
        local value = values[field]
        if option and value ~= nil then
            option:setValue(value)
        end
    end
end

---@param provider fun():AnimatedReloadsHandler[]|nil
function DurationOptions.setHandlersProvider(provider)
    DurationOptions._handlersProvider = provider
end

---@return nil
function DurationOptions.ensureOptions()
    if not (PZAPI and PZAPI.ModOptions) then
        return
    end

    local options = PZAPI.ModOptions:getOptions(DurationOptions.modOptionsId)
    if not options then
        options = PZAPI.ModOptions:create(DurationOptions.modOptionsId, "AnimatedReloads")
    end
    options.apply = DurationOptions.applyOptionsToHandlers

    DurationOptions.byReloadType = {}

    if getDebug() then
        local DurationEditor = require("AnimatedReloads/DurationEditor")
        if not options:getOption("AnimatedReloads_OpenDurationEditor") then
            options:addButton(
                "AnimatedReloads_OpenDurationEditor",
                "Open Reload Duration Editor",
                "Open the debug UI for reload durations.",
                DurationEditor.open
            )
        end
    end

    forEachHandler(function(handler, reloadType)
        ---@type AnimatedReloadsDurationOptionsEntry
        local entry = {}
        for i = 1, #DURATION_FIELDS do
            local field = DURATION_FIELDS[i]
            entry[field] = getOrCreateSlider(options, reloadType, field, getDefaultDurationValue(handler, field))
        end
        DurationOptions.byReloadType[reloadType] = entry
    end)
end

---@param durations table<string,AnimatedReloadsDurationDataEntry>|nil
function DurationOptions.applyDurationsToHandlers(durations)
    if not durations then
        return
    end

    forEachHandler(function(handler, reloadType)
        local values = durations[reloadType]
        if not values then
            return
        end

        for i = 1, #DURATION_FIELDS do
            local field = DURATION_FIELDS[i]
            local value = values[field]
            if value ~= nil then
                handler[HANDLER_DURATION_KEYS[field]] = value
            end
        end
    end)
end

---@param durations table<string,AnimatedReloadsDurationDataEntry>|nil
---@param saveNow boolean|nil
function DurationOptions.applyDurationsToOptions(durations, saveNow)
    if not (DurationOptions.byReloadType and durations) then
        return
    end

    for reloadType, values in pairs(durations) do
        applyValuesToOptionsEntry(reloadType, values)
    end

    if saveNow and PZAPI and PZAPI.ModOptions then
        PZAPI.ModOptions:save()
    end
end

---@return nil
function DurationOptions.applyModDataToHandlers()
    local durations = DurationOptions.getModDataDurations()
    if durations then
        DurationOptions.applyDurationsToHandlers(durations)
        DurationOptions.applyDurationsToOptions(durations, true)
    end
end

---@nodiscard
---@return table<string,AnimatedReloadsDurationDataEntry>|nil
function DurationOptions.getModDataDurations()
    if not ModData then
        return nil
    end

    if ModData.get then
        local data = ModData.get(DurationOptions.modDataKey)
        if data then
            return data
        end
    end

    if ModData.getOrCreate and isServerAuthority() then
        return ModData.getOrCreate(DurationOptions.modDataKey)
    end

    return nil
end

---@param durations table<string,AnimatedReloadsDurationDataEntry>
function DurationOptions.persistModData(durations)
    if not (ModData and ModData.add) then
        return
    end

    ModData.add(DurationOptions.modDataKey, durations)
    if ModData.transmit then
        ModData.transmit(DurationOptions.modDataKey)
    end
end

---@return table<string,AnimatedReloadsDurationDataEntry>|nil
function DurationOptions.ensureModDataDefaults()
    if not (ModData and ModData.getOrCreate) then
        return nil
    end

    local data = ModData.getOrCreate(DurationOptions.modDataKey) or {}
    if hasAnyKey(data) then
        return data
    end

    data = buildDurationsFromHandlers()
    DurationOptions.persistModData(data)
    return data
end

---@return nil
function DurationOptions.applyOptionsToHandlers()
    if not DurationOptions.byReloadType then
        return
    end

    forEachHandler(function(handler, reloadType)
        local entry = DurationOptions.byReloadType[reloadType]
        if entry then
            applyOptionEntryToHandler(handler, entry)
        end
    end)

    if canSyncToServer() then
        DurationOptions.syncToServer()
    elseif isServerAuthority() then
        DurationOptions.persistModData(buildDurationsFromHandlers())
    end
end

---@param reloadType string
---@param load number|nil
---@param loadShort number|nil
---@param unload number|nil
---@param rack number|nil
---@param saveNow boolean|nil
function DurationOptions.updateFromUI(reloadType, load, loadShort, unload, rack, saveNow)
    local entry = DurationOptions.byReloadType and DurationOptions.byReloadType[reloadType]
    if not entry then
        return
    end

    local values = {
        load = load,
        loadShort = loadShort,
        unload = unload,
        rack = rack,
    }

    for i = 1, #DURATION_FIELDS do
        local field = DURATION_FIELDS[i]
        local option = entry[field]
        local value = values[field]
        if option and value ~= nil then
            option:setValue(value)
        end
    end

    DurationOptions.applyOptionsToHandlers()

    if saveNow and PZAPI and PZAPI.ModOptions then
        PZAPI.ModOptions:save()
    end
end

---@return nil
function DurationOptions.syncToServer()
    if not canSyncToServer() then
        return
    end

    local durations = buildDurationsFromHandlers()
    if hasAnyKey(durations) then
        sendClientCommand("AnimatedReloads", "SyncReloadDurations", { durations = durations })
    end
end

---@param module string
---@param command string
---@param player IsoPlayer
---@param args {durations:table<string,AnimatedReloadsDurationDataEntry>}|nil
function DurationOptions.handleClientCommand(module, command, player, args)
    if module ~= "AnimatedReloads" or command ~= "SyncReloadDurations" then
        return
    end

    if not args or not args.durations then
        return
    end

    DurationOptions.persistModData(args.durations)
    DurationOptions.applyDurationsToHandlers(args.durations)
end

---@param tag string
---@param table table<string,AnimatedReloadsDurationDataEntry>|nil
function DurationOptions.handleReceiveGlobalModData(tag, table)
    if tag ~= DurationOptions.modDataKey then
        return
    end

    local durations = table or DurationOptions.getModDataDurations()
    if durations then
        DurationOptions.applyDurationsToHandlers(durations)
        DurationOptions.applyDurationsToOptions(durations, true)
    end
end

---@return nil
function DurationOptions.startWatching()
    if DurationOptions._watching then
        return
    end

    DurationOptions._watching = true

    if Events and Events.OnInitGlobalModData then
        Events.OnInitGlobalModData.Add(function()
            if isServerAuthority() then
                local data = DurationOptions.ensureModDataDefaults()
                if data then
                    DurationOptions.applyDurationsToHandlers(data)
                    if ModData and ModData.transmit then
                        ModData.transmit(DurationOptions.modDataKey)
                    end
                end
            else
                DurationOptions.applyModDataToHandlers()
            end
        end)
    end

    if Events and Events.OnReceiveGlobalModData then
        Events.OnReceiveGlobalModData.Add(DurationOptions.handleReceiveGlobalModData)
    end

    if Events and Events.OnClientCommand and isServerAuthority() then
        Events.OnClientCommand.Add(DurationOptions.handleClientCommand)
    end

    if Events and Events.OnGameStart then
        Events.OnGameStart.Add(DurationOptions.applyModDataToHandlers)
    end
end

return DurationOptions
