local function removeVanillaAmmoRecipes()
    --- I will be removing the vanilla recipes and using mine for more control
    local recipesToRemove = {
        "OpenBoxOfBullets50",
        "OpenBoxOfBullets20",
        "OpenBoxOfShotgunShells",
        "OpenCartonOfBullets",
        "place_ammo_in_box",
        "PlaceBoxesOf556AmmoInCarton",
        "PlaceBoxesOf223AmmoInCarton",
        "PlaceBoxesOf308AmmoInCarton",
        "PlaceBoxesOf9mmBulletsInCarton",
        "PlaceBoxesOf45AutoBulletsInCarton",
        "PlaceBoxesOf38SpecialBulletsInCarton",
        "PlaceBoxesOf44MagnumBulletsInCarton",
        "PlaceBoxesOfShotgunShellsInCarton",
    }

    -- Remove Vanilla for ammo CraftRecipes
    for i = 1, #recipesToRemove do
        local recipe = getScriptManager():getCraftRecipe(recipesToRemove[i])
        if recipe then
            recipe:getInputs():clear()
            recipe:getOutputs():clear()
            recipe:Load(recipe:getName(), [[
        {
            inputs
            {
                item 1 [MWA.FakeItem],
            }
            outputs
            {
                item 1 MWA.FakeItem,
            }
        }
        ]])
        end
    end
end

Events.OnInitGlobalModData.Add(removeVanillaAmmoRecipes)
