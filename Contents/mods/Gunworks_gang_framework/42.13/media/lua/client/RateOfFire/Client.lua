local RateOfFire = require 'RateOfFire/RateOfFire.lua'
local RateOfFire_ClientSide = {}

function RateOfFire_ClientSide.getFiremodeMenuKey(firemode)
    return firemode:match("^Real(.+)") or firemode
end

function RateOfFire_ClientSide.isFiremodeStandard(firemode)
    if firemode == "Auto" or firemode == "Burst" or firemode == "Single" then
        return true
    else
        return false
    end
end

function RateOfFire_ClientSide.OnPlayerUpdateFiremode(playerObj, weapon, newfiremode)
    if not isClient() then
        RateOfFire.RecoilDelayAdjuster(playerObj, weapon)
        return
    end

    if not weapon then return end

    sendClientCommand(playerObj, "RAF", "firemode", {
        itemId = weapon:getID(),
        firemode = newfiremode
    })
end

function RateOfFire_ClientSide.FiremodeSwitchCheck(playerObj, weapon)
    if not playerObj or not weapon or not instanceof(weapon, "HandWeapon") or not weapon:isRanged() then return end
    local newfiremode = weapon:getFireMode()
    if RateOfFire_ClientSide.isFiremodeStandard(newfiremode) then
        newfiremode = "Real" .. newfiremode
        weapon:setFireMode(newfiremode)
        playerObj:setFireMode(newfiremode)
        RateOfFire_ClientSide.OnPlayerUpdateFiremode(playerObj, weapon, newfiremode)
    end
end

function RateOfFire_ClientSide.OnServerCommand(module, command, args)
    if module ~= "RAF" or command ~= "applyWeapon" or not args then return end

    local playerObj = getSpecificPlayer(0)
    if not playerObj then return end

    local item = playerObj:getInventory():getItemWithIDRecursiv(args.itemId)
    if item and instanceof(item, "HandWeapon") then
        if args.firemode then item:setFireMode(args.firemode) end
        if args.recoilDelay then item:setRecoilDelay(args.recoilDelay) end
    end
end

Events.OnServerCommand.Add(RateOfFire_ClientSide.OnServerCommand)
Events.OnWeaponSwing.Add(RateOfFire_ClientSide.FiremodeSwitchCheck)

return RateOfFire_ClientSide
