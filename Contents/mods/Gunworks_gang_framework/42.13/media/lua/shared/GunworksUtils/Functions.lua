local GunworksSharedUtils = {}

local table_insert = table.insert
local table_concat = table.concat

function GunworksSharedUtils.Adjust(name, property, value)
    local item = ScriptManager.instance:getItem(name)
    if not item then return end
    item:DoParam(property .. " = " .. value)
end

function GunworksSharedUtils.AddTagsToItem(item, tags)
    local itemScript = ScriptManager.instance:getItem(item);
    if itemScript then
        local currentTags = itemScript:getTags();
        local newList = {};

        for i, addValue in ipairs(type(tags) ~= "table" and { tags } or tags) do
            if not currentTags:contains(addValue) then
                table_insert(newList, addValue);
            end
        end

        if #newList > 0 then
            itemScript:DoParam("Tags = " .. table_concat(newList, "; "));
        end
    end
end

return GunworksSharedUtils
