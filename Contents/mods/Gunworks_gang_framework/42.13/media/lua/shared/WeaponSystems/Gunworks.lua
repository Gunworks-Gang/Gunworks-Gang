-- Gunworks unified per-gun registration facade.
--
-- One call registers a gun's whole ANIMATION identity, fanning out to the existing per-concern
-- registries so a weapon pack (and the Anim Forge editor) registers a gun ONCE instead of
-- scattering ReloadAnim / Animations / GripAnim calls:
--
--   Gunworks.RegisterWeapon("NA.G36C", {
--       reload = { animId = "NARifle", archetype = "magazine", style = "sprite",
--                  sprite = { loaded = "...", unloaded = "..." }, magItem = "..." },
--       grip   = { animId = "NAGrip" },
--       animatedParts = { attachments = { open = "...", locked = "..." } },
--       customStates  = { threshold = 1, part = "...", slot = "Animated1" },
--   })
--
-- `reload` and `grip` may each be a single profile OR a list of variant profiles. A variant
-- carrying a `when = { attach = <fullType|partType>, present = <bool> }` becomes an
-- attachment-conditional rule: this facade translates it into a matches(gun) predicate (checked
-- before the plain fullType map, so it wins while its part is attached and otherwise falls through
-- to the unconditional rule). Keeping the when->matches translation here means the generated Lua
-- stays declarative data. Extensible: add spec keys (foldingStock, bayonet, rateOfFire, ...) that
-- dispatch to their registries without changing callers.

local ReloadAnim = require("WeaponSystems/ReloadAnim/HandlerFactory")
local Animations = require("WeaponSystems/Utils/Animations")
local GripAnim = require("WeaponSystems/Utils/GripAnim")

local Gunworks = {}

--- True if the gun currently has the given part attached, matched by the part's item fullType OR
--- its partType slot, so a `when` can target either a specific attachment item or a whole slot.
---@param gun HandWeapon
---@param attach string
---@nodiscard
---@return boolean
function Gunworks.gunHasPart(gun, attach)
    local parts = gun:getAllWeaponParts()
    if not parts then
        return false
    end
    for i = 0, parts:size() - 1 do
        local p = parts:get(i)
        if p and (p:getFullType() == attach or p:getPartType() == attach) then
            return true
        end
    end
    return false
end

--- Build a matches(gun) predicate from a `when` block, AND-scoped to a gun fullType.
---@param fullType string
---@param when {attach:string|nil, present:boolean|nil}
---@nodiscard
---@return fun(gun:HandWeapon):boolean
function Gunworks.buildMatches(fullType, when)
    local attach = when.attach
    local present = when.present ~= false
    return function(gun)
        if gun:getFullType() ~= fullType then
            return false
        end
        if not attach then
            return true
        end
        local has = Gunworks.gunHasPart(gun, attach)
        if present then
            return has
        end
        return not has
    end
end

--- A `when`-tagged variant id, unique per (animId, attachment, presence).
---@param animId string
---@param when table
---@return string
local function variantId(animId, when)
    return animId .. "@" .. (when.attach or "any") .. (when.present == false and "!" or "")
end

-- A profile block may be a single profile ({animId=...}) or a list of variant profiles.
---@param block table|table[]|nil
---@return table[]|nil
local function asList(block)
    if not block then
        return nil
    end
    if block.animId then
        return { block }
    end
    return block
end

--- Copy a profile, stripping the editor-only `when` key.
---@param profile table
---@return table
local function profileWithoutWhen(profile)
    local p = {}
    for k, v in pairs(profile) do
        if k ~= "when" then
            p[k] = v
        end
    end
    return p
end

--- Public API: register a gun's animation identity in one call.
---@param fullType string
---@param spec {reload:table|table[]|nil, grip:table|table[]|nil, animatedParts:table|nil, customStates:table|nil}
---@return nil
function Gunworks.RegisterWeapon(fullType, spec)
    if not fullType or not spec then
        return
    end

    local reloads = asList(spec.reload)
    if reloads then
        for i = 1, #reloads do
            local profile = reloads[i]
            if profile.when then
                local p = profileWithoutWhen(profile)
                p.matches = Gunworks.buildMatches(fullType, profile.when)
                p.id = variantId(profile.animId, profile.when)
                ReloadAnim.RegisterWeapon(nil, p)
            else
                ReloadAnim.RegisterWeapon(fullType, profile)
            end
        end
    end

    local grips = asList(spec.grip)
    if grips then
        for i = 1, #grips do
            local profile = grips[i]
            if profile.when then
                GripAnim.RegisterWeapon(nil, {
                    animId = profile.animId,
                    matches = Gunworks.buildMatches(fullType, profile.when),
                    id = variantId(profile.animId, profile.when),
                })
            else
                GripAnim.RegisterWeapon(fullType, { animId = profile.animId })
            end
        end
    end

    if spec.animatedParts then
        Animations.RegisterWeaponWithAnimatedParts(fullType, spec.animatedParts)
    end

    if spec.customStates then
        Animations.RegisterWeaponsWithCustomStates(fullType, spec.customStates)
    end
end

--- Public API: register many guns at once. Keys are weapon fullTypes.
---@param entries table<string, table>
---@return nil
function Gunworks.RegisterMultipleWeapons(entries)
    if not entries then
        return
    end
    for fullType, spec in pairs(entries) do
        Gunworks.RegisterWeapon(fullType, spec)
    end
end

return Gunworks
