# Getting Started

> **30-second version:**
>
> ```bash
> git clone https://github.com/ajayzend/codebase-rag-agent.git
> cd codebase-rag-agent
> make setup PROJECT=myapp
> make index REPO=/path/to/your/project PROJECT=myapp LANGUAGE=typescript
> make query Q="auth token logic" PROJECT=myapp
> ```
>
> Done. Skip to [Connect to your IDE](#5-connect-to-your-ide) if that worked.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Install the framework](#2-install-the-framework)
3. [Bootstrap your project](#3-bootstrap-your-project)
4. [Index your codebase](#4-index-your-codebase)
5. [Connect to your IDE](#5-connect-to-your-ide)
6. [Verify it works](#6-verify-it-works)
7. [Language setup guide](#7-language-setup-guide)
  - [TypeScript / Node.js](#typescript--nodejs)
  - [Python](#python)
  - [Java](#java)
  - [Kotlin](#kotlin)
  - [PHP](#php)
  - [Go](#go)
  - [Ruby on Rails](#ruby-on-rails)
  - [Rust](#rust)
  - [C# / .NET](#c--net)
  - [Scala](#scala)
  - [Swift](#swift)
  - [Multi-language monorepos](#multi-language-monorepos)
8. [Daily workflow](#8-daily-workflow)
9. [Environment variables reference](#9-environment-variables-reference)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Prerequisites


| Tool                  | Version | How to install                                                                     |
| --------------------- | ------- | ---------------------------------------------------------------------------------- |
| Python                | 3.10+   | `brew install python` · [python.org](https://python.org)                           |
| Git                   | any     | pre-installed on macOS/Linux                                                       |
| `make`                | any     | pre-installed on macOS/Linux · `winget install GnuWin32.Make` on Windows           |
| Docker *(optional)*   | 24+     | [docker.com](https://docker.com) — only if you prefer Docker over the local binary |
| `gh` CLI *(optional)* | 2+      | `brew install gh` — only needed for PR review indexing                             |
| `uv` *(optional)*     | any     | `brew install uv` — makes Python installs 10× faster                               |


> **No Docker required.** By default the framework downloads a Weaviate binary and runs it directly — no container needed.

---

## 2. Install the framework

Clone the framework once. It lives alongside your projects, not inside them.

```bash
git clone https://github.com/ajayzend/codebase-rag-agent.git
cd codebase-rag-agent
```

Add these three lines to your shell profile (`~/.zshrc` or `~/.bashrc`) so all your projects can find the framework:

```bash
export AGENTS_ROOT=/path/to/sdlc-agent-framework    # ← replace with actual path
export AGENTS_VENV=~/.sdlc-agents-venv/bin/python
export AGENTS_WEAVIATE_URL=http://localhost:8090
```

Reload your profile:

```bash
source ~/.zshrc   # or source ~/.bashrc
```

---

## 3. Bootstrap your project

Run this once per project name. It sets up everything from scratch:

```bash
make setup PROJECT=myapp
```

**What it does:**


| Step | Action                                                                                             |
| ---- | -------------------------------------------------------------------------------------------------- |
| 1    | Verifies Python 3.10+                                                                              |
| 2    | Creates `~/.sdlc-agents-venv` and installs `weaviate-client`, `fastembed`, `sentence-transformers` |
| 3    | Downloads the Weaviate binary to `~/.weaviate-bin/` (one-time, ~50 MB)                             |
| 4    | Starts Weaviate in the background on `http://localhost:8090`                                       |
| 5    | Initialises vector DB collections for your project                                                 |


Replace `myapp` with a short slug for your project. It becomes the namespace for all Weaviate collections — e.g. `CodebaseKnowledge_myapp`.

### Prefer Docker?

```bash
make docker-start PROJECT=myapp    # pull image + start container
make schema       PROJECT=myapp    # init schema
```

The docker-compose file is at the repo root. Data persists in a named Docker volume.

---

## 4. Index your codebase

Point the indexer at your project directory. Set `LANGUAGE` to the primary language:

```bash
make index REPO=/path/to/your/project PROJECT=myapp LANGUAGE=typescript
```

**Language values:** `typescript` · `javascript` · `python` · `java` · `kotlin` · `php` · `go` · `ruby` · `rust` · `csharp` · `swift` · `scala`

**What gets indexed automatically:**

- Source files for all supported languages
- Docs: `.md`, `.mdx`
- Config: `.yaml`, `.yml`, `.toml`, `.sql`

**What is always skipped:**

- Dependency dirs: `node_modules`, `vendor`, `target`, `.venv`, `dist`, `build`
- Lock files: `package-lock.json`, `composer.lock`, `Cargo.lock`, `Gemfile.lock`, etc.
- Generated files: `*.d.ts`, `*.pb.go`, `*.generated.`*, `*.class`, `*.pyc`
- Files over 150 KB

### Index your coding standards too

```bash
make index-standards REPO=/path/to/your/project PROJECT=myapp
```

Standards are picked up from: `CLAUDE.md`, `README.md`, `CONTRIBUTING.md`, `.claude/rules/*.md`, `.cursor/rules/*.mdc`, `docs/standards/*.md`

---

## 5. Connect to your IDE

### Claude Code

Install all 20 slash commands into your project with one command:

```bash
make claude-setup TARGET=/path/to/your/project
```

Then open your project in Claude Code and run:

```
/configure
```

The configure wizard auto-detects your stack, maps your directories to modules, writes `CLAUDE.md` and `.claude/settings.json`, and runs the first KB index. Before writing anything it shows you a full preview and waits for confirmation.

### Cursor

Copy the agent playbooks into your project's Cursor rules folder:

```bash
cp -r /path/to/sdlc-agent-framework/cursor/agents /path/to/your/project/.cursor/rules/
```

Open Cursor Composer and reference the `controller` playbook to start a ticket workflow.

### Environment variables for the IDE

The commands inside Claude Code and Cursor read from these env vars. Set them in your shell profile (they were added in step 2), or add them to `.claude/settings.json`:

```json
{
  "env": {
    "AGENTS_ROOT": "/path/to/sdlc-agent-framework",
    "AGENTS_VENV": "~/.sdlc-agents-venv/bin/python",
    "AGENTS_WEAVIATE_URL": "http://localhost:8090",
    "AGENTS_PROJECT": "myapp",
    "AGENTS_LANGUAGE": "typescript"
  }
}
```

---

## 6. Verify it works

```bash
make status                                             # Weaviate health check
make stats  PROJECT=myapp                              # how many chunks indexed
make query  Q="authentication logic" PROJECT=myapp     # test a search
```

A working query looks like this:

```
## RAG Context [CodebaseKnowledge_myapp]: 'authentication logic' (top 5)

### [1] src/auth/auth.service.ts (score: 0.921)
Module: auth | Type: service | Category: business-logic

[code snippet...]

---

### [2] src/auth/jwt.strategy.ts (score: 0.887)
...
```

If you get no results, see [Troubleshooting](#10-troubleshooting).

---

## 7. Language setup guide

Each section below is self-contained. Jump to your language.

---

### TypeScript / Node.js

**Frameworks:** NestJS · Express · Next.js · Nuxt · Fastify · Remix

```bash
make index REPO=/path/to/project PROJECT=myapp LANGUAGE=typescript
```

**Files indexed:** `.ts` · `.tsx` · `.js` · `.jsx` · `.vue` · `.mjs` · `.cjs`

**Skipped:** `node_modules` · `dist` · `.next` · `.nuxt` · `.turbo` · `*.d.ts` · `*.min.js` · `*.map`

**Smart chunking:** Splits at `export class`, `export function`, `export const`, and decorators (`@Injectable`, `@Controller`, `@Component`). Method chunks are prefixed with their enclosing class name for better retrieval.

**Auto-classified file types:**


| File pattern                    | Classified as |
| ------------------------------- | ------------- |
| `*.service.ts`                  | service       |
| `*.controller.ts`               | controller    |
| `*.vue`, `*.tsx`                | component     |
| `*.schema.ts`, `*Entity.ts`     | schema        |
| `*.middleware.ts`, `*.guard.ts` | middleware    |
| `*.dto.ts`                      | dto           |
| `*.spec.ts`, `*.test.ts`        | test          |


**NestJS project layout:**

```
src/
├── auth/
│   ├── auth.service.ts         → module: auth, type: service
│   ├── auth.controller.ts      → module: auth, type: controller
│   └── auth.guard.ts           → module: auth, type: middleware
├── payments/
│   ├── payments.service.ts     → module: payments, type: service
│   └── payment.entity.ts       → module: payments, type: schema
└── common/
    └── interceptors/           → module: common, type: middleware
```

**Add a standards file:**

```
CLAUDE.md
docs/standards/typescript.md    ← your team's TS conventions
docs/standards/nestjs.md
```

---

### Python

**Frameworks:** Django · FastAPI · Flask · SQLAlchemy

```bash
make index REPO=/path/to/project PROJECT=myapp LANGUAGE=python
```

**Files indexed:** `.py`

**Skipped:** `__pycache__` · `.venv` · `venv` · `env` · `.tox` · `.mypy_cache` · `migrations`

**Smart chunking:** Splits at `class`, `def`, `async def`.

**Auto-classified file types:**


| File pattern                 | Classified as |
| ---------------------------- | ------------- |
| `*_service.py`               | service       |
| `*_view.py`, `*views.py`     | controller    |
| `*_model.py`, `*models.py`   | schema        |
| `*_serializer.py`            | dto           |
| `*_repository.py`            | repository    |
| `*_test.py`, `test_*.py`     | test          |
| `settings.py`, `*.config.py` | config        |


**Django project layout:**

```
myapp/
├── accounts/
│   ├── models.py           → module: users, type: schema
│   ├── views.py            → module: users, type: controller
│   ├── serializers.py      → module: users, type: dto
│   └── tests.py            → module: users, type: test
├── payments/
│   ├── models.py           → module: payments, type: schema
│   └── services.py         → module: payments, type: service
└── config/
    └── settings.py         → module: infra, type: config
```

**FastAPI layout:**

```
app/
├── api/routes/             → type: controller
├── services/               → type: service
├── models/                 → type: schema
├── schemas/                → type: dto
└── core/                   → module: infra
```

---

### Java

**Frameworks:** Spring Boot · Quarkus · Micronaut

```bash
make index REPO=/path/to/project PROJECT=myapp LANGUAGE=java
```

**Files indexed:** `.java` · `.xml` · `.yaml` · `.yml` · `.sql` · `.properties`

**Skipped:** `target` · `.gradle` · `.mvn` · `*.class` · `*.jar`

**Smart chunking:** Splits at `class`, `interface`, `enum`, `record`, and public method declarations.

**Auto-classified file types:**


| File pattern                                   | Classified as |
| ---------------------------------------------- | ------------- |
| `*Controller.java`                             | controller    |
| `*Service.java`                                | service       |
| `*Repository.java`                             | repository    |
| `*Entity.java`                                 | schema        |
| `*DTO.java`, `*Request.java`, `*Response.java` | dto           |
| `*Config.java`                                 | config        |
| `*Test.java`, `*Tests.java`                    | test          |
| `*Util.java`, `*Utils.java`, `*Helper.java`    | util          |


**Spring Boot project layout:**

```
src/main/java/com/myapp/
├── controller/             → type: controller
├── service/                → type: service
├── repository/             → type: repository
├── entity/                 → type: schema
├── dto/                    → type: dto
├── config/                 → type: config
└── util/                   → type: util
src/main/resources/
├── application.yml         → type: config (auto-indexed)
└── application.properties  → type: config
```

---

### Kotlin

**Frameworks:** Spring Boot · Ktor · Android

```bash
make index REPO=/path/to/project PROJECT=myapp LANGUAGE=kotlin
```

**Files indexed:** `.kt` · `.kts`

**Skipped:** `target` · `.gradle` · `*.class`

**Smart chunking:** Splits at Kotlin declarations including `class`, `object`, `fun`, `data class`, `sealed class`, `open class`, `internal class`.

**Auto-classified file types:** Same as Java — `*Controller.kt` → controller, `*Service.kt` → service, `*Repository.kt` → repository, `*Spec.kt` → test.

---

### PHP

**Frameworks:** Laravel · Symfony · CodeIgniter

```bash
make index REPO=/path/to/project PROJECT=myapp LANGUAGE=php
```

**Files indexed:** `.php`

**Skipped:** `vendor` · `storage` · `bootstrap/cache` · `*.phar`

**Smart chunking:** Splits at `class`, `interface`, `trait`, `function`, `namespace`.

**Auto-classified file types:**


| File pattern                | Classified as |
| --------------------------- | ------------- |
| `*Controller.php`           | controller    |
| `*Service.php`              | service       |
| `*Repository.php`           | repository    |
| `*Model.php`                | schema        |
| `*Middleware.php`           | middleware    |
| `*Request.php`, `*Form.php` | dto           |
| `*Helper.php`               | util          |


**Laravel project layout:**

```
app/
├── Http/
│   ├── Controllers/        → type: controller
│   ├── Middleware/         → type: middleware
│   └── Requests/           → type: dto
├── Models/                 → type: schema
├── Services/               → type: service
├── Repositories/           → type: repository
└── Helpers/                → type: util
routes/                     → type: controller
```

---

### Go

```bash
make index REPO=/path/to/project PROJECT=myapp LANGUAGE=go
```

**Files indexed:** `.go` · `go.mod`

**Skipped:** `vendor` · `pkg`

**Smart chunking:** Splits at `func`, `type ... struct`, `type ... interface`, `var`, `const`.

**Auto-classified file types:**


| File pattern              | Classified as |
| ------------------------- | ------------- |
| `*_handler.go`            | controller    |
| `*_service.go`            | service       |
| `*_repository.go`         | repository    |
| `*_middleware.go`         | middleware    |
| `*_test.go`               | test          |
| `*_util.go`, `*_utils.go` | util          |


**Standard Go project layout:**

```
cmd/                        → module: infra
internal/
├── handler/                → type: controller
├── service/                → type: service
├── repository/             → type: repository
├── model/                  → type: schema
└── middleware/             → type: middleware
pkg/                        → module: common
```

---

### Ruby on Rails

```bash
make index REPO=/path/to/project PROJECT=myapp LANGUAGE=ruby
```

**Files indexed:** `.rb` · `.erb`

**Skipped:** `vendor` · `log` · `tmp` · `public` · `Gemfile.lock`

**Smart chunking:** Splits at `class`, `module`, `def`.

**Auto-classified file types:**


| File pattern      | Classified as |
| ----------------- | ------------- |
| `*_controller.rb` | controller    |
| `*_model.rb`      | schema        |
| `*_service.rb`    | service       |
| `*_mailer.rb`     | service       |
| `*_spec.rb`       | test          |
| `*_helper.rb`     | util          |


**Rails layout:**

```
app/
├── controllers/            → type: controller
├── models/                 → type: schema
├── services/               → type: service
├── mailers/                → type: service
├── helpers/                → type: util
└── views/                  → module: ui-pages
spec/ or test/              → type: test
config/                     → type: config
```

---

### Rust

```bash
make index REPO=/path/to/project PROJECT=myapp LANGUAGE=rust
```

**Files indexed:** `.rs` · `Cargo.toml`

**Skipped:** `target` · `.cargo` · `*.pb.rs`

**Smart chunking:** Splits at `pub fn`, `fn`, `struct`, `impl`, `enum`, `trait`, `mod`.

**Class context injection:** `struct` and `impl` names are injected into method-level chunks.

---

### C# / .NET

```bash
make index REPO=/path/to/project PROJECT=myapp LANGUAGE=csharp
```

**Files indexed:** `.cs`

**Skipped:** `bin` · `obj` · `*.dll` · `*.exe`

**Smart chunking:** Splits at `class`, `interface`, `enum`, `struct`, `record`.

**Auto-classified:** `*Controller.cs` → controller, `*Service.cs` → service, `*Repository.cs` → repository, `*Test.cs` / `*Tests.cs` → test, `*Middleware.cs` → middleware.

---

### Scala

```bash
make index REPO=/path/to/project PROJECT=myapp LANGUAGE=scala
```

**Files indexed:** `.scala`

**Skipped:** `target` · `.sbt`

**Smart chunking:** Splits at `class`, `object`, `trait`, `def`, including Scala-specific forms: `case class`, `sealed class`, `abstract class`, `case object`.

---

### Swift

```bash
make index REPO=/path/to/project PROJECT=myapp LANGUAGE=swift
```

**Files indexed:** `.swift` · `.m`

**Skipped:** `Pods` · `.build` · `*.pb.swift`

**Smart chunking:** Splits at `class`, `struct`, `enum`, `protocol`, `func`, `extension`.

---

### Multi-language monorepos

Index each service as a separate `REPO` pass, all under the same `PROJECT`:

```bash
make index REPO=./services/auth-api    PROJECT=myapp LANGUAGE=java
make index REPO=./services/frontend    PROJECT=myapp LANGUAGE=typescript
make index REPO=./services/pipeline    PROJECT=myapp LANGUAGE=python
make index REPO=./mobile/ios           PROJECT=myapp LANGUAGE=swift
```

All chunks land in the same Weaviate collections (namespaced by `PROJECT`). Module classification keeps them separate — a query for "auth token validation" won't surface unrelated frontend code.

**Very large monorepos** — use separate project namespaces per service to keep each collection focused:

```bash
make index REPO=./services/auth   PROJECT=myapp-auth LANGUAGE=java
make index REPO=./services/web    PROJECT=myapp-web  LANGUAGE=typescript
```

---

## 8. Daily workflow

### Starting a new ticket

```
# In Claude Code — full pipeline with one command
/controller TICKET-123

# Or step by step
/solution TICKET-123    # draft approach from ticket + RAG context
/code                   # TDD implementation
/review-code            # quality gate
```

### After writing code

```bash
make index REPO=/path/to/project PROJECT=myapp    # re-index changed files only
```

### After merging PRs

```bash
make index-prs PROJECT=myapp    # index review comments into ReviewPatterns
```

### Manual RAG searches

```bash
# Basic
make query Q="payment retry logic" PROJECT=myapp

# Scoped to a module
make query Q="auth token validation" PROJECT=myapp \
  QUERY_ARGS="--multi-query --module auth --min-score 0.5"

# Search PR review patterns
make query Q="missing null check" PROJECT=myapp \
  QUERY_ARGS="--collection reviews"

# Search coding standards
make query Q="error handling pattern" PROJECT=myapp \
  QUERY_ARGS="--collection standards"
```

---

## 9. Environment variables reference


| Variable                    | Default                        | Description                                               |
| --------------------------- | ------------------------------ | --------------------------------------------------------- |
| `AGENTS_ROOT`               | —                              | Absolute path to this repository                          |
| `AGENTS_VENV`               | —                              | Path to Python interpreter in the venv                    |
| `AGENTS_WEAVIATE_URL`       | `http://localhost:8090`        | Weaviate HTTP URL                                         |
| `AGENTS_WEAVIATE_GRPC_PORT` | `AGENTS_WEAVIATE_URL port + 1` | Override gRPC port only if non-standard                   |
| `AGENTS_PROJECT`            | `default`                      | Project namespace for Weaviate collections                |
| `AGENTS_LANGUAGE`           | *(empty)*                      | Primary language — used by multi-query variant generation |


Copy `.env.example` to `.env` and fill in your values. Never commit `.env`.

---

## 10. Troubleshooting

### Weaviate won't start

```bash
make status    # check if it's up
make stop      # kill any stuck process on port 8090
make start     # start fresh
```

If the port is already in use by something else:

```bash
make start WEAVIATE_PORT=8095    # use a different port
# also set AGENTS_WEAVIATE_URL=http://localhost:8095 in your shell
```

### "No results" for a query

1. `make stats PROJECT=myapp` — confirms chunks were indexed
2. `make status` — confirms Weaviate is healthy
3. Try a simpler query without `--min-score`
4. If files were added recently, run `make full-index REPO=... PROJECT=myapp`

### Embedding model downloads on every run

It downloads once to `~/.cache/huggingface/hub/` and loads from cache on all subsequent runs. If you want to relocate the cache:

```bash
export HF_HUB_CACHE=/path/to/fast-disk/.cache
```

### Large files being skipped

```bash
make stats PROJECT=myapp    # check skipped count
```

To raise the limit, edit `MAX_FILE_BYTES` in `scripts/update_kb.py` (default: `150_000`).

### Schema mismatch after changing the embedding model

```bash
make migrate      PROJECT=myapp                # drops + recreates all collections
make full-index   REPO=/path PROJECT=myapp     # re-embed everything
make index-standards REPO=/path PROJECT=myapp
```

### PHP `vendor/` or Java `target/` being indexed

Both are in the skip list by default. If they're appearing in stats, double-check that `REPO` points to your project root, not a parent directory.

### Windows

Recommended: **WSL 2** (Ubuntu). All commands work without changes.

Alternatives:

- Git Bash: use absolute paths for `REPO` (`/c/Users/you/project`)
- PowerShell + `make` from Chocolatey (`choco install make`)

---

## Quick reference card

```bash
# ── One-time setup ──────────────────────────────────────────────────────────
git clone https://github.com/ajayzend/codebase-rag-agent.git
cd codebase-rag-agent
make setup PROJECT=myapp

# ── Per project (run once per project) ──────────────────────────────────────
make index        REPO=/path/to/project PROJECT=myapp LANGUAGE=java
make index-standards REPO=/path/to/project PROJECT=myapp
make claude-setup TARGET=/path/to/project    # install slash commands

# ── Daily ───────────────────────────────────────────────────────────────────
make index        REPO=/path/to/project PROJECT=myapp   # sync changed files
make index-prs    PROJECT=myapp                         # after merging PRs
make query        Q="your question" PROJECT=myapp       # manual search

# ── Claude Code workflow ─────────────────────────────────────────────────────
# /configure → /solution TICKET-123 → /code → /review-code → /safe-commit
```

