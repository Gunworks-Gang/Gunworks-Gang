local GunworksKeybinds = {}

GunworksKeybinds.MOD_OPTIONS_ID = "Gunworks"

GunworksKeybinds.Bindings = {
    { value = "Gunworks_UnderbarrelUse", key = Keyboard.KEY_U, name = "Gunworks: Toggle underbarrel" },
    { value = "Gunworks_OpenLoaderUI",   key = Keyboard.KEY_O, name = "Gunworks: Open weapon loader UI" },
    { value = "Gunworks_SwitchFirerate", key = Keyboard.KEY_T, name = "Gunworks: Cycle fire mode" },
}

local options = PZAPI.ModOptions:create(GunworksKeybinds.MOD_OPTIONS_ID, "Gunworks")

for _, binding in ipairs(GunworksKeybinds.Bindings) do
    options:addKeyBind(binding.value, binding.name, binding.key)
end

function GunworksKeybinds.GetBoundKey(actionName, fallback)
    local option = options:getOption(actionName)
    if option then
        return option:getValue()
    end
    return fallback
end

return GunworksKeybinds
