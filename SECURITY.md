# Security policy

## Reporting a vulnerability

Please report vulnerabilities privately through GitHub:
**Security → Report a vulnerability** on this repository. Don't open a public issue.

Include what you found, how to reproduce it, and the impact you expect. You'll get an
acknowledgement, and a fix or mitigation will be coordinated with you before any
public disclosure.

## Scope

In scope: the configuration and scripts in this repository, for example a script
that exposes CouchDB beyond loopback, leaks credentials, or modifies resources
outside the project.

Out of scope: vulnerabilities in the upstream projects. Report those to them directly:

- [Self-hosted LiveSync](https://github.com/vrtmrz/obsidian-livesync/security)
- [Apache CouchDB](https://couchdb.apache.org/#security)
- [Tailscale](https://tailscale.com/security)

## Security model

The protections this setup provides, and its limits, are described in
[docs/architecture.md](docs/architecture.md#security-model).

## Hardening checklist

- Generate long random passwords for `COUCHDB_PASSWORD` and `VAULT_PASSWORD`, and
  keep `.env` at mode 600.
- Turn on LiveSync's end-to-end and metadata encryption on every device, and keep the
  passphrase in a password manager.
- If other people share your tailnet, restrict who can reach the server's port with
  Tailscale access control policies.
- Keep off-box copies of the backups, and run `make restore-test` after upgrades.
- Hold LiveSync plugin updates for about a week after release.
