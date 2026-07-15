-- Gunworks: shared per-tick weapon-part reconcile scheduler.
--
-- Historically each weapon subsystem added its OWN Events.OnPlayerUpdate handler to keep a gun's
-- cosmetic parts in sync with its state (the reload flint + ensured parts, the double-barrel locks,
-- and more to come with the unified action system). That meant N independent per-tick passes with no
-- defined order between them -- which is exactly where "a part flickers for a frame" desync bugs breed.
--
-- This module replaces those with ONE ordered pass: each subsystem registers a provider, and a single
-- OnPlayerUpdate runs them in a fixed order for the local player. Providers keep full ownership of their
-- own logic (including any MP nudge / server authority); this module owns only the dispatch, the
-- ordering, per-provider fault isolation, and a boot-time conflict warning.
--
-- Providers MUST be idempotent (swap a part only when desired ~= current) -- they already are.

local PartReconcile = {}

---@class GunworksPartProvider
---@field id string
---@field order number
---@field fn fun(player: IsoPlayer)
---@field partTypes string[]|nil

---@type GunworksPartProvider[]
local providers = {}

local function sortByOrder()
    table.sort(providers, function(a, b) return a.order < b.order end)
end

--- Register a per-tick part reconciler. `fn(player)` is invoked once per local-player tick in ascending
--- `order`. `partTypes` (optional) are the static PartType strings this provider owns; they are used
--- only by the boot-time conflict check. Re-registering the same `id` replaces it (reload-safe).
---@param id string
---@param order number
---@param fn fun(player: IsoPlayer)
---@param partTypes string[]|nil
---@return nil
function PartReconcile.register(id, order, fn, partTypes)
    if type(id) ~= "string" or type(fn) ~= "function" then
        return
    end
    order = tonumber(order) or 0
    for i = 1, #providers do
        if providers[i].id == id then
            providers[i] = { id = id, order = order, fn = fn, partTypes = partTypes }
            sortByOrder()
            return
        end
    end
    providers[#providers + 1] = { id = id, order = order, fn = fn, partTypes = partTypes }
    sortByOrder()
end

--- Introspection: the registered providers in run order (id + order). Handy for tests / debugging.
---@return { id: string, order: number }[]
function PartReconcile.list()
    local out = {}
    for i = 1, #providers do
        out[i] = { id = providers[i].id, order = providers[i].order }
    end
    return out
end

--- The single ordered pass. Each provider is isolated by pcall, so one bad tick on some odd weapon
--- cannot break the others -- or spam-error every gun (including mods that don't use the framework).
---@param player IsoPlayer|nil
---@return nil
local function runProviders(player)
    if not player then
        return
    end
    for i = 1, #providers do
        pcall(providers[i].fn, player)
    end
end

-- Boot-time conflict detector: warn if two providers declare the SAME static PartType -- the one overlap
-- the ordered pass cannot resolve for you (they would fight over that part every tick). Dynamic per-gun
-- PartTypes (e.g. the reload flint, chosen per weapon) are not declared here and so are not checked.
local function checkConflicts()
    local owner = {}
    for i = 1, #providers do
        local p = providers[i]
        if p.partTypes then
            for j = 1, #p.partTypes do
                local pt = p.partTypes[j]
                if owner[pt] and owner[pt] ~= p.id then
                    print(string.format(
                        "[Gunworks/PartReconcile] WARNING: PartType '%s' is claimed by both '%s' and '%s' "
                        .. "-- they will fight over it every tick. Assign it to exactly one provider.",
                        tostring(pt), tostring(owner[pt]), tostring(p.id)))
                else
                    owner[pt] = p.id
                end
            end
        end
    end
end

-- The dedicated server fires no per-player tick (IsoPlayer.update returns before the OnPlayerUpdate
-- trigger on a server; see PartState.lua), so the pass is client / singleplayer only. Each subsystem
-- reconciles server-authoritatively through its own command path when running on the dedicated server.
if not isServer() then
    Events.OnPlayerUpdate.Add(runProviders)
end
Events.OnGameBoot.Add(checkConflicts)

return PartReconcile
