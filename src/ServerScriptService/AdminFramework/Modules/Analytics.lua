--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("AdminFramework"):WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

return {
    Name = "Analytics",
    Description = "Current-server joins, leaves, performance, staff activity, and live-server information.",
    Actions = {
        {
            Name = "Analytics.GetSnapshot",
            Permission = "Analytics.View",
            Category = Constants.LogCategories.Commands,
            Execute = function(context)
                local snapshot = context.AnalyticsService:GetSnapshot()
                snapshot.LiveServers = context.CrossServerService:GetLiveServers(50)
                return { Success = true, Message = "Analytics loaded", Data = snapshot }
            end,
        },
    },
}
