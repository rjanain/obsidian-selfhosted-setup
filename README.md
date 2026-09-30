# Obsidian Self-Hosted Sync

[![ci](https://github.com/rjanain/obsidian-selfhosted-setup/actions/workflows/ci.yml/badge.svg)](https://github.com/rjanain/obsidian-selfhosted-setup/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Obsidian + LiveSync + Tailscale.** Real-time, end-to-end encrypted sync for
[Obsidian](https://obsidian.md) on your own server, with no ports open to the internet.

## Features

- **Real-time sync** across macOS, Windows, Linux, iOS, iPadOS and Android, using the
  [Self-hosted LiveSync](https://github.com/vrtmrz/obsidian-livesync) plugin.
- **Private network only.** CouchDB listens on loopback; [Tailscale](https://tailscale.com)
  is the only way in. No domain, reverse proxy or port forwarding.
- **End-to-end encrypted.** The server stores ciphertext; the passphrase stays on your devices.
- **Backed up and verified.** Weekly snapshots, an automated restore test, and a smoke
  test in CI.
- **Safe on a shared host.** Isolated folder, Compose project, network and volumes.

## Architecture

```
 Devices                                   Server
 Obsidian + LiveSync + Tailscale          ┌─────────────────────────────────────┐
        │                                 │ tailscale serve :6984 (HTTPS)       │
        └── tailnet (WireGuard) ─────────▶│        │                            │
                                          │        ▼                            │
                                          │ CouchDB 127.0.0.1:5984              │
                                          │ (encrypted chunks only)             │
                                          │        │ weekly snapshot            │
                                          │        ▼                            │
                                          │ /opt/obsidian-livesync/backups      │
                                          └─────────────────────────────────────┘
```

Details and the security model: [docs/architecture.md](docs/architecture.md).

## Requirements

| Component | Minimum |
| --- | --- |
| Server | Always-on Linux host (amd64 or arm64), 1 vCPU, 1 GB RAM |
| Software | Docker Engine with Compose v2, Tailscale |
| Network | A tailnet with MagicDNS and HTTPS certificates enabled |
| Clients | Obsidian, the Self-hosted LiveSync plugin, and Tailscale on each device |

Full list and server preparation: [docs/requirements.md](docs/requirements.md).

## Quick start

On a prepared server:

```bash
sudo git clone https://github.com/rjanain/obsidian-selfhosted-setup.git /opt/obsidian-livesync
sudo chown -R "$USER": /opt/obsidian-livesync && cd /opt/obsidian-livesync
cp .env.example .env && chmod 600 .env   # set passwords and TS_HOSTNAME
make up provision serve-on
make verify                              # expect: All checks passed
```

Then [connect your devices](docs/device-setup.md) and
[schedule backups](docs/backups.md). The complete walkthrough, including deploying
from a workstation, is in the [installation guide](docs/installation.md).

## Documentation

| Guide | Contents |
| --- | --- |
| [Requirements](docs/requirements.md) | Prerequisites; choosing and preparing a server |
| [Installation](docs/installation.md) | Server installation and verification |
| [Device setup](docs/device-setup.md) | Connecting Obsidian on desktop and mobile |
| [Backups](docs/backups.md) | Schedule, retention, restore testing, off-box copies |
| [Operations](docs/operations.md) | Routine tasks, upgrades, troubleshooting, uninstall |
| [Configuration](docs/configuration.md) | Every `.env` setting |
| [Architecture](docs/architecture.md) · [Decisions](docs/decisions.md) · [Roadmap](docs/roadmap.md) | Design and plans |

## Security

Report vulnerabilities privately; see [SECURITY.md](SECURITY.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Run `make lint smoke-test` before opening a
pull request.

## License

[MIT](LICENSE). Obsidian, Self-hosted LiveSync, CouchDB and Tailscale are separate
projects under their own licenses.
