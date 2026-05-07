local DynamicAttachment = {}
local StatsFactory = require("WeaponSystems/Utils/StatsFactory")

-------------------------------------------------
-- Registry: attachmentFullType -> partnerFullType
-- Bidirectional – registering a pair adds both directions.
-------------------------------------------------
DynamicAttachment.AttachmentPairs = {}

--- Register an attachment pair (bidirectional swap).
--- @param attachmentA string  e.g. "MWA.BIPOD"
--- @param attachmentB string  e.g. "MWA.BIPOD_RETRACTED"
function DynamicAttachment.RegisterPair(attachmentA, attachmentB)
    DynamicAttachment.AttachmentPairs[attachmentA] = attachmentB
    DynamicAttachment.AttachmentPairs[attachmentB] = attachmentA
end

-------------------------------------------------
-- Query helpers
-------------------------------------------------

--- Returns the partner attachment type if any installed attachment is a registered pair member, or nil.
--- Also returns the partType slot so we know where to swap.
--- @param weapon HandWeapon
--- @return string|nil partnerType, string|nil partType, WeaponPart|nil currentPart
function DynamicAttachment.GetSwappableAttachment(weapon)
    if not weapon then return nil end

    local parts = weapon:getAllWeaponParts()
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part then
            local fullType = part:getFullType()
            local partner = DynamicAttachment.AttachmentPairs[fullType]
            if partner then
                return partner, part:getPartType(), part
            end
        end
    end
    return nil
end

--- Check whether the weapon has any swappable attachment pair installed.
--- @param weapon HandWeapon
--- @return boolean
function DynamicAttachment.HasSwappableAttachment(weapon)
    return DynamicAttachment.GetSwappableAttachment(weapon) ~= nil
end

function DynamicAttachment.DeployedBipodAdjustStats(weapon)
    if not weapon then return end
    StatsFactory.ReapplyAllModifiers(weapon)
end

-------------------------------------------------
-- Core swap
-------------------------------------------------

--- Swap the currently installed paired attachment with its partner.
--- @param weapon HandWeapon
function DynamicAttachment.SwapAttachment(weapon)
    if not weapon then return end

    local partnerType, partType, currentPart = DynamicAttachment.GetSwappableAttachment(weapon)
    if not partnerType or not partType then return end

    if currentPart then
        weapon:detachWeaponPart(currentPart)
    end

    local newPart = instanceItem(partnerType)
    if newPart and instanceof(newPart, "WeaponPart") then
        weapon:attachWeaponPart(newPart, true)
    end
    DynamicAttachment.DeployedBipodAdjustStats(weapon)
end

return DynamicAttachment
