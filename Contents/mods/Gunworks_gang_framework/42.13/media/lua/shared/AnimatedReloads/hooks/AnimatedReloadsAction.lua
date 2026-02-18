require("TimedActions/ISEjectMagazine")
require("TimedActions/ISInsertMagazine")
require("TimedActions/ISRackFirearm")
require("TimedActions/ISTimedActionQueue")
require("TimedActions/ISReloadWeaponAction")

local AnimatedReloadsAction = require("AnimatedReloads/Action/AnimatedReloadsAction")

local originalEjectStart = ISEjectMagazine.start

---@param self ISEjectMagazine
function ISEjectMagazine:start()
    originalEjectStart(self)

    local handler = AnimatedReloadsAction.getHandler(self)
    if handler and handler.onEjectStart then
        local handled = handler.onEjectStart(self)
        if handled then
            return
        end
    end
end

---@param self ISEjectMagazine
function ISEjectMagazine:serverStart()
    local handler = AnimatedReloadsAction.getHandler(self)
    self:initVars()
    local durationMs = AnimatedReloadsAction.getActionDurationMs(self, handler and handler.unloadDuration, 1200)
    emulateAnimEventOnce(self.netAction, durationMs, "unloadFinished", nil)
end

local originalEjectAnimEvent = ISEjectMagazine.animEvent

---@param self ISEjectMagazine
---@param event string
---@param parameter string
function ISEjectMagazine:animEvent(event, parameter)
    local handler = AnimatedReloadsAction.getHandler(self)
    if handler and handler.onEjectAnimEvent then
        local handled = handler.onEjectAnimEvent(self, event, parameter)
        if handled then
            return
        end
    end

    originalEjectAnimEvent(self, event, parameter)
end

local originalEjectStop = ISEjectMagazine.stop

---@param self ISEjectMagazine
function ISEjectMagazine:stop()
    local handler = AnimatedReloadsAction.getHandler(self)
    if handler and handler.onEjectStop then
        local handled = handler.onEjectStop(self)
        if handled then
            return
        end
    end

    originalEjectStop(self)
    AnimatedReloadsAction.resetWeaponModel(self, handler)
end

local originalEjectPerform = ISEjectMagazine.perform

---@param self ISEjectMagazine
function ISEjectMagazine:perform()
    local handler = AnimatedReloadsAction.getHandler(self)
    if handler and handler.onEjectPerform then
        local handled = handler.onEjectPerform(self)
        if handled then
            return
        end
    end

    originalEjectPerform(self)
    AnimatedReloadsAction.resetWeaponModel(self, handler)
end

local originalInsertStart = ISInsertMagazine.start

---@param self ISInsertMagazine
function ISInsertMagazine:start()
    local handler = AnimatedReloadsAction.getHandler(self)
    if handler and handler.onInsertStart then
        local handled = handler.onInsertStart(self)
        if handled then
            return
        end
    end

    originalInsertStart(self)

    if self.shouldShortRackAfterInsert and AnimatedReloadsAction.shouldQueueShortRackAfterInsert(self) then
        self:setAnimVariable("isLoadingShort", true)
        if self.character then
            self.character:clearVariable("isLoading")
        end
    end
end

---@param self ISInsertMagazine
function ISInsertMagazine:serverStart()
    local handler = AnimatedReloadsAction.getHandler(self)
    self:initVars()
    local loadSeconds = handler and handler.loadDuration
    if handler and AnimatedReloadsAction.shouldUseShortLoad(self, handler) then
        loadSeconds = handler.loadShortDuration or handler.loadDuration
    end
    local durationMs = AnimatedReloadsAction.getActionDurationMs(self, loadSeconds, 1500)
    emulateAnimEventOnce(self.netAction, durationMs, "loadFinished", nil)
end

local originalInsertStop = ISInsertMagazine.stop

---@param self ISInsertMagazine
function ISInsertMagazine:stop()
    local handler = AnimatedReloadsAction.getHandler(self)
    if handler and handler.onInsertStop then
        local handled = handler.onInsertStop(self)
        if handled then
            return
        end
    end

    originalInsertStop(self)
    AnimatedReloadsAction.resetWeaponModel(self, handler)
end

local originalInsertAnimEvent = ISInsertMagazine.animEvent

---@param self ISInsertMagazine
---@param event string
---@param parameter string
function ISInsertMagazine:animEvent(event, parameter)
    local handler = AnimatedReloadsAction.getHandler(self)
    if handler and handler.onInsertAnimEvent then
        local handled = handler.onInsertAnimEvent(self, event, parameter)
        if handled then
            return
        end
    end

    originalInsertAnimEvent(self, event, parameter)
end

local originalInsertLoadAmmo = ISInsertMagazine.loadAmmo

---@param self ISInsertMagazine
function ISInsertMagazine:loadAmmo()
    local handler = AnimatedReloadsAction.getHandler(self)
    if handler and handler.onInsertLoadAmmo then
        local handled = handler.onInsertLoadAmmo(self)
        if handled then
            return
        end
    end

    originalInsertLoadAmmo(self)
end

local originalInsertPerform = ISInsertMagazine.perform

---@param self ISInsertMagazine
function ISInsertMagazine:perform()
    local handler = AnimatedReloadsAction.getHandler(self)
    if handler and handler.onInsertPerform then
        local handled = handler.onInsertPerform(self)
        if handled then
            return
        end
    end

    originalInsertPerform(self)
    AnimatedReloadsAction.resetWeaponModel(self, handler)
end

local originalRackStart = ISRackFirearm.start

---@param self ISRackFirearm
function ISRackFirearm:start()
    if self and self.gun then
        local modData = self.gun:getModData()
        if modData and modData.shortRackAfterInsert then
            self.useShortRack = true
            modData.shortRackAfterInsert = nil
        end
    end

    local handler = AnimatedReloadsAction.getHandler(self)
    if handler and handler.onRackStart then
        local handled = handler.onRackStart(self)
        if handled then
            return
        end
    end

    originalRackStart(self)
end

---@param self ISRackFirearm
function ISRackFirearm:serverStart()
    local handler = AnimatedReloadsAction.getHandler(self)
    self:ejectSpentRounds()
    self:initVars()
    local durationMs = AnimatedReloadsAction.getActionDurationMs(self, handler and handler.rackDuration, 1200)
    emulateAnimEventOnce(self.netAction, math.min(100, durationMs), "rackBullet", nil)
    emulateAnimEventOnce(self.netAction, durationMs, "rackingFinished", nil)
end

local originalRackStop = ISRackFirearm.stop

---@param self ISRackFirearm
function ISRackFirearm:stop()
    local handler = AnimatedReloadsAction.getHandler(self)
    if handler and handler.onRackStop then
        local handled = handler.onRackStop(self)
        if handled then
            return
        end
    end

    originalRackStop(self)
end

local originalRackPerform = ISRackFirearm.perform

---@param self ISRackFirearm
function ISRackFirearm:perform()
    local handler = AnimatedReloadsAction.getHandler(self)
    if handler and handler.onRackPerform then
        local handled = handler.onRackPerform(self)
        if handled then
            return
        end
    end

    originalRackPerform(self)
end

AnimatedReloadsAction.initializeSharedSystems()

return AnimatedReloadsAction
