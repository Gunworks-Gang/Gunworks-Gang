-- Gunworks reload-animation framework: composed timed-action hooks.
--
-- This file MUST load after the other Gunworks hook files so its captured originals
-- already include their wrappers. Within media/lua/shared/WeaponSystems/Hooks/ the
-- engine auto-loads alphabetically: AnimationsHooks -> CustomSystemHooks ->
-- ReloadAnimHooks -> WeaponUpgradeHooks. So every "prev" captured below is the
-- Gunworks+vanilla chain, and this layer wraps it OUTERMOST: run the reload-anim
-- handler dispatch, then defer to prev. Guns without a registered reload-anim profile
-- fall straight through to prev, so vanilla and every other Gunworks weapon are
-- unaffected.

require("TimedActions/ISEjectMagazine")
require("TimedActions/ISInsertMagazine")
require("TimedActions/ISRackFirearm")
require("TimedActions/ISTimedActionQueue")
require("TimedActions/ISReloadWeaponAction")

---@class GunworksReloadAnim
local ReloadAnim = require("WeaponSystems/Utils/ReloadAnim")
require("WeaponSystems/ReloadAnim/HandlerFactory")
require("WeaponSystems/ReloadAnim/Timing")
require("WeaponSystems/ReloadAnim/Visuals")
require("WeaponSystems/ReloadAnim/Sync")
require("WeaponSystems/ReloadAnim/PartState")
require("WeaponSystems/ReloadAnim/PartSwap")
local SpeedLoader = require("WeaponSystems/Utils/SpeedLoader")

-- Re-wrap on every load. A Core.ResetLua (e.g. a client joining a modded MP server)
-- resets the vanilla timed-action classes to unwrapped, so these hooks MUST re-apply
-- each time this file runs. We deliberately do NOT guard on a flag: the require cache
-- can return the same ReloadAnim table across a ResetLua while the vanilla classes are
-- fresh, so a flag would wrongly skip re-wrapping and silently disable the reload anims.
-- Capturing the current (already Gunworks+vanilla-wrapped) method as "prev" each load is
-- safe because PZ runs this file once per VM via the module loader.

-------------------------------------------------
-- ISEjectMagazine
-------------------------------------------------
local prevEjectStart = ISEjectMagazine.start
---@param self ISEjectMagazine
function ISEjectMagazine:start()
    local handler = ReloadAnim.getHandlerForAction(self)
    prevEjectStart(self)
    if handler and handler.onEjectStart then
        if handler.onEjectStart(self) then
            return
        end
    end
end

-- Gunworks does not wrap Eject.serverStart, so prev is vanilla. For a registered gun
-- we replace it with a custom-duration finish event; unregistered guns keep vanilla.
local prevEjectServerStart = ISEjectMagazine.serverStart
---@param self ISEjectMagazine
function ISEjectMagazine:serverStart()
    local handler = ReloadAnim.getHandlerForAction(self)
    if not handler then
        return prevEjectServerStart(self)
    end

    self:initVars()
    local durationMs = ReloadAnim.getActionDurationMs(self, handler.unloadDuration, 1200)
    emulateAnimEventOnce(self.netAction, durationMs, "unloadFinished", nil)
end

local prevEjectAnimEvent = ISEjectMagazine.animEvent
---@param self ISEjectMagazine
---@param event string
---@param parameter string
function ISEjectMagazine:animEvent(event, parameter)
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onEjectAnimEvent then
        if handler.onEjectAnimEvent(self, event, parameter) then
            return
        end
    end

    prevEjectAnimEvent(self, event, parameter)
end

local prevEjectStop = ISEjectMagazine.stop
---@param self ISEjectMagazine
function ISEjectMagazine:stop()
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onEjectStop then
        if handler.onEjectStop(self) then
            return
        end
    end

    prevEjectStop(self)
    if handler then
        ReloadAnim.resetWeaponModel(self, handler)
    end
end

local prevEjectPerform = ISEjectMagazine.perform
---@param self ISEjectMagazine
function ISEjectMagazine:perform()
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onEjectPerform then
        if handler.onEjectPerform(self) then
            return
        end
    end

    prevEjectPerform(self)
    if handler then
        ReloadAnim.resetWeaponModel(self, handler)
    end
end

