local ConditionalModel = {}
local StatsFactory     = require("WeaponSystems/Utils/StatsFactory")

-------------------------------------------------
-- Registry: weaponFullType -> {
--   rules   = { { parts = { <slot> = <match>, ... }, model = "Module.Model" }, ... }
--   default = "Module.Model" | nil   model used when no rule matched
-- }
--
-- Each rule's `parts` maps a weapon-part slot (PartType string, e.g. "Barrel",
-- "Handguard") to the part that must be installed there. A <match> is:
--   * a string        exact part fullType installed in that slot
--   * a string array   any one of these part fullTypes
-- Every slot in `parts` must match for the rule to fire (logical AND).
--
-- Rules are tested top to bottom and the first match wins, so list the most
-- specific combos first. `model` must be the name of a `model` script block
-- (with module prefix) - it is set as the weapon's WeaponSprite.
-------------------------------------------------
ConditionalModel.Registry = {}

-------------------------------------------------
-- Match helpers
-------------------------------------------------

local function slotMatches(want, installedType)
    if type(want) == "string" then
        return installedType == want
    end
    if type(want) == "table" then
        for i = 1, #want do
            if installedType == want[i] then return true end
        end
    end
    return false
end

--- @param weapon HandWeapon
--- @param parts table  { <slot> = <match>, ... }
--- @return boolean
local function ruleMatches(weapon, parts)
    if type(parts) ~= "table" then return false end

    for slot, want in pairs(parts) do
        local part = weapon:getWeaponPart(slot)
        local installedType = part and part:getFullType() or false
        if not slotMatches(want, installedType) then
            return false
        end
    end
    return true
end

-------------------------------------------------
-- Registration API
-------------------------------------------------

--- Register a weapon whose displayed model depends on which parts are installed.
--- @param weaponType string  weapon fullType e.g. "MarzModular.M203_CAR15_Weapon"
--- @param config     table   { rules = { ... }, default = string|nil }
function ConditionalModel.Register(weaponType, config)
    if not weaponType or type(config) ~= "table" then return end

    ConditionalModel.Registry[weaponType] = {
        rules   = config.rules or {},
        default = config.default,
    }
end

--- Register several weapons at once. entries = { [weaponType] = config, ... }
function ConditionalModel.RegisterMultiple(entries)
    if type(entries) ~= "table" then return end
    for weaponType, config in pairs(entries) do
        ConditionalModel.Register(weaponType, config)
    end
end

function ConditionalModel.IsRegistered(weaponType)
    return weaponType ~= nil and ConditionalModel.Registry[weaponType] ~= nil
end

-------------------------------------------------
-- Query
-------------------------------------------------

--- Work out which model a weapon should display from its installed parts.
--- @param weapon HandWeapon
--- @return string|nil  model (WeaponSprite) name, or nil when the weapon is not
---                      registered, or no rule matched and no default is set
function ConditionalModel.ResolveModel(weapon)
    if not weapon then return nil end

    local entry = ConditionalModel.Registry[weapon:getFullType()]
    if not entry then return nil end

    for i = 1, #entry.rules do
        local rule = entry.rules[i]
        if rule.model and ruleMatches(weapon, rule.parts) then
            return rule.model
        end
    end

    return entry.default
end

--- Set the weapon's model straight away to whatever its parts resolve to.
--- Safe to call any time; a no-op for an unregistered weapon or when nothing
--- resolves. Prefer letting the StatsFactory layer below do this - call it only
--- from code paths that do not run ReapplyAllModifiers.
--- @param weapon HandWeapon
--- @return boolean  true when a model was applied
function ConditionalModel.Apply(weapon)
    local model = ConditionalModel.ResolveModel(weapon)
    if not model then return false end

    if weapon:getWeaponSprite() ~= model then
        weapon:setWeaponSprite(model)
    end
    return true
end

-------------------------------------------------
-- StatsFactory layer
-- Runs on every ReapplyAllModifiers (equip, part attach/detach, load, upgrade).
-- Registered after CustomStatsAttachments so a resolved combo model overrides
-- the per-part WeaponSprite that layer may set.
-------------------------------------------------
local function getModifiers(weapon)
    local model = ConditionalModel.ResolveModel(weapon)
    if not model then return nil end
    return { StatsFactory.Set("WeaponSprite", model) }
end

StatsFactory.RegisterModifierLayer("ConditionalModel", getModifiers, { WeaponSprite = true })

return ConditionalModel
