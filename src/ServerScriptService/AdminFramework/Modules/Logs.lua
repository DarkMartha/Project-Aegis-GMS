--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("AdminFramework"):WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Util = require(Shared:WaitForChild("Util"))

return {
    Name = "Logs",
    Description = "Recent command, moderation, server, security, and error logs.",
    Actions = {
        {
            Name = "Logs.GetRecent",
            Permission = "Logs.View",
            Category = Constants.LogCategories.Commands,
            Validate = function(_context, _actor, payload)
                local normalized = Util.shallowCopy(payload)
                normalized.Limit = math.clamp(Util.toInteger(payload.Limit) or 50, 1, Constants.MaxLogsReturned)
                normalized.Category = if typeof(payload.Category) == "string" and payload.Category ~= "All" then payload.Category else nil
                normalized.TargetUserId = Util.toInteger(payload.TargetUserId)
                return true, normalized
            end,
            Execute = function(context, _actor, payload)
                return {
                    Success = true,
                    Message = "Logs loaded",
                    Data = context.LogService:GetRecent(payload.Limit, payload.Category, payload.TargetUserId),
                }
            end,
        },
        {
            Name = "Logs.GetErrors",
            Permission = "Logs.Errors",
            Category = Constants.LogCategories.Commands,
            Execute = function(context)
                return {
                    Success = true,
                    Message = "Error logs loaded",
                    Data = context.LogService:GetRecent(100, Constants.LogCategories.Errors, nil),
                }
            end,
        },
    },
}
