--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("AdminFramework"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Constants = require(Shared:WaitForChild("Constants"))
local Util = require(Shared:WaitForChild("Util"))

local LogService = {}
LogService.__index = LogService

function LogService.new(dataStoreManager)
    local self = setmetatable({
        _dataStores = dataStoreManager,
        _entries = {},
        _pending = {},
        _running = true,
    }, LogService)

    task.spawn(function()
        while self._running do
            task.wait(Config.Persistence.LogFlushSeconds)
            self:Flush()
        end
    end)

    game:BindToClose(function()
        self._running = false
        self:Flush()
    end)

    return self
end

function LogService:Write(category: string, action: string, actor: Player?, options: {[string]: any}?)
    options = options or {}
    local actorUserId = if actor then actor.UserId else (options.ActorUserId or 0)
    local actorName = if actor then actor.Name else (options.ActorName or "System")
    local entry = {
        Id = Util.guid(),
        Timestamp = os.time(),
        IsoTime = Util.isoTimestamp(),
        Category = category,
        Action = action,
        Success = if options.Success == nil then true else options.Success,
        ActorUserId = actorUserId,
        ActorName = actorName,
        TargetUserId = options.TargetUserId,
        TargetName = options.TargetName,
        Message = Util.clampString(options.Message, 500, action),
        Payload = if Config.Logging.IncludePayloads then Util.serializable(options.Payload) else nil,
        ServerJobId = game.JobId,
        PlaceId = game.PlaceId,
    }

    table.insert(self._entries, 1, entry)
    while #self._entries > Config.Logging.MemoryLimit do
        table.remove(self._entries)
    end

    if Config.Logging.Persist then
        table.insert(self._pending, entry)
    end
    return entry
end

function LogService:GetRecent(limit: number?, category: string?, targetUserId: number?): {any}
    local result = {}
    limit = math.clamp(math.floor(limit or 30), 1, Constants.MaxLogsReturned)
    for _, entry in self._entries do
        if (not category or entry.Category == category)
            and (not targetUserId or entry.TargetUserId == targetUserId or entry.ActorUserId == targetUserId) then
            table.insert(result, Util.deepCopy(entry))
            if #result >= limit then
                break
            end
        end
    end
    return result
end

function LogService:Flush()
    if #self._pending == 0 or not Config.Logging.Persist then
        return
    end

    local batch = self._pending
    self._pending = {}
    local day = os.date("!%Y%m%d")
    local jobKey = if game.JobId ~= "" then string.sub(game.JobId, 1, 20) else "studio"
    local key = string.format("%s:%s", day, jobKey)

    local ok, result = self._dataStores:Update("Logs", key, function(existing)
        existing = if typeof(existing) == "table" then existing else {}
        for _, entry in batch do
            table.insert(existing, entry)
        end
        while #existing > Config.Logging.PersistedBucketLimit do
            table.remove(existing, 1)
        end
        return existing
    end, {})

    if not ok then
        warn("[Aegis GMS] Log flush failed: " .. tostring(result))
        for _, entry in batch do
            table.insert(self._pending, entry)
        end
    end
end

return LogService
