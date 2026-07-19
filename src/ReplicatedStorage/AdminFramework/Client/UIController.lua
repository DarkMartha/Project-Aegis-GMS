--!strict

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local UIController = {}
UIController.__index = UIController

local function create(className: string, properties: {[string]: any}?, children: {Instance}?): Instance
    local instance = Instance.new(className)
    if properties then
        for property, value in properties do
            (instance :: any)[property] = value
        end
    end
    if children then
        for _, child in children do
            child.Parent = instance
        end
    end
    return instance
end

local function corner(parent: Instance, radius: number?)
    create("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

local function stroke(parent: Instance, color: Color3, transparency: number?)
    create("UIStroke", {
        Color = color,
        Transparency = transparency or 0.55,
        Thickness = 1,
        Parent = parent,
    })
end

local function padding(parent: Instance, amount: number)
    create("UIPadding", {
        PaddingTop = UDim.new(0, amount),
        PaddingBottom = UDim.new(0, amount),
        PaddingLeft = UDim.new(0, amount),
        PaddingRight = UDim.new(0, amount),
        Parent = parent,
    })
end

local function formatDuration(seconds: number): string
    seconds = math.max(0, math.floor(seconds))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    if hours > 0 then
        return string.format("%dh %02dm", hours, minutes)
    end
    return string.format("%dm %02ds", minutes, secs)
end

local function valueText(value: any): string
    if typeof(value) == "boolean" then
        return if value then "Yes" else "No"
    elseif typeof(value) == "number" then
        return tostring(math.floor(value * 10) / 10)
    elseif value == nil then
        return "—"
    end
    return tostring(value)
end

function UIController.new(requestRemote: RemoteFunction, pushRemote: RemoteEvent, Config, Constants)
    local self = setmetatable({
        RequestRemote = requestRemote,
        PushRemote = pushRemote,
        Config = Config,
        Constants = Constants,
        Snapshot = nil,
        ScreenGui = nil,
        Root = nil,
        Content = nil,
        Sidebar = nil,
        PageTitle = nil,
        StatusLabel = nil,
        ToggleButton = nil,
        CurrentPage = "Dashboard",
        SelectedUserId = nil,
        PageButtons = {},
        Renderers = {},
        Connections = {},
        Open = Config.Panel.StartOpen,
        Busy = false,
    }, UIController)
    return self
end

function UIController:_request(envelope: {[string]: any}): {[string]: any}
    local ok, result = pcall(function()
        return self.RequestRemote:InvokeServer(envelope)
    end)
    if not ok then
        return { Success = false, Message = "Server request failed: " .. tostring(result) }
    end
    if typeof(result) ~= "table" then
        return { Success = false, Message = "Server returned an invalid response" }
    end
    return result
end

function UIController:_action(actionName: string, payload: {[string]: any}?, onSuccess: ((any) -> ())?)
    if self.Busy then
        self:Toast("Busy", "The previous action is still being processed.", "Warning")
        return
    end
    self.Busy = true
    self:_setStatus("Running " .. actionName .. "…")
    task.spawn(function()
        local result = self:_request({ kind = "action", action = actionName, payload = payload or {} })
        self.Busy = false
        self:_setStatus(if result.Success then "Ready" else "Action rejected")
        self:Toast(if result.Success then "Completed" else "Action Failed", result.Message or actionName, if result.Success then "Success" else "Danger")
        if result.Success and onSuccess then
            onSuccess(result.Data)
        end
    end)
end

function UIController:_setStatus(text: string)
    if self.StatusLabel then
        self.StatusLabel.Text = text
    end
end

function UIController:Has(permission: string): boolean
    local map = self.Snapshot and self.Snapshot.User and self.Snapshot.User.Permissions
    return map and map[permission] == true or false
end

function UIController:HasPrefix(prefix: string): boolean
    local map = self.Snapshot and self.Snapshot.User and self.Snapshot.User.Permissions
    if not map then return false end
    for permission, granted in map do
        if granted and string.sub(permission, 1, #prefix) == prefix then
            return true
        end
    end
    return false
end

function UIController:_loadSnapshot(showToast: boolean?): boolean
    self:_setStatus("Refreshing…")
    local result = self:_request({ kind = "snapshot" })
    if not result.Success then
        self:_setStatus("Access denied")
        if showToast ~= false then
            self:Toast("Panel Unavailable", result.Message or "Snapshot failed", "Danger")
        end
        return false
    end
    self.Snapshot = result.Data
    self:_setStatus("Ready")
    if showToast then
        self:Toast("Refreshed", "The server snapshot is current.", "Success")
    end
    return true
end

function UIController:_label(parent: Instance, text: string, size: UDim2?, muted: boolean?): TextLabel
    return create("TextLabel", {
        BackgroundTransparency = 1,
        Size = size or UDim2.new(1, 0, 0, 26),
        Text = text,
        TextColor3 = if muted then self.Config.Theme.MutedText else self.Config.Theme.Text,
        TextSize = if muted then 13 else 15,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        Parent = parent,
    }) :: TextLabel
end

function UIController:_button(parent: Instance, text: string, callback: () -> (), styleName: string?, size: UDim2?): TextButton
    local style = styleName or "Default"
    local background = self.Config.Theme.SurfaceAlt
    if style == "Accent" then background = self.Config.Theme.Accent end
    if style == "Danger" then background = self.Config.Theme.Danger end
    if style == "Success" then background = self.Config.Theme.Success end
    if style == "Warning" then background = self.Config.Theme.Warning end

    local button = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = background,
        Size = size or UDim2.new(0, 132, 0, 36),
        Text = text,
        TextColor3 = self.Config.Theme.Text,
        TextSize = 13,
        Font = Enum.Font.GothamSemibold,
        Parent = parent,
    }) :: TextButton
    corner(button, 7)

    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.12), { BackgroundTransparency = 0.14 }):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.12), { BackgroundTransparency = 0 }):Play()
    end)
    button.Activated:Connect(callback)
    return button
end

function UIController:_input(parent: Instance, placeholder: string, default: string?, size: UDim2?): TextBox
    local box = create("TextBox", {
        BackgroundColor3 = self.Config.Theme.SurfaceAlt,
        Size = size or UDim2.new(1, 0, 0, 36),
        PlaceholderText = placeholder,
        PlaceholderColor3 = self.Config.Theme.MutedText,
        Text = default or "",
        TextColor3 = self.Config.Theme.Text,
        TextSize = 13,
        Font = Enum.Font.Gotham,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = parent,
    }) :: TextBox
    padding(box, 10)
    corner(box, 7)
    stroke(box, self.Config.Theme.SurfaceAlt, 0.2)
    return box
end

function UIController:_scroll(parent: Instance, size: UDim2?): ScrollingFrame
    local frame = create("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = size or UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = self.Config.Theme.Accent,
        Parent = parent,
    }) :: ScrollingFrame
    create("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = frame,
    })
    return frame
