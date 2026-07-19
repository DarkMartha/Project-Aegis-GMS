--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("AdminFramework"):WaitForChild("Shared")
local Permissions = require(Shared:WaitForChild("Permissions"))
local Constants = require(Shared:WaitForChild("Constants"))
local Util = require(Shared:WaitForChild("Util"))
local Validators = require(script.Parent.Parent.Core.Validators)

local function rankValidator(_context, _actor, payload)
    local ok, normalized = Validators.userId(payload)
    if not ok then return false, normalized end
    local rankName = Util.clampString(payload.Rank, 80, "")
    if not Permissions.isValidRank(rankName) then
        return false, "Choose a valid rank"
    end
    normalized.Rank = rankName
    normalized.TargetName = Util.safeUserName(normalized.TargetUserId)
    return true, normalized
end

return {
    Name = "Staff",
    Description = "Custom ranks, temporary ranks, staff notes, activity, and permission overrides.",
    Actions = {
        {
            Name = "Staff.GetDirectory",
            Permission = "Staff.View",
            Category = Constants.LogCategories.Staff,
            Execute = function(context)
                return { Success = true, Message = "Staff directory loaded", Data = context.RankService:GetStaffDirectory() }
            end,
        },
        {
            Name = "Staff.SetRank",
            Permission = "Ranks.Assign",
            Category = Constants.LogCategories.Staff,
            Validate = rankValidator,
            Execute = function(context, actor, payload)
                local success, message = context.RankService:SetCustomRank(actor, payload.TargetUserId, payload.Rank)
                local target = game:GetService("Players"):GetPlayerByUserId(payload.TargetUserId)
                if success and target then context.PushRemote:FireClient(target, { Type = "RefreshPermissions" }) end
                return { Success = success, Message = message }
            end,
        },
        {
            Name = "Staff.RemoveRank",
            Permission = "Staff.Remove",
            Category = Constants.LogCategories.Staff,
            Validate = function(_context, _actor, payload)
                local ok, normalized = Validators.userId(payload)
                if not ok then return false, normalized end
                normalized.TargetName = Util.safeUserName(normalized.TargetUserId)
                return true, normalized
            end,
            Execute = function(context, actor, payload)
                local success, message = context.RankService:SetCustomRank(actor, payload.TargetUserId, nil)
                local target = game:GetService("Players"):GetPlayerByUserId(payload.TargetUserId)
                if success and target then context.PushRemote:FireClient(target, { Type = "RefreshPermissions" }) end
                return { Success = success, Message = message }
            end,
        },
        {
            Name = "Staff.SetTemporaryRank",
            Permission = "Ranks.Temporary",
            Category = Constants.LogCategories.Staff,
            Validate = function(context, actor, payload)
                local ok, normalized = rankValidator(context, actor, payload)
                if not ok then return false, normalized end
                normalized.DurationMinutes = math.clamp(Util.toInteger(payload.DurationMinutes) or 60, 1, 60 * 24 * 30)
                return true, normalized
            end,
            Execute = function(context, actor, payload)
                local success, message = context.RankService:SetTemporaryRank(actor, payload.TargetUserId, payload.Rank, payload.DurationMinutes)
                local target = game:GetService("Players"):GetPlayerByUserId(payload.TargetUserId)
                if success and target then context.PushRemote:FireClient(target, { Type = "RefreshPermissions" }) end
                return { Success = success, Message = message }
            end,
        },
        {
            Name = "Staff.SetPermissionOverrides",
            Permission = "Ranks.Permissions",
            Category = Constants.LogCategories.Staff,
            Validate = function(_context, _actor, payload)
                local ok, normalized = Validators.userId(payload)
                if not ok then return false, normalized end
                normalized.Allow = if typeof(payload.Allow) == "table" then payload.Allow else {}
                normalized.Deny = if typeof(payload.Deny) == "table" then payload.Deny else {}
                return true, normalized
            end,
            Execute = function(context, actor, payload)
                local success, message = context.RankService:SetOverrides(actor, payload.TargetUserId, payload.Allow, payload.Deny)
                return { Success = success, Message = message }
            end,
        },
        {
            Name = "Staff.AddNote",
            Permission = "Staff.Notes",
            Category = Constants.LogCategories.Staff,
            Validate = function(_context, _actor, payload)
                local ok, normalized = Validators.userId(payload)
                if not ok then return false, normalized end
                normalized.Note = Util.clampString(payload.Note, 1000, "")
                if normalized.Note == "" then return false, "A staff note is required" end
                return true, normalized
            end,
            Execute = function(context, actor, payload)
                local ok, updated = context.DataStoreManager:Update("Staff", tostring(payload.TargetUserId), function(record)
                    record = if typeof(record) == "table" then record else {}
                    record.Notes = record.Notes or {}
                    table.insert(record.Notes, {
                        Id = Util.guid(),
                        Text = payload.Note,
                        CreatedAt = os.time(),
                        CreatedBy = actor.UserId,
                        CreatedByName = actor.Name,
                    })
                    while #record.Notes > 50 do table.remove(record.Notes, 1) end
                    return record
                end, {})
                context.RankService:RefreshUser(payload.TargetUserId)
                if not ok then return { Success = false, Message = "Could not save staff note: " .. tostring(updated) } end
                return { Success = true, Message = "Staff note added" }
            end,
        },
        {
            Name = "Staff.GetActivity",
            Permission = "Staff.Activity",
            Category = Constants.LogCategories.Staff,
            Execute = function(context)
                return { Success = true, Message = "Staff activity loaded", Data = context.AnalyticsService:GetSnapshot().StaffActions }
            end,
        },
    },
}
