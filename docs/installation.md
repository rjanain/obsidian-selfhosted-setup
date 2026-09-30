# Installation

This guide installs the CouchDB server and publishes it on your tailnet. Before you
start, meet the [requirements](requirements.md) and
[prepare the server](requirements.md#preparing-the-server).

In this guide, `<server>` is the server's full Tailscale name, for example
`my-vps.tail1234.ts.net`. To print it, run this on the server:

```bash
tailscale status --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))'
```

## 1. Configure Tailscale

In the [admin console DNS settings](https://login.tailscale.com/admin/dns), turn on
**MagicDNS**, then **HTTPS Certificates → Enable**.

> **Privacy note.** Obsidian's mobile apps only connect to servers with a publicly
> trusted certificate, so certificates are required whenever a phone or tablet
> syncs. Traffic is already encrypted by WireGuard inside the tailnet; the
> certificate exists because the app requires it.
>
> Every publicly trusted certificate is recorded in the public, append-only
> Certificate Transparency logs. The server's name (`<machine>.<tailnet>.ts.net`)
> therefore becomes public and permanent. The name does not reveal the server's IP
> address or grant access, and only machines that request a certificate are listed.
> If the machine name reveals anything you'd rather keep private, rename it in the
> admin console **before** enabling certificates.

**Check** (on the server): `tailscale status --json | grep -A1 CertDomains` lists
`<server>`.

## 2. Install and configure

Choose one option.

### Option A: clone on the server (recommended)

```bash
sudo git clone https://github.com/rjanain/obsidian-selfhosted-setup.git /opt/obsidian-livesync
sudo chown -R "$USER": /opt/obsidian-livesync
cd /opt/obsidian-livesync
cp .env.example .env && chmod 600 .env
```

Edit `.env` and set at least:

| Setting | Value |
| --- | --- |
| `COUCHDB_PASSWORD` | A new random password (server admin; stays on the server) |
| `VAULT_PASSWORD` | A new random password (used by your devices) |
| `TS_HOSTNAME` | `<server>` |

Generate each password with `openssl rand -base64 30 | tr -d '/+=' | cut -c1-32`,
and store it in your password manager. All settings are described in
[configuration.md](configuration.md).

### Option B: push from your workstation

Keeps the working copy and `.env` on your computer. `deploy.sh` copies files over
SSH and never starts or restarts anything.

```bash
cp .env.example .env                  # set the values above, plus DEPLOY_HOST and DEPLOY_USER
make lint smoke-test                  # optional: tests the stack locally (needs Docker)
./scripts/deploy.sh --init --dry-run  # preview: shows it would create /opt/obsidian-livesync
./scripts/deploy.sh --init --env      # create the folder, copy the files and .env (mode 600)
```

Later deployments are `make deploy` (files only) or `make deploy-env` (files and
`.env`).

## 3. Start, provision and publish

On the server, in `/opt/obsidian-livesync`:

```bash
make up           # start CouchDB on 127.0.0.1:5984 (loopback only)
make provision    # create the vault database and the device user
make serve-on     # publish https://<server>:6984 on the tailnet
```

- `make provision` is idempotent. It finishes with three checks, and all of them must
  report `ok`: the device user can open the vault, it cannot read server settings,
  and anonymous requests are refused.
- `make serve-on` refuses to run if HTTPS certificates are off, if `TS_HOSTNAME`
  doesn't match the certificate, or if the port is already in use.

## 4. Verify

Run `make verify` from any machine on the tailnet that has this repository and your
`.env`. The server itself works too.

```text
=== Verifying https://<server>:6984 (database obsidian_vault, user obsidian) ===
  ok    /_up answers over HTTPS with a trusted certificate
        cert: issuer=C=US, O=Let's Encrypt, CN=... notAfter=...
  ok    anonymous access refused (401)
  ok    obsidian can open obsidian_vault (0 documents)
  ok    CORS preflight allows app://obsidian.md with credentials
  ok    CORS preflight allows capacitor://localhost with credentials
  ok    no plain-HTTP path: <server>:5984 is closed

All checks passed.
```

The first HTTPS request after `make serve-on` can take a few seconds while Tailscale
obtains the certificate.

**Check:** `make verify` prints `All checks passed`. On a phone with Tailscale on,
`https://<server>:6984/_up` shows `{"seeds":{},"status":"ok"}` behind a valid padlock.

## Next steps

1. [Connect your devices](device-setup.md).
2. [Schedule backups](backups.md).
