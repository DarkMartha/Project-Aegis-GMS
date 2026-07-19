--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("AdminFramework"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Constants = require(Shared:WaitForChild("Constants"))
local Util = require(Shared:WaitForChild("Util"))

local BanService = {}
BanService.__index = BanService

function BanService.new(dataStoreManager, logService)
    return setmetatable({
        _dataStores = dataStoreManager,
        _logService = logService,
        _crossServer = nil,
    }, BanService)
end

function BanService:SetCrossServer(crossServer)
    self._crossServer = crossServer
    crossServer:RegisterHandler(Constants.Topics.BanSync, function(envelope)
        local payload = if typeof(envelope) == "table" and envelope.Data then envelope.Data else envelope
        self:_handleSync(payload)
    end)
end

function BanService:GetBan(userId: number): any
    local record = self._dataStores:Get("Bans", tostring(userId), nil)
    if typeof(record) ~= "table" or not record.Active then
        return nil
    end
    if record.ExpiresAt and os.time() >= record.ExpiresAt then
        record.Active = false
        record.ExpiredAt = os.time()
        self._dataStores:Set("Bans", tostring(userId), record)
        return nil
    end
    return record
end

function BanService:EnforceJoin(player: Player): boolean
    local record = self:GetBan(player.UserId)
    if not record then
        return false
    end
    local expiry = if record.ExpiresAt then "\nExpires: " .. Util.isoTimestamp(record.ExpiresAt) else ""
    player:Kick(string.format("%s\nReason: %s%s", Config.Moderation.BanMessage, record.Reason or "No reason provided", expiry))
    return true
end

function BanService:Ban(actor: Player, userId: number, reason: string, durationMinutes: number?, global: boolean?): (boolean, string)
    if userId <= 0 then
        return false, "Invalid user ID"
    end
    local expiresAt = nil
    if durationMinutes and durationMinutes > 0 then
        expiresAt = os.time() + math.floor(durationMinutes * 60)
    end

    local userName = Util.safeUserName(userId)
    local record = {
        UserId = userId,
        UserName = userName,
        Reason = Util.clampString(reason, Constants.MaxReasonLength, Config.Moderation.DefaultReason),
        CreatedAt = os.time(),
        CreatedBy = actor.UserId,
        CreatedByName = actor.Name,
        ExpiresAt = expiresAt,
        Active = true,
        Global = if global == nil then true else global,
    }

    local ok, err = self._dataStores:Set("Bans", tostring(userId), record)
    if not ok then
        return false, "Could not save ban: " .. tostring(err)
    end

    local target = Players:GetPlayerByUserId(userId)
    if target then
        target:Kick(string.format("You were banned by %s.\nReason: %s", actor.Name, record.Reason))
    end

    if self._crossServer and record.Global then
        self._crossServer:Publish(Constants.Topics.BanSync, {
            Action = "Ban",
            Record = record,
        })
    end

    return true, if expiresAt then "Temporary ban applied to " .. userName else "Ban applied to " .. userName
end

function BanService:Unban(actor: Player, userId: number): (boolean, string)
    local existing = self._dataStores:Get("Bans", tostring(userId), nil)
    if typeof(existing) ~= "table" then
        return false, "No ban record was found"
    end
    existing.Active = false
    existing.RevokedAt = os.time()
    existing.RevokedBy = actor.UserId
    local ok, err = self._dataStores:Set("Bans", tostring(userId), existing)
    if not ok then
        return false, "Could not revoke ban: " .. tostring(err)
    end

    if self._crossServer and existing.Global then
        self._crossServer:Publish(Constants.Topics.BanSync, {
            Action = "Unban",
            UserId = userId,
        })
    end
    return true, "Ban revoked for " .. Util.safeUserName(userId)
end

function BanService:_handleSync(payload: any)
    if typeof(payload) ~= "table" then
        return
    end
    if payload.Action == "Ban" and typeof(payload.Record) == "table" then
        local record = payload.Record
        local userId = tonumber(record.UserId)
        if userId then
            local target = Players:GetPlayerByUserId(userId)
            if target then
                target:Kick(string.format("You were banned.\nReason: %s", tostring(record.Reason or "No reason provided")))
            end
        end
    end
end

return BanService
