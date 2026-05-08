local GunworksKeybinds = {}

GunworksKeybinds.MOD_OPTIONS_ID = "Gunworks"

GunworksKeybinds.Bindings = {
    { value = "Gunworks_UnderbarrelUse", key = Keyboard.KEY_U, name = "UI_optionscreen_binding_Gunworks_UnderbarrelUse" },
    { value = "Gunworks_OpenLoaderUI",   key = Keyboard.KEY_O, name = "UI_optionscreen_binding_Gunworks_OpenLoaderUI" },
    { value = "Gunworks_SwitchFirerate", key = Keyboard.KEY_T, name = "UI_optionscreen_binding_Gunworks_SwitchFirerate" },
}

local function getOptions()
    if not PZAPI or not PZAPI.ModOptions then
        return nil
    end

    local options = PZAPI.ModOptions:getOptions(GunworksKeybinds.MOD_OPTIONS_ID)
    if not options then
        options = PZAPI.ModOptions:create(GunworksKeybinds.MOD_OPTIONS_ID, "Gunworks")
    end

    for _, binding in ipairs(GunworksKeybinds.Bindings) do
        if not options:getOption(binding.value) then
            options:addKeyBind(binding.value, binding.name, binding.key)
        end
    end

    return options
end

local function loadOptions()
    if not getOptions() then
        return
    end

    PZAPI.ModOptions:load()
end

function GunworksKeybinds.GetBoundKey(actionName, fallback)
    local options = getOptions()
    if options then
        local option = options:getOption(actionName)
        if option then
            return option:getValue()
        end
    end

    local core = getCore()
    if core then
        local bound = core:getKey(actionName)
        if bound and bound ~= 0 then
            return bound
        end
    end
    return fallback
end

getOptions()
Events.OnGameBoot.Add(loadOptions)

return GunworksKeybinds
