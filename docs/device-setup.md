# Device setup

This guide connects Obsidian on each device to the server. Finish the
[installation](installation.md) first: `make verify` must pass.

You need these values from `.env`:

| LiveSync field | Value |
| --- | --- |
| URI | `https://<server>:6984` (`TS_HOSTNAME`, `TS_HTTPS_PORT`) |
| Username | `VAULT_USER` (default `obsidian`) |
| Password | `VAULT_PASSWORD` |
| Database | `VAULT_DB` (default `obsidian_vault`) |

## Before you begin

### Vault location

A vault is the folder of notes Obsidian opens. LiveSync must be the **only** sync
tool for it. If iCloud Drive, Obsidian Sync, Dropbox, OneDrive or Syncthing already
syncs the vault, switch that off first, after zipping a copy somewhere safe. Two sync
tools on one folder create duplicates and conflicts.

- **macOS:** keep the vault out of iCloud Drive. Also keep it out of `~/Documents` and
  `~/Desktop` if iCloud's "Desktop & Documents Folders" setting is on. For example,
  use `~/Obsidian/<vault name>`.
- **iOS and iPadOS:** store the vault **On My iPhone/iPad**. When creating it, turn
  **Store in iCloud** off.

### Attachments

LiveSync syncs images, PDFs and audio like notes. The cost is disk space on the server
and a longer first download on phones. The plugin can skip files above a size you set.

## First device

Use the computer that holds the most up-to-date copy of the vault. If you're starting
fresh, use the computer that's switched on most often, create a new vault, and write
one note so the first upload has something in it.

1. Install and sign in to Tailscale, set to start at login.
2. In Obsidian, open **Settings → Community plugins**, turn community plugins on,
   then **Browse → Self-hosted LiveSync → Install → Enable**.
3. In the LiveSync setup wizard, choose to set up a server connection manually. Pick
   **CouchDB** and enter the values from the table above.
4. Test the connection. The wizard's database configuration check reports
   **Access forbidden**. This is expected (see [expected messages](#expected-messages)).
5. When asked about the remote's synchronisation settings, choose **Use this device's
   settings**.
6. Turn on **end-to-end encryption** and **metadata encryption**, with a new
   passphrase. Store the passphrase in your password manager **before** continuing:
   without it, nothing on the server can be read.
7. Choose the **LiveSync** sync mode, then run the initial upload (rebuild the remote
   from this vault).
8. Run **Copy setup URI** and store the URI and its passphrase in your password
   manager. Other devices join with it.

**Check:** `make verify` reports a document count above 0, and an edit survives an
Obsidian restart.

### Expected messages

| Message | Meaning | Action |
| --- | --- | --- |
| *Checking database configuration: ❗ Access forbidden. We could not continue the test.* | The check reads CouchDB's server-wide settings, which requires the server admin. The device user is deliberately not an admin; the settings were applied when the server started (`couchdb/livesync.ini`). | None. Skip any "Fix" buttons. |
| *The selected remote has no saved synchronisation settings. This is normal for a new remote.* | The database is new. | On the first device, choose **Use this device's settings**. On a later device, this most likely means the wrong URI or database name: cancel and check them. |

## Additional devices

For each device:

1. Install Tailscale and sign in to the same tailnet.
   - **iOS / iPadOS:** Tailscale settings → **VPN On Demand** on.
   - **Android:** system settings → VPN → Tailscale → **Always-on VPN**.
   - **macOS / Windows / Linux:** start Tailscale at login.
2. Install Obsidian and create an **empty** vault with the same name (see
   [vault location](#vault-location)).
3. Install Self-hosted LiveSync, choose **Use a setup URI**, paste the URI, enter its
   passphrase, and fetch everything from the remote.

**Check:** an edit on one device appears on the others within seconds.

## Settings sync (optional)

Obsidian keeps its settings in the vault's hidden `.obsidian` folder:

| Path in `.obsidian` | Contents | Sync? |
| --- | --- | --- |
| `app.json`, `appearance.json`, `hotkeys.json` | Editor options, theme and font, shortcuts | Usually |
| `core-plugins.json`, `community-plugins.json` | Which plugins are enabled | Yes |
| `plugins/<name>/` | Each community plugin's code and settings | Yes, with care: some plugins are desktop-only |
| `themes/`, `snippets/` | Themes and CSS snippets | Yes |
| `workspace.json`, `workspace-mobile.json` | Open tabs and layout | No: per device |

LiveSync offers two mechanisms. Use **one**; the plugin's documentation warns
against letting both manage the same files.

- **Customization Sync (recommended):** each device has a name, and you choose per
  item what to send and apply. Handles desktop-only plugins well.
- **Hidden File Sync:** mirrors `.obsidian` as-is. Simpler, but less selective.

Turn it on only after note sync works on every device, one device at a time.

## Plugin updates

Don't install LiveSync updates on release day. Wait about a week: a faulty release
can break encrypted sync on every device at once.

For other problems, see [troubleshooting](operations.md#troubleshooting).
