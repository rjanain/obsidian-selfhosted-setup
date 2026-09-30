# Roadmap

Ideas for after the sync setup has been running for a few weeks. None of this is
built yet, and none of it is needed for sync.

## AI second brain

Use an AI agent (for example Claude Code) to maintain part of the vault as a
knowledge base, following
[Karpathy's LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) pattern.

1. In the vault: add `CLAUDE.md` (rules for the agent), `raw/` (sources you drop
   in), `wiki/` (agent-owned), `index.md` and `log.md`.
2. Run the agent in the vault folder on a desktop for ingest, query and tidy-up
   sessions. Its edits sync to every device like any other edit.
3. Guardrails: the agent writes only in `wiki/` unless you ask, and you take a
   snapshot (`make backup`, or a Git commit of the vault) before and after each run.

## Server mirror

The server only ever holds encrypted chunks, so nothing running there can read
your notes. A mirror would change that on purpose: LiveSync's headless client
([`ghcr.io/vrtmrz/livesync-cli`](https://github.com/vrtmrz/obsidian-livesync/discussions/927))
runs on the server with your passphrase, as one more "device". It keeps a
decrypted Markdown copy of the vault in a folder there, and syncs changes both ways.

- **You gain:** agents and scheduled jobs that work on your notes 24/7 without a
  desktop switched on, and a Git history of every note.
- **You give up:** end-to-end encryption for that server. Anyone who gets into the
  server (or its provider) can read your notes.
- **Alternative:** if one of your desktops is always on, running agents there gives
  the same benefits without decrypted notes on the server.

If it's added, it would be an opt-in Compose profile, off by default.
