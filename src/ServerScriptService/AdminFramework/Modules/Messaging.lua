--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("AdminFramework"):WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Util = require(Shared:WaitForChild("Util"))
local Validators = require(script.Parent.Parent.Core.Validators)

local function messageValidator(_context, _actor, payload)
    return Validators.message(payload)
end

return {
    Name = "Messaging",
    Description = "Local notifications, broadcasts, staff broadcasts, and global announcements.",
    Actions = {
        {
            Name = "Messaging.Notify",
            Permission = "Messaging.Notify",
            Category = Constants.LogCategories.Messaging,
            Validate = function(_context, _actor, payload)
                local ok, normalized = Validators.targetPlayer(payload)
                if not ok then return false, normalized end
                local messageOk, withMessage = Validators.message(normalized)
                if not messageOk then return false, withMessage end
                withMessage.Title = Util.clampString(payload.Title, 80, "Staff Notification")
                return true, withMessage
            end,
            Execute = function(context, actor, payload)
                context.PushRemote:FireClient(payload.TargetPlayer, {
                    Type = "Notification",
                    Title = payload.Title,
                    Message = payload.Message,
                    Level = "Info",
                    From = actor.Name,
                })
                return { Success = true, Message = "Notification sent to " .. payload.TargetName }
            end,
        },
        {
            Name = "Messaging.Broadcast",
            Permission = "Messaging.Broadcast",
            Category = Constants.LogCategories.Messaging,
            Validate = messageValidator,
            Execute = function(context, actor, payload)
                context.PushRemote:FireAllClients({
                    Type = "Announcement",
                    Title = Util.clampString(payload.Title, 80, "Server Announcement"),
                    Message = payload.Message,
                    Level = "Info",
                    From = actor.Name,
                })
                return { Success = true, Message = "Server broadcast sent" }
            end,
        },
        {
            Name = "Messaging.StaffBroadcast",
            Permission = "Messaging.StaffChat",
            Category = Constants.LogCategories.Messaging,
            Validate = messageValidator,
            Execute = function(context, actor, payload)
                for _, player in Players:GetPlayers() do
                    if context.RankService:GetRole(player) then
                        context.PushRemote:FireClient(player, {
                            Type = "Notification",
                            Title = "Staff Broadcast",
                            Message = payload.Message,
                            Level = "Staff",
                            From = actor.Name,
                        })
                    end
                end
                context.CrossServerService:Publish(Constants.Topics.StaffBroadcast, {
                    Title = "Staff Broadcast",
                    Message = payload.Message,
                    From = actor.Name,
                    FromUserId = actor.UserId,
                })
                return { Success = true, Message = "Staff broadcast sent" }
            end,
        },
        {
            Name = "Messaging.GlobalAnnouncement",
            Permission = "Messaging.Global",
            Category = Constants.LogCategories.Messaging,
            Validate = messageValidator,
            Execute = function(context, actor, payload)
                local success, err = context.CrossServerService:Publish(Constants.Topics.GlobalAnnouncement, {
                    Title = Util.clampString(payload.Title, 80, "Global Announcement"),
                    Message = payload.Message,
                    From = actor.Name,
                    FromUserId = actor.UserId,
                    Level = "Global",
                })
                if not success then return { Success = false, Message = "Global publish failed: " .. tostring(err) } end
                return { Success = true, Message = "Global announcement published" }
            end,
        },
    },
}
