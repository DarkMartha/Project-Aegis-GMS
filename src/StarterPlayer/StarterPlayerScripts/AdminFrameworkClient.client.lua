--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local FrameworkRoot = ReplicatedStorage:WaitForChild("AdminFramework")
local Shared = FrameworkRoot:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Constants = require(Shared:WaitForChild("Constants"))
local UIController = require(FrameworkRoot:WaitForChild("Client"):WaitForChild("UIController"))

local Remotes = FrameworkRoot:WaitForChild(Constants.RemoteFolderName)
local RequestRemote = Remotes:WaitForChild(Constants.RequestRemoteName) :: RemoteFunction
local PushRemote = Remotes:WaitForChild(Constants.PushRemoteName) :: RemoteEvent

local effectState = {
    Flying = false,
    Noclip = false,
    SpectatingUserId = nil,
    NoclipOriginal = {},
}

local function localHumanoid(): Humanoid?
    local character = LocalPlayer.Character
    return character and character:FindFirstChildOfClass("Humanoid") or nil
end

local function localRoot(): BasePart?
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return if root and root:IsA("BasePart") then root else nil
end

local function stopSpectating()
    effectState.SpectatingUserId = nil
    local camera = workspace.CurrentCamera
    local humanoid = localHumanoid()
    if camera and humanoid then
        camera.CameraType = Enum.CameraType.Custom
        camera.CameraSubject = humanoid
    end
end

local function toggleSpectate(targetUserId: number)
    if effectState.SpectatingUserId == targetUserId then
        stopSpectating()
        return
    end
    local target = Players:GetPlayerByUserId(targetUserId)
    local humanoid = target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")
    local camera = workspace.CurrentCamera
    if target and humanoid and camera then
        effectState.SpectatingUserId = targetUserId
        camera.CameraType = Enum.CameraType.Custom
        camera.CameraSubject = humanoid
    end
end

local function setFly(enabled: boolean)
    effectState.Flying = enabled
    local humanoid = localHumanoid()
    local root = localRoot()
    if humanoid then
        humanoid.PlatformStand = enabled
    end
    if root and not enabled then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
end

local function setNoclip(enabled: boolean)
    effectState.Noclip = enabled
    if not enabled then
        for part, original in effectState.NoclipOriginal do
            if part and part.Parent then
                part.CanCollide = original
            end
        end
        table.clear(effectState.NoclipOriginal)
    end
end

PushRemote.OnClientEvent:Connect(function(payload)
    if typeof(payload) ~= "table" or payload.Type ~= "Effect" then
        return
    end
    if payload.Effect == "Spectate" then
        local userId = tonumber(payload.TargetUserId)
        if userId then toggleSpectate(userId) end
    elseif payload.Effect == "ToggleFly" then
        setFly(not effectState.Flying)
    elseif payload.Effect == "ToggleNoclip" then
        setNoclip(not effectState.Noclip)
    end
end)

RunService.RenderStepped:Connect(function()
    if effectState.Flying then
        local root = localRoot()
        local humanoid = localHumanoid()
        local camera = workspace.CurrentCamera
        if root and humanoid and camera then
            humanoid.PlatformStand = true
            local direction = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction += camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction -= camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction -= camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction += camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direction += Vector3.yAxis end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then direction -= Vector3.yAxis end
            if direction.Magnitude > 0 then direction = direction.Unit end
            root.AssemblyLinearVelocity = direction * 70
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end

    if effectState.Noclip then
        local character = LocalPlayer.Character
        if character then
            for _, descendant in character:GetDescendants() do
                if descendant:IsA("BasePart") then
                    if effectState.NoclipOriginal[descendant] == nil then
                        effectState.NoclipOriginal[descendant] = descendant.CanCollide
                    end
                    descendant.CanCollide = false
                end
            end
        end
    end

    if effectState.SpectatingUserId then
        local target = Players:GetPlayerByUserId(effectState.SpectatingUserId)
        if not target or not target.Character or not target.Character:FindFirstChildOfClass("Humanoid") then
            stopSpectating()
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.25)
    if effectState.Flying then setFly(true) end
    if not effectState.Noclip then table.clear(effectState.NoclipOriginal) end
    if effectState.SpectatingUserId then stopSpectating() end
end)

local controller = UIController.new(RequestRemote, PushRemote, Config, Constants)
controller:Start()
