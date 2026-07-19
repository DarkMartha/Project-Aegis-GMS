--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("AdminFramework"):WaitForChild("Shared")
local Util = require(Shared:WaitForChild("Util"))
local Constants = require(Shared:WaitForChild("Constants"))

local Validators = require(script.Parent.Parent.Core.Validators)

local function targetValidator(_context, _actor, payload)
    return Validators.targetPlayer(payload)
end

local function getTargetParts(payload)
    local character, humanoid, root = Util.getCharacterParts(payload.TargetPlayer)
    if not character or not humanoid or not root then
        return nil, nil, nil, "Target character is not ready"
    end
    return character, humanoid, root, nil
end

return {
    Name = "Players",
    Description = "Player inspection, movement, character control, and authorised client utilities.",
    Actions = {
        {
            Name = "Players.GetProfile",
            Permission = "Players.View",
            Category = Constants.LogCategories.Commands,
            Validate = targetValidator,
            Execute = function(_context, _actor, payload)
                local player = payload.TargetPlayer
                local leaderstats = {}
                local folder = player:FindFirstChild("leaderstats")
                if folder then
                    for _, value in folder:GetChildren() do
                        if value:IsA("ValueBase") then
                            leaderstats[value.Name] = value.Value
                        end
                    end
                end
                local _, humanoid = Util.getCharacterParts(player)
                return {
                    Success = true,
                    Message = "Player profile loaded",
                    Data = {
                        UserId = player.UserId,
                        Name = player.Name,
                        DisplayName = player.DisplayName,
                        AccountAge = player.AccountAge,
                        MembershipType = tostring(player.MembershipType),
                        Health = if humanoid then humanoid.Health else 0,
                        MaxHealth = if humanoid then humanoid.MaxHealth else 0,
                        Team = if player.Team then player.Team.Name else "None",
                        Leaderstats = leaderstats,
                        Muted = player:GetAttribute("AegisMuted") == true,
                        JoinedAt = player:GetAttribute("AegisJoinedAt"),
                    },
                }
            end,
        },
        {
            Name = "Players.Heal",
            Permission = "Players.Heal",
            Validate = targetValidator,
            Execute = function(_context, _actor, payload)
                local _, humanoid, _, err = getTargetParts(payload)
                if err then return { Success = false, Message = err } end
                humanoid.Health = humanoid.MaxHealth
                return { Success = true, Message = "Healed " .. payload.TargetName }
            end,
        },
        {
            Name = "Players.Kill",
            Permission = "Players.Kill",
            Validate = targetValidator,
            Execute = function(context, actor, payload)
                local canManage, reason = Validators.canManageTarget(context, actor, payload.TargetUserId)
                if not canManage then return { Success = false, Message = reason } end
                local _, humanoid, _, err = getTargetParts(payload)
                if err then return { Success = false, Message = err } end
                humanoid.Health = 0
                return { Success = true, Message = "Killed " .. payload.TargetName }
            end,
        },
        {
            Name = "Players.Freeze",
            Permission = "Players.Freeze",
            Validate = targetValidator,
            Execute = function(context, actor, payload)
                local canManage, reason = Validators.canManageTarget(context, actor, payload.TargetUserId)
                if not canManage then return { Success = false, Message = reason } end
                local _, _, root, err = getTargetParts(payload)
                if err then return { Success = false, Message = err } end
                root.Anchored = true
                payload.TargetPlayer:SetAttribute("AegisFrozen", true)
                return { Success = true, Message = "Froze " .. payload.TargetName }
            end,
        },
        {
            Name = "Players.Unfreeze",
            Permission = "Players.Freeze",
            Validate = targetValidator,
            Execute = function(_context, _actor, payload)
                local _, _, root, err = getTargetParts(payload)
                if err then return { Success = false, Message = err } end
                root.Anchored = false
                payload.TargetPlayer:SetAttribute("AegisFrozen", false)
                return { Success = true, Message = "Unfroze " .. payload.TargetName }
            end,
        },
        {
            Name = "Players.Bring",
            Permission = "Players.Teleport",
            Validate = targetValidator,
            Execute = function(context, actor, payload)
                local canManage, reason = Validators.canManageTarget(context, actor, payload.TargetUserId)
                if not canManage then return { Success = false, Message = reason } end
                local _, _, actorRoot = Util.getCharacterParts(actor)
                local _, _, targetRoot, err = getTargetParts(payload)
                if not actorRoot then return { Success = false, Message = "Your character is not ready" } end
                if err then return { Success = false, Message = err } end
                targetRoot.CFrame = actorRoot.CFrame * CFrame.new(3, 0, 0)
                return { Success = true, Message = "Brought " .. payload.TargetName }
            end,
        },
        {
            Name = "Players.Goto",
            Permission = "Players.Teleport",
            Validate = targetValidator,
            Execute = function(_context, actor, payload)
                local _, _, actorRoot = Util.getCharacterParts(actor)
                local _, _, targetRoot, err = getTargetParts(payload)
                if not actorRoot then return { Success = false, Message = "Your character is not ready" } end
                if err then return { Success = false, Message = err } end
                actorRoot.CFrame = targetRoot.CFrame * CFrame.new(3, 0, 0)
                return { Success = true, Message = "Teleported to " .. payload.TargetName }
            end,
        },
        {
            Name = "Players.Respawn",
            Permission = "Players.Respawn",
            Validate = targetValidator,
            Execute = function(_context, _actor, payload)
                payload.TargetPlayer:LoadCharacter()
                return { Success = true, Message = "Respawned " .. payload.TargetName }
            end,
        },
        {
            Name = "Players.Spectate",
            Permission = "Players.Spectate",
            Validate = targetValidator,
            Execute = function(context, actor, payload)
                context.PushRemote:FireClient(actor, {
                    Type = "Effect",
                    Effect = "Spectate",
                    TargetUserId = payload.TargetUserId,
                })
                return { Success = true, Message = "Spectating " .. payload.TargetName }
            end,
        },
        {
            Name = "Players.Fly",
            Permission = "Players.Fly",
            Validate = targetValidator,
            Execute = function(context, actor, payload)
                local canManage, reason = Validators.canManageTarget(context, actor, payload.TargetUserId)
                if not canManage then return { Success = false, Message = reason } end
                context.PushRemote:FireClient(payload.TargetPlayer, { Type = "Effect", Effect = "ToggleFly", AuthorisedBy = actor.UserId })
                return { Success = true, Message = "Toggled flight for " .. payload.TargetName }
            end,
        },
        {
            Name = "Players.Noclip",
            Permission = "Players.Noclip",
            Validate = targetValidator,
            Execute = function(context, actor, payload)
                local canManage, reason = Validators.canManageTarget(context, actor, payload.TargetUserId)
                if not canManage then return { Success = false, Message = reason } end
                context.PushRemote:FireClient(payload.TargetPlayer, { Type = "Effect", Effect = "ToggleNoclip", AuthorisedBy = actor.UserId })
                return { Success = true, Message = "Toggled noclip for " .. payload.TargetName }
            end,
        },
    },
}
