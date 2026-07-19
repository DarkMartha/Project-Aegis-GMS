# Security Policy

## Supported version

Security fixes currently target the latest published Aegis GMS release.

| Version | Supported |
| --- | --- |
| 1.x | Yes |
| Earlier development builds | No |

## Reporting a vulnerability

Please report vulnerabilities privately to the project maintainer rather than opening a public issue containing exploit details.

Include:

- The affected version and module
- Reproduction steps
- Expected and actual behaviour
- Security impact
- A minimal proof of concept, when safe
- Any suggested mitigation

Never include Roblox cookies, API keys, private repository tokens, DataStore contents, player personal data, or live credentials.

## Security design rules

Aegis GMS treats the client as untrusted. All administrative requests must pass server-side shape validation, rate limiting, module checks, permission checks, input normalisation, hierarchy checks, execution, and logging.
