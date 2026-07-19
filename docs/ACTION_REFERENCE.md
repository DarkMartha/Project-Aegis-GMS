# Action Reference

| Action | Permission | Purpose |
|---|---|---|
| `Players.GetProfile` | `Players.View` | Read public profile and leaderstats data |
| `Players.Heal` | `Players.Heal` | Restore target health |
| `Players.Kill` | `Players.Kill` | Set target health to zero |
| `Players.Freeze` / `Players.Unfreeze` | `Players.Freeze` | Toggle anchored character state |
| `Players.Bring` / `Players.Goto` | `Players.Teleport` | Move target or actor |
| `Players.Respawn` | `Players.Respawn` | Reload target character |
| `Players.Spectate` | `Players.Spectate` | Toggle local camera spectate |
| `Players.Fly` | `Players.Fly` | Toggle authorised client flight |
| `Players.Noclip` | `Players.Noclip` | Toggle authorised client noclip |
| `Moderation.Kick` | `Moderation.Kick` | Remove online player |
| `Moderation.Ban` | `Moderation.Ban` | Persistent cross-server ban |
| `Moderation.TempBan` | `Moderation.TempBan` | Expiring cross-server ban |
| `Moderation.Unban` | `Moderation.Unban` | Revoke ban record |
| `Moderation.Warn` | `Moderation.Warn` | Append persistent warning |
| `Moderation.Mute` / `Moderation.Unmute` | `Moderation.Mute` | Persistent TextChatService mute |
| `Moderation.Jail` / `Moderation.Unjail` | `Moderation.Jail` | Hold or release online player |
| `Moderation.AddNote` | `Moderation.Notes` | Append player note |
| `Moderation.GetHistory` | `Logs.PlayerHistory` | Read warnings, notes, ban, and mute |
| `Server.Lock` / `Server.Unlock` | `Server.Lock` | Gate new non-staff joins |
| `Server.Shutdown` | `Server.Shutdown` | Close current server |
| `Server.EmergencyShutdown` | `Server.Shutdown` | Publish fleet-wide shutdown |
| `Server.SoftShutdown` / `Server.Restart` | `Server.SoftShutdown` | Move players to a reserved replacement server |
| `Server.Reserve` | `Server.Reserve` | Create reserved server access code |
| `Server.SetGravity` | `Server.Gravity` | Set workspace gravity |
| `Server.SetTime` | `Server.Time` | Set Lighting clock time |
| `Server.SetBrightness` / `Server.SetFogEnd` | `Server.Lighting` | Adjust Lighting properties |
| `Server.SetWeather` | `Server.Weather` | Set weather integration state |
| `Messaging.Notify` | `Messaging.Notify` | Direct player notification |
| `Messaging.Broadcast` | `Messaging.Broadcast` | Current-server announcement |
| `Messaging.StaffBroadcast` | `Messaging.StaffChat` | Cross-server staff message |
| `Messaging.GlobalAnnouncement` | `Messaging.Global` | Cross-server player announcement |
| `Staff.GetDirectory` | `Staff.View` | List online staff |
| `Staff.SetRank` | `Ranks.Assign` | Set custom rank |
| `Staff.RemoveRank` | `Staff.Remove` | Remove custom rank |
| `Staff.SetTemporaryRank` | `Ranks.Temporary` | Set expiring rank |
| `Staff.SetPermissionOverrides` | `Ranks.Permissions` | Set allow and deny overrides |
| `Staff.AddNote` | `Staff.Notes` | Append staff record note |
| `Staff.GetActivity` | `Staff.Activity` | Read current-server action counts |
| `Logs.GetRecent` | `Logs.View` | Filter recent audit entries |
| `Logs.GetErrors` | `Logs.Errors` | Read recent server errors |
| `Analytics.GetSnapshot` | `Analytics.View` | Read metrics and live servers |
| `Settings.Get` | `Settings.View` | Read safe runtime settings |
| `Settings.Set` | `Settings.Edit` | Edit approved runtime settings |
| `Developer.GetDiagnostics` | `Developer.RemoteMonitor` | Read diagnostics and module state |
| `Developer.ViewDataStoreKey` | `Developer.DataStoreViewer` | Read whitelisted exact DataStore key |
| `Developer.EmitTestNotification` | `Developer.Test` | Verify client push channel |
| `Modules.GetStates` | `Modules.View` | List modules and states |
| `Modules.Toggle` | `Modules.Toggle` | Enable or disable a runtime module |
