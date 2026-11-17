local StatsFactory = require("WeaponSystems/Utils/StatsFactory")
local StatsSync = require("WeaponSystems/Utils/StatsSync")
local Underbarrel = require("WeaponSystems/Utils/Underbarrel")
local Animations = require("WeaponSystems/Utils/Animations")

local AttachmentsDurability = {}

local r = newrandom()

AttachmentsDurability.Registries = {}

---@param attachmentFullTypes string | string[]
function AttachmentsDurability.RegisterAttachment(attachmentFullTypes)
    if type(attachmentFullTypes) == "table" then
        for i = 1, #attachmentFullTypes do
            AttachmentsDurability.Registries[attachmentFullTypes[i]] = true
        end
        return
    end
    AttachmentsDurability.Registries[attachmentFullTypes] = true
end

function AttachmentsDurability.IsAttachmentRegistered(attachmentFullType)
    return AttachmentsDurability.Registries[attachmentFullType] == true
end

local function getRegisteredParts(weapon)
    local parts = weapon:getAllWeaponParts()
    local registered = {}
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if AttachmentsDurability.IsAttachmentRegistered(part:getFullType()) then
            registered[#registered + 1] = part
        end
    end
    return registered
end

local function removeBrokenPart(player, weapon, part)
    weapon:detachWeaponPart(player, part)
    Underbarrel.HandleAttachmentRemoval(weapon, part, player)
    Animations.CallSyncHandWeaponFields(player, weapon)
    player:getInventory():AddItem(part)
    sendAddItemToContainer(player:getInventory(), part)
end

function AttachmentsDurability.RollConditionLowering(player, weapon)
    local parts = getRegisteredParts(weapon)
    local damaged, broken = false, false
    for i = 1, #parts do
        local part = parts[i]
        if r:random(part:getConditionLowerChance()) == 1 then
            part:setCondition(part:getCondition() - 1)
            damaged = true
            if part:isBroken() then
                removeBrokenPart(player, weapon, part)
                broken = true
            end
        end
    end

    if broken then
        StatsFactory.ReapplyAllModifiers(weapon)
        StatsSync.SendToClients(player, weapon)
    elseif damaged then
        syncHandWeaponFields(player, weapon)
    end
end

return AttachmentsDurability