end

function UIController:_card(parent: Instance, title: string, value: string, subtitle: string?): Frame
    local card = create("Frame", {
        BackgroundColor3 = self.Config.Theme.Surface,
        Size = UDim2.new(0, 190, 0, 94),
        Parent = parent,
    }) :: Frame
    corner(card, 10)
    stroke(card, self.Config.Theme.SurfaceAlt)
    self:_label(card, title, UDim2.new(1, -20, 0, 22), true).Position = UDim2.fromOffset(12, 10)
    local valueLabel = self:_label(card, value, UDim2.new(1, -20, 0, 32), false)
    valueLabel.Position = UDim2.fromOffset(12, 35)
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 22
    if subtitle then
        local sub = self:_label(card, subtitle, UDim2.new(1, -20, 0, 18), true)
        sub.Position = UDim2.fromOffset(12, 69)
        sub.TextSize = 11
    end
    return card
end

function UIController:_section(parent: Instance, title: string, size: UDim2?): Frame
    local frame = create("Frame", {
        BackgroundColor3 = self.Config.Theme.Surface,
        Size = size or UDim2.new(1, 0, 0, 180),
        Parent = parent,
    }) :: Frame
    corner(frame, 10)
    stroke(frame, self.Config.Theme.SurfaceAlt)
    local titleLabel = self:_label(frame, title, UDim2.new(1, -24, 0, 30), false)
    titleLabel.Position = UDim2.fromOffset(12, 8)
    titleLabel.Font = Enum.Font.GothamSemibold
    return frame
end

function UIController:_buttonRow(parent: Instance, y: number?): Frame
    local row = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -24, 0, 38),
        Position = UDim2.fromOffset(12, y or 0),
        Parent = parent,
    }) :: Frame
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = row,
    })
    return row
end

function UIController:_clearContent()
    for _, child in self.Content:GetChildren() do
        child:Destroy()
    end
end

function UIController:_findPlayerSummary(userId: number?): any
    if not userId or not self.Snapshot then return nil end
    for _, player in self.Snapshot.Players or {} do
        if player.UserId == userId then return player end
    end
    return nil
end

function UIController:_targetDefault(): string
    return if self.SelectedUserId then tostring(self.SelectedUserId) else ""
end

function UIController:_renderDashboard()
    local content = self.Content
    local header = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 96), Parent = content })
    create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), Parent = header })
    local analytics = self.Snapshot.Analytics or {}
    self:_card(header, "Players Online", tostring(analytics.PlayersOnline or 0), tostring(analytics.JoinsThisServer or 0) .. " joins")
    self:_card(header, "Staff Online", tostring(#(self.Snapshot.Staff or {})), self.Snapshot.User.Role or "No role")
    self:_card(header, "Server Memory", valueText(analytics.MemoryMb) .. " MB", "Version " .. tostring(analytics.PlaceVersion or 0))
    self:_card(header, "Uptime", formatDuration(analytics.UptimeSeconds or 0), tostring(analytics.ActionsThisServer or 0) .. " actions")

    local body = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -110), Position = UDim2.fromOffset(0, 110), Parent = content })
    local actions = self:_section(body, "Server Health", UDim2.new(0.42, -6, 1, 0))
    local healthText = self:_label(actions,
        string.format("Status: Online\nLocked: %s\nGravity: %s\nWeather: %s\nJob: %s",
            valueText(self.Snapshot.Server.Locked),
            valueText(self.Snapshot.Server.Gravity),
            valueText(self.Snapshot.Server.Weather),
            tostring(analytics.JobId or "Studio")
        ),
        UDim2.new(1, -24, 0, 130), true)
    healthText.Position = UDim2.fromOffset(12, 48)
    healthText.TextYAlignment = Enum.TextYAlignment.Top
    local refreshRow = self:_buttonRow(actions, 184)
    self:_button(refreshRow, "Refresh Snapshot", function()
        if self:_loadSnapshot(true) then self:ShowPage("Dashboard") end
    end, "Accent", UDim2.new(0, 150, 0, 36))

    local logs = self:_section(body, "Recent Actions", UDim2.new(0.58, -6, 1, 0))
    logs.Position = UDim2.new(0.42, 6, 0, 0)
    local list = self:_scroll(logs, UDim2.new(1, -24, 1, -54))
    list.Position = UDim2.fromOffset(12, 44)
    for _, entry in self.Snapshot.Logs or {} do
        local item = create("Frame", { BackgroundColor3 = self.Config.Theme.SurfaceAlt, Size = UDim2.new(1, -4, 0, 54), Parent = list })
        corner(item, 7)
        local title = self:_label(item, tostring(entry.Action), UDim2.new(1, -20, 0, 20), false)
        title.Position = UDim2.fromOffset(10, 7)
        title.Font = Enum.Font.GothamSemibold
        local sub = self:_label(item, string.format("%s • %s", tostring(entry.ActorName), tostring(entry.Message)), UDim2.new(1, -20, 0, 20), true)
        sub.Position = UDim2.fromOffset(10, 29)
        sub.TextSize = 11
    end
end

