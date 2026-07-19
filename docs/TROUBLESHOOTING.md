# Troubleshooting

## Panel does not appear

- Press F2 or look for the Open Aegis button.
- Confirm the client script is inside `StarterPlayerScripts`.
- Confirm the player resolves to a rank with `Panel.Access`.
- For group-owned experiences, enable `Config.Group` and set the correct Group ID.
- Check the server output for `[Aegis GMS]` startup errors.

## DataStores fail in Studio

Enable **Game Settings → Security → Enable Studio Access to API Services** and publish the experience. Aegis can use temporary memory fallback in Studio, but that data disappears when the test ends.

## Cross-server features do not work

MessagingService and MemoryStore require a published experience and can be throttled in aggressive tests. Use two live private servers, not only local Studio clients.

## Mutes do not hide messages

The built-in mute filter targets modern `TextChatService` channels. If your game assigns its own `TextChannel.ShouldDeliverCallback`, merge this check into that callback:

```lua
local source = message.TextSource
if source and muteService:IsMuted(source.UserId) and targetTextSource.UserId ~= source.UserId then
    return false
end
```

## Soft shutdown does not work in Studio

TeleportService reserved-server flows cannot be meaningfully completed in Studio. Test in a published private environment.

## Imported `.rbxmx` scripts are in the wrong place

The model is a transport container. Move each imported child into the matching Roblox service, then delete the package model. The server bootstrap must be under `ServerScriptService`; it will not run correctly from Workspace.

## A module refuses to toggle

The `Modules` controller cannot disable itself. Owners can still reach disabled modules server-side for recovery, while ordinary staff cannot.

## Weather changes do not create rain or snow

The framework sets the `AegisWeather` workspace attribute and sends a `Weather` client event. Connect those signals to your game's own weather controller.
