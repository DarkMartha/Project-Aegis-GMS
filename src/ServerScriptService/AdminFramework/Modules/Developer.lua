--!strict

local Stats = game:GetService("Stats")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("AdminFramework"):WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

return {
    Name = "Developer",
    Description = "Restricted diagnostics and whitelisted DataStore inspection.",
    Actions = {
        {
            Name = "Developer.GetDiagnostics",
            Permission = "Developer.RemoteMonitor",
            Category = Constants.LogCategories.Commands,
            Execute = function(context)
                local memory = 0
                pcall(function() memory = Stats:GetTotalMemoryUsageMb() end)
                return {
                    Success = true,
                    Message = "Diagnostics loaded",
                    Data = {
                        MemoryMb = memory,
                        JobId = game.JobId,
                        PlaceId = game.PlaceId,
                        PlaceVersion = game.PlaceVersion,
                        ServerTime = os.time(),
                        ModuleStates = context.ActionService:GetModuleStates(),
                        RecentErrors = context.LogService:GetRecent(20, Constants.LogCategories.Errors, nil),
                    },
                }
            end,
        },
        {
            Name = "Developer.ViewDataStoreKey",
            Permission = "Developer.DataStoreViewer",
            Category = Constants.LogCategories.Commands,
            Validate = function(_context, _actor, payload)
                if not Config.Developer.EnableDataStoreViewer then
                    return false, "DataStore viewer is disabled in Config.lua"
                end
                local store = Util.clampString(payload.Store, 40, "")
                local key = Util.clampString(payload.Key, 120, "")
                if store == "" or key == "" then return false, "Store and key are required" end
                local allowed = false
                for _, name in Config.Developer.AllowedViewerStores do
                    if name == store then allowed = true break end
                end
                if not allowed then return false, "That store is not whitelisted" end
                return true, { Store = store, Key = key }
            end,
            Execute = function(context, _actor, payload)
                local value, err = context.DataStoreManager:RawGet(payload.Store, payload.Key)
                if err then return { Success = false, Message = err } end
                return { Success = true, Message = "DataStore key loaded", Data = value }
            end,
        },
        {
            Name = "Developer.EmitTestNotification",
            Permission = "Developer.Test",
            Category = Constants.LogCategories.Commands,
            Execute = function(context, actor)
                context.PushRemote:FireClient(actor, {
                    Type = "Notification",
                    Title = "Aegis Test",
                    Message = "Client push channel is working.",
                    Level = "Success",
                })
                return { Success = true, Message = "Test notification emitted" }
            end,
        },
    },
}
