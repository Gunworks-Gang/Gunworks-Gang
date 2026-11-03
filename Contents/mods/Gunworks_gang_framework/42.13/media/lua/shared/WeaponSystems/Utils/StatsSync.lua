local StatsFactory = require("WeaponSystems/Utils/StatsFactory")

local StatsSync = {}

-------------------------------------------------
-- MP sync for re-applied modifier layers.
-------------------------------------------------
StatsSync.REVISION_KEY = "GW_StatsRevision"

local appliedRevisions = {}

--- Server: call after the weapon's parts changed and ReapplyAllModifiers ran.
--- No-op in singleplayer and on clients, where the local weapon already changed.
---@param player IsoPlayer
---@param weapon HandWeapon
function StatsSync.SendToClients(player, weapon)
    if not isServer() then return end

    local modData = weapon:getModData()
    modData[StatsSync.REVISION_KEY] = (modData[StatsSync.REVISION_KEY] or 0) + 1
    syncHandWeaponFields(player, weapon)

    if player:getPrimaryHandItem() == weapon or player:getSecondaryHandItem() == weapon then
        sendEquip(player)
    end
end

--- Client: re-apply the held gun's modifier layers whenever its server revision changes.
--- synced stats, and the full re-apply fixes them.
---@param player IsoPlayer
function StatsSync.ApplyServerRevision(player)
    if not isClient() or not player:isLocalPlayer() then return end

    local weapon = player:getPrimaryHandItem()
    if not instanceof(weapon, "HandWeapon") then return end

    local itemId = weapon:getID()
    local revision = weapon:getModData()[StatsSync.REVISION_KEY] or 0
    local applied = appliedRevisions[itemId]
    appliedRevisions[itemId] = revision
    if applied == nil or applied == revision then return end

    StatsFactory.ReapplyAllModifiers(weapon)
    player:resetEquippedHandsModels()
end

Events.OnPlayerUpdate.Add(StatsSync.ApplyServerRevision)

return StatsSync
