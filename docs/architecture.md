# Architecture

## Components

| Component | Role |
| --- | --- |
| Obsidian + Self-hosted LiveSync | Client. Encrypts notes on the device and replicates them to CouchDB. |
| Tailscale (devices) | Puts each device on the private tailnet (WireGuard). |
| `tailscale serve` (server) | The only listener: HTTPS on `:6984` for tailnet members, with a certificate Tailscale obtains from Let's Encrypt. Proxies to CouchDB on loopback. |
| CouchDB 3.5 (`obsidian_couchdb`) | Stores the encrypted vault. Bound to `127.0.0.1:5984`. |
| systemd timer | Weekly snapshot of CouchDB's volumes (`scripts/backup.sh`). |

## Request flow

```
Device                          Server
Obsidian + LiveSync             tailscaled (serve)                 CouchDB
      │  WireGuard tunnel       │                                  │
      └── HTTPS :6984 ─────────▶│ TLS termination ── HTTP ────────▶│ 127.0.0.1:5984
                                │ (tailnet members only)           │ auth: device user
```

1. LiveSync sends a request to `https://<server>:6984` over the tailnet.
2. `tailscaled` on the server terminates TLS and forwards it to `127.0.0.1:5984`.
3. CouchDB authenticates the device user (HTTP Basic over TLS) and applies the
   database's access rules.

## Security model

### What is protected, and how

| Layer | Control |
| --- | --- |
| Network | No public listener. CouchDB binds to loopback; the only path is `tailscale serve`, reachable by tailnet members only. `make verify` confirms the plain-HTTP port is closed. |
| Transport | WireGuard between devices and server, plus TLS on the HTTPS endpoint. |
| Authentication | Anonymous requests are refused (except `/_up`, which only reports health). Devices use a dedicated user that is admin of the vault database only: it can't read server settings or create databases. The admin account is used only on the server. |
| Data at rest | LiveSync encrypts notes and metadata on the device before upload. The passphrase never leaves your devices; the server stores ciphertext only. |
| Backups | Snapshots contain the same ciphertext. The backup folder is mode 700 and snapshots are mode 600. |
| Secrets handling | `.env` is mode 600 and ignored by Git. Scripts pass credentials to `curl` through temporary 0600 config files, never on the command line. |
| Host isolation | Own folder, Compose project, network and volumes. Scripts never run `tailscale up`, and `deploy.sh` refuses to write outside a folder named `obsidian-livesync`. |

### What is not protected

- **Server compromise:** an attacker with root on the server can't read notes, but can
  delete or corrupt the database. Off-box backups cover this.
- **Metadata:** the server sees the number and size of encrypted chunks and when
  devices sync.
- **Machine name:** the server's Tailscale name is published in Certificate
  Transparency logs ([details](installation.md#1-configure-tailscale)).
- **Device compromise:** anyone with access to an unlocked device can read its vault.
- **Tailnet membership:** every member of the tailnet can reach port 6984 and attempt
  to log in. If others share your tailnet, restrict access with Tailscale access
  control policies.

## Compared with alternatives

| | Obsidian Sync | LiveSync on a public server | This project |
| --- | --- | --- | --- |
| Where notes are stored | Obsidian's servers | Your server | Your server |
| Reachable from the internet | Yes (their service) | Yes: a login endpoint anyone can find | No: tailnet members only |
| You maintain | Nothing | Domain, reverse proxy, certificates, firewall | Docker and Tailscale |
| Cost | Subscription | Server and domain | Server (Tailscale's free plan is enough) |

The reasoning behind each design choice is recorded in [decisions.md](decisions.md).
