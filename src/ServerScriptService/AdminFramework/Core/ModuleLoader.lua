--!strict

local ModuleLoader = {}

function ModuleLoader.Load(moduleFolder: Folder, actionService)
    local loaded = {}
    local scripts = moduleFolder:GetChildren()
    table.sort(scripts, function(a, b)
        return a.Name < b.Name
    end)

    for _, child in scripts do
        if child:IsA("ModuleScript") then
            local ok, definition = pcall(require, child)
            if not ok then
                warn(string.format("[Aegis GMS] Module '%s' failed to load: %s", child.Name, tostring(definition)))
            else
                actionService:RegisterModule(definition)
                table.insert(loaded, definition.Name)
            end
        end
    end
    return loaded
end

return ModuleLoader
