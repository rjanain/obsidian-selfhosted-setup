# =============================================================================
# Makefile — obsidian-livesync
# =============================================================================
# Server targets run in the project folder on the server (default
# /opt/obsidian-livesync). Local targets (deploy, verify, pull-backups,
# smoke-test, lint) run on your computer.
# =============================================================================
.PHONY: help up down restart pull ps logs provision serve-on serve-off serve-status \
        backup list-backups restore-test install-backup-timer \
        deploy deploy-env verify pull-backups smoke-test lint

COMPOSE = docker compose

help:        ## List targets
	@awk 'BEGIN{FS=":.*## "} /^[a-z-]+:.*## /{printf "  %-22s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

## ── Server: stack lifecycle ─────────────────────────────────────────────────

up:          ## Start CouchDB (detached)
	$(COMPOSE) up -d
	@$(COMPOSE) ps

down:        ## Stop CouchDB (volumes kept)
	$(COMPOSE) down

restart:     ## Restart CouchDB
	$(COMPOSE) restart

pull:        ## Pull the pinned CouchDB image
	$(COMPOSE) pull

ps:          ## Container status
	$(COMPOSE) ps

logs:        ## Tail CouchDB logs
	$(COMPOSE) logs -f --tail=100

## ── Server: setup ────────────────────────────────────────────────────────────

provision:   ## Create the vault DB + device user (idempotent; resets the user's password)
	@bash scripts/provision.sh

serve-on:    ## Publish CouchDB at https://<TS_HOSTNAME>:<TS_HTTPS_PORT> (tailnet only)
	@bash scripts/tailscale-serve.sh on

serve-off:   ## Remove this project's tailscale serve handler
	@bash scripts/tailscale-serve.sh off

serve-status: ## Show tailscale serve config + certificate domains
	@bash scripts/tailscale-serve.sh status

## ── Server: backups ──────────────────────────────────────────────────────────

backup:      ## Snapshot CouchDB volumes to BACKUP_DIR now (keeps the newest BACKUP_KEEP)
	@bash scripts/backup.sh

list-backups: ## List snapshots
	@. ./.env; ls -lh "$${BACKUP_DIR:-backups}" 2>/dev/null || echo "(no backups yet)"

restore-test: ## Boot the newest snapshot in a throwaway CouchDB and check it
	@bash scripts/restore-test.sh

install-backup-timer: ## Install + start the weekly backup timer (Sun 03:30, systemd; runs as you, from this folder)
	sed -e 's|@USER@|$(shell id -un)|g' -e 's|@GROUP@|$(shell id -gn)|g' -e 's|@DIR@|$(CURDIR)|g' \
		deploy/systemd/obsidian-couchdb-backup.service \
		| sudo tee /etc/systemd/system/obsidian-couchdb-backup.service >/dev/null
	sudo chmod 644 /etc/systemd/system/obsidian-couchdb-backup.service
	sudo install -m 644 deploy/systemd/obsidian-couchdb-backup.timer /etc/systemd/system/
	sudo systemctl daemon-reload
	sudo systemctl enable --now obsidian-couchdb-backup.timer
	systemctl list-timers obsidian-couchdb-backup.timer --no-pager

## ── Local (your computer) ──────────────────────────────────────────────────────

deploy:      ## Push files to the server (no restart)
	@bash scripts/deploy.sh

deploy-env:  ## Push files + .env to the server
	@bash scripts/deploy.sh --env

verify:      ## End-to-end check of the tailnet endpoint, as a device sees it
	@bash scripts/verify.sh

pull-backups: ## Copy the server's snapshots off-box: make pull-backups DEST=/Volumes/<drive>/obsidian-livesync-backups
	@test -n "$(DEST)" || (echo "Usage: make pull-backups DEST=<dir>" && exit 1)
	@set -a; . ./.env; set +a; \
	rsync -av "$${DEPLOY_USER}@$${DEPLOY_HOST}:$${BACKUP_DIR}/" "$(DEST)/"

smoke-test:  ## Boot a throwaway stack locally, provision, verify, back up, restore, tear down
	@bash scripts/smoke-test.sh

lint:        ## shellcheck + compose config
	shellcheck -x scripts/*.sh
	COUCHDB_USER=x COUCHDB_PASSWORD=x $(COMPOSE) config -q
