--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("AdminFramework"):WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Util = require(Shared:WaitForChild("Util"))

return {
    Name = "Modules",
    Description = "Runtime module registry and enable/disable controls.",
    Actions = {
        {
            Name = "Modules.GetStates",
            Permission = "Modules.View",
            Category = Constants.LogCategories.Commands,
            Execute = function(context)
                return { Success = true, Message = "Module states loaded", Data = context.ActionService:GetModuleStates() }
            end,
        },
        {
            Name = "Modules.Toggle",
            Permission = "Modules.Toggle",
            Category = Constants.LogCategories.Server,
            Validate = function(_context, _actor, payload)
                local name = Util.clampString(payload.Module, 80, "")
                if name == "" then return false, "A module name is required" end
                if typeof(payload.Enabled) ~= "boolean" then return false, "Enabled must be true or false" end
                if name == "Modules" and payload.Enabled == false then
                    return false, "The Modules controller cannot disable itself"
                end
                return true, { Module = name, Enabled = payload.Enabled }
            end,
            Execute = function(context, _actor, payload)
                local success, message = context.ActionService:SetModuleEnabled(payload.Module, payload.Enabled)
                if success then
                    context.DataStoreManager:Set("Settings", "modules", context.RuntimeSettings.Modules)
                    context.PushRemote:FireAllClients({ Type = "RefreshPermissions" })
                end
                return { Success = success, Message = message }
            end,
        },
    },
}
