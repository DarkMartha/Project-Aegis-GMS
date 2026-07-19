--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("AdminFramework"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Permissions = require(Shared:WaitForChild("Permissions"))
local Util = require(Shared:WaitForChild("Util"))

local RankService = {}
RankService.__index = RankService

local EMPTY_RECORD = {
    CustomRank = nil,
    TemporaryRank = nil,
    TemporaryRankExpiresAt = nil,
    Overrides = { Allow = {}, Deny = {} },
    Notes = {},
    UpdatedAt = nil,
    UpdatedBy = nil,
}

function RankService.new(dataStoreManager)
    return setmetatable({
        _dataStores = dataStoreManager,
        _cache = {},
    }, RankService)
end

function RankService:IsOwnerUserId(userId: number): boolean
    if game.CreatorType == Enum.CreatorType.User and game.CreatorId == userId then
        return true
    end
    for _, ownerId in Config.Owners do
        if ownerId == userId then
            return true
        end
    end
    return false
end

function RankService:_loadRecord(userId: number)
    if self._cache[userId] then
        return self._cache[userId]
    end

    local record = self._dataStores:Get("Staff", tostring(userId), EMPTY_RECORD)
    if typeof(record) ~= "table" then
        record = Util.deepCopy(EMPTY_RECORD)
    end
    record.Overrides = record.Overrides or { Allow = {}, Deny = {} }
    record.Overrides.Allow = record.Overrides.Allow or {}
    record.Overrides.Deny = record.Overrides.Deny or {}
    record.Notes = record.Notes or {}

    if record.TemporaryRankExpiresAt and os.time() >= record.TemporaryRankExpiresAt then
        record.TemporaryRank = nil
        record.TemporaryRankExpiresAt = nil
        self._dataStores:Set("Staff", tostring(userId), record)
    end

    self._cache[userId] = record
    return record
end

function RankService:RefreshUser(userId: number)
    self._cache[userId] = nil
    return self:_loadRecord(userId)
end

function RankService:_groupRole(player: Player): string?
    if not Config.Group.Enabled or Config.Group.Id <= 0 then
        return nil
    end

    local ok, rankNumber = pcall(function()
        return player:GetRankInGroup(Config.Group.Id)
    end)
    if not ok then
        return nil
    end

    local bestRole = nil
    local bestMinimum = -1
    for _, mapping in Config.Group.RankMap do
        if rankNumber >= mapping.MinimumRank and mapping.MinimumRank > bestMinimum and Permissions.isValidRank(mapping.Role) then
            bestRole = mapping.Role
            bestMinimum = mapping.MinimumRank
        end
    end
    return bestRole
end

function RankService:GetRole(playerOrUserId: Player | number): (string?, {[string]: any})
    local player: Player? = nil
    local userId: number
    if typeof(playerOrUserId) == "Instance" then
        player = playerOrUserId :: Player
        userId = player.UserId
    else
        userId = playerOrUserId :: number
        player = Players:GetPlayerByUserId(userId)
    end

    if self:IsOwnerUserId(userId) then
        return "Owner", self:_loadRecord(userId)
    end

    local record = self:_loadRecord(userId)
    local candidates = {}
    if record.CustomRank and Permissions.isValidRank(record.CustomRank) then
        table.insert(candidates, record.CustomRank)
    end
    if record.TemporaryRank and record.TemporaryRankExpiresAt and os.time() < record.TemporaryRankExpiresAt and Permissions.isValidRank(record.TemporaryRank) then
        table.insert(candidates, record.TemporaryRank)
    end
    if player then
        local groupRole = self:_groupRole(player)
        if groupRole then
            table.insert(candidates, groupRole)
        end
    end

    local winner = nil
    local winnerIndex = 0
    for _, candidate in candidates do
        local index = Permissions.getRankIndex(candidate)
        if index > winnerIndex then
            winner = candidate
            winnerIndex = index
        end
    end
    return winner, record
end

function RankService:HasPermission(player: Player, requested: string): boolean
    local rankName, record = self:GetRole(player)
    local overrides = record.Overrides or { Allow = {}, Deny = {} }

    for _, denied in overrides.Deny or {} do
        if Permissions.matches(denied, requested) then
            return false
        end
    end
    for _, allowed in overrides.Allow or {} do
        if Permissions.matches(allowed, requested) then
            return true
        end
    end

    for _, grant in Permissions.collectRankGrants(rankName) do
        if Permissions.matches(grant, requested) then
            return true
        end
    end
    return false
end

function RankService:GetPermissionMap(player: Player): {[string]: boolean}
    local result = {}
    for _, permission in Permissions.All do
        result[permission] = self:HasPermission(player, permission)
    end
    return result
end

function RankService:CanManage(actor: Player, targetUserId: number, desiredRank: string?): (boolean, string?)
    if self:IsOwnerUserId(actor.UserId) then
        return true, nil
    end

    local actorRole = self:GetRole(actor)
    local targetRole = self:GetRole(targetUserId)
    local actorIndex = Permissions.getRankIndex(actorRole)
    local targetIndex = Permissions.getRankIndex(targetRole)
    local desiredIndex = Permissions.getRankIndex(desiredRank)

    if actorIndex <= targetIndex then
        return false, "You cannot manage someone at or above your rank"
    end
    if desiredRank and actorIndex <= desiredIndex then
        return false, "You cannot assign a rank at or above your own"
    end
    return true, nil
end

function RankService:SetCustomRank(actor: Player, targetUserId: number, rankName: string?): (boolean, string)
    if rankName ~= nil and not Permissions.isValidRank(rankName) then
        return false, "Unknown rank"
    end

    local canManage, reason = self:CanManage(actor, targetUserId, rankName)
    if not canManage then
        return false, reason or "Not allowed"
    end

    local ok, updated = self._dataStores:Update("Staff", tostring(targetUserId), function(record)
        record = if typeof(record) == "table" then record else Util.deepCopy(EMPTY_RECORD)
        record.CustomRank = rankName
        record.UpdatedAt = os.time()
        record.UpdatedBy = actor.UserId
        record.Overrides = record.Overrides or { Allow = {}, Deny = {} }
        record.Notes = record.Notes or {}
        return record
    end, EMPTY_RECORD)

    if not ok then
        return false, "Could not save staff rank: " .. tostring(updated)
    end
    self._cache[targetUserId] = updated
    return true, if rankName then "Rank set to " .. rankName else "Custom rank removed"
end

function RankService:SetTemporaryRank(actor: Player, targetUserId: number, rankName: string, durationMinutes: number): (boolean, string)
    if not Permissions.isValidRank(rankName) then
        return false, "Unknown rank"
    end
    durationMinutes = math.clamp(math.floor(durationMinutes), 1, 60 * 24 * 30)

    local canManage, reason = self:CanManage(actor, targetUserId, rankName)
    if not canManage then
        return false, reason or "Not allowed"
    end

    local expiresAt = os.time() + durationMinutes * 60
    local ok, updated = self._dataStores:Update("Staff", tostring(targetUserId), function(record)
        record = if typeof(record) == "table" then record else Util.deepCopy(EMPTY_RECORD)
        record.TemporaryRank = rankName
        record.TemporaryRankExpiresAt = expiresAt
        record.UpdatedAt = os.time()
        record.UpdatedBy = actor.UserId
        record.Overrides = record.Overrides or { Allow = {}, Deny = {} }
        record.Notes = record.Notes or {}
        return record
    end, EMPTY_RECORD)

    if not ok then
        return false, "Could not save temporary rank: " .. tostring(updated)
    end
    self._cache[targetUserId] = updated
    return true, string.format("Temporary %s rank set for %d minutes", rankName, durationMinutes)
end

function RankService:SetOverrides(actor: Player, targetUserId: number, allow: {string}, deny: {string}): (boolean, string)
    local canManage, reason = self:CanManage(actor, targetUserId, nil)
    if not canManage then
        return false, reason or "Not allowed"
    end

    local function clean(list)
        local result = {}
        for _, value in list do
            if typeof(value) == "string" and #value <= 80 then
                table.insert(result, value)
            end
        end
        return result
    end

    local ok, updated = self._dataStores:Update("Staff", tostring(targetUserId), function(record)
        record = if typeof(record) == "table" then record else Util.deepCopy(EMPTY_RECORD)
        record.Overrides = { Allow = clean(allow), Deny = clean(deny) }
        record.UpdatedAt = os.time()
        record.UpdatedBy = actor.UserId
        return record
    end, EMPTY_RECORD)

    if not ok then
        return false, "Could not save permission overrides: " .. tostring(updated)
    end
    self._cache[targetUserId] = updated
    return true, "Permission overrides updated"
end

function RankService:GetStaffDirectory(): {any}
    local directory = {}
    for _, player in Players:GetPlayers() do
        local role = self:GetRole(player)
        if role then
            table.insert(directory, {
                UserId = player.UserId,
                Name = player.Name,
                DisplayName = player.DisplayName,
                Role = role,
                Online = true,
            })
        end
    end
    table.sort(directory, function(a, b)
        return Permissions.getRankIndex(a.Role) > Permissions.getRankIndex(b.Role)
    end)
    return directory
end

return RankService
