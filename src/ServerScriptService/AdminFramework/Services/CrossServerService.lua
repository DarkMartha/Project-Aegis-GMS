--!strict

local MessagingService = game:GetService("MessagingService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("AdminFramework"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Constants = require(Shared:WaitForChild("Constants"))
local Util = require(Shared:WaitForChild("Util"))

local CrossServerService = {}
CrossServerService.__index = CrossServerService

function CrossServerService.new(logService, rankService)
    local self = setmetatable({
        _logService = logService,
        _rankService = rankService,
        _handlers = {},
        _subscriptions = {},
        _running = true,
        _serverMap = nil,
    }, CrossServerService)

    if Config.CrossServer.LiveServerRegistry then
        self._serverMap = MemoryStoreService:GetSortedMap(Config.CrossServer.RegistryName)
    end

    if Config.CrossServer.Enabled then
        self:_subscribeAll()
    end
    self:_startHeartbeat()

    return self
end

function CrossServerService:RegisterHandler(topic: string, callback: (any) -> ())
    self._handlers[topic] = self._handlers[topic] or {}
    table.insert(self._handlers[topic], callback)
end

function CrossServerService:_dispatch(topic: string, data: any)
    for _, callback in self._handlers[topic] or {} do
        task.spawn(function()
            local ok, err = pcall(callback, data)
            if not ok then
                self._logService:Write(Constants.LogCategories.Errors, "CrossServer.HandlerError", nil, {
                    Success = false,
                    Message = tostring(err),
                    Payload = { Topic = topic },
                })
            end
        end)
    end
end

function CrossServerService:_subscribe(topic: string)
    local ok, subscriptionOrError = pcall(function()
        return MessagingService:SubscribeAsync(topic, function(message)
            self:_dispatch(topic, message.Data)
        end)
    end)
    if ok then
        table.insert(self._subscriptions, subscriptionOrError)
    else
        warn(string.format("[Aegis GMS] Could not subscribe to %s: %s", topic, tostring(subscriptionOrError)))
    end
end

function CrossServerService:_subscribeAll()
    self:_subscribe(Constants.Topics.GlobalAnnouncement)
    self:_subscribe(Constants.Topics.StaffBroadcast)
    self:_subscribe(Constants.Topics.BanSync)
    self:_subscribe(Constants.Topics.EmergencyShutdown)
end

function CrossServerService:Publish(topic: string, data: any): (boolean, string?)
    if not Config.CrossServer.Enabled then
        return false, "Cross-server features are disabled"
    end
    local envelope = {
        ProtocolVersion = Constants.ProtocolVersion,
        SourceJobId = game.JobId,
        SentAt = os.time(),
        Data = Util.serializable(data),
    }
    local ok, err = pcall(function()
        MessagingService:PublishAsync(topic, envelope)
    end)
    if not ok then
        return false, tostring(err)
    end
    return true, nil
end

function CrossServerService:_serverKey(): string
    return if game.JobId ~= "" then game.JobId else "studio-" .. tostring(game.PlaceId)
end

function CrossServerService:_writeHeartbeat()
    if not self._serverMap then
        return
    end
    local staffCount = 0
    for _, player in Players:GetPlayers() do
        if self._rankService:GetRole(player) then
            staffCount += 1
        end
    end
    local record = {
        JobId = game.JobId,
        PlaceId = game.PlaceId,
        Players = #Players:GetPlayers(),
        MaxPlayers = Players.MaxPlayers,
        Staff = staffCount,
        UpdatedAt = os.time(),
        PlaceVersion = game.PlaceVersion,
    }
    local ok, err = pcall(function()
        self._serverMap:SetAsync(
            self:_serverKey(),
            record,
            Config.CrossServer.RecordExpirySeconds,
            os.time()
        )
    end)
    if not ok then
        warn("[Aegis GMS] Live server heartbeat failed: " .. tostring(err))
    end
end

function CrossServerService:_startHeartbeat()
    if not Config.CrossServer.LiveServerRegistry then
        return
    end
    task.spawn(function()
        while self._running do
            self:_writeHeartbeat()
            task.wait(Config.CrossServer.HeartbeatSeconds)
        end
    end)
end

function CrossServerService:GetLiveServers(limit: number?): {any}
    if not self._serverMap then
        return {}
    end
    local ok, entries = pcall(function()
        return self._serverMap:GetRangeAsync(Enum.SortDirection.Descending, math.clamp(limit or 50, 1, 100))
    end)
    if not ok then
        return {}
    end
    local servers = {}
    for _, entry in entries do
        table.insert(servers, entry.value)
    end
    return servers
end

function CrossServerService:Destroy()
    self._running = false
    for _, subscription in self._subscriptions do
        pcall(function()
            subscription:Disconnect()
        end)
    end
end

return CrossServerService
