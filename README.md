# Aegis GMS for Roblox

Aegis GMS is a server-authoritative, permission-driven Roblox administration framework built from the supplied Admin Framework Master Plan. It includes a complete dashboard UI, modular server actions, persistent moderation, custom and group ranks, cross-server messaging, live server discovery, logging, analytics, and guarded developer tools.


## Public project

Aegis GMS is released under the MIT License. You may download, use, modify, and redistribute it subject to the licence terms. Public contributions are welcome through issues and pull requests. Security reports should follow `SECURITY.md`.

## Included

- Twelve panel pages: Dashboard, Players, Moderation, Server, Messaging, Staff, Ranks, Logs, Analytics, Settings, Developer, and Modules.
- Individual permission checks for every action. Rank names are convenient bundles, not the security boundary.
- Permission sources: experience owner, configured owners, custom DataStore rank, temporary rank, Roblox Group rank, allow overrides, and deny overrides.
- Persistent bans, temporary bans, warnings, mutes, player notes, staff records, settings, logs, and analytics.
- Cross-server announcements, staff broadcasts, immediate ban propagation, live-server registry, staff presence, and emergency shutdown.
- Rate limiting, request-shape limits, hierarchy protection, server-side validation, action logging, and safe error handling.
- Player tools: profile, heal, kill, freeze, bring, go-to, respawn, spectate, fly, and noclip.
- Server tools: lock, unlock, shutdown, soft restart, reserve server, gravity, time, brightness, fog, weather state, and fleet-wide emergency shutdown.
- No external packages are required.

## Recommended installation with Rojo

1. Install Rojo and its Roblox Studio plugin.
2. Open this folder in a terminal and run:

   ```text
   rojo serve
   ```

3. Open your Roblox experience, connect the Rojo plugin, and sync the project.
4. Open `src/ReplicatedStorage/AdminFramework/Shared/Config.lua`.
5. Add owner user IDs to `Owners`, or configure your Roblox Group ID and rank map. The creator of a user-owned experience receives Owner automatically.
6. Publish the experience. DataStores, MessagingService, TeleportService, and MemoryStore features require a published experience.
7. For Studio persistence tests, enable **Game Settings → Security → Enable Studio Access to API Services**.
8. Play-test as an authorised account and press **F2** or use the **Open Aegis** button.

## Manual Studio installation

The ZIP also contains `AegisGMS_Studio_Package.rbxmx`.

1. Drag the `.rbxmx` file into Roblox Studio.
2. Expand `AegisGMS_Package`.
3. Move the contents of its `ReplicatedStorage` folder into the real `ReplicatedStorage` service.
4. Move the contents of its `ServerScriptService` folder into the real `ServerScriptService` service.
5. Move `AdminFrameworkClient` from `StarterPlayer/StarterPlayerScripts` into the real `StarterPlayerScripts` service.
6. Delete the empty imported package model.
7. Configure `ReplicatedStorage/AdminFramework/Shared/Config` before publishing.

## First access

For a user-owned experience, the experience creator is automatically Owner. For a group-owned experience, configure `Config.Group` or add a trusted user ID to `Config.Owners`.

A player without `Panel.Access` receives no panel. Hiding buttons is only a convenience; every action is independently checked again on the server.

## Important integration notes

Roblox games do not share one inventory, economy, quest, vehicle, or weather implementation. Aegis exposes the framework and module API, while game-specific data must be connected through a custom module. The built-in weather action sets `workspace` attribute `AegisWeather` and sends a client event; your weather controller can listen for either signal.

The mute service filters modern `TextChatService` channels with `ShouldDeliverCallback`. If your game already owns that callback, merge the Aegis mute check into your existing callback rather than allowing two systems to replace each other.

Fly and noclip are authorised by the server but executed on the affected client. They are administration utilities, not anti-cheat replacements.

## Security model

The client never tells the server what permission it has. It submits an action name and limited payload. The server performs:

```text
Request shape check → rate limit → module state → permission check →
input normalisation → rank hierarchy check → execute → log → notify
```

Read `docs/SECURITY.md` before exposing developer tools or changing rate limits.

## Configuration highlights

`Config.lua` controls:

- Owner user IDs and Roblox Group rank mapping
- Panel key and theme
- Remote rate limits and payload limits
- DataStore prefix and aliases
- persistence and Studio fallback
- cross-server registry settings
- moderation defaults and jail position
- module defaults
- developer DataStore viewer safety gate

## Folder map

```text
src/
├── ReplicatedStorage/AdminFramework
│   ├── Shared
│   └── Client
├── ServerScriptService/AdminFramework
│   ├── Core
│   ├── Services
│   └── Modules
└── StarterPlayer/StarterPlayerScripts
    └── AdminFrameworkClient.client.lua
```

## Documentation

- `docs/ACTION_REFERENCE.md`
- `docs/CUSTOM_MODULES.md`
- `docs/SECURITY.md`
- `docs/TROUBLESHOOTING.md`
- `docs/MASTER_PLAN.md`

## Testing checklist

- Join as the experience creator and open the panel with F2.
- Give a test account a low custom rank, then verify higher-risk buttons are absent and server requests are denied.
- Test warnings and bans in a published private test experience.
- Start two server instances and verify global announcements and ban propagation.
- Confirm lock mode still allows staff with `Panel.Access` to join.
- Confirm your game-specific chat callback still honours mutes.
- Leave developer DataStore viewing disabled until it is genuinely needed.

## Version

Aegis GMS 1.0.0
