--!strict

export type PermissionOverrides = {
    Allow: {string},
    Deny: {string},
}

export type StaffRecord = {
    CustomRank: string?,
    TemporaryRank: string?,
    TemporaryRankExpiresAt: number?,
    Overrides: PermissionOverrides?,
    Notes: {any}?,
    UpdatedAt: number?,
    UpdatedBy: number?,
}

export type BanRecord = {
    UserId: number,
    UserName: string,
    Reason: string,
    CreatedAt: number,
    CreatedBy: number,
    CreatedByName: string,
    ExpiresAt: number?,
    Active: boolean,
    Global: boolean,
}

export type LogEntry = {
    Id: string,
    Timestamp: number,
    IsoTime: string,
    Category: string,
    Action: string,
    Success: boolean,
    ActorUserId: number,
    ActorName: string,
    TargetUserId: number?,
    TargetName: string?,
    Message: string,
    Payload: any?,
    ServerJobId: string,
}

return nil
