# Operations

Server commands run in `/opt/obsidian-livesync`. Run `make help` for every target.

## Routine tasks

| Task | Command |
| --- | --- |
| Container status | `make ps` |
| Follow logs | `make logs` |
| Check the endpoint end to end | `make verify` (any tailnet machine with the repository and `.env`) |
| Show the tailnet endpoint and certificate | `make serve-status` |
| Take the endpoint offline | `make serve-off` (CouchDB keeps running on loopback) |
| Bring it back | `make serve-on` |
| Take a snapshot now | `make backup` |
| List snapshots | `make list-backups` |

## Updating this repository

1. Get the new files: `git pull` on the server (Option A), or `make deploy` from your
   workstation (Option B).
2. Apply any changes: `make up`. Compose recreates the container only if its
   configuration changed. If `couchdb/livesync.ini` changed, also run `make restart`:
   the file is copied into the container at start.
3. Run `make verify`.

## Upgrading CouchDB

1. Change the image tag in `docker-compose.yml`, then run `make smoke-test` on your
   workstation.
2. On the server, take a snapshot with `make backup`.
3. Deploy the change (see above), then run `make pull up`.
4. Run `make verify` and `make restore-test`.

## Rotating credentials

### Device password (`VAULT_PASSWORD`)

1. Set a new `VAULT_PASSWORD` in `.env` (then `make deploy-env` if you use Option B).
2. On the server: `make provision`. It resets the device user's password to the value
   in `.env`.
3. Update the password in LiveSync on each device.

### Server admin password (`COUCHDB_PASSWORD`)

CouchDB stores the admin password in the `couchdb_etc` volume the first time it
starts. Changing `COUCHDB_PASSWORD` in `.env` afterwards has no effect on its own.
To rotate it, on the server:

```bash
# Prompts for the current password; the new one is sent as a JSON string.
curl -u "<COUCHDB_USER>" -X PUT \
  "http://127.0.0.1:5984/_node/_local/_config/admins/<COUCHDB_USER>" \
  -d '"<new password>"'
```

Then set the same value as `COUCHDB_PASSWORD` in `.env`. The new password takes
effect within a second and persists across restarts.

## Adding a second vault

Each vault gets its own database and device user:

```bash
VAULT_DB=work_vault VAULT_USER=work VAULT_PASSWORD='<password>' bash scripts/provision.sh
```

Devices connect to the same URI with the new username, password and database.

## Troubleshooting

| Symptom | Cause | Resolution |
| --- | --- | --- |
| `make serve-on`: *Tailnet HTTPS certificates are not enabled* | Certificates are off for the tailnet. | Enable them ([installation step 1](installation.md#1-configure-tailscale)); the change reaches the server within a few seconds. |
| `make serve-on`: *Certificates cover '…', not TS_HOSTNAME* | `TS_HOSTNAME` in `.env` doesn't match the machine's Tailscale name. | Set `TS_HOSTNAME` to the name printed by `make serve-status`. |
| `make serve-on`: *Port … already serves* or *already listens* | Another service uses `TS_HTTPS_PORT`. | Choose another port in `.env`. |
| TLS error on the first request after `make serve-on` | Tailscale is still obtaining the certificate. | Retry after a few seconds. |
| `make provision`: *Admin login failed* | `COUCHDB_PASSWORD` in `.env` differs from the stored admin password. | Restore the previous value in `.env`, or follow [admin password rotation](#server-admin-password-couchdb_password). |
| LiveSync: *Access forbidden* during the database configuration check | Expected: the device user can't read server settings. | None. See [expected messages](device-setup.md#expected-messages). |
| LiveSync: *The selected remote has no saved synchronisation settings* | New database, or wrong URI or database name. | First device: use this device's settings. Otherwise check the URI and database. |
| A device can't connect | Tailscale is off on the device, or it's signed in to another tailnet. | Turn Tailscale on; then open `https://<server>:6984/_up` in the device's browser. |
| `make restore-test`: *is empty in this snapshot* | The snapshot was taken before any device uploaded. | Expected before the first upload. Take a new snapshot with `make backup` and rerun. |
| Container exits at start with code 1 and no logs | A read-only file was mounted under `/opt/couchdb`. | Mount files elsewhere and copy them in at start, as `docker-compose.yml` does ([decision 7](decisions.md)). |

## Uninstalling

These steps remove only this project and leave everything else on the server alone.

```bash
make serve-off
sudo systemctl disable --now obsidian-couchdb-backup.timer
sudo rm /etc/systemd/system/obsidian-couchdb-backup.{service,timer} && sudo systemctl daemon-reload
docker compose down            # add -v to delete the data volumes (irreversible)
sudo rm -rf /opt/obsidian-livesync
```
