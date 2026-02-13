require 'Distribution/MWA_DistributionFunctions'

local tables = { ProceduralDistributions.list, VehicleDistributions, SuburbsDistributions, BagsAndContainers }
local zombieTables = { AttachedWeaponDefinitions }
local vanillaItems = {
    "Base.AssaultRifle",
    "Base.AssaultRifle2",
    "Base.DoubleBarrelShotgun",
    "Base.DoubleBarrelShotgunSawnoff",
    "Base.HuntingRifle",
    "Base.Pistol",
    "Base.Pistol2",
    "Base.Pistol3",
    "Base.Revolver",
    "Base.Revolver_Long",
    "Base.Revolver_Short",
    "Base.Shotgun",
    "Base.ShotgunSawnoff",
    "Base.VarmintRifle",
    "Base.44Clip",
    "Base.45Clip",
    "Base.9mmClip",
    "Base.M14Clip",
    "Base.556Clip",
    "Base.x2Scope",
    "Base.x4Scope",
    "Base.x8Scope",
    "Base.AmmoStraps",
    "Base.TritiumSights",
    "Base.RecoilPad",
    "Base.Laser",
    "Base.RedDot",
    "Base.GunLight",
    "Base.ChokeTubeFull",
    "Base.ChokeTubeImproved",
}

MWADistro.InsertMany("Base.AssaultRifle", 1, tables, "MWA.M16A2", "MWA.M16A1", "MWA.CAR15", "MWA.XM177")
MWADistro.InsertMany("Base.556Clip", 1, tables, "MWA.556Magazine20", "MWA.556Magazine25", "MWA.556Magazine30")

MWADistro.InsertMany("Base.AssaultRifle2", 1, tables, "MWA.M14", "MWA.G3", "MWA.SCAR_H")
MWADistro.Insert("Base.M14Clip", 1, tables, "MWA.308Magazine20")
MWADistro.InsertMany("Base.Pistol", 1, tables, "MWA.M92FS", "MWA.P226", "MWA.GLOCK17", "MWA.GLOCK19", "MWA.BROWNING_HP")
MWADistro.Insert("Base.Pistol2", 0.5, tables, "MWA.P38")

MWADistro.InsertMany("Base.9mmClip", 1, tables, "MWA.9mmMagazine13", "MWA.9mmMagazine15")
MWADistro.Insert("Base.9mmClip", 1, tables, "MWA.9mmMagazine8")
MWADistro.InsertMany("Base.45Clip", 1, tables, "MWA.45Magazine7", "MWA.45Magazine12")

MWADistro.Insert("Base.Pistol3", 1, tables, "MWA.DEAGLE")
MWADistro.Insert("Base.44Clip", 1, tables, "MWA.44Magazine8")

MWADistro.InsertMany("Base.Shotgun", 1, tables, "MWA.M4_BENELLI", "MWA.REMINGTON_1187", "MWA.MOSSBERG_590",
    "MWA.MODEL_870")
MWADistro.InsertMany("Base.DoubleBarrelShotgun", 1, tables, "MWA.TOZ66", "MWA.SIDE_BY_SIDE")

MWADistro.RemoveMany(
    tables,
    unpack(vanillaItems)
)

Events.OnInitGlobalModData.Add(
    function()
        MWADistro.InsertMany("Base.AssaultRifle", 1, zombieTables, "MWA.M16A2", "MWA.M16A1", "MWA.CAR15", "MWA.XM177")
        MWADistro.InsertMany("Base.556Clip", 1, zombieTables, "MWA.556Magazine20", "MWA.556Magazine25",
            "MWA.556Magazine30")

        MWADistro.InsertMany("Base.AssaultRifle2", 1, zombieTables, "MWA.M14", "MWA.G3", "MWA.SCAR_H")
        MWADistro.Insert("Base.M14Clip", 1, zombieTables, "MWA.308Magazine20")
        MWADistro.InsertMany("Base.Pistol", 1, zombieTables, "MWA.M92FS", "MWA.P226", "MWA.GLOCK17", "MWA.GLOCK19",
            "MWA.BROWNING_HP")
        MWADistro.Insert("Base.Pistol2", 0.5, zombieTables, "MWA.P38")

        MWADistro.InsertMany("Base.9mmClip", 1, zombieTables, "MWA.9mmMagazine13", "MWA.9mmMagazine15")
        MWADistro.Insert("Base.9mmClip", 1, zombieTables, "MWA.9mmMagazine8")
        MWADistro.InsertMany("Base.45Clip", 1, zombieTables, "MWA.45Magazine7", "MWA.45Magazine12")

        MWADistro.Insert("Base.Pistol3", 1, zombieTables, "MWA.DEAGLE")
        MWADistro.Insert("Base.44Clip", 1, zombieTables, "MWA.44Magazine8")

        MWADistro.InsertMany("Base.Shotgun", 1, zombieTables, "MWA.M4_BENELLI", "MWA.REMINGTON_1187", "MWA.MOSSBERG_590",
            "MWA.MODEL_870")
        MWADistro.InsertMany("Base.DoubleBarrelShotgun", 1, zombieTables, "MWA.TOZ66", "MWA.SIDE_BY_SIDE")

        MWADistro.RemoveMany(
            zombieTables,
            unpack(vanillaItems)
        )
    end
)
