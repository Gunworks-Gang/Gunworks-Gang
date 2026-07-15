-- Gunworks grip-animation framework: registry + per-tick selector derivation.
--
-- The held-pose counterpart to ReloadAnim: while a registered gun is in the primary hand,
-- GunworksGripAnim = the gun's grip animId. The weapon pack's held/aim AnimSet nodes gate on
-- that variable, so a registered gun uses a custom grip/aim pose. Selection is by fullType, or
-- by a matches(gun) predicate for attachment-conditional grips (e.g. a different grip when a
-- foregrip is attached). Client-side rendering only (no server authority); MP observers are
-- covered by the same OnTick sweep the reload system uses. Registry structure mirrors
-- WeaponSystems/Utils/ReloadAnim.lua exactly.

local GripAnim = {}

GripAnim.ANIM_VARIABLE = "GunworksGripAnim"

---@class GunworksGripAnimHandler
---@field id string
---@field fullType string|nil
---@field animId string
---@field matches fun(gun:HandWeapon):boolean|nil

---@type GunworksGripAnimHandler[]
GripAnim.handlers = {}
---@type table<string,GunworksGripAnimHandler>
GripAnim.byFullType = {}
---@type GunworksGripAnimHandler[]
GripAnim.matchers = {}

--- Rebuild the lookup indexes from the flat handler list.
---@return nil
function GripAnim.reindex()
    local byFullType = {}
    local matchers = {}
    local list = GripAnim.handlers
    for i = 1, #list do
        local handler = list[i]
        if handler.matches then
            matchers[#matchers + 1] = handler
        end
        if handler.fullType then
            byFullType[handler.fullType] = handler
        end
    end
    GripAnim.byFullType = byFullType
    GripAnim.matchers = matchers
end

--- Register (or replace, by id) a grip handler.
---@param handler GunworksGripAnimHandler
---@return nil
function GripAnim.registerHandler(handler)
    if not handler or not handler.id then
        return
    end

    local list = GripAnim.handlers
    for i = 1, #list do
        if list[i].id == handler.id then
            list[i] = handler
            GripAnim.reindex()
            return
        end
    end

    list[#list + 1] = handler
    GripAnim.reindex()
end

---@nodiscard
---@return GunworksGripAnimHandler[]
function GripAnim.getHandlers()
    return GripAnim.handlers
end

--- Resolve the grip handler for a gun: predicate matchers first, then the fullType index.
---@param gun HandWeapon|nil
---@nodiscard
---@return GunworksGripAnimHandler|nil
function GripAnim.GetGripForGun(gun)
    if not instanceof(gun, "HandWeapon") then
        return nil
    end

    local matchers = GripAnim.matchers
    for i = 1, #matchers do
        if matchers[i].matches(gun) then
            return matchers[i]
        end
    end

    return GripAnim.byFullType[gun:getFullType()]
end

--- Public API: register a grip animation for a gun. Prefer Gunworks.RegisterWeapon.
---@param fullType string|nil  weapon fullType (nil only if profile.matches is set)
---@param profile {animId:string, matches:fun(gun:HandWeapon):boolean|nil, id:string|nil}
---@return nil
function GripAnim.RegisterWeapon(fullType, profile)
    if not profile or not profile.animId or profile.animId == "" then
        return
    end
    if not fullType and not profile.matches then
        return
    end

    GripAnim.registerHandler({
        id = profile.id or fullType or profile.animId,
        fullType = fullType,
        animId = profile.animId,
        matches = profile.matches,
    })
end

-- Transition cache: last value applied per player (keyed by onlineID) so the per-tick pass only
-- writes the variable on a change, never every frame.
---@type table<number, string|false>
local lastGripByOnlineId = {}

--- Per-player tick pass: derive GunworksGripAnim from the held weapon's registered grip animId.
---@param player IsoPlayer|nil
---@return nil
local function deriveGripForPlayer(player)
    if not player then
        return
    end

    local onlineId = player:getOnlineID()
    ---@type string|false
    local desired = false

    local handler = GripAnim.GetGripForGun(player:getPrimaryHandItem())
    if handler then
        desired = handler.animId
    end

    if lastGripByOnlineId[onlineId] == desired then
        return
    end
    lastGripByOnlineId[onlineId] = desired

    if desired then
        player:setVariable(GripAnim.ANIM_VARIABLE, desired)
    else
        player:clearVariable(GripAnim.ANIM_VARIABLE)
    end
end

-- LOCAL player (all machines incl. singleplayer) via OnPlayerUpdate; REMOTE observers (MP) via a
-- throttled OnTick sweep of connected players. Mirrors ReloadAnim/Sync.lua.
Events.OnPlayerUpdate.Add(deriveGripForPlayer)

if isClient() then
    local ticksSincePass = 0
    Events.OnTick.Add(function()
        ticksSincePass = ticksSincePass + 1
        if ticksSincePass < 3 then
            return
        end
        ticksSincePass = 0

        local players = getOnlinePlayers()
        if not players then
            return
        end

        for i = 0, players:size() - 1 do
            deriveGripForPlayer(players:get(i))
        end
    end)
end

return GripAnim
