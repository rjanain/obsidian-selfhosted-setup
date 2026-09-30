# Contributing

Contributions are welcome: bug reports, documentation fixes, and improvements to the
scripts.

## Development setup

You need Docker, `make`, `bash`, `curl`, `python3`, `openssl` and
[ShellCheck](https://www.shellcheck.net/).

```bash
make lint         # shellcheck on every script, and a Compose config check
make smoke-test   # boots a throwaway stack locally and exercises every script
```

`make smoke-test` uses its own Compose project, container name, random credentials
and ports (25984/25985), so it never touches a real deployment. CI runs both targets
on every push and pull request.

## Guidelines

- **Scripts:** Bash with `set -euo pipefail`, ShellCheck-clean, and safe to re-run.
  Pass credentials to `curl` through `curl_auth_cfg` (`scripts/lib.sh`), never on the
  command line.
- **Stay out of other stacks:** don't add anything that touches resources outside
  this project, such as other containers, public ports, `tailscale up`, or host-wide
  scheduler labels. The reasons are in [docs/decisions.md](docs/decisions.md).
- **Documentation:** update the relevant guide in [`docs/`](docs/README.md) in the
  same change as the behaviour it describes. Record new design choices in
  `docs/decisions.md`.
- **No personal details:** never commit `.env`, hostnames, tailnet names or IP
  addresses. Use placeholders such as `<server>` and `your-server.your-tailnet.ts.net`.

## Pull requests

1. Branch from `main`.
2. Use [Conventional Commits](https://www.conventionalcommits.org/) for messages, for
   example `fix: …`, `feat: …`, `docs: …`.
3. Make sure `make lint smoke-test` passes.
4. Describe what changed and how you tested it.
