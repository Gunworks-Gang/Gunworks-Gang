local function setOpenModel(weapon, open)
    local originalSprite = weapon:getWeaponSprite()
    if open then
        originalSprite = originalSprite:match("_OPEN$") and originalSprite or originalSprite .. "_OPEN"
    else
        originalSprite = originalSprite:gsub("_OPEN$", "")
    end
    weapon:setWeaponSprite(originalSprite)
end

function MWAOpenModel(weapon, open)
    local modelFn = MWA_OpenModels[weapon:getFullType()]
    if modelFn then
        modelFn(weapon, open)
    end
end

MWA_OpenModels = {
    --Pistols
    ["MWA.M92FS"] = setOpenModel,
    ["MWA.M1911"] = setOpenModel,
    ["MWA.DEAGLE"] = setOpenModel,
    ["MWA.P226"] = setOpenModel,
    ["MWA.USP_MATCH"] = setOpenModel,
    ["MWA.GLOCK17"] = setOpenModel,
    ["MWA.GLOCK19"] = setOpenModel,
    ["MWA.BROWNING_HP"] = setOpenModel,
    ["MWA.P38"] = setOpenModel,

    --Battle-Rifles
    ["MWA.M1_GARAND"] = setOpenModel,
    ["MWA.M14"] = setOpenModel,
    ["MWA.FAL"] = setOpenModel,

    --Bolt-Rifles
    ["MWA.KAR98K"] = setOpenModel,
    ["MWA.MOSIN"] = setOpenModel,
    ["MWA.M24"] = setOpenModel,
    ["MWA.M40"] = setOpenModel,

    --Shotguns
    ["MWA.BENELLI_M4"] = setOpenModel,
    ["MWA.REMINGTON_1187"] = setOpenModel,
    ["MWA.MOSSBERG_590"] = setOpenModel,
    ["MWA.REMINGTON_870"] = setOpenModel,
    ["MWA.SIDE_BY_SIDE"] = setOpenModel,
    ["MWA.M30_DRILLING"] = setOpenModel,
    ["MWA.TRENCHGUN"] = setOpenModel,
}
