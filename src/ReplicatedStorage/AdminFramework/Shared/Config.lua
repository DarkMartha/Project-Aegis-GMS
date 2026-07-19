--!strict

local Config = {
    -- Add trusted owner user IDs here. The creator of a user-owned experience
    -- is automatically treated as an owner too.
    Owners = {
        -- 123456789,
    },

    Group = {
        Enabled = false,
        Id = 0,
        -- Highest matching MinimumRank wins.
        RankMap = {
            { MinimumRank = 255, Role = "Owner" },
            { MinimumRank = 250, Role = "Head Administrator" },
            { MinimumRank = 200, Role = "Administrator" },
            { MinimumRank = 150, Role = "Senior Moderator" },
            { MinimumRank = 100, Role = "Moderator" },
            { MinimumRank = 50, Role = "Helper" },
        },
    },

    Panel = {
        ToggleKey = "F2",
        StartOpen = false,
        RefreshSeconds = 8,
        Title = "Aegis Game Management",
    },

    Theme = {
        Background = Color3.fromRGB(15, 17, 24),
        Surface = Color3.fromRGB(24, 27, 37),
        SurfaceAlt = Color3.fromRGB(31, 35, 47),
        Accent = Color3.fromRGB(195, 44, 221),
        AccentSoft = Color3.fromRGB(112, 46, 133),
        Text = Color3.fromRGB(239, 241, 247),
        MutedText = Color3.fromRGB(158, 164, 181),
        Success = Color3.fromRGB(61, 190, 125),
        Warning = Color3.fromRGB(238, 174, 71),
        Danger = Color3.fromRGB(232, 74, 95),
    },

    Security = {
        RequestsPerWindow = 18,
        WindowSeconds = 10,
        ActionCooldownSeconds = 0.15,
        MaxPayloadDepth = 5,
        MaxPayloadKeys = 40,
        KickOnRepeatedTampering = false,
        TamperStrikeLimit = 8,
    },

    DataStores = {
        Prefix = "AegisGMS_v1_",
        Staff = "Staff",
        Bans = "Bans",
        Warnings = "Warnings",
        Settings = "Settings",
        Logs = "Logs",
        PlayerPreferences = "PlayerPreferences",
        Analytics = "Analytics",
        Notes = "Notes",
        Mutes = "Mutes",
    },

    Persistence = {
        Enabled = true,
        AllowStudioMemoryFallback = true,
        RetryCount = 4,
        RetryDelaySeconds = 1.5,
        LogFlushSeconds = 20,
        AnalyticsFlushSeconds = 30,
    },

    CrossServer = {
        Enabled = true,
        LiveServerRegistry = true,
        RegistryName = "AegisGMS_LiveServers_v1",
        HeartbeatSeconds = 30,
        RecordExpirySeconds = 90,
    },

    Moderation = {
        DefaultReason = "No reason provided",
        DefaultTempBanMinutes = 60,
        DefaultMuteMinutes = 15,
        JailPosition = Vector3.new(0, 25, 0),
        BanMessage = "You are banned from this experience.",
    },

    Logging = {
        Persist = true,
        MemoryLimit = 350,
        PersistedBucketLimit = 120,
        IncludePayloads = true,
    },

    Modules = {
        Players = true,
        Moderation = true,
        Server = true,
        Messaging = true,
        Staff = true,
        Logs = true,
        Analytics = true,
        Settings = true,
        Developer = true,
        Modules = true,
    },

    Developer = {
        EnableDataStoreViewer = false,
        EnableDebugActions = false,
        AllowedViewerStores = {
            "Staff",
            "Bans",
            "Warnings",
            "Settings",
            "Notes",
            "Mutes",
        },
    },
}

return table.freeze(Config)
