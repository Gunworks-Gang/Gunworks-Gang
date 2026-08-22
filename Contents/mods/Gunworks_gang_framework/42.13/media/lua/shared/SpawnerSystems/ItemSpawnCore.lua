local ItemSpawnCore = {}

local r = newrandom()

ItemSpawnCore.SPAWNER_ITEM_MODDATA_KEY = "Gunworks_SpawnerItemType"

function ItemSpawnCore.shouldProcess()
    return not isClient() or isServer()
end

function ItemSpawnCore.pickRandomItem(list)
    if not list or #list == 0 then return nil end
    return list[r:random(#list)]
end

function ItemSpawnCore.getSelectedItemType(spawnerItem, candidates)
    local modData = spawnerItem:getModData()
    local selectedType = modData[ItemSpawnCore.SPAWNER_ITEM_MODDATA_KEY]
    if selectedType then
        return selectedType
    end

    selectedType = ItemSpawnCore.pickRandomItem(candidates)
    if selectedType then
        modData[ItemSpawnCore.SPAWNER_ITEM_MODDATA_KEY] = selectedType
    end

    return selectedType
end

local function replaceContainerSpawner(spawnerItem, container, newItem, bonusItems)
    local addedItem = container:AddItem(newItem)
    if not addedItem then return false end

    container:DoRemoveItem(spawnerItem)

    if isServer() then
        sendReplaceItemInContainer(container, spawnerItem, addedItem)
    end

    for _, bonusItem in ipairs(bonusItems or {}) do
        local addedBonusItem = container:AddItem(bonusItem)
        if addedBonusItem and isServer() then
            sendAddItemToContainer(container, addedBonusItem)
        end
    end

    container:setDirty(true)
    container:setDrawDirty(true)
    return true
end

local function replaceWorldSpawner(spawnerItem, worldItem, newItem, bonusItems)
    local sq = worldItem and worldItem:getSquare()
    if not sq then return false end

    local xoff = worldItem:getOffX() or 0
    local yoff = worldItem:getOffY() or 0
    local zoff = worldItem:getOffZ() or 0

    sq:AddWorldInventoryItem(newItem, xoff, yoff, zoff, true)

    for _, bonusItem in ipairs(bonusItems or {}) do
        sq:AddWorldInventoryItem(bonusItem, xoff, yoff, zoff, true)
    end

    if isServer() then
        sq:transmitRemoveItemFromSquare(worldItem)
    end

    worldItem:removeFromWorld()
    worldItem:removeFromSquare()
    spawnerItem:setWorldItem(nil)
    return true
end

function ItemSpawnCore.newDeferredQueue()
    local activeTicks = {}
    local queue = {}

    function queue.mark(item, resolveFn)
        if activeTicks[item] then return end

        local function tick()
            if not ItemSpawnCore.shouldProcess() then return end
            resolveFn(item)
        end

        activeTicks[item] = tick
        Events.OnTick.Add(tick)
    end

    function queue.clear(item)
        local tick = activeTicks[item]
        if not tick then return end

        Events.OnTick.Remove(tick)
        activeTicks[item] = nil
    end

    return queue
end

function ItemSpawnCore.resolve(item, entry, computeFn, queue, resolveFn)
    if not ItemSpawnCore.shouldProcess() or not item or not entry then return end

    local container = item:getContainer()
    local parent = container and container:getParent()
    local zombieParent = parent and instanceof(parent, "IsoZombie")
    local worldItem = item:getWorldItem()

    if zombieParent or (not container and not worldItem) then
        queue.mark(item, resolveFn)
        return
    end

    queue.clear(item)

    local newItem, bonusItems = computeFn(item, entry)
    if not newItem then return end

    if container then
        replaceContainerSpawner(item, container, newItem, bonusItems)
        return
    end

    replaceWorldSpawner(item, worldItem, newItem, bonusItems)
end

return ItemSpawnCore
