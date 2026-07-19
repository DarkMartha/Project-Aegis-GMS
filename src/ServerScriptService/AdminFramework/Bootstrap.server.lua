--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FrameworkRoot = ReplicatedStorage:WaitForChild("AdminFramework")
local Shared = FrameworkRoot:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Constants = require(Shared:WaitForChild("Constants"))
local Permissions = require(Shared:WaitForChild("Permissions"))
local Util = require(Shared:WaitForChild("Util"))

local Root = script.Parent
local Core = Root:WaitForChild("Core")
local Services = Root:WaitForChild("Services")
local Modules = Root:WaitForChild("Modules")

local DataStoreManager = require(Services:WaitForChild("DataStoreManager"))
local SecurityService = require(Services:WaitForChild("SecurityService"))
local RankService = require(Services:WaitForChild("RankService"))
local LogService = require(Services:WaitForChild("LogService"))
local AnalyticsService = require(Services:WaitForChild("AnalyticsService"))
local CrossServerService = require(Services:WaitForChild("CrossServerService"))
local BanService = require(Services:WaitForChild("BanService"))
local MuteService = require(Services:WaitForChild("MuteService"))
local ActionService = require(Core:WaitForChild("ActionService"))
local ModuleLoader = require(Core:WaitForChild("ModuleLoader"))

local remotes = FrameworkRoot:FindFirstChild(Constants.RemoteFolderName)
if not remotes then
    remotes = Instance.new("Folder")
    remotes.Name = Constants.RemoteFolderName
    remotes.Parent = FrameworkRoot
end

local requestRemote = remotes:FindFirstChild(Constants.RequestRemoteName)
if not requestRemote then
    requestRemote = Instance.new("RemoteFunction")
    requestRemote.Name = Constants.RequestRemoteName
    requestRemote.Parent = remotes
end
assert(requestRemote:IsA("RemoteFunction"), "Aegis Request remote has the wrong class")

local pushRemote = remotes:FindFirstChild(Constants.PushRemoteName)
if not pushRemote then
    pushRemote = Instance.new("RemoteEvent")
    pushRemote.Name = Constants.PushRemoteName
    pushRemote.Parent = remotes
end
assert(pushRemote:IsA("RemoteEvent"), "Aegis Push remote has the wrong class")

local dataStores = DataStoreManager.new()
local security = SecurityService.new()
local rankService = RankService.new(dataStores)
local logService = LogService.new(dataStores)
local analyticsService = AnalyticsService.new(dataStores)
local banService = BanService.new(dataStores, logService)
local muteService = MuteService.new(dataStores)

local savedModules = dataStores:Get("Settings", "modules", {})
local savedSettings = dataStores:Get("Settings", "runtime", {})
local runtimeSettings = {
    Modules = if typeof(savedModules) == "table" then savedModules else {},
    Settings = {
        PanelTitle = Config.Panel.Title,
        SoundsEnabled = true,
        CompactMode = false,
        AnnouncementsEnabled = true,
    },
    Server = {
        Locked = false,
        LockReason = nil,
        LockedBy = nil,
    },
}
if typeof(savedSettings) == "table" then
    for key, value in savedSettings do
        runtimeSettings.Settings[key] = value
    end
end

local crossServer = CrossServerService.new(logService, rankService)
banService:SetCrossServer(crossServer)

local context = {
    Config = Config,
    Constants = Constants,
    Permissions = Permissions,
    Util = Util,
    DataStoreManager = dataStores,
    SecurityService = security,
    RankService = rankService,
    LogService = logService,
    AnalyticsService = analyticsService,
    CrossServerService = crossServer,
    BanService = banService,
    MuteService = muteService,
    RequestRemote = requestRemote,
    PushRemote = pushRemote,
    RuntimeSettings = runtimeSettings,
}

local actionService = ActionService.new(context)
context.ActionService = actionService
local loadedModules = ModuleLoader.Load(Modules, actionService)

local function unpackEnvelope(envelope: any): any
    if typeof(envelope) == "table" and envelope.Data ~= nil then
        return envelope.Data
    end
    return envelope
end

crossServer:RegisterHandler(Constants.Topics.GlobalAnnouncement, function(envelope)
    local payload = unpackEnvelope(envelope)
    if typeof(payload) ~= "table" then return end
    pushRemote:FireAllClients({
        Type = "Announcement",
        Title = payload.Title or "Global Announcement",
        Message = payload.Message or "",
        Level = payload.Level or "Global",
        From = payload.From,
    })
end)

crossServer:RegisterHandler(Constants.Topics.StaffBroadcast, function(envelope)
    if typeof(envelope) == "table" and envelope.SourceJobId == game.JobId then return end
    local payload = unpackEnvelope(envelope)
    if typeof(payload) ~= "table" then return end
    for _, player in Players:GetPlayers() do
        if rankService:GetRole(player) then
            pushRemote:FireClient(player, {
                Type = "Notification",
                Title = payload.Title or "Staff Broadcast",
                Message = payload.Message or "",
                Level = "Staff",
                From = payload.From,
            })
        end
    end
end)

crossServer:RegisterHandler(Constants.Topics.EmergencyShutdown, function(envelope)
    local payload = unpackEnvelope(envelope)
    if typeof(payload) ~= "table" then return end
    local reason = tostring(payload.Reason or "Emergency shutdown")
    pushRemote:FireAllClients({ Type = "Announcement", Title = "Emergency Shutdown", Message = reason, Level = "Danger" })
    task.wait(1)
    for _, player in Players:GetPlayers() do
        player:Kick(reason)
    end
end)

