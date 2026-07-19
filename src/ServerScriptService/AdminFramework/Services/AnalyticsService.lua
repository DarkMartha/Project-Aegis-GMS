--!strict

local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("AdminFramework"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local AnalyticsService = {}
AnalyticsService.__index = AnalyticsService

function AnalyticsService.new(dataStoreManager)
    local self = setmetatable({
        _dataStores = dataStoreManager,
        _startedAt = os.time(),
        _joins = 0,
        _leaves = 0,
        _actions = 0,
        _punishments = 0,
        _staffActions = {},
        _running = true,
    }, AnalyticsService)

    task.spawn(function()
        while self._running do
            task.wait(Config.Persistence.AnalyticsFlushSeconds)
            self:Flush()
        end
    end)

    game:BindToClose(function()
        self._running = false
        self:Flush()
    end)

    return self
end

function AnalyticsService:RecordJoin(_player: Player)
    self._joins += 1
end

function AnalyticsService:RecordLeave(_player: Player)
    self._leaves += 1
end

function AnalyticsService:RecordAction(actor: Player?, category: string)
    self._actions += 1
    if category == "Moderation" then
        self._punishments += 1
    end
    if actor then
        self._staffActions[actor.UserId] = (self._staffActions[actor.UserId] or 0) + 1
    end
end

function AnalyticsService:GetSnapshot(): {[string]: any}
    local memoryMb = 0
    local ok, value = pcall(function()
        return Stats:GetTotalMemoryUsageMb()
    end)
    if ok then
        memoryMb = value
    end

    return {
        PlayersOnline = #Players:GetPlayers(),
        JoinsThisServer = self._joins,
        LeavesThisServer = self._leaves,
        ActionsThisServer = self._actions,
        PunishmentsThisServer = self._punishments,
        UptimeSeconds = os.time() - self._startedAt,
        MemoryMb = math.floor(memoryMb * 10) / 10,
        PlaceVersion = game.PlaceVersion,
        JobId = game.JobId,
        StaffActions = self._staffActions,
    }
end

function AnalyticsService:Flush()
    local key = os.date("!%Y%m%d")
    local snapshot = self:GetSnapshot()
    self._dataStores:Update("Analytics", key, function(existing)
        existing = if typeof(existing) == "table" then existing else {
            Joins = 0,
            Leaves = 0,
            Actions = 0,
            Punishments = 0,
            PeakPlayers = 0,
            Samples = 0,
        }
        existing.Joins = (existing.Joins or 0) + self._joins
        existing.Leaves = (existing.Leaves or 0) + self._leaves
        existing.Actions = (existing.Actions or 0) + self._actions
        existing.Punishments = (existing.Punishments or 0) + self._punishments
        existing.PeakPlayers = math.max(existing.PeakPlayers or 0, snapshot.PlayersOnline)
        existing.Samples = (existing.Samples or 0) + 1
        existing.LastUpdated = os.time()
        return existing
    end, {})

    self._joins = 0
    self._leaves = 0
    self._actions = 0
    self._punishments = 0
end

return AnalyticsService