function UIController:_renderPlayers()
    local content = self.Content
    local left = self:_section(content, "Players", UDim2.new(0.36, -6, 1, 0))
    local search = self:_input(left, "Search name or user ID", "", UDim2.new(1, -24, 0, 36))
    search.Position = UDim2.fromOffset(12, 44)
    local list = self:_scroll(left, UDim2.new(1, -24, 1, -94))
    list.Position = UDim2.fromOffset(12, 86)

    local right = self:_section(content, "Player Inspector", UDim2.new(0.64, -6, 1, 0))
    right.Position = UDim2.new(0.36, 6, 0, 0)
    local details = self:_label(right, "Select a player to inspect them.", UDim2.new(1, -24, 0, 110), true)
    details.Position = UDim2.fromOffset(12, 48)
    details.TextYAlignment = Enum.TextYAlignment.Top

    local actionGrid = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 176), Position = UDim2.fromOffset(12, 164), Parent = right })
    create("UIGridLayout", { CellSize = UDim2.fromOffset(122, 36), CellPadding = UDim2.fromOffset(8, 8), Parent = actionGrid })

    local function selectedPayload()
        return { TargetUserId = self.SelectedUserId }
    end

    local actions = {
        { "Heal", "Players.Heal", "Default" },
        { "Kill", "Players.Kill", "Danger" },
        { "Freeze", "Players.Freeze", "Warning" },
        { "Unfreeze", "Players.Unfreeze", "Default" },
        { "Bring", "Players.Bring", "Default" },
        { "Go To", "Players.Goto", "Default" },
        { "Respawn", "Players.Respawn", "Default" },
        { "Spectate", "Players.Spectate", "Accent" },
        { "Toggle Fly", "Players.Fly", "Accent" },
        { "Toggle Noclip", "Players.Noclip", "Accent" },
    }

    local function updateDetails()
        local player = self:_findPlayerSummary(self.SelectedUserId)
        if not player then
            details.Text = "Select a player to inspect them."
            return
        end
        details.Text = string.format(
            "%s (@%s)\nUser ID: %d • Role: %s\nHealth: %s/%s • Team: %s\nMuted: %s • Frozen: %s • Jailed: %s",
            player.DisplayName,
            player.Name,
            player.UserId,
            player.Role or "Player",
            valueText(player.Health),
            valueText(player.MaxHealth),
            player.Team or "None",
            valueText(player.Muted),
            valueText(player.Frozen),
            valueText(player.Jailed)
        )
    end

    for _, action in actions do
        local labelText, actionName, style = action[1], action[2], action[3]
        if self:Has(actionName == "Players.Unfreeze" and "Players.Freeze" or actionName) then
            self:_button(actionGrid, labelText, function()
                if not self.SelectedUserId then
                    self:Toast("No Player", "Select a player first.", "Warning")
                    return
                end
                self:_action(actionName, selectedPayload(), function()
                    if self:_loadSnapshot(false) then
                        updateDetails()
                    end
                end)
            end, style, UDim2.fromOffset(122, 36))
        end
    end

    local profileBox = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 120), Position = UDim2.fromOffset(12, 356), Parent = right })
    local profileOutput = self:_label(profileBox, "Detailed profile output appears here.", UDim2.new(1, 0, 1, 0), true)
    profileOutput.TextYAlignment = Enum.TextYAlignment.Top
    if self:Has("Players.View") then
        self:_button(right, "Load Detailed Profile", function()
            if not self.SelectedUserId then return end
            self:_action("Players.GetProfile", selectedPayload(), function(data)
                if typeof(data) ~= "table" then return end
                local stats = ""
                for key, value in data.Leaderstats or {} do
                    stats ..= string.format("%s=%s  ", tostring(key), tostring(value))
                end
                profileOutput.Text = string.format("Account age: %s days\nMembership: %s\nJoined this server: %s\nLeaderstats: %s",
                    valueText(data.AccountAge), valueText(data.MembershipType), valueText(data.JoinedAt), if stats == "" then "None" else stats)
            end)
        end, "Default", UDim2.new(0, 180, 0, 36)).Position = UDim2.fromOffset(12, 486)
    end

    local function populate(filter: string)
        for _, child in list:GetChildren() do
            if not child:IsA("UIListLayout") then child:Destroy() end
        end
        filter = string.lower(filter)
        for _, player in self.Snapshot.Players or {} do
            local haystack = string.lower(player.Name .. " " .. player.DisplayName .. " " .. tostring(player.UserId))
            if filter == "" or string.find(haystack, filter, 1, true) then
                local button = self:_button(list, string.format("%s  @%s", player.DisplayName, player.Name), function()
                    self.SelectedUserId = player.UserId
                    updateDetails()
                    populate(search.Text)
                end, if self.SelectedUserId == player.UserId then "Accent" else "Default", UDim2.new(1, -4, 0, 42))
                button.TextXAlignment = Enum.TextXAlignment.Left
                padding(button, 10)
            end
        end
    end
    search:GetPropertyChangedSignal("Text"):Connect(function() populate(search.Text) end)
    populate("")
    updateDetails()
end

function UIController:_renderModeration()
    local content = self.Content
    local form = self:_section(content, "Moderation Console", UDim2.new(0.44, -6, 1, 0))
    local target = self:_input(form, "Target user ID", self:_targetDefault(), UDim2.new(1, -24, 0, 36)); target.Position = UDim2.fromOffset(12, 48)
    local reason = self:_input(form, "Reason", "No reason provided", UDim2.new(1, -24, 0, 36)); reason.Position = UDim2.fromOffset(12, 94)
    local duration = self:_input(form, "Duration in minutes", "60", UDim2.new(1, -24, 0, 36)); duration.Position = UDim2.fromOffset(12, 140)
    local note = self:_input(form, "Staff/player note", "", UDim2.new(1, -24, 0, 72)); note.Position = UDim2.fromOffset(12, 186); note.MultiLine = true; note.TextYAlignment = Enum.TextYAlignment.Top

    local history = self:_section(content, "Player History", UDim2.new(0.56, -6, 1, 0))
    history.Position = UDim2.new(0.44, 6, 0, 0)
    local historyText = self:_label(history, "Load a player's moderation history.", UDim2.new(1, -24, 1, -96), true)
    historyText.Position = UDim2.fromOffset(12, 48)
    historyText.TextYAlignment = Enum.TextYAlignment.Top

    local grid = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 200), Position = UDim2.fromOffset(12, 276), Parent = form })
    create("UIGridLayout", { CellSize = UDim2.new(0.31, 0, 0, 36), CellPadding = UDim2.fromOffset(8, 8), Parent = grid })

    local function payload()
        return {
            TargetUserId = tonumber(target.Text),
            Reason = reason.Text,
            Note = note.Text,
            DurationMinutes = tonumber(duration.Text),
        }
    end

    local actions = {
        { "Kick", "Moderation.Kick", "Danger" }, { "Ban", "Moderation.Ban", "Danger" },
        { "Temp Ban", "Moderation.TempBan", "Warning" }, { "Unban", "Moderation.Unban", "Default" },
        { "Warn", "Moderation.Warn", "Warning" }, { "Mute", "Moderation.Mute", "Warning" },
        { "Unmute", "Moderation.Unmute", "Default" }, { "Jail", "Moderation.Jail", "Danger" },
        { "Unjail", "Moderation.Unjail", "Default" }, { "Add Note", "Moderation.AddNote", "Accent" },
    }
    for _, item in actions do
        local permission = item[2]
        if permission == "Moderation.Unmute" then permission = "Moderation.Mute" end
        if permission == "Moderation.Unjail" then permission = "Moderation.Jail" end
        if permission == "Moderation.AddNote" then permission = "Moderation.Notes" end
        if self:Has(permission) then
            self:_button(grid, item[1], function() self:_action(item[2], payload()) end, item[3], UDim2.new(0.31, 0, 0, 36))
        end
    end

    if self:Has("Logs.PlayerHistory") then
        self:_button(history, "Load History", function()
            self:_action("Moderation.GetHistory", payload(), function(data)
                if typeof(data) ~= "table" then return end
                local lines = {}
                table.insert(lines, "BAN: " .. (data.Ban and (data.Ban.Reason or "Active") or "None active"))
                table.insert(lines, "MUTE: " .. (data.Mute and data.Mute.Active and (data.Mute.Reason or "Active") or "None active"))
                table.insert(lines, "")
                table.insert(lines, "WARNINGS")
                for _, warning in data.Warnings or {} do
                    table.insert(lines, string.format("• %s by %s", warning.Reason or "No reason", warning.CreatedByName or warning.CreatedBy or "Unknown"))
                end
                table.insert(lines, "")
                table.insert(lines, "NOTES")
                for _, entry in data.Notes or {} do
                    table.insert(lines, string.format("• %s by %s", entry.Text or "", entry.CreatedByName or entry.CreatedBy or "Unknown"))
                end
                historyText.Text = table.concat(lines, "\n")
            end)
        end, "Accent", UDim2.new(0, 140, 0, 36)).Position = UDim2.new(0, 12, 1, -48)
    end
