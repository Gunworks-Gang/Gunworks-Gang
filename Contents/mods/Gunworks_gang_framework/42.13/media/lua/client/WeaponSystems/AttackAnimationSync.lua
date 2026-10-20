local OrdnanceFactory = require("ExplosivesSystems/OrdnanceFactory")

local MODULE = "GWAttackAnimation"
local TIMEOUT_MS = 5000
local outgoing = {}
local incoming = {}
local sequence = 0

local function clearRemote(player)
    local context = incoming[player]
    if not context then return end
    incoming[player] = nil
    player:clearVariable("GW_RemoteAttackType")
    if context.kind == "throw" then
        player:setAttackAnimThrowTimer(0)
    end
    local weaponType = WeaponType.getWeaponType(player)
    player:setVariable("Weapon", weaponType:getType())
    player:setVariable("rangedWeapon", weaponType:isRanged())
    player:setVariable("AimFloorAnim", false)
    player:setAimAtFloor(false)
    player:setInitiateAttack(false)
    player:setAttackStarted(false)
end

local function onWeaponSwing(player, weapon)
    if not isClient() or not player then return end
    if not player:isLocalPlayer() then
        local context = incoming[player]
        if context then context.pending = false end
        return
    end
    if not weapon then return end

    local original = weapon:getModData().GW_BayonetOriginalWeapon
    local kind = original and "bayonet" or nil
    if not kind and OrdnanceFactory.IsRegistered(weapon:getFullType()) and not player:isDoShove() then
        kind = "throw"
    end
    if not kind then
        local context = outgoing[player]
        if context then
            sendClientCommand(player, MODULE, "stop", { sequence = context.sequence })
            outgoing[player] = nil
        end
        return
    end

    sequence = sequence + 1
    outgoing[player] = { sequence = sequence, started = getTimestampMs() }
    sendClientCommand(player, MODULE, "start", {
        itemId = (original or weapon):getID(),
        sequence = sequence,
        kind = kind,
        attackType = player:getVariableString("AttackType") or "",
        combatSpeed = player:getVariableFloat("CombatSpeed", 1),
        aimAtFloor = player:isAimAtFloor(),
        critical = player:isCriticalHit(),
    })
end

local function onServerCommand(module, command, args)
    if module ~= MODULE or not args then return end
    local player = getPlayerByOnlineID(args.onlineID)
    if not player or player:isLocalPlayer() then return end

    if command == "stop" then
        local context = incoming[player]
        if context and context.sequence == args.sequence then
            clearRemote(player)
        end
        return
    end
    if command ~= "start" then return end
    if args.kind ~= "bayonet" and args.kind ~= "throw" then return end

    clearRemote(player)
    args.started = getTimestampMs()
    args.pending = true
    incoming[player] = args
    player:setVariable("GW_RemoteAttackType", args.attackType or "")
    player:setVariable("CombatSpeed", args.combatSpeed)
    player:setVariable("AimFloorAnim", args.aimAtFloor == true)
    player:setAimAtFloor(args.aimAtFloor == true)
    player:setCriticalHit(args.critical == true)
    player:setDoShove(false)
    player:setDoGrapple(false)
    player:setVariable("Weapon", args.kind == "bayonet" and "spear" or "throwing")
    player:setVariable("rangedWeapon", args.kind == "throw")
    if args.kind == "throw" then
        player:setAttackAnimThrowTimer(2000)
    end
    player:setAttackStarted(true)
    player:setInitiateAttack(true)
end

local function onTick()
    if not isClient() then return end
    local now = getTimestampMs()
    for player, context in pairs(outgoing) do
        if player:isDead() or not player:isAttackStarted() or now - context.started > TIMEOUT_MS then
            sendClientCommand(player, MODULE, "stop", { sequence = context.sequence })
            outgoing[player] = nil
        end
    end
    for player, context in pairs(incoming) do
        if player:isDead() or now - context.started > TIMEOUT_MS then
            clearRemote(player)
        elseif context.pending then
            player:setAttackStarted(true)
            player:setInitiateAttack(true)
        end
    end
end

Events.OnWeaponSwing.Add(onWeaponSwing)
Events.OnServerCommand.Add(onServerCommand)
Events.OnTick.Add(onTick)
