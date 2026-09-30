# Configuration reference

All settings live in `.env` in the project folder. Copy `.env.example` to `.env` and
keep it private (mode 600). Git ignores it.

## CouchDB and vault

| Variable | Default | Description |
| --- | --- | --- |
| `COUCHDB_USER` | *(required)* | Server admin username. Used only on the server; devices never use it. |
| `COUCHDB_PASSWORD` | *(required)* | Server admin password. Stored in the `couchdb_etc` volume the first time CouchDB starts; see [rotation](operations.md#server-admin-password-couchdb_password). |
| `VAULT_DB` | `obsidian_vault` | Database for the vault. Lowercase; starts with a letter. |
| `VAULT_USER` | `obsidian` | Device user. Admin of `VAULT_DB` only; no server-wide rights. Must differ from `COUCHDB_USER`. |
| `VAULT_PASSWORD` | *(required)* | Device user's password. `make provision` applies it. |
| `COUCHDB_LOCAL_PORT` | `5984` | CouchDB's port on the server's loopback interface. |
| `COUCHDB_CONTAINER` | `obsidian_couchdb` | Container name. Used by Compose and the backup script. |

## Tailscale

| Variable | Default | Description |
| --- | --- | --- |
| `TS_HOSTNAME` | *(required)* | The server's full MagicDNS name, e.g. `my-vps.tail1234.ts.net`. Must match the certificate. |
| `TS_HTTPS_PORT` | `6984` | Tailnet HTTPS port. `make serve-on` refuses a port that's already in use. |

## Deployment from a workstation (Option B)

| Variable | Default | Description |
| --- | --- | --- |
| `DEPLOY_HOST` | *(required for Option B)* | The server's Tailscale name or `100.x` address. Also used by `make pull-backups`. |
| `DEPLOY_USER` | `deploy` | SSH user on the server. Needs `sudo` and membership of the `docker` group. |
| `REMOTE_DIR` | `/opt/obsidian-livesync` | Install folder. Must be an absolute path ending in `/obsidian-livesync`. |

## Backups

| Variable | Default | Description |
| --- | --- | --- |
| `BACKUP_DIR` | `<project folder>/backups` | Snapshot folder on the server. `.env.example` sets `/opt/obsidian-livesync/backups`. |
| `BACKUP_KEEP` | `4` | Number of snapshots to keep; older ones are deleted after each new snapshot. |
| `RESTORE_TEST_PORT` | `15984` | Loopback port for the throwaway CouchDB used by `make restore-test`. |

## Script overrides

These are read from the environment, not from `.env`:

| Variable | Used by | Description |
| --- | --- | --- |
| `ENV_FILE` | All scripts | Path to an alternative env file. The smoke test uses this. |
| `COUCH_URL` | `scripts/provision.sh` | CouchDB URL to provision. Default `http://127.0.0.1:$COUCHDB_LOCAL_PORT`. |

## Files

| File | Purpose |
| --- | --- |
| `docker-compose.yml` | CouchDB service: image, loopback port, resource limits, health check. |
| `couchdb/livesync.ini` | CouchDB settings LiveSync needs: authentication, CORS, size limits. Copied into the container at start. |
| `deploy/systemd/obsidian-couchdb-backup.{service,timer}` | Weekly backup job. `make install-backup-timer` fills in the user and folder. |
