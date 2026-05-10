# =============================================================================
# SDLC Agent Framework — Makefile
# =============================================================================
# Usage:
#   make setup PROJECT=myapp          # one-command bootstrap (installs everything)
#   make index REPO=/path/to/project  # index a codebase
#   make query Q="auth token logic"   # run a RAG search
#   make help                         # list all targets
#
# All variables can be overridden via env or CLI:
#   PROJECT=myapp REPO=~/code/myapp make index
# =============================================================================

# ── Configurable variables ────────────────────────────────────────────────────

PROJECT          ?= $(shell echo $${AGENTS_PROJECT:-default})
REPO             ?= $(shell echo $${REPO_ROOT:-.})
VENV             ?= $(HOME)/.sdlc-agents-venv
WEAVIATE_URL     ?= $(shell echo $${AGENTS_WEAVIATE_URL:-http://localhost:8090})
WEAVIATE_PORT    ?= 8090
WEAVIATE_VERSION ?= 1.36.9

# Primary language of the indexed project. Used by multi-query to add a
# language-specific query variant. Set to your project's main language.
# Options: typescript, javascript, python, java, kotlin, php, go, ruby, rust, csharp, swift, scala
LANGUAGE         ?= $(shell echo $${AGENTS_LANGUAGE:-})

PYTHON   := $(VENV)/bin/python
PIP      := $(VENV)/bin/pip
SCRIPTS  := $(CURDIR)/scripts

# Docker targets use this compose file
COMPOSE_FILE := $(CURDIR)/docker-compose.yml

# ── Phony targets ─────────────────────────────────────────────────────────────

.PHONY: help setup install start stop status restart \
        schema index full-index index-standards index-prs migrate \
        query stats prune \
        docker-start docker-stop docker-restart docker-status \
        claude-setup clean

# ── Default: show help ────────────────────────────────────────────────────────

help: ## Show this help message
	@echo ""
	@echo "SDLC Agent Framework"
	@echo "===================="
	@echo ""
	@echo "Usage: make <target> [PROJECT=myapp] [REPO=/path/to/project] [Q=\"query\"]"
	@echo ""
	@printf "%-22s %s\n" "Target" "Description"
	@printf "%-22s %s\n" "------" "-----------"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Current settings:"
	@echo "  PROJECT          = $(PROJECT)"
	@echo "  LANGUAGE         = $(if $(LANGUAGE),$(LANGUAGE),(not set))"
	@echo "  REPO             = $(REPO)"
	@echo "  VENV             = $(VENV)"
	@echo "  WEAVIATE_URL     = $(WEAVIATE_URL)"
	@echo ""

# ── One-command bootstrap ─────────────────────────────────────────────────────

setup: ## Bootstrap everything: venv, deps, Weaviate, schema (PROJECT=myapp)
	@echo "=== SDLC Agent Framework Setup ==="
	@echo "  Project:  $(PROJECT)"
	@echo "  Venv:     $(VENV)"
	@echo ""
	@$(MAKE) install
	@$(MAKE) start
	@$(MAKE) schema
	@echo ""
	@echo "=== Setup complete ==="
	@echo ""
	@echo "Next: index your codebase"
	@echo "  make index REPO=/path/to/your/project PROJECT=$(PROJECT)"
	@echo ""
	@echo "Add to your shell profile:"
	@echo "  export AGENTS_ROOT=$(CURDIR)"
	@echo "  export AGENTS_VENV=$(PYTHON)"
	@echo "  export AGENTS_WEAVIATE_URL=$(WEAVIATE_URL)"
	@echo "  export AGENTS_PROJECT=$(PROJECT)"

# ── Python environment ────────────────────────────────────────────────────────

install: ## Create venv and install Python dependencies
	@echo "[install] Checking Python 3.10+..."
	@python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' \
		|| (echo "ERROR: Python 3.10+ required"; exit 1)
	@if [ ! -d "$(VENV)" ]; then \
		echo "[install] Creating venv at $(VENV)..."; \
		if command -v uv >/dev/null 2>&1; then \
			uv venv "$(VENV)"; \
		else \
			python3 -m venv "$(VENV)"; \
		fi; \
	fi
	@echo "[install] Installing dependencies..."
	@if command -v uv >/dev/null 2>&1; then \
		uv pip install --python "$(PYTHON)" -r "$(SCRIPTS)/requirements.txt"; \
	else \
		$(PIP) install -r "$(SCRIPTS)/requirements.txt"; \
	fi
	@echo "[install] Verifying..."
	@$(PYTHON) -c "import weaviate, fastembed, sentence_transformers; print('[install] OK')"

# ── Weaviate (local binary) ───────────────────────────────────────────────────

start: ## Start Weaviate (local binary, background). Downloads binary if missing.
	@echo "[start] Starting Weaviate (project=$(PROJECT), port=$(WEAVIATE_PORT))..."
	@AGENTS_PROJECT=$(PROJECT) WEAVIATE_PORT=$(WEAVIATE_PORT) \
		$(PYTHON) $(SCRIPTS)/start_weaviate.py --background \
		--project $(PROJECT) --port $(WEAVIATE_PORT)

stop: ## Stop Weaviate (kills process on WEAVIATE_PORT)
	@echo "[stop] Stopping Weaviate on port $(WEAVIATE_PORT)..."
	@lsof -ti tcp:$(WEAVIATE_PORT) | xargs -r kill -9 2>/dev/null && \
		echo "[stop] Weaviate stopped." || echo "[stop] Weaviate was not running."

restart: stop start ## Restart Weaviate

status: ## Check if Weaviate is running
	@curl -sf $(WEAVIATE_URL)/v1/.well-known/ready >/dev/null \
		&& echo "Weaviate is UP at $(WEAVIATE_URL)" \
		|| echo "Weaviate is DOWN at $(WEAVIATE_URL)"

# ── Weaviate (Docker) ─────────────────────────────────────────────────────────

docker-start: ## Start Weaviate via Docker Compose
	@echo "[docker] Starting Weaviate..."
	@WEAVIATE_PORT=$(WEAVIATE_PORT) WEAVIATE_DATA_DIR=$(HOME)/.weaviate-$(PROJECT)/data \
		docker compose -f $(COMPOSE_FILE) up -d
	@echo "[docker] Waiting for Weaviate to be ready..."
	@for i in 1 2 3 4 5 6 7 8 9 10; do \
		curl -sf $(WEAVIATE_URL)/v1/.well-known/ready >/dev/null && break || sleep 2; \
	done
	@$(MAKE) status

docker-stop: ## Stop Weaviate Docker container
	@echo "[docker] Stopping Weaviate..."
	@docker compose -f $(COMPOSE_FILE) down

docker-restart: docker-stop docker-start ## Restart Weaviate Docker container

docker-status: ## Show Docker container status
	@docker compose -f $(COMPOSE_FILE) ps

# ── Schema management ─────────────────────────────────────────────────────────

schema: ## Initialize Weaviate schema for PROJECT (safe to re-run)
	@echo "[schema] Initializing schema for project=$(PROJECT)..."
	@AGENTS_WEAVIATE_URL=$(WEAVIATE_URL) \
		$(PYTHON) $(SCRIPTS)/update_kb.py --init-schema --project $(PROJECT)

migrate: ## Drop and recreate schema (use after changing embedding model)
	@echo "[migrate] WARNING: This drops all vectors for project=$(PROJECT)."
	@echo "Press Ctrl+C within 5 seconds to cancel..."
	@sleep 5
	@AGENTS_WEAVIATE_URL=$(WEAVIATE_URL) \
		$(PYTHON) $(SCRIPTS)/update_kb.py --migrate --project $(PROJECT)
	@$(MAKE) schema

# ── Indexing ──────────────────────────────────────────────────────────────────

index: ## Incremental index: only re-embeds changed files (REPO=/path/to/project)
	@echo "[index] Indexing $(REPO) → project=$(PROJECT)..."
	@AGENTS_WEAVIATE_URL=$(WEAVIATE_URL) \
		$(PYTHON) $(SCRIPTS)/update_kb.py \
		--repo-root $(REPO) --project $(PROJECT)

full-index: ## Full re-index: drops hashes and re-embeds everything (REPO=...)
	@echo "[full-index] Full re-index of $(REPO) → project=$(PROJECT)..."
	@AGENTS_WEAVIATE_URL=$(WEAVIATE_URL) \
		$(PYTHON) $(SCRIPTS)/update_kb.py \
		--full --repo-root $(REPO) --project $(PROJECT)

index-standards: ## Index coding standards documents (REPO=...)
	@echo "[index-standards] Indexing standards from $(REPO) → project=$(PROJECT)..."
	@AGENTS_WEAVIATE_URL=$(WEAVIATE_URL) \
		$(PYTHON) $(SCRIPTS)/update_kb.py \
		--standards --repo-root $(REPO) --project $(PROJECT)

index-prs: ## Index PR review comments from GitHub (requires: gh auth login)
	@echo "[index-prs] Indexing PR comments → project=$(PROJECT)..."
	@AGENTS_WEAVIATE_URL=$(WEAVIATE_URL) \
		$(PYTHON) $(SCRIPTS)/update_pr_kb.py \
		--project $(PROJECT) --limit $(PR_LIMIT) $(if $(filter true,$(INCLUDE_OPEN)),--include-open,)

PR_LIMIT    ?= 50
INCLUDE_OPEN ?= false

# ── Query / Search ────────────────────────────────────────────────────────────

query: ## RAG search with re-ranking (Q="your query", PROJECT=myapp, LANGUAGE=java)
	@[ -n "$(Q)" ] || (echo "Usage: make query Q=\"your search query\""; exit 1)
	@AGENTS_WEAVIATE_URL=$(WEAVIATE_URL) AGENTS_LANGUAGE=$(LANGUAGE) \
		$(PYTHON) $(SCRIPTS)/query_rag.py "$(Q)" \
		--project $(PROJECT) --rerank $(QUERY_ARGS)

# Pass extra args via QUERY_ARGS, e.g.:
#   make query Q="auth" QUERY_ARGS="--multi-query --module auth --min-score 0.5"
#   make query Q="auth" LANGUAGE=java QUERY_ARGS="--multi-query"

stats: ## Show indexing statistics for PROJECT
	@AGENTS_WEAVIATE_URL=$(WEAVIATE_URL) \
		$(PYTHON) $(SCRIPTS)/update_kb.py --stats --project $(PROJECT)

prune: ## Remove deleted files from Weaviate index (REPO=...)
	@echo "[prune] Pruning stale entries for $(REPO) → project=$(PROJECT)..."
	@AGENTS_WEAVIATE_URL=$(WEAVIATE_URL) \
		$(PYTHON) $(SCRIPTS)/update_kb.py \
		--prune --repo-root $(REPO) --project $(PROJECT)

# ── Claude Code integration ───────────────────────────────────────────────────

claude-setup: ## Copy Claude commands to TARGET project's .claude/commands/
	@[ -n "$(TARGET)" ] || (echo "Usage: make claude-setup TARGET=/path/to/project"; exit 1)
	@echo "[claude-setup] Installing commands to $(TARGET)/.claude/commands/..."
	@mkdir -p "$(TARGET)/.claude/commands"
	@cp $(CURDIR)/claude/commands/*.md "$(TARGET)/.claude/commands/"
	@echo "[claude-setup] Copied $(shell ls $(CURDIR)/claude/commands/*.md | wc -l | tr -d ' ') commands."
	@echo ""
	@echo "Next: configure environment variables in $(TARGET)/.claude/settings.json"
	@echo "  See: $(CURDIR)/claude/settings-template.json"

# ── Cleanup ───────────────────────────────────────────────────────────────────

clean: ## Remove Python venv and cached files
	@echo "[clean] Removing venv at $(VENV)..."
	@rm -rf "$(VENV)"
	@find $(SCRIPTS) -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	@echo "[clean] Done."

clean-data: ## Remove Weaviate data for PROJECT (DESTRUCTIVE)
	@echo "[clean-data] WARNING: Deleting ~/.weaviate-$(PROJECT)/"
	@echo "Press Ctrl+C within 5 seconds to cancel..."
	@sleep 5
	@rm -rf "$(HOME)/.weaviate-$(PROJECT)"
	@echo "[clean-data] Data deleted."