-------------------------------------------------
-- ISInsertMagazine
-------------------------------------------------
local prevInsertStart = ISInsertMagazine.start
---@param self ISInsertMagazine
function ISInsertMagazine:start()
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onInsertStart then
        handler.onInsertStart(self)
    end

    prevInsertStart(self)

    if handler then
        if self.shouldShortRackAfterInsert and ReloadAnim.shouldQueueShortRackAfterInsert(self) then
            self:setAnimVariable("isLoadingShort", true)
            if self.character then
                self.character:clearVariable("isLoading")
            end
        end
    end
end

-- Gunworks DOES wrap Insert.serverStart (vanilla + a speedloader eject side-effect).
-- The registered-gun path uses a custom finish-event duration and skips prev, so it
-- must inline that one side-effect; unregistered guns keep the full Gunworks+vanilla path.
local prevInsertServerStart = ISInsertMagazine.serverStart
---@param self ISInsertMagazine
function ISInsertMagazine:serverStart()
    local handler = ReloadAnim.getHandlerForAction(self)
    if not handler then
        return prevInsertServerStart(self)
    end

    self:initVars()
    if self.magazine and SpeedLoader.IsCompatibleTypeForGun(self.magazine:getFullType(), self.gun) then
        ISReloadWeaponAction.ejectSpentRounds(self)
    end

    local loadSeconds = handler.loadDuration
    if ReloadAnim.shouldUseShortLoad(self, handler) then
        loadSeconds = handler.loadShortDuration or handler.loadDuration
    end
    local durationMs = ReloadAnim.getActionDurationMs(self, loadSeconds, 1500)
    emulateAnimEventOnce(self.netAction, durationMs, "loadFinished", nil)
end

local prevInsertAnimEvent = ISInsertMagazine.animEvent
---@param self ISInsertMagazine
---@param event string
---@param parameter string
function ISInsertMagazine:animEvent(event, parameter)
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onInsertAnimEvent then
        if handler.onInsertAnimEvent(self, event, parameter) then
            return
        end
    end

    prevInsertAnimEvent(self, event, parameter)
end

local prevInsertLoadAmmo = ISInsertMagazine.loadAmmo
---@param self ISInsertMagazine
function ISInsertMagazine:loadAmmo()
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onInsertLoadAmmo then
        if handler.onInsertLoadAmmo(self) then
            return
        end
    end

    prevInsertLoadAmmo(self)
end

local prevInsertStop = ISInsertMagazine.stop
---@param self ISInsertMagazine
function ISInsertMagazine:stop()
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onInsertStop then
        if handler.onInsertStop(self) then
            return
        end
    end

    prevInsertStop(self)
    if handler then
        ReloadAnim.resetWeaponModel(self, handler)
    end
end

local prevInsertPerform = ISInsertMagazine.perform
---@param self ISInsertMagazine
function ISInsertMagazine:perform()
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onInsertPerform then
        if handler.onInsertPerform(self) then
            return
        end
    end

    prevInsertPerform(self)
    if handler then
        ReloadAnim.resetWeaponModel(self, handler)
    end
end

-------------------------------------------------
-- ISRackFirearm
-------------------------------------------------
local prevRackStart = ISRackFirearm.start
---@param self ISRackFirearm
function ISRackFirearm:start()
    if self and self.gun then
        local modData = self.gun:getModData()
        if modData and modData.shortRackAfterInsert then
            self.useShortRack = true
            modData.shortRackAfterInsert = nil
        end
    end

    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onRackStart then
        if handler.onRackStart(self) then
            return
        end
    end

    prevRackStart(self)
end

-- Gunworks does not wrap Rack.serverStart, so prev is vanilla. Registered guns get a
-- custom-duration rack; unregistered keep vanilla.
local prevRackServerStart = ISRackFirearm.serverStart
---@param self ISRackFirearm
function ISRackFirearm:serverStart()
    local handler = ReloadAnim.getHandlerForAction(self)
    if not handler then
        return prevRackServerStart(self)
    end

    self:ejectSpentRounds()
    self:initVars()
    local durationMs = ReloadAnim.getActionDurationMs(self, handler.rackDuration, 1200)
    emulateAnimEventOnce(self.netAction, math.min(100, durationMs), "rackBullet", nil)
    emulateAnimEventOnce(self.netAction, durationMs, "rackingFinished", nil)
end

local prevRackStop = ISRackFirearm.stop
---@param self ISRackFirearm
function ISRackFirearm:stop()
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onRackStop then
        handler.onRackStop(self)
    end

    prevRackStop(self)
end

local prevRackPerform = ISRackFirearm.perform
---@param self ISRackFirearm
function ISRackFirearm:perform()
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onRackPerform then
        handler.onRackPerform(self)
    end

    prevRackPerform(self)
