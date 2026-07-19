# Security Guide

## Trust boundary

Everything inside `StarterPlayer` and every Remote payload is untrusted. The panel's button visibility is not authorization. `ActionService` is the only supported execution path for client-requested administrative actions.

## Request pipeline

1. `SecurityService` checks that the request is a shallow, serializable table within depth and key limits.
2. Per-player request windows and per-action cooldowns reject spam.
3. `ActionService` verifies that the action exists and its module is enabled.
4. `RankService` checks the action's exact permission.
5. The action validator converts and bounds every client-supplied value.
6. Moderation and staff actions compare actor and target hierarchy.
7. Execution occurs inside `pcall`; errors become safe client messages and error logs.
8. Every accepted action is logged with actor, target, result, and a serializable payload.

## Permission precedence

1. Explicit deny override
2. Explicit allow override
3. Resolved role grants and inherited grants

Owner identity affects the resolved role, but deny overrides still protect against accidental broad grants for non-owner roles. Experience creators and `Config.Owners` resolve as Owner.

## Dangerous settings

Keep these conservative:

- `Security.RequestsPerWindow`
- `Security.WindowSeconds`
- `Security.MaxPayloadDepth`
- `Security.MaxPayloadKeys`
- `Developer.EnableDataStoreViewer`
- `Developer.AllowedViewerStores`

The DataStore viewer is read-only, exact-key only, permission guarded, disabled by default, and limited to an explicit alias allow-list.

## Cross-server validation

MessagingService messages are treated as data, not executable code. The framework subscribes only to fixed topic names and handles fixed payload fields. Never add `loadstring`, dynamic `require` asset IDs, or client-selected MessagingService topics.

## Custom modules

Every custom action must provide:

- a fixed action name
- a fixed permission
- a validator for all client data
- an executor that uses server-owned state
- a sensible log category

Do not accept arbitrary Instance paths, DataStore names, Lua source, module IDs, URLs, class names, or property names from clients.

## Anti-cheat note

This is an administration framework. It does not make client physics trustworthy. Server-authorised fly and noclip are convenience tools, and your game should exempt only the exact authorised player state from anti-cheat checks.
