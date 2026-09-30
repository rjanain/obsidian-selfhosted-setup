# Requirements

## Summary

| Component | Minimum |
| --- | --- |
| Server | Always-on Linux host, amd64 or arm64, 1 vCPU, 1 GB RAM |
| Container runtime | Docker Engine with the Compose v2 plugin |
| Network | A Tailscale tailnet with MagicDNS and HTTPS certificates enabled |
| Clients | Obsidian, the Self-hosted LiveSync plugin, and Tailscale on each device |

## Server

- **Host:** any always-on Linux machine, such as a VPS, a home server, or a Raspberry
  Pi 4/5. amd64 and arm64 are both supported.
- **CPU and memory:** 1 vCPU and 1 GB RAM. CouchDB is capped at 512 MB and one CPU
  (`docker-compose.yml`); an idle instance with a small vault uses about 70 MB.
- **Disk:** the database takes roughly 2–3× the vault size, because LiveSync keeps
  revision history until compaction. Backups add up to `BACKUP_KEEP` full snapshots
  (4 by default).
- **User account:** a non-root user in the `docker` group, with `sudo` rights.
  `tailscale serve` and the backup timer need root.
- **Software:**

  | Package | Used for |
  | --- | --- |
  | Docker Engine + Compose v2 plugin | Running CouchDB |
  | Tailscale | The only network path to the server |
  | `make` | Command shortcuts (`make up`, `make verify`, …) |
  | `curl`, `python3` | HTTP checks and JSON handling in the scripts |
  | `git` | Installing with Option A (clone on the server) |
  | `rsync` | Installing with Option B (push from a workstation) |
  | systemd | The weekly backup timer (optional) |

## Tailscale

- Any plan works, including the free Personal plan.
- In the [admin console DNS settings](https://login.tailscale.com/admin/dns), turn on
  **MagicDNS** and **HTTPS Certificates**. Read the
  [privacy note](installation.md#1-configure-tailscale) before enabling certificates.

## Client devices

| Platform | Needs |
| --- | --- |
| macOS, Windows, Linux | Obsidian, the Self-hosted LiveSync plugin, Tailscale set to start at login |
| iOS, iPadOS | Obsidian, the Self-hosted LiveSync plugin, Tailscale with **VPN On Demand** |
| Android | Obsidian, the Self-hosted LiveSync plugin, Tailscale set as **Always-on VPN** |

## Workstation (optional)

A workstation is only needed to deploy from your computer (Option B), run
`make verify` from outside the server, copy backups off the server, or work on this
repository.

- `bash`, `make`, `curl`, `python3`, `openssl`, `ssh`, `rsync`. On macOS, the Xcode
  Command Line Tools provide these.
- Docker, for `make smoke-test`.
- [ShellCheck](https://www.shellcheck.net/), for `make lint`.

## Choosing a server

Any provider works. A budget KVM VPS (for example from RackNerd or Hetzner) is more
than enough, and so is a machine at home that stays on. The stack is built to share a
host with other Docker workloads: it uses its own folder, Compose project, network and
volumes, and binds nothing to a public interface.

## Preparing the server

These steps assume a fresh Ubuntu or Debian server, such as a new VPS.

1. Connect as root and create a non-root user with `sudo`:

   ```bash
   adduser deploy && usermod -aG sudo deploy
   ```

2. Install Docker Engine by following the
   [official instructions](https://docs.docker.com/engine/install/), then let the user
   run Docker (log out and back in afterwards):

   ```bash
   sudo usermod -aG docker deploy
   ```

3. Install Tailscale ([instructions](https://tailscale.com/download/linux)) and join
   your tailnet:

   ```bash
   sudo tailscale up
   ```

   This is the only time `tailscale up` is needed. The scripts in this repository
   never run it.

4. Install the remaining tools:

   ```bash
   sudo apt install -y git make curl python3 rsync
   ```

5. Optional: once the server is reachable over Tailscale, close its public SSH port.
   Keep the provider's web console as a fallback.

**Check:** as the new user, `docker compose version` and `tailscale status` both
succeed.

Next: [Installation](installation.md).
