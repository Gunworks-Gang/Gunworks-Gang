---@class AnimatedReloadsAction
local AnimatedReloadsAction = require("AnimatedReloads/Action/Core")

---@class AnimatedReloadsHandler
---@field id string
---@field reloadType string|nil
---@field style string|nil
---@field loadedSprite string|nil
---@field unloadedSprite string|nil
---@field magItem string|nil
---@field magPart AnimatedReloadsPartSpec|string|nil
---@field parts table<string,AnimatedReloadsPartSpec>|nil
---@field states table<string,AnimatedReloadsAttachmentState>|nil
---@field loadedState string|nil
---@field unloadedState string|nil
---@field shortRackAfterInsert boolean|nil
---@field loadDuration number|nil
---@field loadShortDuration number|nil
---@field unloadDuration number|nil
---@field rackDuration number|nil
---@field matches fun(gun:HandWeapon):boolean|nil
---@field onEjectStart fun(action:ISEjectMagazine):boolean|nil
---@field onEjectAnimEvent fun(action:ISEjectMagazine,event:string,parameter:string):boolean|nil
---@field onEjectStop fun(action:ISEjectMagazine):boolean|nil
---@field onEjectPerform fun(action:ISEjectMagazine):boolean|nil
---@field onInsertStart fun(action:ISInsertMagazine):boolean|nil
---@field onInsertAnimEvent fun(action:ISInsertMagazine,event:string,parameter:string):boolean|nil
---@field onInsertStop fun(action:ISInsertMagazine):boolean|nil
---@field onInsertLoadAmmo fun(action:ISInsertMagazine):boolean|nil
---@field onInsertPerform fun(action:ISInsertMagazine):boolean|nil
---@field onRackStart fun(action:ISRackFirearm):boolean|nil
---@field onRackStop fun(action:ISRackFirearm):boolean|nil
---@field onRackPerform fun(action:ISRackFirearm):boolean|nil

---@class AnimatedReloadsPartSpec
---@field partType string|nil
---@field itemType string|nil
---@field doChange boolean|nil

---@class AnimatedReloadsAttachmentState
---@field attach (AnimatedReloadsPartSpec|string)[]|nil
---@field detach (AnimatedReloadsPartSpec|string)[]|nil

require("AnimatedReloads/Action/State")
require("AnimatedReloads/Action/Timing")
require("AnimatedReloads/Action/WeaponVisuals")
require("AnimatedReloads/Action/HandlerFactory")
require("AnimatedReloads/Action/CommandSync")
require("AnimatedReloads/Action/Bootstrap")

return AnimatedReloadsAction