end

function UIController:_renderServer()
    local content = self.Content
    local control = self:_section(content, "Server Controls", UDim2.new(0.48, -6, 1, 0))
    local environment = self:_section(content, "Environment", UDim2.new(0.52, -6, 1, 0)); environment.Position = UDim2.new(0.48, 6, 0, 0)

    local reason = self:_input(control, "Reason for lock/restart/shutdown", "Maintenance", UDim2.new(1, -24, 0, 36)); reason.Position = UDim2.fromOffset(12, 48)
    local row1 = self:_buttonRow(control, 98)
    if self:Has("Server.Lock") then
        self:_button(row1, "Lock", function() self:_action("Server.Lock", { Reason = reason.Text }) end, "Warning")
        self:_button(row1, "Unlock", function() self:_action("Server.Unlock", {}) end, "Success")
    end
    local row2 = self:_buttonRow(control, 146)
    if self:Has("Server.SoftShutdown") then
        self:_button(row2, "Soft Restart", function() self:_action("Server.SoftShutdown", { Reason = reason.Text }) end, "Warning")
    end
    if self:Has("Server.Reserve") then
        self:_button(row2, "Reserve Server", function()
            self:_action("Server.Reserve", {}, function(data)
                if data and data.AccessCode then
                    self:Toast("Reserved Code", tostring(data.AccessCode), "Success")
                end
            end)
        end, "Accent")
    end
    if self:Has("Server.Shutdown") then
        local confirmAt = 0
        self:_button(control, "Shutdown This Server", function()
            if os.clock() - confirmAt > 4 then
                confirmAt = os.clock()
                self:Toast("Confirm Shutdown", "Click the shutdown button again within four seconds.", "Warning")
                return
            end
            self:_action("Server.Shutdown", { Reason = reason.Text })
        end, "Danger", UDim2.new(1, -24, 0, 38)).Position = UDim2.fromOffset(12, 204)

        local emergencyConfirmAt = 0
        self:_button(control, "Emergency Shutdown All Servers", function()
            if os.clock() - emergencyConfirmAt > 4 then
                emergencyConfirmAt = os.clock()
                self:Toast("Confirm Global Shutdown", "Click again within four seconds. This affects every active server.", "Danger")
                return
            end
            self:_action("Server.EmergencyShutdown", { Reason = reason.Text })
        end, "Danger", UDim2.new(1, -24, 0, 38)).Position = UDim2.fromOffset(12, 252)
    end

    local gravity = self:_input(environment, "Gravity (0-1000)", tostring(self.Snapshot.Server.Gravity or 196.2), UDim2.new(1, -24, 0, 36)); gravity.Position = UDim2.fromOffset(12, 48)
    local time = self:_input(environment, "Clock time (0-24)", "14", UDim2.new(1, -24, 0, 36)); time.Position = UDim2.fromOffset(12, 94)
    local brightness = self:_input(environment, "Brightness (0-10)", "2", UDim2.new(1, -24, 0, 36)); brightness.Position = UDim2.fromOffset(12, 140)
    local fog = self:_input(environment, "Fog end distance", "100000", UDim2.new(1, -24, 0, 36)); fog.Position = UDim2.fromOffset(12, 186)
    local weather = self:_input(environment, "Weather state", tostring(self.Snapshot.Server.Weather or "Clear"), UDim2.new(1, -24, 0, 36)); weather.Position = UDim2.fromOffset(12, 232)

    local grid = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 90), Position = UDim2.fromOffset(12, 282), Parent = environment })
    create("UIGridLayout", { CellSize = UDim2.new(0.48, 0, 0, 36), CellPadding = UDim2.fromOffset(8, 8), Parent = grid })
    if self:Has("Server.Gravity") then self:_button(grid, "Apply Gravity", function() self:_action("Server.SetGravity", { Value = tonumber(gravity.Text) }) end, "Default") end
    if self:Has("Server.Time") then self:_button(grid, "Apply Time", function() self:_action("Server.SetTime", { Value = tonumber(time.Text) }) end, "Default") end
    if self:Has("Server.Lighting") then
        self:_button(grid, "Apply Brightness", function() self:_action("Server.SetBrightness", { Value = tonumber(brightness.Text) }) end, "Default")
        self:_button(grid, "Apply Fog", function() self:_action("Server.SetFogEnd", { Value = tonumber(fog.Text) }) end, "Default")
    end
    if self:Has("Server.Weather") then self:_button(grid, "Apply Weather", function() self:_action("Server.SetWeather", { Value = weather.Text }) end, "Accent") end
end

function UIController:_renderMessaging()
    local content = self.Content
    local compose = self:_section(content, "Compose Message", UDim2.new(0.58, -6, 1, 0))
    local info = self:_section(content, "Delivery", UDim2.new(0.42, -6, 1, 0)); info.Position = UDim2.new(0.58, 6, 0, 0)

    local target = self:_input(compose, "Target user ID (direct notification only)", self:_targetDefault(), UDim2.new(1, -24, 0, 36)); target.Position = UDim2.fromOffset(12, 48)
    local title = self:_input(compose, "Title", "Server Announcement", UDim2.new(1, -24, 0, 36)); title.Position = UDim2.fromOffset(12, 94)
    local message = self:_input(compose, "Message", "", UDim2.new(1, -24, 0, 140)); message.Position = UDim2.fromOffset(12, 140); message.MultiLine = true; message.TextYAlignment = Enum.TextYAlignment.Top
    local row = self:_buttonRow(compose, 294)
    local function payload() return { TargetUserId = tonumber(target.Text), Title = title.Text, Message = message.Text } end
    if self:Has("Messaging.Notify") then self:_button(row, "Notify Player", function() self:_action("Messaging.Notify", payload()) end, "Default") end
    if self:Has("Messaging.Broadcast") then self:_button(row, "Server Broadcast", function() self:_action("Messaging.Broadcast", payload()) end, "Accent") end
    local row2 = self:_buttonRow(compose, 342)
    if self:Has("Messaging.StaffChat") then self:_button(row2, "Staff Broadcast", function() self:_action("Messaging.StaffBroadcast", payload()) end, "Warning") end
    if self:Has("Messaging.Global") then self:_button(row2, "Global Announcement", function() self:_action("Messaging.GlobalAnnouncement", payload()) end, "Danger") end

    local description = self:_label(info,
        "Direct notifications reach one player.\n\nServer broadcasts reach everyone in this server.\n\nStaff broadcasts travel to staff across active servers.\n\nGlobal announcements travel to every subscribed server.",
        UDim2.new(1, -24, 0, 220), true)
    description.Position = UDim2.fromOffset(12, 52)
    description.TextYAlignment = Enum.TextYAlignment.Top
