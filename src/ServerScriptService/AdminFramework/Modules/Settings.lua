--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("AdminFramework"):WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Util = require(Shared:WaitForChild("Util"))

return {
    Name = "Settings",
    Description = "Runtime panel, logging, and safety settings. Permanent defaults remain in Config.lua.",
    Actions = {
        {
            Name = "Settings.Get",
            Permission = "Settings.View",
            Category = Constants.LogCategories.Commands,
            Execute = function(context)
                return {
                    Success = true,
                    Message = "Settings loaded",
                    Data = context.RuntimeSettings.Settings,
                }
            end,
        },
        {
            Name = "Settings.Set",
            Permission = "Settings.Edit",
            Category = Constants.LogCategories.Server,
            Validate = function(_context, _actor, payload)
                local key = Util.clampString(payload.Key, 80, "")
                if key == "" then return false, "A setting key is required" end
                local allowed = {
                    PanelTitle = "string",
                    SoundsEnabled = "boolean",
                    CompactMode = "boolean",
                    AnnouncementsEnabled = "boolean",
                }
                local expected = allowed[key]
                if not expected then return false, "That runtime setting is not editable" end
                if typeof(payload.Value) ~= expected then return false, "Setting value has the wrong type" end
                return true, { Key = key, Value = payload.Value }
            end,
            Execute = function(context, _actor, payload)
                context.RuntimeSettings.Settings[payload.Key] = payload.Value
                context.DataStoreManager:Set("Settings", "runtime", context.RuntimeSettings.Settings)
                context.PushRemote:FireAllClients({ Type = "RuntimeSettings", Settings = context.RuntimeSettings.Settings })
                return { Success = true, Message = payload.Key .. " updated" }
            end,
        },
    },
}
