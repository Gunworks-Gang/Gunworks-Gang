require('ISUI/ISInventoryPaneContextMenu')
local RateOfFire_ClientSide = require('WeaponSystems/Client')

ISInventoryPaneContextMenu.onChangefiremode = function(playerObj, weapon, newfiremode)
    if RateOfFire_ClientSide.isFiremodeStandard(newfiremode) then
        newfiremode = "Real" .. newfiremode
    end
    weapon:setFireMode(newfiremode)
    playerObj:setFireMode(newfiremode)
    RateOfFire_ClientSide.OnPlayerUpdateFiremode(playerObj, weapon, newfiremode)
end

ISInventoryPaneContextMenu.doChangeFireModeMenu = function(playerObj, weapon, context)
    local firemodeOption = context:addOption(getText("ContextMenu_ChangeFireMode"))
    local subMenuFiremode = context:getNew(context)
    context:addSubMenu(firemodeOption, subMenuFiremode)

    local currentFiremodeKey = RateOfFire_ClientSide.getFiremodeMenuKey(weapon:getFireMode())

    for i = 0, weapon:getFireModePossibilities():size() - 1 do
        local firemode = weapon:getFireModePossibilities():get(i)
        local firemodeKey = RateOfFire_ClientSide.getFiremodeMenuKey(firemode)
        if firemodeKey ~= currentFiremodeKey then
            subMenuFiremode:addOption(getText("ContextMenu_FireMode_" .. firemode),
                playerObj, ISInventoryPaneContextMenu.onChangefiremode, weapon, firemode)
        end
    end
end
