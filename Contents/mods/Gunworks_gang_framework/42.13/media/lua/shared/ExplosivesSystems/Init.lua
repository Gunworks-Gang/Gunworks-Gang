local ExplosivesSystems = {}

ExplosivesSystems.MODULE_NAME = "GWG_Explosives"
ExplosivesSystems.ImpactHooks = {}

function ExplosivesSystems.AddImpactHook(fn)
    if type(fn) ~= "function" then return end
    ExplosivesSystems.ImpactHooks[#ExplosivesSystems.ImpactHooks + 1] = fn
end

function ExplosivesSystems.RemoveImpactHook(fn)
    for i = #ExplosivesSystems.ImpactHooks, 1, -1 do
        if ExplosivesSystems.ImpactHooks[i] == fn then
            table.remove(ExplosivesSystems.ImpactHooks, i)
            return
        end
    end
end

return ExplosivesSystems
