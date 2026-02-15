local function restoreContainer(container)
    if not container then return end
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)

        if instanceof(item, "HandWeapon") and item:isRanged() then
            SWMG_Core.RestoreFoldedStockState(item)
            SWMG_Core.RestoreDeployedBipodState(item)
        end

        if item.getInventory and item:getInventory() then
            restoreContainer(item:getInventory())
        end
    end
end

local function restorePlayer(playerObj)
    if not playerObj then return end
    restoreContainer(playerObj:getInventory())
end

Events.OnGameStart.Add(function()
    for i = 0, getNumActivePlayers() - 1 do
        restorePlayer(getSpecificPlayer(i))
    end
end)

Events.OnCreatePlayer.Add(function(_, playerObj)
    restorePlayer(playerObj)
end)
