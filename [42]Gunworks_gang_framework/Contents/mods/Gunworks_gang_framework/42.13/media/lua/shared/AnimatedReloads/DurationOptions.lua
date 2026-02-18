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

---@class AnimatedReloadsDurationOptionsShared
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

---@nodiscard
---@return table<string,AnimatedReloadsDurationDataEntry>
local function buildDurationsFromHandlers()
    ---@type table<string,AnimatedReloadsDurationDataEntry>
    local durations = {}
    local __list = getHandlers()
    for i = 1, #__list do
        local handler = __list[i]
        if handler.reloadType then
            durations[handler.reloadType] = {
                load = handler.loadDuration,
                loadShort = handler.loadShortDuration,
                unload = handler.unloadDuration,
                rack = handler.rackDuration,
            }
        end
    end

    return durations
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
    if not getDebug() then
        return
    end

    local options = PZAPI.ModOptions:getOptions(DurationOptions.modOptionsId)
    if not options then
        options = PZAPI.ModOptions:create(DurationOptions.modOptionsId, "AnimatedReloads")
    end
    options.apply = DurationOptions.applyOptionsToHandlers

    DurationOptions.byReloadType = {}

    local DurationEditor = require("AnimatedReloads/DurationEditor")
    if not options:getOption("AnimatedReloads_OpenDurationEditor") then
        options:addButton(
            "AnimatedReloads_OpenDurationEditor",
            "Open Reload Duration Editor",
            "Open the debug UI for reload durations.",
            DurationEditor.open
        )
    end

    local __list = getHandlers()
    for i = 1, #__list do
        local handler = __list[i]
        if handler.reloadType then
            local reloadType = handler.reloadType
            ---@type AnimatedReloadsDurationOptionsEntry
            local entry = {}
            entry.load = options:getOption("Reload_" .. reloadType .. "_LoadDuration")
                or options:addSlider(
                    "Reload_" .. reloadType .. "_LoadDuration",
                    reloadType .. " load duration",
                    0.1,
                    5,
                    0.1,
                    handler.loadDuration or 1,
                    "Seconds"
                )
            entry.loadShort = options:getOption("Reload_" .. reloadType .. "_LoadShortDuration")
                or options:addSlider(
                    "Reload_" .. reloadType .. "_LoadShortDuration",
                    reloadType .. " load short duration",
                    0.1,
                    5,
                    0.1,
                    handler.loadShortDuration or handler.loadDuration or 1,
                    "Seconds"
                )
            entry.unload = options:getOption("Reload_" .. reloadType .. "_UnloadDuration")
                or options:addSlider(
                    "Reload_" .. reloadType .. "_UnloadDuration",
                    reloadType .. " unload duration",
                    0.1,
                    5,
                    0.1,
                    handler.unloadDuration or 1,
                    "Seconds"
                )
            entry.rack = options:getOption("Reload_" .. reloadType .. "_RackDuration")
                or options:addSlider(
                    "Reload_" .. reloadType .. "_RackDuration",
                    reloadType .. " rack duration",
                    0.1,
                    5,
                    0.1,
                    handler.rackDuration or 1,
                    "Seconds"
                )
            DurationOptions.byReloadType[reloadType] = entry
        end
    end
end

---@param durations table<string,AnimatedReloadsDurationDataEntry>|nil
function DurationOptions.applyDurationsToHandlers(durations)
    if not durations then
        return
    end

    local __list = getHandlers()
    for i = 1, #__list do
        local handler = __list[i]
        if handler.reloadType then
            local entry = durations[handler.reloadType]
            if entry then
                if entry.load ~= nil then
                    handler.loadDuration = entry.load
                end
                if entry.loadShort ~= nil then
                    handler.loadShortDuration = entry.loadShort
                end
                if entry.unload ~= nil then
                    handler.unloadDuration = entry.unload
                end
                if entry.rack ~= nil then
                    handler.rackDuration = entry.rack
                end
            end
        end
    end
end

---@param durations table<string,AnimatedReloadsDurationDataEntry>|nil
---@param saveNow boolean|nil
function DurationOptions.applyDurationsToOptions(durations, saveNow)
    if not (DurationOptions.byReloadType and durations) then
        return
    end

    for reloadType, data in pairs(durations) do
        local entry = DurationOptions.byReloadType[reloadType]
        if entry then
            if entry.load and data.load ~= nil then
                entry.load:setValue(data.load)
            end
            if entry.loadShort and data.loadShort ~= nil then
                entry.loadShort:setValue(data.loadShort)
            end
            if entry.unload and data.unload ~= nil then
                entry.unload:setValue(data.unload)
            end
            if entry.rack and data.rack ~= nil then
                entry.rack:setValue(data.rack)
            end
        end
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
    local hasData = false
    for _ in pairs(data) do
        hasData = true
        break
    end
    if not hasData then
        data = buildDurationsFromHandlers()
        DurationOptions.persistModData(data)
    end

    return data
end

---@return nil
function DurationOptions.applyOptionsToHandlers()
    if not DurationOptions.byReloadType then
        return
    end

    local __list = getHandlers()
    for i = 1, #__list do
        local handler = __list[i]
        local entry = DurationOptions.byReloadType[handler.reloadType]
        if entry then
            if entry.load then
                handler.loadDuration = entry.load:getValue()
            end
            if entry.loadShort then
                handler.loadShortDuration = entry.loadShort:getValue()
            end
            if entry.unload then
                handler.unloadDuration = entry.unload:getValue()
            end
            if entry.rack then
                handler.rackDuration = entry.rack:getValue()
            end
        end
    end

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

    if load ~= nil then
        entry.load:setValue(load)
    end
    if entry.loadShort and loadShort ~= nil then
        entry.loadShort:setValue(loadShort)
    end
    if unload ~= nil then
        entry.unload:setValue(unload)
    end
    if rack ~= nil then
        entry.rack:setValue(rack)
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
    local hasDurations = false
    for _ in pairs(durations) do
        hasDurations = true
        break
    end

    if hasDurations then
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

    if getDebug() and PZAPI and PZAPI.ModOptions then
        DurationOptions.ensureOptions()
        PZAPI.ModOptions:load()
    end

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

