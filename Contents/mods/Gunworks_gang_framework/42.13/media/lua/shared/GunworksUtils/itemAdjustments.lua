local GunworksSharedUtils = {}
local table_concat = table.concat

--- Set a script property on an item. No-op if the item does not exist.
---@param name string      full item type, e.g. `"Base.Bullets9mm"`
---@param property string  script property to set, e.g. `"Icon"`, `"Weight"`, `"WorldStaticModel"`
---@param value any        new value; concatenated into `"<property> = <value>"`
function GunworksSharedUtils.Adjust(name, property, value)
    local item = ScriptManager.instance:getItem(name)
    if not item then return end
    item:DoParam(property .. " = " .. value)
end

--- Add one or more tags to an item without removing existing tags.
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

--- Add one or more valid weapons to an attachment's MountOn list.
--- Existing mounts are preserved and duplicate or missing weapons are skipped.
---@param attachment string       full attachment item type
---@param weapons string|string[] one weapon type, or a list of weapon types
function GunworksSharedUtils.AddWeaponsToMountOn(attachment, weapons)
    local attachmentScript = ScriptManager.instance:getItem(attachment)
    if not attachmentScript then return end

    local mountOptions = instanceItem(attachment):getMountOn()
    local weaponList = type(weapons) == "table" and weapons or { weapons }
    local newMounts = {}

    for _, weapon in ipairs(weaponList) do
        if not mountOptions:contains(weapon) and instanceItem(weapon) then
            newMounts[#newMounts + 1] = weapon
        end
    end

    if #newMounts == 0 then return end

    for index = 0, mountOptions:size() - 1 do
        local weapon = mountOptions:get(index)
        if weapon and instanceItem(weapon) then
            newMounts[#newMounts + 1] = weapon
        end
    end

    attachmentScript:DoParam("MountOn = " .. table_concat(newMounts, "; "))
end

--- Add model weapon parts to an item. Invalid parts are skipped.
---@param itemName string  full weapon type, e.g. `"Base.AssaultRifle"`
---@param parts string[]|string[][]  one `{ partType, modelName, ... }` part, or a list of them
function GunworksSharedUtils.AddToModelWeaponPart(itemName, parts)
    local itemScript = ScriptManager.instance:getItem(itemName)
    if not itemScript then return end

    ---@type string[][]
    local partList = type(parts[1]) == "table" and parts or { parts }

    for _, part in ipairs(partList) do
        local fieldCount = #part
        if fieldCount >= 2 and fieldCount <= 4 then
            itemScript:DoParam("ModelWeaponPart = " .. table_concat(part, " "))
        end
    end
end

--- Adjust optional ammunition properties in one call.
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
