local WeaponDistribution = {}

function WeaponDistribution.Insert(baseItem, chance, tables, newItem)
    local script = ScriptManager.instance:getItem(baseItem)
    if not script then return end
    for _, lootTable in pairs(tables) do
        for _, data in pairs(lootTable) do
            if data.items then
                for i, item in pairs(data.items) do
                    if item == script:getName() or item == script:getFullName() then
                        table.insert(data.items, newItem)
                        table.insert(data.items, data.items[i + 1] * (chance or 1))
                    end
                end
            end
            if data.weapons then
                for i, item in pairs(data.weapons) do
                    if item == script:getName() or item == script:getFullName() then
                        table.insert(data.weapons, newItem)
                    end
                end
            end
        end
    end
end

function WeaponDistribution.InsertMany(baseItem, chance, tables, ...)
    for _, item in ipairs({ ... }) do
        WeaponDistribution.Insert(baseItem, chance, tables, item)
    end
end

function WeaponDistribution.RemoveEverywhere(tables, item)
    local script = ScriptManager.instance:getItem(item)
    local a, b = item, nil
    if script then a, b = script:getName(), script:getFullName() end

    for _, lootTable in pairs(tables) do
        for _, data in pairs(lootTable) do
            if data.items then
                for i = #data.items - 1, 1, -2 do
                    if data.items[i] == a or data.items[i] == b then
                        table.remove(data.items, i + 1)
                        table.remove(data.items, i)
                    end
                end
            end
            if data.weapons then
                for i = #data.weapons, 1, -1 do
                    if data.weapons[i] == a or data.weapons[i] == b then
                        table.remove(data.weapons, i)
                    end
                end
            end
        end
    end
end

function WeaponDistribution.RemoveMany(tables, ...)
    for _, item in ipairs({ ... }) do
        WeaponDistribution.RemoveEverywhere(tables, item)
    end
end

function WeaponDistribution.SetChance(item, chance, tables)
    local script = ScriptManager.instance:getItem(item)
    local a, b = item, nil
    if script then a, b = script:getName(), script:getFullName() end

    for _, lootTable in pairs(tables) do
        for _, data in pairs(lootTable) do
            if data.items then
                for i = 1, #data.items - 1, 2 do
                    if data.items[i] == a or data.items[i] == b then
                        data.items[i + 1] = chance
                    end
                end
            end
        end
    end
end

function WeaponDistribution.SetChanceMany(chance, tables, ...)
    for _, item in ipairs({ ... }) do
        WeaponDistribution.SetChance(item, chance, tables)
    end
end

return WeaponDistribution
