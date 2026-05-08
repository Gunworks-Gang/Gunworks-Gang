local GunworksKeybinds = require("WeaponSystems/ISUI/GunworksKeybinds")
local Underbarrel = require("WeaponSystems/Utils/Underbarrel")

-------------------------------------------------
-- Key Bindings
-------------------------------------------------

local KEYBIND_TOGGLE_UNDERBARREL = "Gunworks_UnderbarrelUse"

local function onKeyPressed(key)
    local player = getSpecificPlayer(0)
    if not player then return end

    if key == GunworksKeybinds.GetBoundKey(KEYBIND_TOGGLE_UNDERBARREL, Keyboard.KEY_U) then
        local primaryHand = player:getPrimaryHandItem()
        if primaryHand then
            Underbarrel.ToggleUnderbarrel(primaryHand, player)
        end
    end
end

Events.OnKeyPressed.Add(onKeyPressed)
