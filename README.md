# obsidian-selfhosted-setup

[![ci](https://github.com/rjanain/obsidian-selfhosted-setup/actions/workflows/ci.yml/badge.svg)](https://github.com/rjanain/obsidian-selfhosted-setup/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Obsidian + LiveSync + Tailscale:** real-time, end-to-end encrypted sync for your
[Obsidian](https://obsidian.md) notes, on your own server, with **no ports open to
the internet**.

- **Real-time sync** across Mac, Windows, Linux, iPhone, iPad and Android, using the
  [Self-hosted LiveSync](https://github.com/vrtmrz/obsidian-livesync) plugin and a
  CouchDB server.
- **Private by default.** CouchDB listens on `127.0.0.1` only; [Tailscale](https://tailscale.com)
  is the single way in. No domain, reverse proxy, port forwarding or Let's Encrypt setup.
  Tailscale also issues the trusted HTTPS certificate that mobile Obsidian requires.
- **End-to-end encrypted.** The server only stores encrypted chunks; the passphrase
  never leaves your devices.
- **Tested and backed up.** A smoke test boots the whole stack in CI; weekly
  snapshots come with a restore test that proves they work.
- **Safe on a shared server.** Its own folder, Compose project, network and volumes,
  and it never touches your other containers, ports or Tailscale settings.

```
 Your devices                                        Your server (VPS or home box)
 Obsidian + LiveSync + Tailscale                    ┌──────────────────────────────────────┐
        │                                           │ tailscale serve  :6984  (HTTPS)      │
        └──── tailnet (WireGuard) ─── HTTPS ───────▶│        │                             │
                                                    │        ▼                             │
                                                    │ obsidian_couchdb  127.0.0.1:5984     │
                                                    │ (E2EE chunks only, 512 MB cap)       │
                                                    │        │ weekly, Sun 03:30           │
                                                    │        ▼                             │
                                                    │ /opt/obsidian-livesync/backups       │
                                                    └──────────────────────────────────────┘
```

## Why this setup

| | Obsidian Sync | LiveSync on a public server | **This repo** |
| --- | --- | --- | --- |
| Where notes are stored | Obsidian's servers | Your server | Your server |
| Reachable from the internet | Yes (their service) | Yes: a login page anyone can find | **No**: tailnet members only |
| You maintain | Nothing | Domain, reverse proxy, TLS certificates, firewall | Docker + Tailscale |
| Cost | Subscription | Server + domain | Server (Tailscale's free plan is enough) |

## Requirements

**Server:** any always-on Linux machine: a small VPS, a home server, or a
Raspberry Pi 4/5.

- amd64 or arm64, 1 vCPU, 1 GB RAM (CouchDB is capped at 512 MB)
- Disk: roughly 2–3× your vault size for the database, plus backups. Each weekly
  snapshot is a full copy, and the newest 4 are kept (`BACKUP_KEEP`).
- [Docker Engine](https://docs.docker.com/engine/install/) with the Compose v2 plugin (`docker compose`)
- [Tailscale](https://tailscale.com/download/linux), signed in to your tailnet
- A user in the `docker` group, with `sudo` (for `tailscale serve` and the backup timer)
- `git`, `make`, `curl`, `python3`, `rsync` (Debian/Ubuntu: `sudo apt install -y git make curl python3 rsync`)
- systemd (optional, for the weekly backup timer)

**Tailscale:** any plan, including the free Personal plan. In the
[admin console](https://login.tailscale.com/admin/dns), turn on **MagicDNS** and
**HTTPS Certificates**.

**Each device:** Obsidian, the Self-hosted LiveSync community plugin, and the
Tailscale app signed in to the same tailnet.

**Your computer** (optional, for `deploy`, `verify`, `pull-backups`, `smoke-test`):
`bash`, `make`, `curl`, `python3`, `openssl`, `ssh`, `rsync` (on macOS, the Xcode
Command Line Tools provide these), plus Docker for `make smoke-test` and
`shellcheck` for `make lint`.

### Getting a server

Any provider works. Budget KVM VPS plans (RackNerd, Hetzner, and others) are
plenty for this, and so is a machine at home that stays on. For example, on a small
RackNerd VPS:

1. Buy the plan and pick Ubuntu or Debian as the OS.
2. SSH in, create a non-root user with `sudo`, and install Docker and Tailscale
   (links above).
3. Run `sudo tailscale up` once to join your tailnet. After that, you can reach the
   server by its Tailscale name, and close its public SSH port if you like.

The repo is built to share that server with other Docker stacks: it lives in
`/opt/obsidian-livesync`, uses its own Compose project, and binds nothing publicly.

## Quick start

On the server (the full walkthrough, with a check after each phase, is in
[docs/runbook.md](docs/runbook.md)):

```bash
sudo git clone https://github.com/rjanain/obsidian-selfhosted-setup.git /opt/obsidian-livesync
sudo chown -R "$USER": /opt/obsidian-livesync && cd /opt/obsidian-livesync
cp .env.example .env && chmod 600 .env   # set passwords and TS_HOSTNAME
make up provision serve-on               # start, create the vault DB, publish on the tailnet
```

Then point LiveSync on each device at `https://<machine>.<tailnet>.ts.net:6984`
([runbook phases 2–3](docs/runbook.md#phase-2--first-device-a-desktop)).

Prefer to keep the repo on your computer? `./scripts/deploy.sh --init --env` pushes
it to the server over SSH instead (set `DEPLOY_HOST` and `DEPLOY_USER` in `.env`).

## Safety rules

- **Own folder, project, network and volumes:** `/opt/obsidian-livesync`, Compose
  project `obsidian-livesync`, container `obsidian_couchdb`. `deploy.sh` only
  writes to a folder named `obsidian-livesync`, and it checks the remote folder
  really holds this project before its `rsync --delete`.
- **Loopback only.** CouchDB binds to `127.0.0.1`; `tailscale serve` on **:6984**
  is the only way in. `serve-on` refuses a port that is already in use.
- **No scheduler labels.** Backups use a systemd timer, so host-wide label
  schedulers (e.g. Ofelia) never pick up jobs from this container.
- **Never `tailscale up`.** The scripts only use `tailscale serve`, so the flags your
  server was brought up with (`--ssh`, exit node…) are never reset.

The reasoning behind each choice is in [docs/decisions.md](docs/decisions.md).

## Layout

| Path | Purpose |
| --- | --- |
| `docker-compose.yml` | CouchDB 3.5.2 service: loopback port, limits, healthcheck |
| `couchdb/livesync.ini` | CouchDB settings LiveSync needs (CORS, auth, size limits) |
| `.env.example` | Secrets, vault names, tailnet hostname, optional deploy target |
| `scripts/deploy.sh` | Optional: push files from your computer (guarded, never restarts anything) |
| `scripts/provision.sh` | Create the vault DB + device user, idempotent |
| `scripts/tailscale-serve.sh` | `on` / `off` / `status` for the HTTPS endpoint |
| `scripts/verify.sh` | End-to-end check from a device: TLS, auth, CORS, no plain-HTTP path |
| `scripts/backup.sh` · `restore-test.sh` | Weekly snapshot (keeps the newest 4), and proof that it restores |
| `scripts/smoke-test.sh` | Throwaway local stack exercising every script (also runs in CI) |
| `deploy/systemd/` | Weekly backup service + timer |
| `docs/runbook.md` | Decisions, phases 0–4, backups, operations, uninstall |
| `docs/roadmap.md` | Later ideas: AI second brain, server mirror |

## Commands

Run `make help` for the full list.

| Where | Command | Does |
| --- | --- | --- |
| Server | `make up provision serve-on` | Start, provision, publish on the tailnet |
| Any tailnet machine | `make verify` | Check the endpoint as a device sees it |
| Server | `make backup restore-test install-backup-timer` | Snapshot, prove it restores, schedule weekly |
| Your computer | `make pull-backups DEST=/Volumes/<drive>/obsidian-livesync-backups` | Copy snapshots off the server |
| Your computer | `make lint smoke-test` | shellcheck, compose config, full local test (needs Docker) |

## Roadmap

Once sync has run for a few weeks: an AI "second brain" that maintains part of the
vault, and an optional server mirror for always-on agents (which gives up
end-to-end encryption on the server). Details and trade-offs are in
[docs/roadmap.md](docs/roadmap.md).

## Further reading

- [LiveSync own-server guide](https://github.com/vrtmrz/obsidian-livesync/blob/main/docs/setup_own_server.md)
- [Tailscale Serve](https://tailscale.com/kb/1312/serve) · [Tailscale HTTPS certificates](https://tailscale.com/kb/1153/enabling-https)

## License

[MIT](LICENSE). Obsidian, Self-hosted LiveSync, CouchDB and Tailscale are separate
projects under their own licenses; this repo only configures them.
