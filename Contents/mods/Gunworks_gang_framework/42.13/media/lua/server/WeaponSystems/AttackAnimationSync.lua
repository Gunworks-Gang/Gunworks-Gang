local Bayonet = require("WeaponSystems/Utils/Bayonet")
local OrdnanceFactory = require("ExplosivesSystems/OrdnanceFactory")

local MODULE = "GWAttackAnimation"
local spearAttacks = { default = true, miss = true, overhead = true, charge = true, spearstab = true }

local function onClientCommand(module, command, player, args)
    if module ~= MODULE or not player or not args then return end
    if command ~= "start" and command ~= "stop" then return end
    if type(args.sequence) ~= "number" then return end

    local relay = { onlineID = player:getOnlineID(), sequence = args.sequence }
    if command == "start" then
        local weapon = player:getPrimaryHandItem()
        if not weapon or not instanceof(weapon, "HandWeapon") or weapon:getID() ~= args.itemId then return end
        if args.kind == "bayonet" then
            if not Bayonet.IsBayonetDeployed(weapon) then return end
            if not spearAttacks[args.attackType] then return end
        elseif args.kind == "throw" then
            if not OrdnanceFactory.IsRegistered(weapon:getFullType()) then return end
        else
            return
        end
        if type(args.combatSpeed) ~= "number" or args.combatSpeed ~= args.combatSpeed then return end
        relay.kind = args.kind
        relay.attackType = args.attackType
        relay.combatSpeed = math.max(0.1, math.min(3, args.combatSpeed))
        relay.aimAtFloor = args.aimAtFloor == true
        relay.critical = args.critical == true
    end

    local players = getOnlinePlayers()
    for i = 0, players:size() - 1 do
        local observer = players:get(i)
        if observer ~= player then
            sendServerCommand(observer, MODULE, command, relay)
        end
    end
end

Events.OnClientCommand.Add(onClientCommand)
