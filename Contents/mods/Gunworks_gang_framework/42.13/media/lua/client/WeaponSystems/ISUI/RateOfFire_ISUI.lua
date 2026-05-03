require('ISUI/ISInventoryPaneContextMenu')
local GunworksKeybinds = require('WeaponSystems/ISUI/GunworksKeybinds')
local RateOfFire_ClientSide = require('WeaponSystems/Client')
local RateOfFire_ISUI = {}

local KEYBIND_SWITCH_FIRERATE = "Gunworks_SwitchFirerate"

local function DisplayMessage(character, message)
    if not character or not message then return end
    character:Say(message, 0.55, 0.55, 0.55, UIFont.Dialogue, 0, "default")
end

function RateOfFire_ISUI.NormalizeFiremode(firemode)
    if not firemode then return nil end
    if RateOfFire_ClientSide.isFiremodeStandard(firemode) then
        return "Real" .. firemode
    end
    return firemode
end

function RateOfFire_ISUI.GetFiremodeLabel(firemode)
    local normalized = RateOfFire_ISUI.NormalizeFiremode(firemode)
    if not normalized then return nil end

    local translated = getTextOrNull("ContextMenu_FireMode_" .. normalized)
    if translated then
        return translated
    end

    local modeKey = RateOfFire_ClientSide.getFiremodeMenuKey(normalized)
    return getTextOrNull("ContextMenu_FireMode_" .. modeKey) or modeKey or normalized
end

function RateOfFire_ISUI.GetFiremodeEntries(weapon)
    local entries = {}
    if not weapon or not instanceof(weapon, "HandWeapon") or not weapon:isRanged() then
        return entries
    end

    local possibilities = weapon:getFireModePossibilities()
    if not possibilities then
        return entries
    end

    local currentMode = RateOfFire_ISUI.NormalizeFiremode(weapon:getFireMode())
    local currentModeKey = currentMode and RateOfFire_ClientSide.getFiremodeMenuKey(currentMode) or nil
    local seen = {}

    for i = 0, possibilities:size() - 1 do
        local firemode = RateOfFire_ISUI.NormalizeFiremode(possibilities:get(i))
        local modeKey = firemode and RateOfFire_ClientSide.getFiremodeMenuKey(firemode) or nil

        if firemode and modeKey and not seen[modeKey] then
            seen[modeKey] = true
            entries[#entries + 1] = {
                mode = firemode,
                modeKey = modeKey,
                label = RateOfFire_ISUI.GetFiremodeLabel(firemode),
                isCurrent = modeKey == currentModeKey,
            }
        end
    end

    return entries
end

function RateOfFire_ISUI.GetSelectableFiremodeEntries(weapon)
    local entries = {}
    for _, entry in ipairs(RateOfFire_ISUI.GetFiremodeEntries(weapon)) do
        if not entry.isCurrent then
            entries[#entries + 1] = entry
        end
    end
    return entries
end

function RateOfFire_ISUI.HasMultipleFiremodes(weapon)
    return #RateOfFire_ISUI.GetFiremodeEntries(weapon) > 1
end

function RateOfFire_ISUI.ApplyFiremode(playerObj, weapon, newfiremode)
    if not playerObj or not weapon or not newfiremode then
        return false
    end

    newfiremode = RateOfFire_ISUI.NormalizeFiremode(newfiremode)
    if weapon:getFireMode() == newfiremode then
        return false
    end

    weapon:setFireMode(newfiremode)
    playerObj:setFireMode(newfiremode)
    RateOfFire_ClientSide.OnPlayerUpdateFiremode(playerObj, weapon, newfiremode)

    local label = RateOfFire_ISUI.GetFiremodeLabel(newfiremode)
    if label then
        DisplayMessage(playerObj, getText("ContextMenu_ChangeFireMode") .. ": " .. label)
    end

    return true
end

function RateOfFire_ISUI.CycleFiremode(playerObj, weapon)
    local entries = RateOfFire_ISUI.GetFiremodeEntries(weapon)
    if #entries <= 1 then
        return false
    end

    local currentMode = RateOfFire_ISUI.NormalizeFiremode(weapon:getFireMode())
    local currentModeKey = currentMode and RateOfFire_ClientSide.getFiremodeMenuKey(currentMode) or nil
    local nextEntry = entries[1]

    for index, entry in ipairs(entries) do
        if entry.modeKey == currentModeKey then
            nextEntry = entries[(index % #entries) + 1]
            break
        end
    end

    return RateOfFire_ISUI.ApplyFiremode(playerObj, weapon, nextEntry.mode)
end

ISInventoryPaneContextMenu.onChangefiremode = function(playerObj, weapon, newfiremode)
    return RateOfFire_ISUI.ApplyFiremode(playerObj, weapon, newfiremode)
end

ISInventoryPaneContextMenu.doChangeFireModeMenu = function(playerObj, weapon, context)
    local entries = RateOfFire_ISUI.GetSelectableFiremodeEntries(weapon)
    if #entries == 0 then return end

    local firemodeOption = context:addOption(getText("ContextMenu_ChangeFireMode"))
    local subMenuFiremode = context:getNew(context)
    context:addSubMenu(firemodeOption, subMenuFiremode)

    for _, entry in ipairs(entries) do
        subMenuFiremode:addOption(entry.label,
            playerObj, ISInventoryPaneContextMenu.onChangefiremode, weapon, entry.mode)
    end
end

local function onKeyPressed(key)
    local playerObj = getSpecificPlayer(0)
    if not playerObj or playerObj:isDead() then return end

    if key ~= GunworksKeybinds.GetBoundKey(KEYBIND_SWITCH_FIRERATE, Keyboard.KEY_T) then
        return
    end

    local weapon = playerObj:getPrimaryHandItem()
    if not weapon or not instanceof(weapon, "HandWeapon") or not weapon:isRanged() then
        return
    end

    RateOfFire_ISUI.CycleFiremode(playerObj, weapon)
end

Events.OnKeyPressed.Add(onKeyPressed)

return RateOfFire_ISUI
