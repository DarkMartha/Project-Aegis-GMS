# Aegis GMS 1.0.0

Aegis GMS is a modular, server-authoritative administration framework for Roblox.

## Highlights

- Twelve-page administrative dashboard
- Individual permission checks for every action
- Owner, custom, temporary, group-rank, allow-override, and deny-override permission sources
- Persistent bans, temporary bans, warnings, mutes, notes, settings, logs, and analytics
- Cross-server announcements, staff broadcasts, server discovery, staff presence, ban propagation, and emergency shutdown
- Player, moderation, server, messaging, staff, rank, logging, analytics, developer, settings, and module controls
- Rojo project plus an `.rbxmx` package for manual Roblox Studio installation
- MIT licensed

## Installation

Download `Aegis_GMS_Roblox_Admin_Framework_v1.0.0.zip` from this release, extract
it, and read `READ_ME_FIRST.md` before importing the Studio package. The release
download intentionally contains only the files required for manual installation.

The editable Rojo source and extended documentation remain available from the
repository's **Code -> Download ZIP** option.

Before publishing, configure trusted owners and any Roblox Group mappings in:

`src/ReplicatedStorage/AdminFramework/Shared/Config.lua`

## Important

Use a private published test experience before deploying to production. DataStore, MessagingService, TeleportService, and MemoryStore behaviour cannot be fully tested in an unpublished local place.
