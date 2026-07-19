--!strict

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("AdminFramework"):WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Util = require(Shared:WaitForChild("Util"))

local function numberPayload(field: string, minimum: number, maximum: number)
    return function(_context, _actor, payload)
        local value = Util.toNumber(payload[field])
        if not value then return false, field .. " must be a number" end
        local normalized = Util.shallowCopy(payload)
        normalized[field] = math.clamp(value, minimum, maximum)
        return true, normalized
    end
end

local function softShutdown(context, actor: Player, reason: string)
    if RunService:IsStudio() then
        return false, "Soft shutdown teleporting cannot be tested inside Studio"
    end
    local players = Players:GetPlayers()
    if #players == 0 then
        return true, "No players needed teleporting"
    end

    local ok, accessCodeOrError = pcall(function()
        return TeleportService:ReserveServer(game.PlaceId)
    end)
    if not ok then
        return false, "Could not reserve replacement server: " .. tostring(accessCodeOrError)
    end

    context.PushRemote:FireAllClients({
        Type = "Announcement",
        Title = "Server Restart",
        Message = reason,
        Level = "Warning",
    })
    task.wait(2)

    local teleportOk, teleportError = pcall(function()
        TeleportService:TeleportToPrivateServer(game.PlaceId, accessCodeOrError, players, nil, {
            AegisSoftShutdown = true,
            RequestedBy = actor.UserId,
        })
    end)
    if not teleportOk then
        return false, "Reserved server created, but teleport failed: " .. tostring(teleportError)
    end
    return true, "Soft shutdown started"
end