end

function UIController:_renderStaff()
    local content = self.Content
    local directory = self:_section(content, "Online Staff Directory", UDim2.new(0.48, -6, 1, 0))
    local controls = self:_section(content, "Staff Management", UDim2.new(0.52, -6, 1, 0)); controls.Position = UDim2.new(0.48, 6, 0, 0)
    local list = self:_scroll(directory, UDim2.new(1, -24, 1, -56)); list.Position = UDim2.fromOffset(12, 46)
    for _, staff in self.Snapshot.Staff or {} do
        local item = create("Frame", { BackgroundColor3 = self.Config.Theme.SurfaceAlt, Size = UDim2.new(1, -4, 0, 54), Parent = list }); corner(item, 7)
        local name = self:_label(item, string.format("%s  @%s", staff.DisplayName, staff.Name), UDim2.new(1, -20, 0, 20), false); name.Position = UDim2.fromOffset(10, 7)
        local role = self:_label(item, tostring(staff.Role), UDim2.new(1, -20, 0, 18), true); role.Position = UDim2.fromOffset(10, 30); role.TextSize = 11
    end

    local target = self:_input(controls, "Target user ID", self:_targetDefault(), UDim2.new(1, -24, 0, 36)); target.Position = UDim2.fromOffset(12, 48)
    local rank = self:_input(controls, "Exact rank name", "Moderator", UDim2.new(1, -24, 0, 36)); rank.Position = UDim2.fromOffset(12, 94)
    local duration = self:_input(controls, "Temporary duration in minutes", "60", UDim2.new(1, -24, 0, 36)); duration.Position = UDim2.fromOffset(12, 140)
    local note = self:_input(controls, "Staff note", "", UDim2.new(1, -24, 0, 72)); note.Position = UDim2.fromOffset(12, 186); note.MultiLine = true
    local function payload() return { TargetUserId = tonumber(target.Text), Rank = rank.Text, DurationMinutes = tonumber(duration.Text), Note = note.Text } end
    local row = self:_buttonRow(controls, 272)
    if self:Has("Ranks.Assign") then self:_button(row, "Set Rank", function() self:_action("Staff.SetRank", payload()) end, "Accent") end
    if self:Has("Ranks.Temporary") then self:_button(row, "Temporary Rank", function() self:_action("Staff.SetTemporaryRank", payload()) end, "Warning") end
    local row2 = self:_buttonRow(controls, 320)
    if self:Has("Staff.Remove") then self:_button(row2, "Remove Rank", function() self:_action("Staff.RemoveRank", payload()) end, "Danger") end
    if self:Has("Staff.Notes") then self:_button(row2, "Add Staff Note", function() self:_action("Staff.AddNote", payload()) end, "Default") end
end

function UIController:_renderRanks()
    local content = self.Content
    local hierarchy = self:_section(content, "Rank Hierarchy", UDim2.new(0.42, -6, 1, 0))
    local editor = self:_section(content, "Permission Override Editor", UDim2.new(0.58, -6, 1, 0)); editor.Position = UDim2.new(0.42, 6, 0, 0)
    local list = self:_scroll(hierarchy, UDim2.new(1, -24, 1, -56)); list.Position = UDim2.fromOffset(12, 46)
    for index = #(self.Snapshot.RankOrder or {}), 1, -1 do
        local rankName = self.Snapshot.RankOrder[index]
        local item = create("Frame", { BackgroundColor3 = self.Config.Theme.SurfaceAlt, Size = UDim2.new(1, -4, 0, 42), Parent = list }); corner(item, 7)
        local label = self:_label(item, string.format("%02d  %s", index, rankName), UDim2.new(1, -20, 1, 0), false); label.Position = UDim2.fromOffset(10, 0); label.TextYAlignment = Enum.TextYAlignment.Center
    end

    local target = self:_input(editor, "Target user ID", self:_targetDefault(), UDim2.new(1, -24, 0, 36)); target.Position = UDim2.fromOffset(12, 48)
    local allow = self:_input(editor, "Allow permissions, comma separated", "", UDim2.new(1, -24, 0, 80)); allow.Position = UDim2.fromOffset(12, 94); allow.MultiLine = true
    local deny = self:_input(editor, "Deny permissions, comma separated", "", UDim2.new(1, -24, 0, 80)); deny.Position = UDim2.fromOffset(12, 184); deny.MultiLine = true
    local help = self:_label(editor, "Examples: Players.Heal, Moderation.*\nDeny rules win over allow rules. Server-side validation still applies.", UDim2.new(1, -24, 0, 58), true); help.Position = UDim2.fromOffset(12, 276)

    local function split(text: string)
        local result = {}
        for part in string.gmatch(text, "[^,]+") do
            local cleaned = string.match(part, "^%s*(.-)%s*$")
            if cleaned and cleaned ~= "" then table.insert(result, cleaned) end
        end
        return result
    end
    if self:Has("Ranks.Permissions") then
        self:_button(editor, "Apply Overrides", function()
            self:_action("Staff.SetPermissionOverrides", { TargetUserId = tonumber(target.Text), Allow = split(allow.Text), Deny = split(deny.Text) })
        end, "Accent", UDim2.new(0, 160, 0, 38)).Position = UDim2.fromOffset(12, 348)
    end
end

