local ExplosivesSystems = {}

--------------------------------------------------------------------
--- Module identifier for client/server commands
--------------------------------------------------------------------
ExplosivesSystems.MODULE_NAME = "GWG_Explosives"

--------------------------------------------------------------------
--- Impact hooks: list of fn(ordnance, square)
--- Called when any ordnance finishes its flight / detonates.
--------------------------------------------------------------------
ExplosivesSystems.ImpactHooks = {}

--------------------------------------------------------------------
--- Impact hook management
--------------------------------------------------------------------
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
