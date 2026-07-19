# Custom Module API

Place a ModuleScript inside `ServerScriptService/AdminFramework/Modules`. The loader discovers it automatically at server start.

```lua
return {
    Name = "Economy",
    Description = "Example game-specific economy actions.",
    Actions = {
        {
            Name = "Economy.SetCoins",
            Permission = "Developer.Test",
            Category = "Commands",
            Validate = function(context, actor, payload)
                local userId = tonumber(payload.TargetUserId)
                local amount = tonumber(payload.Amount)
                if not userId or not amount then
                    return false, "TargetUserId and Amount are required"
                end
                return true, {
                    TargetUserId = math.floor(userId),
                    Amount = math.clamp(math.floor(amount), 0, 1_000_000),
                }
            end,
            Execute = function(context, actor, payload)
                -- Replace this with your economy service.
                return {
                    Success = true,
                    Message = "Economy adapter accepted the request",
                }
            end,
        },
    },
}
```

## Action result

Return a table with:

```lua
{
    Success = true,
    Message = "Human-readable result",
    Data = optionalSerializableData,
}
```

If `Success` is omitted, it defaults to true. Never return Instances to the client.

## Available context

Executors and validators receive the shared server context, including:

- `Config`
- `Constants`
- `Permissions`
- `Util`
- `DataStoreManager`
- `SecurityService`
- `RankService`
- `LogService`
- `AnalyticsService`
- `CrossServerService`
- `BanService`
- `MuteService`
- `ActionService`
- `PushRemote`
- `RuntimeSettings`

## Adding a new permission

1. Add the permission string to `Shared/Permissions.lua` under `Permissions.All`.
2. Grant it to one or more rank definitions.
3. Use the exact same string in the action's `Permission` field.
4. Add a client control only as a convenience. The server check remains mandatory.

## Client page extensions

The bundled panel is intentionally dependency-free and programmatic. Add a renderer in `Client/UIController.lua`, add its navigation entry, and call the action through `_action`. Do not invoke custom RemoteEvents that bypass `ActionService`.