local function playerSummary(player: Player)
    local role = rankService:GetRole(player)
    local _, humanoid = Util.getCharacterParts(player)
    return {
        UserId = player.UserId,
        Name = player.Name,
        DisplayName = player.DisplayName,
        Role = role,
        Team = if player.Team then player.Team.Name else "None",
        Health = if humanoid then math.floor(humanoid.Health) else 0,
        MaxHealth = if humanoid then math.floor(humanoid.MaxHealth) else 0,
        AccountAge = player.AccountAge,
        Muted = player:GetAttribute("AegisMuted") == true,
        Frozen = player:GetAttribute("AegisFrozen") == true,
        Jailed = player:GetAttribute("AegisJailed") == true,
    }
end

local function buildSnapshot(player: Player)
    local role = rankService:GetRole(player)
    local permissions = rankService:GetPermissionMap(player)
    local players = {}
    if permissions["Players.View"] then
        for _, current in Players:GetPlayers() do
            table.insert(players, playerSummary(current))
        end
        table.sort(players, function(a, b)
            return string.lower(a.Name) < string.lower(b.Name)
        end)
    end

    local snapshot = {
        Framework = {
            Name = Constants.FrameworkName,
            Version = Constants.Version,
            ProtocolVersion = Constants.ProtocolVersion,
        },
        User = {
            UserId = player.UserId,
            Name = player.Name,
            DisplayName = player.DisplayName,
            Role = role,
            Permissions = permissions,
        },
        Players = players,
        Analytics = analyticsService:GetSnapshot(),
        Server = {
            Locked = runtimeSettings.Server.Locked,
            LockReason = runtimeSettings.Server.LockReason,
            Gravity = workspace.Gravity,
            Weather = workspace:GetAttribute("AegisWeather") or "Clear",
        },
        Settings = runtimeSettings.Settings,
        RankOrder = Permissions.RankOrder,
        Modules = if permissions["Modules.View"] then actionService:GetModuleStates() else {},
        Staff = if permissions["Staff.View"] then rankService:GetStaffDirectory() else {},
        Logs = if permissions["Logs.View"] then logService:GetRecent(40, nil, nil) else {},
        LoadedModules = loadedModules,
    }
    return Util.serializable(snapshot)
end

requestRemote.OnServerInvoke = function(player: Player, envelope: any)
    local valid, reason = security:ValidateEnvelope(player, envelope)
    if not valid then
        return { Success = false, Message = reason }
    end

    local kind = envelope.kind
    if kind == "ping" then
        return { Success = true, Message = "pong", ServerTime = os.time(), Version = Constants.Version }
    end

    if not rankService:HasPermission(player, "Panel.Access") then
        return { Success = false, Message = "You do not have access to the admin panel" }
    end

    if kind == "snapshot" then
        local allowed, rateReason = security:CheckRateLimit(player, "__snapshot")
        if not allowed then return { Success = false, Message = rateReason } end
        return { Success = true, Message = "Snapshot loaded", Data = buildSnapshot(player) }
    elseif kind == "action" then
        if typeof(envelope.action) ~= "string" then
            security:AddStrike(player, "Action request missing action name")
            return { Success = false, Message = "Missing action name" }
        end
        return actionService:Execute(player, envelope.action, envelope.payload)
    end

    security:AddStrike(player, "Unknown request kind: " .. tostring(kind))
    return { Success = false, Message = "Unknown request kind" }
end

local function onCharacter(player: Player, character: Model)
    task.defer(function()
        local root = character:WaitForChild("HumanoidRootPart", 10)
        if not root or not root:IsA("BasePart") then return end
        if player:GetAttribute("AegisFrozen") == true then
            root.Anchored = true
        end
        if player:GetAttribute("AegisJailed") == true then
            root.CFrame = CFrame.new(Config.Moderation.JailPosition)
            root.Anchored = true
        end
    end)
end

local function onPlayerAdded(player: Player)
    player:SetAttribute("AegisJoinedAt", os.time())
    player:SetAttribute("AegisFrozen", false)
    player:SetAttribute("AegisJailed", false)
    analyticsService:RecordJoin(player)

    if banService:EnforceJoin(player) then
        return
    end
    muteService:ApplyPlayerState(player)

    if runtimeSettings.Server.Locked and not rankService:HasPermission(player, "Panel.Access") then
        player:Kick(runtimeSettings.Server.LockReason or "This server is currently locked")
        return
    end

    player.CharacterAdded:Connect(function(character)
        onCharacter(player, character)
    end)
    if player.Character then
        onCharacter(player, player.Character)
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
    analyticsService:RecordLeave(player)
    security:CleanupPlayer(player)
end)

for _, player in Players:GetPlayers() do
    task.spawn(onPlayerAdded, player)
end

logService:Write(Constants.LogCategories.Server, "Framework.Started", nil, {
    Message = string.format("%s v%s started with %d modules", Constants.FrameworkName, Constants.Version, #loadedModules),
    Payload = { Modules = loadedModules },
})

print(string.format("[%s] v%s loaded successfully (%d modules)", Constants.FrameworkName, Constants.Version, #loadedModules))