function UIController:_renderLogs()
    local content = self.Content
    local controls = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), Parent = content })
    local category = self:_input(controls, "Category or All", "All", UDim2.new(0, 220, 0, 36)); category.Position = UDim2.fromOffset(0, 0)
    local target = self:_input(controls, "Filter user ID", "", UDim2.new(0, 180, 0, 36)); target.Position = UDim2.fromOffset(230, 0)
    local listSection = self:_section(content, "Audit Stream", UDim2.new(1, 0, 1, -52)); listSection.Position = UDim2.fromOffset(0, 52)
    local list = self:_scroll(listSection, UDim2.new(1, -24, 1, -56)); list.Position = UDim2.fromOffset(12, 46)

    local function renderEntries(entries)
        for _, child in list:GetChildren() do if not child:IsA("UIListLayout") then child:Destroy() end end
        for _, entry in entries or {} do
            local item = create("Frame", { BackgroundColor3 = self.Config.Theme.SurfaceAlt, Size = UDim2.new(1, -4, 0, 68), Parent = list }); corner(item, 7)
            local title = self:_label(item, string.format("%s  [%s]", tostring(entry.Action), tostring(entry.Category)), UDim2.new(1, -20, 0, 22), false); title.Position = UDim2.fromOffset(10, 7); title.Font = Enum.Font.GothamSemibold
            local detail = self:_label(item, string.format("%s → %s • %s", tostring(entry.ActorName), tostring(entry.TargetName or "Server"), tostring(entry.Message)), UDim2.new(1, -20, 0, 20), true); detail.Position = UDim2.fromOffset(10, 31); detail.TextSize = 11
            local time = self:_label(item, tostring(entry.IsoTime or entry.Timestamp), UDim2.new(1, -20, 0, 16), true); time.Position = UDim2.fromOffset(10, 50); time.TextSize = 10
        end
    end

    renderEntries(self.Snapshot.Logs)
    self:_button(controls, "Refresh Logs", function()
        self:_action("Logs.GetRecent", { Category = category.Text, TargetUserId = tonumber(target.Text), Limit = 100 }, renderEntries)
    end, "Accent", UDim2.new(0, 140, 0, 36)).Position = UDim2.fromOffset(420, 0)
    if self:Has("Logs.Errors") then
        self:_button(controls, "Errors Only", function() self:_action("Logs.GetErrors", {}, renderEntries) end, "Danger", UDim2.new(0, 120, 0, 36)).Position = UDim2.fromOffset(570, 0)
    end
end

function UIController:_renderAnalytics()
    local content = self.Content
    local cards = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 96), Parent = content })
    create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), Parent = cards })
    local analytics = self.Snapshot.Analytics or {}
    self:_card(cards, "Joins", tostring(analytics.JoinsThisServer or 0), "this server")
    self:_card(cards, "Leaves", tostring(analytics.LeavesThisServer or 0), "this server")
    self:_card(cards, "Actions", tostring(analytics.ActionsThisServer or 0), "staff actions")
    self:_card(cards, "Punishments", tostring(analytics.PunishmentsThisServer or 0), "moderation")

    local section = self:_section(content, "Live Server Fleet", UDim2.new(1, 0, 1, -110)); section.Position = UDim2.fromOffset(0, 110)
    local list = self:_scroll(section, UDim2.new(1, -24, 1, -98)); list.Position = UDim2.fromOffset(12, 46)
    local function render(data)
        if not data then data = analytics end
        for _, child in list:GetChildren() do if not child:IsA("UIListLayout") then child:Destroy() end end
        local servers = data.LiveServers or {}
        if #servers == 0 then
            self:_label(list, "No live-server registry records are currently available.", UDim2.new(1, -4, 0, 36), true)
        end
        for _, server in servers do
            local item = create("Frame", { BackgroundColor3 = self.Config.Theme.SurfaceAlt, Size = UDim2.new(1, -4, 0, 54), Parent = list }); corner(item, 7)
            local title = self:_label(item, string.format("Place %s • %s/%s players", tostring(server.PlaceId), tostring(server.Players), tostring(server.MaxPlayers)), UDim2.new(1, -20, 0, 20), false); title.Position = UDim2.fromOffset(10, 7)
            local sub = self:_label(item, string.format("Staff: %s • Version: %s • Updated: %s", tostring(server.Staff), tostring(server.PlaceVersion), tostring(server.UpdatedAt)), UDim2.new(1, -20, 0, 18), true); sub.Position = UDim2.fromOffset(10, 30); sub.TextSize = 11
        end
    end
    render(analytics)
    self:_button(section, "Refresh Analytics", function() self:_action("Analytics.GetSnapshot", {}, render) end, "Accent", UDim2.new(0, 160, 0, 36)).Position = UDim2.new(0, 12, 1, -44)
end

function UIController:_renderSettings()
    local content = self.Content
    local runtime = self:_section(content, "Runtime Preferences", UDim2.new(0.58, -6, 1, 0))
    local explanation = self:_section(content, "Configuration Boundary", UDim2.new(0.42, -6, 1, 0)); explanation.Position = UDim2.new(0.58, 6, 0, 0)
    local title = self:_input(runtime, "Panel title", tostring(self.Snapshot.Settings.PanelTitle or self.Config.Panel.Title), UDim2.new(1, -24, 0, 36)); title.Position = UDim2.fromOffset(12, 48)
    if self:Has("Settings.Edit") then
        self:_button(runtime, "Save Panel Title", function() self:_action("Settings.Set", { Key = "PanelTitle", Value = title.Text }) end, "Accent", UDim2.new(0, 160, 0, 36)).Position = UDim2.fromOffset(12, 94)

        local function toggleButton(key: string, y: number)
            local current = self.Snapshot.Settings[key] == true
            local button
            button = self:_button(runtime, string.format("%s: %s", key, if current then "On" else "Off"), function()
                current = not current
                button.Text = string.format("%s: %s", key, if current then "On" else "Off")
                self:_action("Settings.Set", { Key = key, Value = current })
            end, if current then "Success" else "Default", UDim2.new(0, 220, 0, 36))
            button.Position = UDim2.fromOffset(12, y)
        end
        toggleButton("SoundsEnabled", 148)
        toggleButton("CompactMode", 194)
        toggleButton("AnnouncementsEnabled", 240)
    end
    local info = self:_label(explanation,
        "Runtime settings are deliberately narrow. Permanent owner IDs, group mappings, security limits, DataStore names, and developer switches remain in Shared/Config.lua.\n\nThat division prevents a compromised panel session from rewriting the framework's trust boundary.",
        UDim2.new(1, -24, 0, 250), true)
    info.Position = UDim2.fromOffset(12, 50)
    info.TextYAlignment = Enum.TextYAlignment.Top
end

