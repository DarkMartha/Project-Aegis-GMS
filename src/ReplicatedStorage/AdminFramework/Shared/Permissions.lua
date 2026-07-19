--!strict

local Permissions = {}

Permissions.All = {
    "Panel.Access",
    "Players.View", "Players.Stats", "Players.Inventory", "Players.Heal", "Players.Kill",
    "Players.Freeze", "Players.Teleport", "Players.Respawn", "Players.Spectate",
    "Players.Fly", "Players.Noclip",
    "Moderation.Kick", "Moderation.Ban", "Moderation.TempBan", "Moderation.Unban",
    "Moderation.Warn", "Moderation.Mute", "Moderation.Jail", "Moderation.Notes",
    "Moderation.Appeals",
    "Server.View", "Server.Lock", "Server.Shutdown", "Server.SoftShutdown",
    "Server.Reserve", "Server.Gravity", "Server.Lighting", "Server.Time", "Server.Weather",
    "Messaging.Notify", "Messaging.Broadcast", "Messaging.StaffChat", "Messaging.Global",
    "Staff.View", "Staff.Promote", "Staff.Demote", "Staff.Remove", "Staff.Activity", "Staff.Notes",
    "Ranks.View", "Ranks.Assign", "Ranks.Temporary", "Ranks.Permissions",
    "Logs.View", "Logs.Errors", "Logs.PlayerHistory",
    "Analytics.View",
    "Settings.View", "Settings.Edit", "Settings.Security",
    "Developer.RemoteMonitor", "Developer.EventViewer", "Developer.DataStoreViewer",
    "Developer.Debug", "Developer.Test",
    "Modules.View", "Modules.Toggle",
}

Permissions.RankOrder = {
    "Tester",
    "Event Host",
    "Helper",
    "Trial Moderator",
    "Moderator",
    "Senior Moderator",
    "Administrator",
    "Head Administrator",
    "Developer",
    "Lead Developer",
    "Owner",
}

Permissions.Ranks = {
    ["Tester"] = {
        Inherits = nil,
        Grants = { "Panel.Access", "Players.View", "Server.View" },
    },
    ["Event Host"] = {
        Inherits = "Tester",
        Grants = { "Messaging.Notify", "Messaging.Broadcast", "Server.Time", "Server.Weather" },
    },
    ["Helper"] = {
        Inherits = "Tester",
        Grants = { "Players.Stats", "Moderation.Warn", "Moderation.Notes", "Staff.View", "Logs.View" },
    },
    ["Trial Moderator"] = {
        Inherits = "Helper",
        Grants = { "Moderation.Kick", "Moderation.Mute", "Moderation.Jail", "Players.Freeze", "Players.Teleport", "Players.Spectate" },
    },
    ["Moderator"] = {
        Inherits = "Trial Moderator",
        Grants = { "Moderation.TempBan", "Players.Heal", "Players.Respawn", "Logs.PlayerHistory" },
    },
    ["Senior Moderator"] = {
        Inherits = "Moderator",
        Grants = { "Moderation.Ban", "Moderation.Unban", "Players.Kill", "Server.Lock", "Staff.Activity", "Staff.Notes" },
    },
    ["Administrator"] = {
        Inherits = "Senior Moderator",
        Grants = { "Players.*", "Moderation.*", "Server.Gravity", "Server.Lighting", "Server.Time", "Server.Weather", "Messaging.StaffChat", "Analytics.View" },
    },
    ["Head Administrator"] = {
        Inherits = "Administrator",
        Grants = { "Server.*", "Messaging.Global", "Staff.Promote", "Staff.Demote", "Staff.Remove", "Ranks.View", "Ranks.Assign", "Ranks.Temporary", "Settings.View", "Modules.View" },
    },
    ["Developer"] = {
        Inherits = "Head Administrator",
        Grants = { "Developer.RemoteMonitor", "Developer.EventViewer", "Developer.Test", "Settings.Edit", "Modules.Toggle" },
    },
    ["Lead Developer"] = {
        Inherits = "Developer",
        Grants = { "Developer.*", "Ranks.Permissions", "Settings.Security" },
    },
    ["Owner"] = {
        Inherits = "Lead Developer",
        Grants = { "*" },
    },
}

function Permissions.matches(grant: string, requested: string): boolean
    if grant == "*" or grant == requested then
        return true
    end
    if string.sub(grant, -2) == ".*" then
        local prefix = string.sub(grant, 1, #grant - 1)
        return string.sub(requested, 1, #prefix) == prefix
    end
    return false
end

function Permissions.getRankIndex(rankName: string?): number
    if not rankName then
        return 0
    end
    for index, name in Permissions.RankOrder do
        if name == rankName then
            return index
        end
    end
    return 0
end

function Permissions.isValidRank(rankName: string?): boolean
    return rankName ~= nil and Permissions.Ranks[rankName] ~= nil
end

function Permissions.collectRankGrants(rankName: string?): {string}
    local grants = {}
    local visited = {}
    local current = rankName
    while current and not visited[current] do
        visited[current] = true
        local definition = Permissions.Ranks[current]
        if not definition then
            break
        end
        for _, permission in definition.Grants do
            table.insert(grants, permission)
        end
        current = definition.Inherits
    end
    return grants
end

return table.freeze(Permissions)
