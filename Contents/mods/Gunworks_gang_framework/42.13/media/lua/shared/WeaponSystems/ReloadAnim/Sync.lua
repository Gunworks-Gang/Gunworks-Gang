-- Gunworks reload-animation framework: multiplayer variable propagation.
--
-- Timed actions replicate their animation variables when PlayerActionsState is entered.
-- Observers do not run the reloader's Lua start hooks, and custom selectors set after
-- that snapshot are not included. Derive GunworksReloadAnim on every rendering machine
-- from the synced PerformingAction state and the equipped gun's shared registry profile.
-- This also supports profiles whose XML nodes use WeaponReloadType directly.
--
-- Compare against the actual variables on each pass: successive eject/insert/rack actions
-- can reset them while the desired animId stays the same. Caching only the last animId
-- misses both those resets and phase changes. Write only mismatches, and clear the custom
-- selector when the reload ends; this also avoids sharing a cache across SP/split-screen
-- players whose online IDs may be identical.

---@class GunworksReloadAnim
local ReloadAnim = require("WeaponSystems/Utils/ReloadAnim")
-- Register the input repair AFTER vanilla's reload/rack handlers, including when
-- this module is required directly rather than through ReloadAnimHooks.
require("TimedActions/ISReloadWeaponAction")

--- Set the selector on a character.
---@param character IsoGameCharacter|nil
---@param animId string|nil
---@return nil
function ReloadAnim.setReloadAnimVar(character, animId)
    if not character or not animId then
        return
    end

    character:setVariable(ReloadAnim.ANIM_VARIABLE, animId)
end

--- Clear the selector on a character.
---@param character IsoGameCharacter|nil
---@return nil
function ReloadAnim.clearReloadAnimVar(character)
    if not character then
        return
    end

    character:clearVariable(ReloadAnim.ANIM_VARIABLE)
end

--- Per-player tick pass: derive GunworksReloadAnim for EVERY player (local reloader + remote
--- observers + the server's view) from their synced reload state + equipped weapon.
---@param player IsoPlayer|nil
---@return nil
local function deriveReloadAnimForPlayer(player)
    if not player then
        return
    end

    local handler = nil

    if player:getVariableString("PerformingAction") == "Reload" then
        local item = player:getPrimaryHandItem()
        handler = ReloadAnim.GetHandlerForGun(item)
    end

    local current = player:getVariableString(ReloadAnim.ANIM_VARIABLE)
    if handler then
        local desired = handler.animId
        if current ~= desired then
            player:setVariable(ReloadAnim.ANIM_VARIABLE, desired)
        end

        -- RackAiming and the reload phase flags already ride the action snapshot. Select
        -- the custom family during rack as well as load, without changing those flags.
        -- Non-magazine unload still requires the profile's explicit customUnload opt-in;
        -- packs without a matching Unload node must retain their engine reload type.
        local useCustomType = player:getVariableBoolean("isLoading")
            or player:getVariableBoolean("isLoadingShort")
            or player:getVariableBoolean("isRacking")
            or (player:getVariableBoolean("isUnloading")
                and (not ReloadAnim.isNonMagArchetype(handler.archetype) or handler.customUnload))
        if useCustomType and player:getVariableString("WeaponReloadType") ~= desired then
            player:setVariable("WeaponReloadType", desired)
        end
    elseif current and current ~= "" then
        player:clearVariable(ReloadAnim.ANIM_VARIABLE)
    end
end

-- The LOCAL player is derived via OnPlayerUpdate, which fires for the local player on every
-- rendering machine - crucially including SINGLEPLAYER, where getOnlinePlayers() returns an empty
-- list (LuaManager: SP is neither GameServer.server nor GameClient.client).
Events.OnPlayerUpdate.Add(deriveReloadAnimForPlayer)

-- IsoPlayer.checkReloading runs AFTER OnPlayerUpdate and resets WeaponReloadType
-- before firing either key event. If a rack is already active, the vanilla handler
-- only queues the next action: its start hook cannot repair the active selector.
-- Restore it before animation evaluation so repeated key presses cannot switch the
-- current clip to vanilla and re-fire rackBullet's Start event mid-rack.
Events.OnPressRackButton.Add(deriveReloadAnimForPlayer)
Events.OnPressReloadButton.Add(deriveReloadAnimForPlayer)

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
