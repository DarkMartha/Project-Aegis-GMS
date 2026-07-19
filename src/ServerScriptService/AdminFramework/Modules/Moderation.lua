--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("AdminFramework"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Constants = require(Shared:WaitForChild("Constants"))
local Util = require(Shared:WaitForChild("Util"))
local Validators = require(script.Parent.Parent.Core.Validators)

local function offlineTargetValidator(_context, _actor, payload)
    local ok, normalized = Validators.userId(payload)
    if not ok then return false, normalized end
    normalized.TargetName = Util.safeUserName(normalized.TargetUserId)
    normalized.Reason = Validators.reason(payload)
    return true, normalized
end

local function onlinePunishmentValidator(context, actor, payload)
    local ok, normalized = Validators.targetPlayer(payload)
    if not ok then return false, normalized end
    local allowed, reason = Validators.canManageTarget(context, actor, normalized.TargetUserId)
    if not allowed then return false, reason end
    normalized.Reason = Validators.reason(payload)
    return true, normalized
end

local function offlinePunishmentValidator(context, actor, payload)
    local ok, normalized = offlineTargetValidator(context, actor, payload)
    if not ok then return false, normalized end
    local allowed, reason = Validators.canManageTarget(context, actor, normalized.TargetUserId)
    if not allowed then return false, reason end
    return true, normalized
end

return {
    Name = "Moderation",
    Description = "Persistent punishment records, hierarchy protection, jail, notes, and history.",
    Actions = {
        {
            Name = "Moderation.Kick",
            Permission = "Moderation.Kick",
            Category = Constants.LogCategories.Moderation,
            Validate = onlinePunishmentValidator,
            Execute = function(_context, actor, payload)
                payload.TargetPlayer:Kick(string.format("Kicked by %s.\nReason: %s", actor.Name, payload.Reason))
                return { Success = true, Message = "Kicked " .. payload.TargetName }
            end,
        },
        {
            Name = "Moderation.Ban",
            Permission = "Moderation.Ban",
            Category = Constants.LogCategories.Moderation,
            Validate = offlinePunishmentValidator,
            Execute = function(context, actor, payload)
                local success, message = context.BanService:Ban(actor, payload.TargetUserId, payload.Reason, nil, true)
                return { Success = success, Message = message }
            end,
        },
        {
            Name = "Moderation.TempBan",
            Permission = "Moderation.TempBan",
            Category = Constants.LogCategories.Moderation,
            Validate = function(context, actor, payload)
                local ok, normalized = offlinePunishmentValidator(context, actor, payload)
                if not ok then return false, normalized end
                normalized.DurationMinutes = math.clamp(Util.toInteger(payload.DurationMinutes) or Config.Moderation.DefaultTempBanMinutes, 1, 60 * 24 * 365)
                return true, normalized
            end,
            Execute = function(context, actor, payload)
                local success, message = context.BanService:Ban(actor, payload.TargetUserId, payload.Reason, payload.DurationMinutes, true)
                return { Success = success, Message = message }
            end,
        },
        {
            Name = "Moderation.Unban",
            Permission = "Moderation.Unban",
            Category = Constants.LogCategories.Moderation,
            Validate = offlineTargetValidator,
            Execute = function(context, actor, payload)
                local success, message = context.BanService:Unban(actor, payload.TargetUserId)
                return { Success = success, Message = message }
            end,
        },
        {
            Name = "Moderation.Warn",
            Permission = "Moderation.Warn",
            Category = Constants.LogCategories.Moderation,
            Validate = offlinePunishmentValidator,
            Execute = function(context, actor, payload)
                local warning = {
                    Id = Util.guid(),
                    Reason = payload.Reason,
                    CreatedAt = os.time(),
                    CreatedBy = actor.UserId,
                    CreatedByName = actor.Name,
                    Active = true,
                }
                local ok, result = context.DataStoreManager:Update("Warnings", tostring(payload.TargetUserId), function(existing)
                    existing = if typeof(existing) == "table" then existing else {}
                    table.insert(existing, warning)
                    while #existing > 100 do table.remove(existing, 1) end
                    return existing
                end, {})
                if not ok then return { Success = false, Message = "Could not save warning: " .. tostring(result) } end
                local target = Players:GetPlayerByUserId(payload.TargetUserId)
                if target then
                    context.PushRemote:FireClient(target, { Type = "Notification", Title = "Warning", Message = payload.Reason, Level = "Warning" })
                end
                return { Success = true, Message = "Warned " .. payload.TargetName }
            end,
        },
        {
            Name = "Moderation.Mute",
            Permission = "Moderation.Mute",
            Category = Constants.LogCategories.Moderation,
            Validate = function(context, actor, payload)
                local ok, normalized = offlinePunishmentValidator(context, actor, payload)
                if not ok then return false, normalized end
                normalized.DurationMinutes = math.clamp(Util.toInteger(payload.DurationMinutes) or Config.Moderation.DefaultMuteMinutes, 1, 60 * 24 * 30)
                return true, normalized
            end,
            Execute = function(context, actor, payload)
                local success, message = context.MuteService:Mute(actor, payload.TargetUserId, payload.Reason, payload.DurationMinutes)
                return { Success = success, Message = message }
            end,
        },
        {
            Name = "Moderation.Unmute",
            Permission = "Moderation.Mute",
            Category = Constants.LogCategories.Moderation,
            Validate = offlineTargetValidator,
            Execute = function(context, actor, payload)
                local success, message = context.MuteService:Unmute(actor, payload.TargetUserId)
                return { Success = success, Message = message }
            end,
        },
        {
            Name = "Moderation.Jail",
            Permission = "Moderation.Jail",
            Category = Constants.LogCategories.Moderation,
            Validate = onlinePunishmentValidator,
            Execute = function(_context, _actor, payload)
                local _, _, root = Util.getCharacterParts(payload.TargetPlayer)
                if not root then return { Success = false, Message = "Target character is not ready" } end
                payload.TargetPlayer:SetAttribute("AegisJailed", true)
                root.CFrame = CFrame.new(Config.Moderation.JailPosition)
                root.Anchored = true
                return { Success = true, Message = "Jailed " .. payload.TargetName }
            end,
        },
        {
            Name = "Moderation.Unjail",
            Permission = "Moderation.Jail",
            Category = Constants.LogCategories.Moderation,
            Validate = function(_context, _actor, payload)
                return Validators.targetPlayer(payload)
            end,
            Execute = function(_context, _actor, payload)
                local _, _, root = Util.getCharacterParts(payload.TargetPlayer)
                if root then root.Anchored = false end
                payload.TargetPlayer:SetAttribute("AegisJailed", false)
                payload.TargetPlayer:LoadCharacter()
                return { Success = true, Message = "Released " .. payload.TargetName }
            end,
        },
        {
            Name = "Moderation.AddNote",
            Permission = "Moderation.Notes",
            Category = Constants.LogCategories.PlayerHistory,
            Validate = function(_context, _actor, payload)
                local ok, normalized = offlineTargetValidator(nil, nil, payload)
                if not ok then return false, normalized end
                normalized.Note = Util.clampString(payload.Note or payload.Reason, Constants.MaxNoteLength, "")
                if normalized.Note == "" then return false, "A note is required" end
                return true, normalized
            end,
            Execute = function(context, actor, payload)
                local note = { Id = Util.guid(), Text = payload.Note, CreatedAt = os.time(), CreatedBy = actor.UserId, CreatedByName = actor.Name }
                local ok, result = context.DataStoreManager:Update("Notes", tostring(payload.TargetUserId), function(existing)
                    existing = if typeof(existing) == "table" then existing else {}
                    table.insert(existing, note)
                    while #existing > 100 do table.remove(existing, 1) end
                    return existing
                end, {})
                if not ok then return { Success = false, Message = "Could not save note: " .. tostring(result) } end
                return { Success = true, Message = "Note added for " .. payload.TargetName }
            end,
        },
        {
            Name = "Moderation.GetHistory",
            Permission = "Logs.PlayerHistory",
            Category = Constants.LogCategories.PlayerHistory,
            Validate = offlineTargetValidator,
            Execute = function(context, _actor, payload)
                local warnings = context.DataStoreManager:Get("Warnings", tostring(payload.TargetUserId), {})
                local notes = context.DataStoreManager:Get("Notes", tostring(payload.TargetUserId), {})
                local ban = context.BanService:GetBan(payload.TargetUserId)
                local mute = context.DataStoreManager:Get("Mutes", tostring(payload.TargetUserId), nil)
                return {
                    Success = true,
                    Message = "History loaded for " .. payload.TargetName,
                    Data = { Warnings = warnings, Notes = notes, Ban = ban, Mute = mute },
                }
            end,
        },
    },
}
