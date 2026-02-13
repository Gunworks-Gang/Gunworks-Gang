MWA_OnCreate = MWA_OnCreate or {}

function MWA_OnCreate.WeaponOnCreateSetRandomModel(weapon)
    local optionalSprites = weapon:getModData().OptionalWeaponSprites
    if not optionalSprites or optionalSprites == "" then return end

    local sprites = {}
    for sprite in string.gmatch(optionalSprites, "([^;]+)") do
        sprite = sprite:match("^%s*(.-)%s*$")
        if sprite ~= "" then
            table.insert(sprites, sprite)
        end
    end

    if #sprites == 0 then return end

    local randomIndex = newrandom():random(1, #sprites)
    weapon:setWeaponSprite(sprites[randomIndex])
end
