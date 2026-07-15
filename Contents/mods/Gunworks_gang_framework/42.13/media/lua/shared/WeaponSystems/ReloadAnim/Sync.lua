-- Gunworks reload-animation framework: multiplayer variable propagation.
--
-- The per-gun selector GunworksReloadAnim is a character anim variable. Anim variables
-- are a per-machine local map (AnimState evaluates conditions locally) and are NOT
-- networked unless whitelisted + set on the local player, so a value set on the
-- reloader does not reach observers. Vanilla never relies on WeaponReloadType remotely
-- (it rides the synced PerformingAction state instead). We make GunworksReloadAnim
-- present on every rendering machine by RE-DERIVING it locally: the registry is shared
-- data on all clients + the server, so any machine can map a reloading player's equipped
-- weapon fullType to its animId. This sidesteps the proximity/whitelist limits of the
-- engine VariableSync path entirely.
--
-- This per-tick pass is the SINGLE source of truth for the variable, for EVERY player the
-- machine updates (the local reloader, MP observer clients, and the dedicated server's view
-- of connected players). It derives the value purely from synced state: PerformingAction
-- (set to "Reload" by every reload/rack/eject timed action) plus the equipped weapon's
-- registered animId. The timed-action hooks deliberately do NOT set/clear this variable -
-- doing so at action boundaries raced across the eject->insert->rack chain and left the
-- character stuck in the raised-arms fallback when a clear ran without a matching re-set.
-- Deriving it continuously is self-healing: while a reload is active and a registered gun is
-- held the variable is always present, and it clears the moment the reload ends.

---@class GunworksReloadAnim
local ReloadAnim = require("WeaponSystems/Utils/ReloadAnim")

--- Set the selector on the reloader (called by the hooks at action start).
---@param character IsoGameCharacter|nil
---@param animId string|nil
---@return nil
function ReloadAnim.setReloadAnimVar(character, animId)
    if not character or not animId then
        return
    end

    character:setVariable(ReloadAnim.ANIM_VARIABLE, animId)
end

--- Clear the selector (called by the hooks at action stop/perform).
---@param character IsoGameCharacter|nil
---@return nil
function ReloadAnim.clearReloadAnimVar(character)
    if not character then
        return
    end

    character:clearVariable(ReloadAnim.ANIM_VARIABLE)
end

-- Transition cache: last value applied per remote player (keyed by onlineID) so the
-- per-tick pass only writes the variable on a change, never every frame.
---@type table<number, string|false>
local lastAnimByOnlineId = {}

--- Per-player tick pass: derive GunworksReloadAnim for EVERY player (local reloader + remote
--- observers + the server's view) from their synced reload state + equipped weapon.
---@param player IsoPlayer|nil
---@return nil
local function deriveReloadAnimForPlayer(player)
    if not player then
        return
    end

    local onlineId = player:getOnlineID()
    ---@type string|false
    local desired = false

    if player:getVariableString("PerformingAction") == "Reload" then
        local item = player:getPrimaryHandItem()
        local handler = ReloadAnim.GetHandlerForGun(item)
        if handler then
            desired = handler.animId
        end
    end

    if lastAnimByOnlineId[onlineId] == desired then
        return
    end
    lastAnimByOnlineId[onlineId] = desired

    if desired then
        player:setVariable(ReloadAnim.ANIM_VARIABLE, desired)
        -- Overwrite the engine WeaponReloadType anim variable so the vanilla reload node
        -- (LoadRifleNoMag / LoadDblBarrel / ...) stops matching and only our custom node plays.
        -- This is the remote/self-healing counterpart to the same override in the
        -- ISReloadWeaponAction start hook: it covers MP observers, who render a remote reloader
        -- without ever running that action's start. Node-matching only - the reload mechanics read
        -- gun:getWeaponReloadType() directly, never this variable.
        --
        -- Gate on isLoading: the UNLOAD action (ISUnloadBulletsFromFirearm) also sets
        -- PerformingAction=Reload, but with isUnloading (not isLoading), and it has its own vanilla
        -- node (UnloadRifleNoMag) still keyed on the real WeaponReloadType. We must NOT override it
        -- there, or the unload would match no node (raised-arms fallback, round never ejected).
        if player:getVariableBoolean("isLoading") then
            player:setVariable("WeaponReloadType", desired)
        end
    else
        player:clearVariable(ReloadAnim.ANIM_VARIABLE)
    end
end

-- The LOCAL player is derived via OnPlayerUpdate, which fires for the local player on every
-- rendering machine - crucially including SINGLEPLAYER, where getOnlinePlayers() returns an empty
-- list (LuaManager: SP is neither GameServer.server nor GameClient.client).
Events.OnPlayerUpdate.Add(deriveReloadAnimForPlayer)

-- REMOTE players (MP observers watching someone else reload) never get an OnPlayerUpdate - a remote
-- player's IsoPlayer.update returns early via updateRemotePlayer before the trigger - so the custom
-- reload node would lose to vanilla on the observer. OnTick DOES fire on a client (IngameState), so
-- sweep the connected players there to derive the selector for the remote ones too. MP-client only:
-- in SP getOnlinePlayers() is empty (the local player is already covered above), and the dedicated
-- server neither fires OnTick nor renders.
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
            deriveReloadAnimForPlayer(players:get(i))
        end
    end)
end

return ReloadAnim
