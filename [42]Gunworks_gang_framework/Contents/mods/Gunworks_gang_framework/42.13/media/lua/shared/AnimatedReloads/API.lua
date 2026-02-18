local AnimatedReloadsAction = require("AnimatedReloads/hooks/AnimatedReloadsAction")
local DurationOptions = require("AnimatedReloads/DurationOptions")

---@class AnimatedReloadsAPI
local AnimatedReloadsAPI = {}

---@nodiscard
---@return AnimatedReloadsAction
function AnimatedReloadsAPI.getActionModule()
    return AnimatedReloadsAction
end

---@nodiscard
---@return AnimatedReloadsDurationOptionsShared
function AnimatedReloadsAPI.getDurationOptionsModule()
    return DurationOptions
end

---@param handler AnimatedReloadsHandler
function AnimatedReloadsAPI.registerReloadHandler(handler)
    AnimatedReloadsAction.registerReloadHandler(handler)
end

---@param handlerId string|nil
function AnimatedReloadsAPI.unregisterReloadHandler(handlerId)
    AnimatedReloadsAction.unregisterReloadHandler(handlerId)
end

---@nodiscard
---@return AnimatedReloadsHandler[]
function AnimatedReloadsAPI.getHandlers()
    return AnimatedReloadsAction.getHandlers()
end

---@param options {id:string|nil,reloadType:string|nil,style:string|nil,magItem:string|nil,sprite:{loaded:string|nil,unloaded:string|nil}|nil,attachments:{magPart:AnimatedReloadsPartSpec|string|nil,parts:table<string,AnimatedReloadsPartSpec>|nil,states:table<string,AnimatedReloadsAttachmentState>|nil,loadedState:string|nil,unloadedState:string|nil}|nil,durations:{load:number|nil,loadShort:number|nil,unload:number|nil,rack:number|nil}|nil,shortRackAfterInsert:boolean|nil,matches:fun(gun:HandWeapon):boolean|nil}|nil
function AnimatedReloadsAPI.registerWeaponReloadHandler(options)
    AnimatedReloadsAction.registerWeaponReloadHandler(options)
end

---@param provider fun():AnimatedReloadsHandler[]|nil
function AnimatedReloadsAPI.setHandlersProvider(provider)
    DurationOptions.setHandlersProvider(provider)
end

function AnimatedReloadsAPI.applyDurationSettings()
    if DurationOptions.applyModDataToHandlers then
        DurationOptions.applyModDataToHandlers()
    elseif DurationOptions.applySandboxToHandlers then
        DurationOptions.applySandboxToHandlers()
    end
end

function AnimatedReloadsAPI.startDurationWatcher()
    if DurationOptions.startWatching then
        DurationOptions.startWatching()
    end
end


return AnimatedReloadsAPI
