# Documentation

## Rollout

Work through the phases in order. Each phase ends with a check; don't start the next
one until it passes.

| Phase | Goal | Guide | Done when |
| --- | --- | --- | --- |
| 0 | Server prepared, Tailscale HTTPS enabled | [Requirements](requirements.md#preparing-the-server), [Installation §1](installation.md#1-configure-tailscale) | `tailscale status --json` lists the server under `CertDomains` |
| 1 | CouchDB running and published on the tailnet | [Installation](installation.md) | `make verify` prints `All checks passed` |
| 2 | First device syncing | [Device setup](device-setup.md#first-device) | `make verify` shows a document count above 0 |
| 3 | Every device syncing | [Device setup](device-setup.md#additional-devices) | An edit on one device appears on the others within seconds |
| 4 | Backups scheduled and proven | [Backups](backups.md) | `make restore-test` prints `Restore test passed` |

## Guides

| Guide | Contents |
| --- | --- |
| [Requirements](requirements.md) | Server, network and client prerequisites; choosing and preparing a server |
| [Installation](installation.md) | Installing the server, publishing it on the tailnet, verification |
| [Device setup](device-setup.md) | Connecting Obsidian on desktop and mobile; settings sync |
| [Backups](backups.md) | Schedule, retention, restore testing, off-box copies |
| [Operations](operations.md) | Routine tasks, updates, credential rotation, troubleshooting, uninstall |

## Reference

| Document | Contents |
| --- | --- |
| [Configuration](configuration.md) | Every `.env` setting |
| [Architecture](architecture.md) | Components, request flow, security model, alternatives |
| [Design decisions](decisions.md) | The choices behind the setup, and why |
| [Roadmap](roadmap.md) | Ideas not yet built |
