# Contributing to Aegis GMS

Thank you for helping improve Aegis GMS.

## Before opening a pull request

1. Search existing issues and pull requests.
2. Keep changes focused on one feature or fix.
3. Preserve the server-authoritative security model.
4. Never trust permission, rank, or target data supplied by the client.
5. Add or update documentation for new actions, permissions, modules, or settings.
6. Test in a private published Roblox experience when DataStore, MessagingService, MemoryStore, or TeleportService behaviour is involved.

## Code expectations

- Use clear Luau names and typed annotations where they improve safety.
- Validate all remote payloads on the server.
- Register every action with an individual permission.
- Log administrative actions and failures without exposing secrets.
- Avoid external dependencies unless there is a strong reason to add one.
- Keep game-specific systems behind modules or adapters.

## Pull request checklist

- [ ] The change has been play-tested.
- [ ] Permission checks are enforced server-side.
- [ ] Rank hierarchy rules still apply where relevant.
- [ ] Documentation and changelog entries are included.
- [ ] No tokens, cookies, private place IDs, webhooks, or personal identifiers are committed.

## Reporting security problems

Do not publish exploitable security issues in a public issue. Follow `SECURITY.md` instead.
