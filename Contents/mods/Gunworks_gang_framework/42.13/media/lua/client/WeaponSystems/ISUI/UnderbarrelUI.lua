local GunworksKeybinds = require("WeaponSystems/ISUI/GunworksKeybinds")
local Underbarrel = require("WeaponSystems/Utils/Underbarrel")

-------------------------------------------------
-- Key Bindings
-------------------------------------------------

local KEYBIND_USE_UNDERBARREL = "Gunworks_UnderbarrelUse"
local KEYBIND_RESTORE_MAIN = "Gunworks_UnderbarrelRestore"

local function onKeyPressed(key)
    local player = getSpecificPlayer(0)
    if not player then return end

    if key == GunworksKeybinds.GetBoundKey(KEYBIND_USE_UNDERBARREL, Keyboard.KEY_U) then
        if not Underbarrel.IsUsingUnderbarrel(player) then
            local primaryHand = player:getPrimaryHandItem()
            if primaryHand then
                if Underbarrel.CanSwapToUnderbarrel(primaryHand) then
                    Underbarrel.SwapToUnderbarrel(primaryHand, player)
                elseif Underbarrel.HasIntegratedUnderbarrel(primaryHand) and Underbarrel.IsIntegratedUnderbarrelDeployed(primaryHand) then
                    Underbarrel.SwapToIntegratedUnderbarrel(primaryHand, player)
                end
            end
        end
    elseif key == GunworksKeybinds.GetBoundKey(KEYBIND_RESTORE_MAIN, Keyboard.KEY_Y) then
        if Underbarrel.IsUsingUnderbarrel(player) then
            Underbarrel.RestoreOriginalWeapon(player)
        end
    end
end

Events.OnKeyPressed.Add(onKeyPressed)
