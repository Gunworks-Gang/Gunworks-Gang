local GunworksKeybinds = {}

GunworksKeybinds.Bindings = {
    { value = "Gunworks_UnderbarrelUse",     key = Keyboard.KEY_U },
    { value = "Gunworks_UnderbarrelRestore", key = Keyboard.KEY_Y },
    { value = "Gunworks_OpenLoaderUI",       key = Keyboard.KEY_O },
}

local function hasBinding(value)
    if not keyBinding then return false end
    for i = 1, #keyBinding do
        local entry = keyBinding[i]
        if entry and entry.value == value then
            return true
        end
    end
    return false
end

local function register()
    if not keyBinding then return end

    for _, binding in ipairs(GunworksKeybinds.Bindings) do
        if not hasBinding(binding.value) then
            keyBinding[#keyBinding + 1] = {
                value = binding.value,
                key = binding.key,
            }
        end
    end
end

function GunworksKeybinds.GetBoundKey(actionName, fallback)
    local core = getCore()
    if core then
        local bound = core:getKey(actionName)
        if bound and bound ~= 0 then
            return bound
        end
    end
    return fallback
end

Events.OnGameBoot.Add(register)

return GunworksKeybinds
