--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("AdminFramework"):WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local Validators = {}

function Validators.userId(payload: any, field: string?): (boolean, any)
    field = field or "TargetUserId"
    local userId = Util.toInteger(payload[field])
    if not userId or userId <= 0 then
        return false, "A valid user ID is required"
    end
    local normalized = Util.shallowCopy(payload)
    normalized[field] = userId
    return true, normalized
end

function Validators.targetPlayer(payload: any): (boolean, any)
    local ok, normalizedOrReason = Validators.userId(payload)
    if not ok then
        return false, normalizedOrReason
    end
    local normalized = normalizedOrReason
    local target = Util.findPlayer(normalized.TargetUserId)
    if not target then
        return false, "That player is not in this server"
    end
    normalized.TargetPlayer = target
    normalized.TargetName = target.Name
    return true, normalized
end

function Validators.reason(payload: any, defaultReason: string?): string
    local reason = Util.clampString(payload.Reason, Constants.MaxReasonLength, defaultReason or Config.Moderation.DefaultReason)
    if reason == "" then
        reason = defaultReason or Config.Moderation.DefaultReason
    end
    return reason
end

function Validators.message(payload: any): (boolean, any)
    local message = Util.clampString(payload.Message, Constants.MaxMessageLength, "")
    if message == "" then
        return false, "A message is required"
    end
    local normalized = Util.shallowCopy(payload)
    normalized.Message = message
    return true, normalized
end

function Validators.canManageTarget(context, actor: Player, targetUserId: number): (boolean, string?)
    if actor.UserId == targetUserId and not context.RankService:IsOwnerUserId(actor.UserId) then
        return false, "You cannot use that moderation action on yourself"
    end
    return context.RankService:CanManage(actor, targetUserId, nil)
end

return table.freeze(Validators)