function UIController:_renderDeveloper()
    local content = self.Content
    local diagnostics = self:_section(content, "Diagnostics", UDim2.new(0.55, -6, 1, 0))
    local viewer = self:_section(content, "Whitelisted DataStore Viewer", UDim2.new(0.45, -6, 1, 0)); viewer.Position = UDim2.new(0.55, 6, 0, 0)
    local output = self:_label(diagnostics, "Run diagnostics to inspect server health.", UDim2.new(1, -24, 1, -104), true); output.Position = UDim2.fromOffset(12, 48); output.TextYAlignment = Enum.TextYAlignment.Top
    if self:Has("Developer.RemoteMonitor") then
        self:_button(diagnostics, "Run Diagnostics", function()
            self:_action("Developer.GetDiagnostics", {}, function(data)
                local lines = {
                    "Job ID: " .. tostring(data.JobId),
                    "Place ID: " .. tostring(data.PlaceId),
                    "Place Version: " .. tostring(data.PlaceVersion),
                    "Memory: " .. valueText(data.MemoryMb) .. " MB",
                    "Server Time: " .. tostring(data.ServerTime),
                    "",
                    "Modules:",
                }
                for _, module in data.ModuleStates or {} do
                    table.insert(lines, string.format("• %s: %s (%s actions)", module.Name, if module.Enabled then "Enabled" else "Disabled", module.ActionCount))
                end
                output.Text = table.concat(lines, "\n")
            end)
        end, "Accent", UDim2.new(0, 160, 0, 36)).Position = UDim2.new(0, 12, 1, -48)
    end

    local store = self:_input(viewer, "Store alias", "Staff", UDim2.new(1, -24, 0, 36)); store.Position = UDim2.fromOffset(12, 48)
    local key = self:_input(viewer, "Exact key", tostring(LocalPlayer.UserId), UDim2.new(1, -24, 0, 36)); key.Position = UDim2.fromOffset(12, 94)
    local viewerOutput = self:_label(viewer, "Viewer output appears here.", UDim2.new(1, -24, 0, 260), true); viewerOutput.Position = UDim2.fromOffset(12, 146); viewerOutput.TextYAlignment = Enum.TextYAlignment.Top
    if self:Has("Developer.DataStoreViewer") then
        self:_button(viewer, "Read Key", function()
            self:_action("Developer.ViewDataStoreKey", { Store = store.Text, Key = key.Text }, function(data)
                local ok, encoded = pcall(function() return game:GetService("HttpService"):JSONEncode(data) end)
                viewerOutput.Text = if ok then encoded else tostring(data)
            end)
        end, "Warning", UDim2.new(0, 130, 0, 36)).Position = UDim2.new(0, 12, 1, -48)
    end
end

function UIController:_renderModules()
    local content = self.Content
    local section = self:_section(content, "Module Registry", UDim2.fromScale(1, 1))
    local list = self:_scroll(section, UDim2.new(1, -24, 1, -56)); list.Position = UDim2.fromOffset(12, 46)
    for _, module in self.Snapshot.Modules or {} do
        local item = create("Frame", { BackgroundColor3 = self.Config.Theme.SurfaceAlt, Size = UDim2.new(1, -4, 0, 66), Parent = list }); corner(item, 8)
        local title = self:_label(item, module.Name, UDim2.new(0.32, 0, 0, 22), false); title.Position = UDim2.fromOffset(12, 8); title.Font = Enum.Font.GothamSemibold
        local description = self:_label(item, module.Description or "", UDim2.new(0.55, 0, 0, 32), true); description.Position = UDim2.fromOffset(12, 31); description.TextSize = 11
        local status = self:_label(item, if module.Enabled then "Enabled" else "Disabled", UDim2.new(0, 80, 0, 22), true); status.Position = UDim2.new(1, -214, 0, 8)
        if self:Has("Modules.Toggle") and module.Name ~= "Modules" then
            self:_button(item, if module.Enabled then "Disable" else "Enable", function()
                self:_action("Modules.Toggle", { Module = module.Name, Enabled = not module.Enabled }, function()
                    if self:_loadSnapshot(false) then self:ShowPage("Modules") end
                end)
            end, if module.Enabled then "Danger" else "Success", UDim2.fromOffset(110, 34)).Position = UDim2.new(1, -122, 0.5, -17)
        end
    end
end

function UIController:_registerRenderers()
    self.Renderers = {
        Dashboard = function() self:_renderDashboard() end,
        Players = function() self:_renderPlayers() end,
        Moderation = function() self:_renderModeration() end,
        Server = function() self:_renderServer() end,
        Messaging = function() self:_renderMessaging() end,
        Staff = function() self:_renderStaff() end,
        Ranks = function() self:_renderRanks() end,
        Logs = function() self:_renderLogs() end,
        Analytics = function() self:_renderAnalytics() end,
        Settings = function() self:_renderSettings() end,
        Developer = function() self:_renderDeveloper() end,
        Modules = function() self:_renderModules() end,
    }
end

function UIController:_pageAllowed(pageName: string): boolean
    local checks = {
        Dashboard = function() return self:Has("Panel.Access") end,
        Players = function() return self:Has("Players.View") end,
        Moderation = function() return self:HasPrefix("Moderation.") end,
        Server = function() return self:Has("Server.View") end,
        Messaging = function() return self:HasPrefix("Messaging.") end,
        Staff = function() return self:Has("Staff.View") end,
        Ranks = function() return self:Has("Ranks.View") or self:Has("Ranks.Assign") end,
        Logs = function() return self:Has("Logs.View") end,
        Analytics = function() return self:Has("Analytics.View") end,
        Settings = function() return self:Has("Settings.View") end,
        Developer = function() return self:HasPrefix("Developer.") end,
        Modules = function() return self:Has("Modules.View") end,
    }
    return checks[pageName] and checks[pageName]() or false
end

function UIController:ShowPage(pageName: string)
    if not self:_pageAllowed(pageName) then return end
    self.CurrentPage = pageName
    self.PageTitle.Text = pageName
    for name, button in self.PageButtons do
        button.BackgroundColor3 = if name == pageName then self.Config.Theme.AccentSoft else self.Config.Theme.Surface
    end
    self:_clearContent()
    local renderer = self.Renderers[pageName]
    if renderer then renderer() end
end

function UIController:SetOpen(open: boolean)
    self.Open = open
    self.Root.Visible = open
    self.ToggleButton.Text = if open then "Close Aegis" else "Open Aegis"
end

function UIController:Toast(title: string, message: string, level: string?)
    if not self.ScreenGui then return end
    local color = self.Config.Theme.Accent
    if level == "Success" then color = self.Config.Theme.Success end
    if level == "Warning" then color = self.Config.Theme.Warning end
    if level == "Danger" then color = self.Config.Theme.Danger end
    if level == "Staff" then color = self.Config.Theme.AccentSoft end

    local toast = create("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = self.Config.Theme.Surface,
        Position = UDim2.new(1, -18, 0, -90),
        Size = UDim2.fromOffset(360, 78),
        Parent = self.ScreenGui,
        ZIndex = 50,
    }) :: Frame
    corner(toast, 10)
    stroke(toast, color, 0.1)
    local bar = create("Frame", { BackgroundColor3 = color, Size = UDim2.fromOffset(5, 58), Position = UDim2.fromOffset(8, 10), Parent = toast, ZIndex = 51 }); corner(bar, 3)
    local titleLabel = self:_label(toast, title, UDim2.new(1, -34, 0, 22), false); titleLabel.Position = UDim2.fromOffset(22, 10); titleLabel.Font = Enum.Font.GothamSemibold; titleLabel.ZIndex = 51
    local messageLabel = self:_label(toast, message, UDim2.new(1, -34, 0, 36), true); messageLabel.Position = UDim2.fromOffset(22, 34); messageLabel.TextSize = 12; messageLabel.ZIndex = 51
    TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Quint), { Position = UDim2.new(1, -18, 0, 18) }):Play()
    task.delay(4.5, function()
        if toast.Parent then
            local tween = TweenService:Create(toast, TweenInfo.new(0.22), { Position = UDim2.new(1, 390, 0, 18), BackgroundTransparency = 1 })
            tween:Play()
            tween.Completed:Wait()
            toast:Destroy()
        end
    end)
