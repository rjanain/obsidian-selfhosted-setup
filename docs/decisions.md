# Design decisions

Short records of the choices baked into this repo, and why.

| # | Decision | Why |
| --- | --- | --- |
| 1 | **CouchDB backend**, not object storage (S3/MinIO) or P2P | Only CouchDB gives LiveSync's real-time mode with an always-on server. The S3 mode is periodic only; P2P needs a peer with the data online. |
| 2 | **`tailscale serve` on :6984**, not a public reverse proxy or Funnel | A trusted HTTPS certificate (which mobile Obsidian requires) with zero public exposure: no domain, no open port, no reverse proxy. 6984 is CouchDB's usual HTTPS port and leaves 443 free for anything else on the server. |
| 3 | **CouchDB binds to 127.0.0.1 only** | `tailscale serve` is the single way in; there is no plain-HTTP path, even inside the tailnet. `verify.sh` checks this. |
| 4 | **Separate Compose project in its own folder** (default `/opt/obsidian-livesync`) | Own network, volumes and container names (`obsidian-livesync_*`, `obsidian_couchdb`), so it can share a server with other Docker stacks. `deploy.sh` only writes to a folder named `obsidian-livesync` that already holds this project. |
| 5 | **No scheduler labels; backups use a systemd timer** | Label-based schedulers such as Ofelia (`ofelia daemon --docker`) adopt job labels from every container on the host. Labels here could be picked up by another stack's scheduler, and a second scheduler could re-run other stacks' jobs. A systemd timer has no such side effect. |
| 6 | **Device user is admin of its vault DB only** | LiveSync writes `_design/chunks` (chunk garbage collection), which needs DB-admin; members-only would break it. The user has no server roles and can't read `_config` or create databases (the smoke test checks both). |
| 7 | **The ini is copied into `default.d` at start**, not bind-mounted there | The stock entrypoint runs `find /opt/couchdb … -exec chown` under `set -e`; a read-only file under `/opt/couchdb` makes it exit 1 with no logs. Copying first keeps `tini` and the stock entrypoint. |
| 8 | **`require_valid_user_except_for_up = true`** | Lets the healthcheck and `verify.sh` hit `/_up` without credentials. It only ever returns `{"status":"ok"}`. |
| 9 | **Pinned `couchdb:3.5.2`** | Reproducible deploys. Upgrades go through `make smoke-test` first. |
| 10 | **Scripts never call `tailscale up`** | `tailscale up` without the flags the host was first brought up with (`--ssh`, `--advertise-exit-node`, `--hostname`…) can reset them. The scripts only use `tailscale serve`, and `serve-on` refuses a port that is already in use. |
| 11 | **512 MB / 1 CPU limits, `oom_score_adj: -500`** | Sized for a small VPS shared with other workloads. As a data store, CouchDB should outlive less important processes under memory pressure. |
