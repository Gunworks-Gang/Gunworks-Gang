local AnimatedReloadsAPI = require("AnimatedReloads/API")

local function registerBrenAttachmentReload()
    AnimatedReloadsAPI.registerWeaponReloadHandler({
        id = "AnimatedReloads_BrenMK2_Attachments",
        style = "attachments",
        reloadType = "brenmk2reload",

        -- hand prop used during reload anim
        magItem = "AnimatedReloads.BrenMK2_ReloadMagazine",

        -- weapon-part setup used on the gun model
        attachments = {
            magPart = "mag",
            parts = {
                mag = {
                    partType = "magazine",
                    itemType = "AnimatedReloads.BrenMK2_ReloadMagazine",
                },
                -- optional cover example:
                -- coverOpen = { partType = "magcover", itemType = "MyMod.Bren_Cover_Open" },
                -- coverClosed = { partType = "magcover", itemType = "MyMod.Bren_Cover_Closed" },
            },

            states = {
                loaded = { attach = { "mag" } },
                unloaded = { detach = { "mag" } },
                -- optional:
                -- coverOpen = { attach = { "coverOpen" }, detach = { "coverClosed" } },
                -- coverClosed = { attach = { "coverClosed" }, detach = { "coverOpen" } },
            },
            loadedState = "loaded",
            unloadedState = "unloaded",
        },

        shortRackAfterInsert = true,
        durations = {
            load = 1.3,
            loadShort = 1.5,
            unload = 1.8,
            rack = 1.0,
        },
    })

    AnimatedReloadsAPI.applyDurationSettings()
end

Events.OnGameBoot.Add(registerBrenAttachmentReload)
