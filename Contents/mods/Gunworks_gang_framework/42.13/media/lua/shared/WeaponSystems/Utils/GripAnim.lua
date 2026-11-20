-- Gunworks grip-animation framework: registry + per-tick selector derivation.
--
-- The held-pose counterpart to ReloadAnim: while a registered gun is in the primary hand,
-- GunworksGripAnim = the gun's grip animId. The weapon pack's held/aim AnimSet nodes gate on
-- that variable, so a registered gun uses a custom grip/aim pose. Selection is by a matches(gun)
-- predicate (attachment-conditional grips of one gun), then by the gun's fullType, then by a
-- registered weapon part installed on the gun (e.g. any gun carrying a vertical foregrip).
-- Client-side rendering only (no server authority); MP observers are covered by the same OnTick
-- sweep the reload system uses. Registry structure mirrors WeaponSystems/Utils/ReloadAnim.lua.
--
-- The "Foregrip" grip set ships with Guns of Marz: every idle/move/aim/fire node of two-handed
-- firearms with the left hand on a vertical foregrip (AnimSets/<set>/<state>/Foregrip_Rifle,
-- GW_Foregrip_* nodes) and the clips they play (anims_X/Bob/Foregrip_Rifle, Marz_Foregrip_*).
-- A weapon pack only registers its foregrip attachments: GripAnim.RegisterMultipleForegrips({...}).
--
-- A gun's own grip may name variants per part grip: { animId = "SMG", variants = { Foregrip = "ForegripSMG" } }
-- plays ForegripSMG while a registered "Foregrip" part is installed, and SMG otherwise.

local GripAnim = {}

GripAnim.ANIM_VARIABLE = "GunworksGripAnim"
GripAnim.FOREGRIP = "Foregrip"

---@class GunworksGripAnimHandler
---@field id       string
---@field fullType string | nil
---@field animId   string
---@field matches  fun(gun: HandWeapon): boolean | nil
---@field variants table<string, GunworksGripAnimHandler> | nil

---@type GunworksGripAnimHandler[]
GripAnim.handlers = {}
---@type table<string, GunworksGripAnimHandler>
GripAnim.byFullType = {}
---@type GunworksGripAnimHandler[]
GripAnim.matchers = {}
---@type table<string, GunworksGripAnimHandler>
GripAnim.byPart = {}

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

--- The grip of the first registered weapon part installed on the gun.
---@param gun HandWeapon
---@nodiscard
---@return GunworksGripAnimHandler | nil
local function gripForParts(gun)
    local byPart = GripAnim.byPart
    local parts = gun:getAllWeaponParts()
    for i = 0, parts:size() - 1 do
        local handler = byPart[parts:get(i):getFullType()]
        if handler then
            return handler
        end
    end
    return nil
end

--- Resolve the grip handler for a gun: predicate matchers first, then the fullType index, then
--- the registered weapon parts installed on the gun. A gun's own grip switches to its variant for
--- the grip of an installed part (SMG + Foregrip part -> ForegripSMG).
---@param gun HandWeapon | nil
---@nodiscard
---@return GunworksGripAnimHandler | nil
function GripAnim.GetGripForGun(gun)
    if not instanceof(gun, "HandWeapon") then
        return nil
    end

    local handler = nil
    local matchers = GripAnim.matchers
    for i = 1, #matchers do
        if matchers[i].matches(gun) then
            handler = matchers[i]
            break
        end
    end
    handler = handler or GripAnim.byFullType[gun:getFullType()]

    if not handler then
        return gripForParts(gun)
    end
    if handler.variants then
        local part = gripForParts(gun)
        if part and handler.variants[part.animId] then
            return handler.variants[part.animId]
        end
    end
    return handler
end

--- Public API: any gun with this weapon part installed uses the grip animation (unless the gun has
--- its own grip registered by fullType or by a matches predicate, which win).
---@param partFullType string             weapon part item fullType, e.g. "MarzGuns.Stub_Foregrip"
---@param profile      { animId: string }
---@return nil
function GripAnim.RegisterPart(partFullType, profile)
    if not partFullType or not profile or not profile.animId or profile.animId == "" then
        return
    end

    GripAnim.byPart[partFullType] = { id = "part:" .. partFullType, animId = profile.animId }
end

--- Public API: register many parts at once. Keys are weapon part fullTypes.
---@param entries table<string, { animId: string }>
---@return nil
function GripAnim.RegisterMultipleParts(entries)
    if not entries then
        return
    end
    for partFullType, profile in pairs(entries) do
        GripAnim.RegisterPart(partFullType, profile)
    end
end

--- Public API: a vertical foregrip attachment; guns carrying it use the Gunworks foregrip grip.
---@param partFullType string
---@return nil
function GripAnim.RegisterForegrip(partFullType)
    GripAnim.RegisterPart(partFullType, { animId = GripAnim.FOREGRIP })
end

--- Public API: register many foregrip attachments at once.
---@param partFullTypes string[]
---@return nil
function GripAnim.RegisterMultipleForegrips(partFullTypes)
    if not partFullTypes then
        return
    end
    for i = 1, #partFullTypes do
        GripAnim.RegisterForegrip(partFullTypes[i])
    end
end

--- Public API: register a grip animation for a gun. Prefer Gunworks.RegisterWeapon.
--- profile.variants maps a part grip animId to the animId this gun plays while that part is installed.
---@param fullType string | nil                                                                                                                 weapon fullType (nil only if profile.matches is set)
---@param profile  { animId: string, matches: fun(gun: HandWeapon): boolean | nil, id: string | nil, variants: table<string, string> | nil }
---@return nil
function GripAnim.RegisterWeapon(fullType, profile)
    if not profile or not profile.animId or profile.animId == "" then
        return
    end
    if not fullType and not profile.matches then
        return
    end

    local id = profile.id or fullType or profile.animId
    local variants = nil
    if profile.variants then
        variants = {}
        for partAnimId, animId in pairs(profile.variants) do
            variants[partAnimId] = { id = id .. "+" .. partAnimId, fullType = fullType, animId = animId }
        end
    end

    GripAnim.registerHandler({
        id = id,
        fullType = fullType,
        animId = profile.animId,
        matches = profile.matches,
        variants = variants,
    })
end

--- Public API: register many guns at once. Keys are weapon fullTypes.
---@param entries table<string, { animId: string, variants: table<string, string> | nil }>
---@return nil
function GripAnim.RegisterMultipleWeapons(entries)
    if not entries then
        return
    end
    for fullType, profile in pairs(entries) do
        GripAnim.RegisterWeapon(fullType, profile)
    end
end

-- Transition cache: last value applied per player (keyed by onlineID) so the per-tick pass only
-- writes the variable on a change, never every frame.
---@type table<number, string | false>
local lastGripByOnlineId = {}

--- Per-player tick pass: derive GunworksGripAnim from the held weapon's registered grip animId.
---@param player IsoPlayer | nil
---@return nil
local function deriveGripForPlayer(player)
    if not player then
        return
    end

    local onlineId = player:getOnlineID()
    ---@type string | false
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
    Events.OnTick.Add(function ()
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
