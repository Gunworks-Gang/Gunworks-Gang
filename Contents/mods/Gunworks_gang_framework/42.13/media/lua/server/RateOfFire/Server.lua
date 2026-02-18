local RateOfFire = require('RateOfFire/RateOfFire')
local RateOfFire_ServerSide = {}

function RateOfFire_ServerSide.OnClientCommand(module, command, player, args)
    if module ~= "RAF" then return end
    if command ~= "firemode" then return end
    if not player or not args then return end

    local weapon = RateOfFire.GetWeaponById(player, args.itemId)
    if not weapon then return end

    if args.firemode then weapon:setFireMode(args.firemode) end
    RateOfFire.RecoilDelayAdjuster(player, weapon)

    sendServerCommand(player, "RAF", "applyWeapon", {
        itemId = weapon:getID(),
        firemode = weapon:getFireMode(),
        recoilDelay = weapon:getRecoilDelay()
    })
end

Events.OnClientCommand.Add(RateOfFire_ServerSide.OnClientCommand)
