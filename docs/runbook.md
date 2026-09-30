# Runbook — phased rollout

Each phase ends with a check. Don't start the next phase until that check passes.

In the commands below, `<server>` is your server's full Tailscale name, for example
`my-vps.tail1234.ts.net` (it goes in `TS_HOSTNAME` in `.env`). Server commands run
in the project folder, `/opt/obsidian-livesync` by default.

| Phase | What | Time | Where |
| --- | --- | --- | --- |
| 0 | Decisions, server prep, Tailscale settings | ~30 min | Server, Tailscale admin console, devices |
| 1 | Server: CouchDB + `tailscale serve` | ~30 min | Server |
| 2 | First device (a desktop) | ~30 min | Obsidian on your main computer |
| 3 | Other devices | ~15 min each | Phones, tablets, other computers |
| 4 | Backups, restore test, off-box copy | ~1 h | Server, your computer |

Ideas for later (an AI "second brain" and a server mirror) are in
[roadmap.md](roadmap.md); they aren't part of this setup.

---

## Decisions to make first

**1. Where does your vault live today?** "Vault" is the folder of notes Obsidian
opens. If something already syncs it (iCloud Drive, Obsidian Sync, Dropbox,
OneDrive, Syncthing), switch that off for this vault before Phase 2. Two sync tools
on one folder fight each other and create duplicates and conflicts. On an iPhone or
iPad, a LiveSync vault must be stored **On My iPhone/iPad**, not in iCloud.

*Starting fresh, with no vault yet?* Nothing to move. Just create the new vault on
local disk in Phase 2. On a Mac, keep it out of iCloud Drive, and out of
`~/Documents` and `~/Desktop` if iCloud's "Desktop & Documents Folders" is on
(for example, use `~/Obsidian/<vault name>`).

**2. Which devices?** Every device needs Tailscale, Obsidian and the LiveSync
plugin. Desktop and mobile both work.

**3. Sync attachments (images, PDFs, audio)?** LiveSync syncs them like notes. The
cost is disk space on the server (the database is roughly the size of the vault,
plus history until compaction) and a longer first download on phones. LiveSync can
skip files above a size you set.

**4. Sync Obsidian's settings too?** Settings live in the vault's hidden
`.obsidian` folder:

| In `.obsidian` | What it is | Sync it? |
| --- | --- | --- |
| `app.json`, `appearance.json`, `hotkeys.json` | Editor options, theme and font choice, shortcuts | Usually yes |
| `core-plugins.json`, `community-plugins.json` | Which plugins are turned on | Yes |
| `plugins/<name>/` | Each community plugin's code and its settings (`data.json`) | Yes, with care: some plugins are desktop-only |
| `themes/`, `snippets/` | Downloaded themes and your CSS snippets | Yes |
| `workspace.json`, `workspace-mobile.json` | Open tabs and pane layout, rewritten constantly | No: it's per device |

LiveSync offers two ways, and you should pick **one**; the plugin's docs warn against
letting both manage the same files:

- **Customization Sync** (recommended). You give each device a name, and choose
  per item what to send and what to apply. It handles "the phone shouldn't get this
  desktop-only plugin" well.
- **Hidden File Sync.** Mirrors the `.obsidian` files as they are. Simpler, but
  blunter.

Turn either one on only after plain note sync works on every device (end of Phase 3).

**5. Enable Tailscale HTTPS certificates?** Needed if any device is a phone or
tablet: Obsidian mobile only connects to a server with a trusted certificate.
Inside the tailnet, traffic is already encrypted by WireGuard, so the certificate
isn't there for secrecy. It's there because the app requires it. The trade-off:
the certificate is public, so your machine name and tailnet name (for example
`my-vps.tail1234.ts.net`) appear in public Certificate Transparency logs. That
reveals a name only; the server stays unreachable from outside your tailnet.
Rename the machine in the Tailscale admin console first if the name matters to you.
Desktop-only setups could skip this, but this repo assumes HTTPS.

