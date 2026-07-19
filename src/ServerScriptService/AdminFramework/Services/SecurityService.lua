--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("AdminFramework"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local SecurityService = {}
SecurityService.__index = SecurityService

function SecurityService.new()
    return setmetatable({
        _requestWindows = {},
        _lastActions = {},
        _strikes = {},
    }, SecurityService)
end

local function payloadShapeIsSafe(value: any, depth: number, counters: {keys: number}): boolean
    if depth > Config.Security.MaxPayloadDepth then
        return false
    end

    local kind = typeof(value)
    if kind == "nil" or kind == "boolean" or kind == "number" or kind == "string" then
        return true
    end
    if kind ~= "table" then
        return false
    end

    for key, child in value do
        counters.keys += 1
        if counters.keys > Config.Security.MaxPayloadKeys then
            return false
        end
        if typeof(key) ~= "string" and typeof(key) ~= "number" then
            return false
        end
        if not payloadShapeIsSafe(child, depth + 1, counters) then
            return false
        end
    end
    return true
end

function SecurityService:ValidateEnvelope(player: Player, envelope: any): (boolean, string?)
    if typeof(envelope) ~= "table" then
        self:AddStrike(player, "Non-table request envelope")
        return false, "Malformed request"
    end

    if not payloadShapeIsSafe(envelope, 0, { keys = 0 }) then
        self:AddStrike(player, "Payload exceeded structural limits")
        return false, "Request payload rejected"
    end

    if typeof(envelope.kind) ~= "string" then
        self:AddStrike(player, "Missing request kind")
        return false, "Missing request kind"
    end

    return true, nil
end

function SecurityService:CheckRateLimit(player: Player, actionName: string): (boolean, string?)
    local now = os.clock()
    local userId = player.UserId
    local window = self._requestWindows[userId]
    if not window or now - window.startedAt >= Config.Security.WindowSeconds then
        window = { startedAt = now, count = 0 }
        self._requestWindows[userId] = window
    end

    window.count += 1
    if window.count > Config.Security.RequestsPerWindow then
        self:AddStrike(player, "Rate limit exceeded")
        return false, "Too many requests. Slow down."
    end

    self._lastActions[userId] = self._lastActions[userId] or {}
    local last = self._lastActions[userId][actionName]
    if last and now - last < Config.Security.ActionCooldownSeconds then
        return false, "Action cooldown active"
    end
    self._lastActions[userId][actionName] = now
    return true, nil
end

function SecurityService:AddStrike(player: Player, reason: string): number
    local userId = player.UserId
    self._strikes[userId] = (self._strikes[userId] or 0) + 1
    warn(string.format("[Aegis GMS] Security strike %d for %s (%d): %s", self._strikes[userId], player.Name, userId, reason))

    if Config.Security.KickOnRepeatedTampering and self._strikes[userId] >= Config.Security.TamperStrikeLimit then
        player:Kick("Admin framework security validation failed repeatedly.")
    end
    return self._strikes[userId]
end

function SecurityService:CleanupPlayer(player: Player)
    self._requestWindows[player.UserId] = nil
    self._lastActions[player.UserId] = nil
    self._strikes[player.UserId] = nil
end

return SecurityService
