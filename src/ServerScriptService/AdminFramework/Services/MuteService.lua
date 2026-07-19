--!strict

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("AdminFramework"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local MuteService = {}
MuteService.__index = MuteService

function MuteService.new(dataStoreManager)
    local self = setmetatable({
        _dataStores = dataStoreManager,
        _cache = {},
        _boundChannels = {},
    }, MuteService)

    task.spawn(function()
        self:_bindTextChannels()
    end)
    return self
end

function MuteService:_load(userId: number)
    if self._cache[userId] ~= nil then
        return self._cache[userId]
    end
    local record = self._dataStores:Get("Mutes", tostring(userId), false)
    if typeof(record) == "table" and record.Active and record.ExpiresAt and os.time() >= record.ExpiresAt then
        record.Active = false
        record.ExpiredAt = os.time()
        self._dataStores:Set("Mutes", tostring(userId), record)
    end
    self._cache[userId] = record
    return record
end

function MuteService:IsMuted(userId: number): boolean
    local record = self:_load(userId)
    return typeof(record) == "table" and record.Active == true
end

function MuteService:Mute(actor: Player, userId: number, reason: string, durationMinutes: number): (boolean, string)
    durationMinutes = math.clamp(math.floor(durationMinutes), 1, 60 * 24 * 30)
    local record = {
        Active = true,
        UserId = userId,
        Reason = Util.clampString(reason, 300, Config.Moderation.DefaultReason),
        CreatedAt = os.time(),
        CreatedBy = actor.UserId,
        ExpiresAt = os.time() + durationMinutes * 60,
    }
    local ok, err = self._dataStores:Set("Mutes", tostring(userId), record)
    if not ok then
        return false, "Could not save mute: " .. tostring(err)
    end
    self._cache[userId] = record
    local target = Players:GetPlayerByUserId(userId)
    if target then
        target:SetAttribute("AegisMuted", true)
    end
    return true, string.format("Muted %s for %d minutes", Util.safeUserName(userId), durationMinutes)
end

function MuteService:Unmute(actor: Player, userId: number): (boolean, string)
    local record = self:_load(userId)
    if typeof(record) ~= "table" then
        record = { UserId = userId }
    end
    record.Active = false
    record.RevokedAt = os.time()
    record.RevokedBy = actor.UserId
    local ok, err = self._dataStores:Set("Mutes", tostring(userId), record)
    if not ok then
        return false, "Could not revoke mute: " .. tostring(err)
    end
    self._cache[userId] = record
    local target = Players:GetPlayerByUserId(userId)
    if target then
        target:SetAttribute("AegisMuted", false)
    end
    return true, "Unmuted " .. Util.safeUserName(userId)
end

function MuteService:ApplyPlayerState(player: Player)
    player:SetAttribute("AegisMuted", self:IsMuted(player.UserId))
end

function MuteService:_bindChannel(channel: Instance)
    if not channel:IsA("TextChannel") or self._boundChannels[channel] then
        return
    end
    self._boundChannels[channel] = true

    local previous = channel.ShouldDeliverCallback
    channel.ShouldDeliverCallback = function(message: TextChatMessage, targetTextSource: TextSource)
        if previous then
            local ok, allowed = pcall(previous, message, targetTextSource)
            if ok and allowed == false then
                return false
            end
        end
        local source = message.TextSource
        if source and self:IsMuted(source.UserId) and targetTextSource.UserId ~= source.UserId then
            return false
        end
        return true
    end
end

function MuteService:_bindTextChannels()
    local channels = TextChatService:WaitForChild("TextChannels", 20)
    if not channels then
        warn("[Aegis GMS] TextChannels was not available; chat mute delivery filter was not bound.")
        return
    end
    for _, channel in channels:GetChildren() do
        self:_bindChannel(channel)
    end
    channels.ChildAdded:Connect(function(channel)
        self:_bindChannel(channel)
    end)
end

return MuteService
