# Backups

## Overview

Your notes exist in three places, and each protects against something different:

| Copy | Location | Protects against | Readable without tools |
| --- | --- | --- | --- |
| The vault on each device | Every device | Losing a device | Yes, plain Markdown |
| Server snapshots | `BACKUP_DIR` on the server | Bad edits or deletions that synced everywhere; database damage | No: encrypted chunks |
| Off-box copies | External drive or another computer | Losing the server | No: same as the snapshots |

The device copies are **not** backups on their own: a deletion reaches every device
within seconds. Snapshots let you go back in time.

## Schedule and retention

| Setting | Default | Where |
| --- | --- | --- |
| Schedule | Weekly, Sunday 03:30 server time (up to 10 minutes later; a missed run happens at the next boot) | `deploy/systemd/obsidian-couchdb-backup.timer` |
| Retention | Newest 4 snapshots (the last four weeks) | `BACKUP_KEEP` in `.env` |
| Location | `/opt/obsidian-livesync/backups`, directory mode 700, files mode 600 | `BACKUP_DIR` in `.env` |

Each snapshot is a full copy of CouchDB's data and configuration volumes, taken while
it runs (CouchDB's storage files are append-only, so this is safe).

Because snapshots are weekly, up to a week of changes may not be in any snapshot yet.
Take one by hand with `make backup` before anything risky: a CouchDB upgrade, a
LiveSync rebuild, or a large reorganisation of the vault.

## Setup

On the server, in `/opt/obsidian-livesync`:

```bash
make backup                 # take a snapshot now
make install-backup-timer   # install and start the weekly timer (runs as you, from this folder)
```

**Check:** `systemctl list-timers obsidian-couchdb-backup.timer` shows the next run.

## Restore test

```bash
make restore-test
```

This unpacks the newest snapshot into a temporary folder, boots it in a throwaway
CouchDB on `127.0.0.1:15984`, and checks that the device user can open the vault and
that it holds documents. The live database and the tailnet endpoint are never touched.

Run it after the first device has uploaded; before that, the vault is empty and the
test reports a failure on purpose. Repeat it after upgrades, and periodically.

**Check:** `make restore-test` prints `Restore test passed`.

## Off-box copies

From your workstation, copy the snapshots off the server. This uses `DEPLOY_USER`,
`DEPLOY_HOST` and `BACKUP_DIR` from `.env`:

```bash
make pull-backups DEST=/Volumes/<drive>/obsidian-livesync-backups
```

It copies only new snapshots and never deletes anything at the destination, so the
drive keeps every snapshot until you remove old ones. Run it once a week, any time
after the Sunday snapshot.

## Reading a snapshot

Snapshots contain encrypted chunks. Restoring one needs Docker (to run CouchDB) and
your LiveSync passphrase; the notes are then read through Obsidian and LiveSync. For a
copy you can open without any of that, also keep a plain copy of the vault folder on
the same drive, for example with Time Machine or a dated zip of the vault.