**6. Where do off-box backups go?** Weekly snapshots are kept on the server. A
copy somewhere else (an external drive, another computer, a cloud bucket) protects
you if the server is lost. See Phase 4.

---

## Phase 0 — Prepare

**Server** (any always-on Linux machine; full list in the README's Requirements):

1. Install Docker Engine with the Compose plugin: <https://docs.docker.com/engine/install/>.
   Add your user to the `docker` group (`sudo usermod -aG docker "$USER"`, then log
   out and back in).
2. Install Tailscale and join your tailnet: <https://tailscale.com/download/linux>.
   You run `sudo tailscale up` once here; this repo's scripts never run it.
3. Install the small tools the scripts use (Debian/Ubuntu shown):
   `sudo apt install -y git make curl python3 rsync`.

**Tailscale admin console:** [DNS settings](https://login.tailscale.com/admin/dns)
→ make sure **MagicDNS** is on, then **HTTPS Certificates → Enable** (decision 5).

**Devices** (skip if you're starting with a new, empty vault):

- Zip a copy of your current vault somewhere safe.
- Move the vault out of any other sync service (decision 1).

**Check** (server): `tailscale status --json | grep -A1 CertDomains` shows `<server>`.

---

## Phase 1 — Server

**Option A — clone on the server** (simplest):

```bash
sudo git clone https://github.com/rjanain/obsidian-selfhosted-setup.git /opt/obsidian-livesync
sudo chown -R "$USER": /opt/obsidian-livesync
cd /opt/obsidian-livesync
cp .env.example .env && chmod 600 .env   # set passwords and TS_HOSTNAME=<server>
```

**Option B — push from your computer** (keeps `.env` on your computer, too):

```bash
cp .env.example .env          # set passwords, TS_HOSTNAME, DEPLOY_HOST, DEPLOY_USER
make lint smoke-test          # optional: local throwaway stack, needs Docker
./scripts/deploy.sh --dry-run # shows it would create /opt/obsidian-livesync, nothing else
./scripts/deploy.sh --init --env
```

Generate each password with `openssl rand -base64 30 | tr -d '/+=' | cut -c1-32`,
and put them in your password manager.

Then, on the server:

```bash
cd /opt/obsidian-livesync
make up           # starts obsidian_couchdb (127.0.0.1:5984 only)
make provision    # vault DB + device user; all checks must say ok
make serve-on     # https://<server>:6984, tailnet only
```

**Check:** `make verify` prints "All checks passed". Run it from any tailnet machine
that has this repo and your `.env` (the server itself works too). Also open
`https://<server>:6984/_up` in a phone's browser with Tailscale on: it should show
`{"status":"ok"}` behind a valid padlock.

---

## Phase 2 — First device (a desktop)

Use the computer that holds the most up-to-date copy of the vault. Starting fresh?
Pick the computer that's on most often, create a new vault on local disk (see
decision 1), and write one note so the first upload has something in it.

1. Obsidian → Settings → Community plugins → Browse → install and enable
   **Self-hosted LiveSync**.
2. Run the setup wizard and choose to set up a new server connection manually:
   - Remote type: **CouchDB**
   - URI: `https://<server>:6984`
   - Username / password: `VAULT_USER` / `VAULT_PASSWORD` from `.env`
   - Database: `VAULT_DB` (default `obsidian_vault`)
3. Test the connection. The plugin's "check database configuration" step may say it
   can't read the server config. That's expected, because the device user isn't a
   server admin. `make provision` already applied the settings on the server.
4. Turn on **end-to-end encryption** with a new passphrase, and turn on metadata
   encryption. Put the passphrase in your password manager **before** continuing.
   If it's lost, the server copy can't be read.
5. Sync mode: **LiveSync**. Then do the initial upload (rebuild the remote from this vault).
6. Use the plugin's "copy setup URI" command, and save the URI and its passphrase in
   your password manager.
7. Don't install LiveSync updates on release day. Wait about a week; a bad release
   can break encrypted sync.

**Check:** `make verify` now shows a document count above 0, and an edit on this
computer survives an Obsidian restart.

---

## Phase 3 — Other devices

For each device:

1. Install Tailscale and sign in to the same tailnet.
   - iPhone / iPad: Tailscale settings → **VPN On Demand** on.
   - Android: system settings → VPN → Tailscale → **Always-on VPN**.
   - macOS / Windows / Linux: Tailscale set to start at login.
2. Install Obsidian and create an **empty** vault with the same name (on iPhone/iPad,
   stored On My iPhone/iPad).
3. Install Self-hosted LiveSync → choose "use a setup URI" → paste the URI →
   enter its passphrase → fetch everything from the remote.

**Check:** an edit on the phone appears on the desktop within seconds, and the reverse.

Settings sync (decision 4) can be turned on now, one device at a time.

---

## Phase 4 — Backups

There are three copies of your notes, and they protect against different things:

| Copy | Where | Protects against | Readable without tools? |
| --- | --- | --- | --- |
| The vault on each device | Every device | A device being lost | Yes, plain Markdown |
| Weekly snapshot | Server, `BACKUP_DIR` (newest 4) | Bad edits or deletes that synced everywhere; database damage | No: encrypted chunks |
| Off-box copy | External drive / other computer | Losing the server | Same as the snapshots |

The device copies are **not** backups on their own: a deletion syncs to every device
within seconds. The snapshots let you go back in time, to any of the last four
Sundays. Because they're weekly, up to a week of changes isn't in any snapshot yet,
so run `make backup` by hand before anything risky (a CouchDB upgrade, a LiveSync
rebuild, a big reorganisation of the vault).

On the server:

```bash
make backup                 # snapshot now → BACKUP_DIR
make restore-test           # boots the snapshot in a throwaway CouchDB on :15984
make install-backup-timer   # weekly, Sunday 03:30; keeps the newest 4 (runs as you, from this folder)
```

On your computer, copy the snapshots off the server (uses `DEPLOY_USER`,
`DEPLOY_HOST` and `BACKUP_DIR` from `.env`):

```bash
make pull-backups DEST=/Volumes/<drive>/obsidian-livesync-backups
```

It only copies snapshots that aren't there yet, and never deletes anything on the
drive, so the drive keeps every snapshot until you remove old ones yourself. Run it
once a week, any time after the Sunday snapshot, whenever the drive is plugged in.

A snapshot holds encrypted chunks. Restoring one needs Docker (to run CouchDB) and
your LiveSync passphrase; reading notes then goes through Obsidian + LiveSync. For a
copy you can open without any of that, also keep a plain copy of the vault folder on
the drive, for example with Time Machine or a dated zip of the vault.

**Check:** `make restore-test` prints "Restore test passed", and
`systemctl list-timers obsidian-couchdb-backup.timer` shows the next run.

---

## Operations

| Task | Command |
| --- | --- |
| Status / logs | `make ps` · `make logs` (server) |
| Rotate the device password | edit `VAULT_PASSWORD` in `.env` (and `make deploy-env` if you use Option B) → server: `make provision` → update each device |
| Upgrade CouchDB | bump the tag in `docker-compose.yml` → `make smoke-test` → deploy (git pull or `make deploy`) → server: `make pull up` |
| Take the endpoint offline | server: `make serve-off` (CouchDB keeps running on loopback) |
| Add a second vault | server: `VAULT_DB=work_vault VAULT_USER=work VAULT_PASSWORD=... bash scripts/provision.sh` |

### Uninstall (leaves everything else on the server alone)

```bash
make serve-off
sudo systemctl disable --now obsidian-couchdb-backup.timer
sudo rm /etc/systemd/system/obsidian-couchdb-backup.{service,timer} && sudo systemctl daemon-reload
docker compose down            # add -v to delete the data volumes (irreversible)
sudo rm -rf /opt/obsidian-livesync
```