end

-------------------------------------------------
-- ISReloadWeaponAction (non-magazine reloads: shotgun / revolver / bolt / dbl-barrel / lever)
-------------------------------------------------
-- Only non-mag archetype handlers carry onReload* callbacks, so a magazine gun (its handler
-- has none) and every unregistered gun fall straight through to vanilla. start/animEvent/stop/
-- perform add ONLY the optional off-hand prop and model swaps; the vanilla action keeps full
-- ownership of the shell-by-shell loadFinished/loadAmmo loop. serverStart additionally applies
-- the profile's authored load duration, but only when one is set - a registered gun without
-- durations.load keeps byte-for-byte vanilla timing.
local prevReloadStart = ISReloadWeaponAction.start
---@param self ISReloadWeaponAction
function ISReloadWeaponAction:start()
    local handler = ReloadAnim.getHandlerForAction(self)
    prevReloadStart(self)
    -- Vanilla start() just set the WeaponReloadType anim variable to the gun's engine reload type
    -- (e.g. "boltactionnomag"), which makes the matching vanilla reload node (LoadRifleNoMag) a
    -- candidate. Our custom node is gated on the separate GunworksReloadAnim variable, so the two
    -- compete - and for some archetypes the vanilla node wins even though ours has a higher
    -- ConditionPriority. Overwrite WeaponReloadType with our animId so NO vanilla reload node
    -- matches and only the custom node plays. Safe: this variable feeds AnimSet node conditions
    -- ONLY - the reload MECHANICS read gun:getWeaponReloadType() directly, never this variable.
    if handler and handler.animId and ReloadAnim.isNonMagArchetype(handler.archetype) then
        self:setAnimVariable("WeaponReloadType", handler.animId)
    end
    if handler and handler.onReloadStart then
        handler.onReloadStart(self)
    end
end

local prevReloadServerStart = ISReloadWeaponAction.serverStart
---@param self ISReloadWeaponAction
function ISReloadWeaponAction:serverStart()
    local handler = ReloadAnim.getHandlerForAction(self)
    if not handler or not ReloadAnim.isNonMagArchetype(handler.archetype) or handler.loadDuration == nil then
        return prevReloadServerStart(self)
    end

    self:initVars()
    if isServer() then
        self:ejectSpentRounds()
        if not self.bullets then
            self.netAction:forceComplete()
        end
    end

    -- emulateAnimEvent REPEATS: each loadFinished loads one round, so this is the per-round interval.
    emulateAnimEvent(self.netAction, ReloadAnim.getActionDurationMs(self, handler.loadDuration, 0), "loadFinished", nil)
end

local prevReloadAnimEvent = ISReloadWeaponAction.animEvent
---@param self ISReloadWeaponAction
---@param event string
---@param parameter string
function ISReloadWeaponAction:animEvent(event, parameter)
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onReloadAnimEvent then
        handler.onReloadAnimEvent(self, event, parameter)
    end

    -- Always run vanilla: its animEvent owns loadFinished -> loadAmmo (shell-by-shell load)
    -- and rackingFinished. Skipping it would stop ammo from loading.
    prevReloadAnimEvent(self, event, parameter)

    -- Muzzle-loaders (autoRack = false) have no break-action to close. The vanilla double-barrel
    -- reload runs a close/rack "snap-back" stage right after the rounds load (playReloadSound rack ->
    -- rackBullet -> rackingFinished). The rounds are already in by loadFinished, so force-complete the
    -- action here to end it before that stage starts and the snap-back animation plays.
    if event == "loadFinished" and handler and handler.autoRack == false then
        self:forceComplete()
    end
end

local prevReloadStop = ISReloadWeaponAction.stop
---@param self ISReloadWeaponAction
function ISReloadWeaponAction:stop()
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onReloadStop then
        handler.onReloadStop(self)
    end

    prevReloadStop(self)
    if handler then
        ReloadAnim.resetWeaponModel(self, handler)
    end
end

local prevReloadPerform = ISReloadWeaponAction.perform
---@param self ISReloadWeaponAction
function ISReloadWeaponAction:perform()
    local handler = ReloadAnim.getHandlerForAction(self)
    if handler and handler.onReloadPerform then
        handler.onReloadPerform(self)
    end

    prevReloadPerform(self)
    if handler then
        ReloadAnim.resetWeaponModel(self, handler)
    end
end

return ReloadAnim