return {
    Name = "Server",
    Description = "Server lifecycle, locking, environment controls, and reserved-server operations.",
    Actions = {
        {
            Name = "Server.GetState",
            Permission = "Server.View",
            Category = Constants.LogCategories.Server,
            Execute = function(context)
                return {
                    Success = true,
                    Message = "Server state loaded",
                    Data = {
                        Locked = context.RuntimeSettings.Server.Locked,
                        LockReason = context.RuntimeSettings.Server.LockReason,
                        Gravity = workspace.Gravity,
                        ClockTime = Lighting.ClockTime,
                        Brightness = Lighting.Brightness,
                        FogEnd = Lighting.FogEnd,
                        Weather = workspace:GetAttribute("AegisWeather") or "Clear",
                    },
                }
            end,
        },
        {
            Name = "Server.Lock",
            Permission = "Server.Lock",
            Category = Constants.LogCategories.Server,
            Execute = function(context, actor, payload)
                local reason = Util.clampString(payload.Reason, 300, "Server locked by staff")
                context.RuntimeSettings.Server.Locked = true
                context.RuntimeSettings.Server.LockReason = reason
                context.RuntimeSettings.Server.LockedBy = actor.UserId
                return { Success = true, Message = "Server locked" }
            end,
        },
        {
            Name = "Server.Unlock",
            Permission = "Server.Lock",
            Category = Constants.LogCategories.Server,
            Execute = function(context)
                context.RuntimeSettings.Server.Locked = false
                context.RuntimeSettings.Server.LockReason = nil
                context.RuntimeSettings.Server.LockedBy = nil
                return { Success = true, Message = "Server unlocked" }
            end,
        },
        {
            Name = "Server.Shutdown",
            Permission = "Server.Shutdown",
            Category = Constants.LogCategories.Server,
            Execute = function(context, actor, payload)
                local reason = Util.clampString(payload.Reason, 300, "Server shut down by staff")
                context.PushRemote:FireAllClients({ Type = "Announcement", Title = "Server Shutdown", Message = reason, Level = "Danger" })
                task.delay(1.5, function()
                    for _, player in Players:GetPlayers() do
                        player:Kick(string.format("Server shutdown requested by %s.\n%s", actor.Name, reason))
                    end
                end)
                return { Success = true, Message = "Shutdown initiated" }
            end,
        },
        {
            Name = "Server.SoftShutdown",
            Permission = "Server.SoftShutdown",
            Category = Constants.LogCategories.Server,
            Execute = function(context, actor, payload)
                local success, message = softShutdown(context, actor, Util.clampString(payload.Reason, 300, "Server restarting for maintenance"))
                return { Success = success, Message = message }
            end,
        },
        {
            Name = "Server.EmergencyShutdown",
            Permission = "Server.Shutdown",
            Category = Constants.LogCategories.Server,
            Execute = function(context, actor, payload)
                local reason = Util.clampString(payload.Reason, 300, "Emergency shutdown requested by " .. actor.Name)
                local success, err = context.CrossServerService:Publish(Constants.Topics.EmergencyShutdown, {
                    Reason = reason,
                    RequestedBy = actor.UserId,
                    RequestedByName = actor.Name,
                })
                if not success then return { Success = false, Message = "Emergency publish failed: " .. tostring(err) } end
                return { Success = true, Message = "Emergency shutdown sent to every active server" }
            end,
        },
        {
            Name = "Server.Restart",
            Permission = "Server.SoftShutdown",
            Category = Constants.LogCategories.Server,
            Execute = function(context, actor, payload)
                local success, message = softShutdown(context, actor, Util.clampString(payload.Reason, 300, "Server restarting"))
                return { Success = success, Message = message }
            end,
        },
        {
            Name = "Server.Reserve",
            Permission = "Server.Reserve",
            Category = Constants.LogCategories.Server,
            Execute = function(_context)
                if RunService:IsStudio() then
                    return { Success = false, Message = "ReserveServer is unavailable in Studio" }
                end
                local ok, codeOrError = pcall(function()
                    return TeleportService:ReserveServer(game.PlaceId)
                end)
                if not ok then return { Success = false, Message = tostring(codeOrError) } end
                return { Success = true, Message = "Reserved server created", Data = { AccessCode = codeOrError } }
            end,
        },
        {
            Name = "Server.SetGravity",
            Permission = "Server.Gravity",
            Category = Constants.LogCategories.Server,
            Validate = numberPayload("Value", 0, 1000),
            Execute = function(_context, _actor, payload)
                workspace.Gravity = payload.Value
                return { Success = true, Message = "Gravity set to " .. tostring(payload.Value) }
            end,
        },
        {
            Name = "Server.SetTime",
            Permission = "Server.Time",
            Category = Constants.LogCategories.Server,
            Validate = numberPayload("Value", 0, 24),
            Execute = function(_context, _actor, payload)
                Lighting.ClockTime = payload.Value
                return { Success = true, Message = "Clock time updated" }
            end,
        },
        {
            Name = "Server.SetBrightness",
            Permission = "Server.Lighting",
            Category = Constants.LogCategories.Server,
            Validate = numberPayload("Value", 0, 10),
            Execute = function(_context, _actor, payload)
                Lighting.Brightness = payload.Value
                return { Success = true, Message = "Brightness updated" }
            end,
        },
        {
            Name = "Server.SetFogEnd",
            Permission = "Server.Lighting",
            Category = Constants.LogCategories.Server,
            Validate = numberPayload("Value", 0, 100000),
            Execute = function(_context, _actor, payload)
                Lighting.FogEnd = payload.Value
                return { Success = true, Message = "Fog distance updated" }
            end,
        },
        {
            Name = "Server.SetWeather",
            Permission = "Server.Weather",
            Category = Constants.LogCategories.Server,
            Validate = function(_context, _actor, payload)
                local weather = Util.clampString(payload.Value or payload.Weather, 50, "Clear")
                if weather == "" then return false, "Weather name is required" end
                local normalized = Util.shallowCopy(payload)
                normalized.Value = weather
                return true, normalized
            end,
            Execute = function(context, _actor, payload)
                workspace:SetAttribute("AegisWeather", payload.Value)
                context.PushRemote:FireAllClients({ Type = "Weather", Value = payload.Value })
                return { Success = true, Message = "Weather state set to " .. payload.Value }
            end,
        },
    },
}
