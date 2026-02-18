---@class AnimatedReloadsAction
local AnimatedReloadsAction = require("AnimatedReloads/Action/Core")
---@return boolean
function AnimatedReloadsAction.hookClientCommands()
    if AnimatedReloadsAction._clientCommandsHooked then
        return true
    end

    if not isServer() or not Events or not Events.OnClientCommand then
        return false
    end

    AnimatedReloadsAction._clientCommandsHooked = true

    Events.OnClientCommand.Add(function(module, command, player, args)
        local commandModule = AnimatedReloadsAction.getCommandModule()
        if commandModule and module ~= commandModule then
            return
        end

        if command ~= "SetWeaponSprite" then
            return
        end

        if not player or not args or not args.sprite or args.sprite == "" then
            return
        end

        local item = player:getPrimaryHandItem()
        if not item then
            return
        end

        item:setWeaponSprite(args.sprite)
        player:resetEquippedHandsModels()
        if syncHandWeaponFields then
            syncHandWeaponFields(player, item)
        end
        commandModule = AnimatedReloadsAction.getCommandModule()
        if commandModule and sendServerCommand then
            sendServerCommand(commandModule, "SetWeaponSprite", {
                onlineID = player:getOnlineID(),
                sprite = args.sprite
            })
        end
    end)

    return true
end

---@return boolean
function AnimatedReloadsAction.hookServerCommands()
    if AnimatedReloadsAction._serverCommandsHooked then
        return true
    end

    if not isClient() or not Events or not Events.OnServerCommand then
        return false
    end

    AnimatedReloadsAction._serverCommandsHooked = true

    Events.OnServerCommand.Add(function(module, command, args)
        local commandModule = AnimatedReloadsAction.getCommandModule()
        if commandModule and module ~= commandModule then
            return
        end

        if command ~= "SetWeaponSprite" then
            return
        end

        if not args or not args.sprite or args.sprite == "" or not args.onlineID then
            return
        end

        local player = getPlayerByOnlineID(args.onlineID)
        if not player then
            return
        end

        local item = player:getPrimaryHandItem()
        if not item then
            return
        end

        item:setWeaponSprite(args.sprite)
        player:resetEquippedHandsModels()
    end)

    return true
end

function AnimatedReloadsAction.initializeCommandHooks()
    if not AnimatedReloadsAction.hookClientCommands() then
        if Events and Events.OnGameBoot and not AnimatedReloadsAction._clientCommandsHookedEvent then
            AnimatedReloadsAction._clientCommandsHookedEvent = true
            Events.OnGameBoot.Add(function()
                AnimatedReloadsAction.hookClientCommands()
            end)
        end
    end

    if not AnimatedReloadsAction.hookServerCommands() then
        if Events and Events.OnGameBoot and not AnimatedReloadsAction._serverCommandsHookedEvent then
            AnimatedReloadsAction._serverCommandsHookedEvent = true
            Events.OnGameBoot.Add(function()
                AnimatedReloadsAction.hookServerCommands()
            end)
    end
end
end

return AnimatedReloadsAction
