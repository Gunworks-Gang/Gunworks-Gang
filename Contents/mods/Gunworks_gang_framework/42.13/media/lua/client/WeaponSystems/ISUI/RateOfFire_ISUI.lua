require('ISUI/ISInventoryPaneContextMenu')
local GunworksKeybinds = require('WeaponSystems/ISUI/GunworksKeybinds')
local RateOfFire_ClientSide = require('WeaponSystems/Client')
local RateOfFire = require('WeaponSystems/Utils/RateOfFire')
local RateOfFire_ISUI = {}

local KEYBIND_SWITCH_FIRERATE = "Gunworks_SwitchFirerate"

local function DisplayMessage(character, message)
    if not character or not message then return end
    character:Say(message, 0.55, 0.55, 0.55, UIFont.Dialogue, 0, "default")
end

--- Normalizes a raw fire mode to its "Real" variant, but only for weapons registered with the
--- RPM system. Unregistered weapons stay on vanilla fire modes entirely (opt-out).
---@param firemode string
---@param weapon HandWeapon
function RateOfFire_ISUI.NormalizeFiremode(firemode, weapon)
    if not firemode then return nil end
    if not RateOfFire.IsWeaponRegistered(weapon) then return firemode end
    if RateOfFire_ClientSide.isFiremodeStandard(firemode) then
        return "Real" .. firemode
    end
    return firemode
end

function RateOfFire_ISUI.GetFiremodeLabel(firemode, rpm)
    if not firemode then return nil end

    local label = getTextOrNull("ContextMenu_FireMode_" .. firemode)
    if not label then
        local modeKey = RateOfFire_ClientSide.getFiremodeMenuKey(firemode)
        label = getTextOrNull("ContextMenu_FireMode_" .. modeKey) or modeKey or firemode
    end

    if rpm then
        label = label .. " (" .. rpm .. " RPM)"
    end

    return label
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

    local currentMode = RateOfFire_ISUI.NormalizeFiremode(weapon:getFireMode(), weapon)
    local currentRpmStage = RateOfFire.GetRpmStageIndex(weapon)
    local seen = {}

    for i = 0, possibilities:size() - 1 do
        local firemode = RateOfFire_ISUI.NormalizeFiremode(possibilities:get(i), weapon)
        local modeKey = firemode and RateOfFire_ClientSide.getFiremodeMenuKey(firemode) or nil

        if firemode and modeKey then
            local rpmStages = firemode == "RealAuto" and RateOfFire.GetRpmStages(weapon) or nil

            if rpmStages and #rpmStages > 1 then
                for stageIndex, rpm in ipairs(rpmStages) do
                    local seenKey = modeKey .. "#" .. stageIndex
                    if not seen[seenKey] then
                        seen[seenKey] = true
                        entries[#entries + 1] = {
                            mode = firemode,
                            modeKey = modeKey,
                            rpmStage = stageIndex,
                            label = RateOfFire_ISUI.GetFiremodeLabel(firemode, rpm),
                            isCurrent = firemode == currentMode and stageIndex == currentRpmStage,
                        }
                    end
                end
            elseif not seen[modeKey] then
                seen[modeKey] = true
                entries[#entries + 1] = {
                    mode = firemode,
                    modeKey = modeKey,
                    label = RateOfFire_ISUI.GetFiremodeLabel(firemode),
                    isCurrent = firemode == currentMode,
                }
            end
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

function RateOfFire_ISUI.ApplyFiremode(playerObj, weapon, newfiremode, rpmStage)
    if not playerObj or not weapon or not newfiremode then
        return false
    end

    newfiremode = RateOfFire_ISUI.NormalizeFiremode(newfiremode, weapon)

    local firemodeChanged = weapon:getFireMode() ~= newfiremode
    local rpmStageChanged = rpmStage ~= nil and RateOfFire.GetRpmStageIndex(weapon) ~= rpmStage
    if not firemodeChanged and not rpmStageChanged then
        return false
    end

    weapon:setFireMode(newfiremode)
    playerObj:setFireMode(newfiremode)
    if rpmStage then
        RateOfFire.SetRpmStageIndex(weapon, rpmStage)
    end
    RateOfFire_ClientSide.OnPlayerUpdateFiremode(playerObj, weapon, newfiremode, rpmStage)

    local rpm = rpmStage and RateOfFire.GetRpmForStage(weapon, rpmStage) or nil
    local label = RateOfFire_ISUI.GetFiremodeLabel(newfiremode, rpm)
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

    local currentIndex = 1
    for index, entry in ipairs(entries) do
        if entry.isCurrent then
            currentIndex = index
            break
        end
    end

    local nextEntry = entries[(currentIndex % #entries) + 1]
    return RateOfFire_ISUI.ApplyFiremode(playerObj, weapon, nextEntry.mode, nextEntry.rpmStage)
end

ISInventoryPaneContextMenu.onChangefiremode = function(playerObj, weapon, newfiremode, rpmStage)
    return RateOfFire_ISUI.ApplyFiremode(playerObj, weapon, newfiremode, rpmStage)
end

ISInventoryPaneContextMenu.doChangeFireModeMenu = function(playerObj, weapon, context)
    local entries = RateOfFire_ISUI.GetSelectableFiremodeEntries(weapon)
    if #entries == 0 then return end

    local firemodeOption = context:addOption(getText("ContextMenu_ChangeFireMode"))
    local subMenuFiremode = context:getNew(context)
    context:addSubMenu(firemodeOption, subMenuFiremode)

    for _, entry in ipairs(entries) do
        subMenuFiremode:addOption(entry.label,
            playerObj, ISInventoryPaneContextMenu.onChangefiremode, weapon, entry.mode, entry.rpmStage)
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
