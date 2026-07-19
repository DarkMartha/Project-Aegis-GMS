--!strict

local Constants = {
    FrameworkName = "Aegis GMS",
    Version = "1.0.0",
    ProtocolVersion = 1,

    RemoteFolderName = "Remotes",
    RequestRemoteName = "Request",
    PushRemoteName = "Push",

    Topics = {
        GlobalAnnouncement = "AegisGMS:GlobalAnnouncement:v1",
        StaffBroadcast = "AegisGMS:StaffBroadcast:v1",
        BanSync = "AegisGMS:BanSync:v1",
        EmergencyShutdown = "AegisGMS:EmergencyShutdown:v1",
    },

    LogCategories = {
        Staff = "Staff",
        Moderation = "Moderation",
        Server = "Server",
        Commands = "Commands",
        Errors = "Errors",
        PlayerHistory = "PlayerHistory",
        Security = "Security",
        Messaging = "Messaging",
    },

    MaxReasonLength = 300,
    MaxMessageLength = 500,
    MaxNoteLength = 1000,
    MaxLogsReturned = 100,
}

return table.freeze(Constants)