end

function UIController:HandlePush(payload: any)
    if typeof(payload) ~= "table" then return end
    if payload.Type == "Notification" or payload.Type == "Announcement" then
        if payload.Type == "Announcement" and self.Snapshot and self.Snapshot.Settings and self.Snapshot.Settings.AnnouncementsEnabled == false then
            return
        end
        self:Toast(payload.Title or "Notification", payload.Message or "", payload.Level or "Info")
    elseif payload.Type == "RefreshPermissions" then
        if self:_loadSnapshot(false) then
            self:_buildSidebar()
            self:ShowPage("Dashboard")
        end
    elseif payload.Type == "RuntimeSettings" and typeof(payload.Settings) == "table" then
        if self.Snapshot then self.Snapshot.Settings = payload.Settings end
    end
end

function UIController:_buildSidebar()
    for _, child in self.Sidebar:GetChildren() do
        if child.Name == "PageButton" then child:Destroy() end
    end
    self.PageButtons = {}
    local pages = { "Dashboard", "Players", "Moderation", "Server", "Messaging", "Staff", "Ranks", "Logs", "Analytics", "Settings", "Developer", "Modules" }
    local y = 88
    for _, pageName in pages do
        if self:_pageAllowed(pageName) then
            local button = self:_button(self.Sidebar, pageName, function() self:ShowPage(pageName) end, "Default", UDim2.new(1, -20, 0, 34))
            button.Name = "PageButton"
            button.Position = UDim2.fromOffset(10, y)
            button.TextXAlignment = Enum.TextXAlignment.Left
            padding(button, 12)
            self.PageButtons[pageName] = button
            y += 40
        end
    end
end

function UIController:_makeDraggable(handle: GuiObject, target: GuiObject)
    local dragging = false
    local dragStart = Vector2.zero
    local startPosition = target.Position
    local activeInput: InputObject? = nil

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            activeInput = input
            dragStart = input.Position
            startPosition = target.Position
        end
    end)
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            activeInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == activeInput then
            local delta = input.Position - dragStart
            target.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            activeInput = nil
        end
    end)
end

function UIController:_buildUI()
    local screen = create("ScreenGui", {
        Name = "AegisAdminPanel",
        ResetOnSpawn = false,
        IgnoreGuiInset = false,
        DisplayOrder = 1000,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = LocalPlayer:WaitForChild("PlayerGui"),
    }) :: ScreenGui
    self.ScreenGui = screen

    local toggle = self:_button(screen, "Open Aegis", function() self:SetOpen(not self.Open) end, "Accent", UDim2.fromOffset(124, 34))
    toggle.AnchorPoint = Vector2.new(1, 1)
    toggle.Position = UDim2.new(1, -16, 1, -16)
    toggle.ZIndex = 20
    self.ToggleButton = toggle

    local root = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = self.Config.Theme.Background,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(1080, 660),
        Visible = self.Open,
        Parent = screen,
    }) :: Frame
    corner(root, 12)
    stroke(root, self.Config.Theme.Accent, 0.45)
    self.Root = root

    create("UISizeConstraint", { MinSize = Vector2.new(820, 520), MaxSize = Vector2.new(1280, 760), Parent = root })

    local sidebar = create("Frame", { BackgroundColor3 = self.Config.Theme.Surface, Size = UDim2.new(0, 182, 1, 0), Parent = root }) :: Frame
    corner(sidebar, 12)
    self.Sidebar = sidebar
    local logo = self:_label(sidebar, self.Constants.FrameworkName, UDim2.new(1, -20, 0, 30), false); logo.Position = UDim2.fromOffset(12, 14); logo.Font = Enum.Font.GothamBold; logo.TextSize = 17
    local role = self:_label(sidebar, self.Snapshot.User.Role or "Staff", UDim2.new(1, -20, 0, 20), true); role.Position = UDim2.fromOffset(12, 46); role.TextSize = 11

    local topbar = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -182, 0, 62), Position = UDim2.fromOffset(182, 0), Parent = root }) :: Frame
    local pageTitle = self:_label(topbar, "Dashboard", UDim2.new(0.5, 0, 0, 30), false); pageTitle.Position = UDim2.fromOffset(22, 12); pageTitle.Font = Enum.Font.GothamBold; pageTitle.TextSize = 20
    self.PageTitle = pageTitle
    local status = self:_label(topbar, "Ready", UDim2.new(0, 200, 0, 22), true); status.AnchorPoint = Vector2.new(1, 0); status.Position = UDim2.new(1, -18, 0, 17); status.TextXAlignment = Enum.TextXAlignment.Right
    self.StatusLabel = status
    local close = self:_button(topbar, "×", function() self:SetOpen(false) end, "Danger", UDim2.fromOffset(34, 34)); close.AnchorPoint = Vector2.new(1, 0); close.Position = UDim2.new(1, -226, 0, 11); close.TextSize = 20

    local content = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -214, 1, -84), Position = UDim2.fromOffset(198, 68), Parent = root }) :: Frame
    self.Content = content

    self:_makeDraggable(topbar, root)
    self:_buildSidebar()
end

function UIController:Start(): boolean
    local snapshotResult = self:_request({ kind = "snapshot" })
    if not snapshotResult.Success then
        warn("[Aegis GMS] Panel access denied: " .. tostring(snapshotResult.Message))
        return false
    end
    self.Snapshot = snapshotResult.Data
    self:_registerRenderers()
    self:_buildUI()
    self:ShowPage("Dashboard")
    self:SetOpen(self.Open)

    local toggleKey = Enum.KeyCode[self.Config.Panel.ToggleKey] or Enum.KeyCode.F2
    table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == toggleKey then
            self:SetOpen(not self.Open)
        end
    end))

    table.insert(self.Connections, self.PushRemote.OnClientEvent:Connect(function(payload)
        self:HandlePush(payload)
    end))

    task.spawn(function()
        while self.ScreenGui and self.ScreenGui.Parent do
            task.wait(self.Config.Panel.RefreshSeconds)
            local autoPages = { Dashboard = true, Players = true, Logs = true, Analytics = true, Modules = true }
            if self.Open and not self.Busy and autoPages[self.CurrentPage] then
                local current = self.CurrentPage
                if self:_loadSnapshot(false) then
                    self:ShowPage(current)
                end
            end
        end
    end)

    return true
end

return UIController
