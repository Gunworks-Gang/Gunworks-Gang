local GunworksSharedUtils = {}

--- Override a single script property on an already-loaded item.
---
--- Thin wrapper around `ScriptItem:DoParam`. If the item does not exist
--- (usually because the mod that defines it is not enabled) the call is a
--- silent no-op, so patch scripts can run unconditionally.
---@param name string      full item type, e.g. `"Base.Bullets9mm"`
---@param property string  script property to set, e.g. `"Icon"`, `"Weight"`, `"WorldStaticModel"`
---@param value any        new value; concatenated into `"<property> = <value>"`
function GunworksSharedUtils.Adjust(name, property, value)
    local item = ScriptManager.instance:getItem(name)
    if not item then return end
    item:DoParam(property .. " = " .. value)
end

--- Add one or more tags to an already-loaded item without dropping its existing tags.
---
--- Tags the item already carries are left untouched; only genuinely new tags
--- are added. No-op if the item does not exist. Accepts either a single tag
--- string or an array of tag strings.
---@param item string           full item type, e.g. `"Base.Bullets9mm"`
---@param tags string|string[]  one tag, or a list of tags, to add
function GunworksSharedUtils.AddTagsToItem(item, tags)
    local itemScript = ScriptManager.instance:getItem(item)
    if not itemScript then return end

    local currentTags = itemScript:getTags()
    local tagList = type(tags) == "table" and tags or { tags }

    for _, addValue in ipairs(tagList) do
        if not currentTags:contains(addValue) then
            currentTags:add(addValue)
        end
    end
end

--- Reskin / reweight a piece of ammunition in a single call.
---
--- Convenience wrapper over `Adjust` + `AddTagsToItem` covering the fields a
--- content mod normally overrides when swapping vanilla-compatible rounds for
--- its own art. Every field is optional; anything omitted is left as-is.
---@class GunworksAmmoStats
---@field icon string|nil                inventory icon name (without the `Item_` prefix)
---@field worldStaticModel string|nil    world model, e.g. `"MarzGuns.9x19_Round_Base"`
---@field weight string|number|nil       item weight
---@field metalValue string|number|nil   item metalValue
---@field tags string|string[]|nil       extra tag(s) to add, e.g. `"MarzGuns:ammo20"`
---
---@param item string  full ammo item type, e.g. `"SWMG.9x19_Bullet"`
---@param params GunworksAmmoStats
function GunworksSharedUtils.AdjustAmmunitionStats(item, params)
    if params.icon then GunworksSharedUtils.Adjust(item, "Icon", params.icon) end
    if params.worldStaticModel then GunworksSharedUtils.Adjust(item, "WorldStaticModel", params.worldStaticModel) end
    if params.weight then GunworksSharedUtils.Adjust(item, "Weight", params.weight) end
    if params.metalValue then GunworksSharedUtils.Adjust(item, "metalValue", params.metalValue) end
    if params.tags then GunworksSharedUtils.AddTagsToItem(item, params.tags) end
end

return GunworksSharedUtils
