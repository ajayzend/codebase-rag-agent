<div align="center">

# SDLC Agent Framework

**AI-assisted software development for any codebase — grounded in your actual code.**

[![Python](https://img.shields.io/badge/Python-3.10%2B-blue?logo=python&logoColor=white)](https://python.org)
[![Weaviate](https://img.shields.io/badge/Weaviate-1.28-green?logo=weaviate)](https://weaviate.io)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

Works with · **TypeScript** · **JavaScript** · **Python** · **Java** · **Kotlin** · **PHP** · **Go** · **Ruby** · **Rust** · **C#** · **Swift** · **Scala** · and any monorepo

</div>

---

## What Is This?

A **local RAG pipeline + AI agent playbook system** that gives AI coding assistants (Claude Code, Cursor) ground truth about your codebase — so they stop hallucinating file names, APIs, and patterns that don't exist.

```
Your Codebase + Standards + PR History
         │
         ▼
   Weaviate (local vector DB)          ← hybrid search (vector + BM25) + re-ranking
         │
         ▼
   AI Agent (Claude / Cursor)          ← grounded in real code, real patterns
         │
         ▼
   Solution → Code → Review → PR      ← structured pipeline with human gates
```

Works on a 20-year-old monolith or a greenfield microservice. No cloud. No API keys for indexing. Everything runs locally.

---

## The Problem It Solves

| Problem | Without This | With This |
|---------|-------------|-----------|
| AI hallucinates your codebase | Agent invents file paths and APIs | Agent queries your actual code via RAG |
| Inconsistent reviews | Every reviewer has different standards | Team review patterns indexed and surfaced |
| Lost architectural decisions | "Why did we do it this way?" — nobody knows | Solution archive stored in vector DB |
| Context switching | 30–40% of time re-reading familiar code | Agent retrieves relevant context in <100ms |
| AI agents with no memory | Each session starts from scratch | PR history, solutions, and standards persist |

---

## Quick Start

> Three commands. Under 10 minutes. Works for any language.

### Step 1 — Clone the framework

```bash
git clone https://github.com/ajayzend/codebase-rag-agent.git
cd codebase-rag-agent
```

### Step 2 — Bootstrap (installs everything)

```bash
make setup PROJECT=myapp
```

This one command:
- Checks Python 3.10+, creates a virtual environment, installs all dependencies
- Downloads Weaviate and starts it in the background on `localhost:8090`
- Initialises the vector DB schema for your project

> **Prefer Docker?** Use `make docker-start PROJECT=myapp && make schema PROJECT=myapp` instead.

### Step 3 — Index your project

```bash
make index REPO=/path/to/your/project PROJECT=myapp LANGUAGE=typescript
```

Replace `LANGUAGE` with your stack: `python`, `java`, `php`, `go`, `ruby`, `kotlin`, `rust`, `csharp`, `scala`, or `swift`.

**That's it.** Verify with:

```bash
make status                                              # Weaviate health check
make stats  PROJECT=myapp                               # how many chunks indexed
make query  Q="authentication logic" PROJECT=myapp      # test a search
```

---

## Connect to Your IDE

### Claude Code

```bash
make claude-setup TARGET=/path/to/your/project
```

Then open your project in Claude Code and run `/configure`. The wizard detects your stack and writes all config automatically.

### Cursor

```bash
cp -r cursor/agents /path/to/your/project/.cursor/rules/
```

Then open the `controller` agent playbook in Cursor Composer to start a ticket workflow.

---

## The SDLC Pipeline

```
TICKET
  │
  ├─ /update-kb          Sync codebase to Weaviate             [fast]
  ├─ /update-standards   Index coding rules                    [fast]
  ├─ /update-pr-kb       Index PR review patterns              [fast]
  │
  ├─ /solution           Draft approach using RAG context      [fast]
  ├─ /challenge-solution Adversarial stress-test               [review]
  ├─ /review-solution    ✋ GATE — approve or block             [review]
  │
  ├─ /code               TDD implementation using RAG          [fast]
  ├─ /review-code        ✋ GATE — review implementation        [review]
  ├─ /write-tests        Write or fix unit tests               [review]
  ├─ /review-tests       Audit test quality and gaps           [review]
  ├─ /mate-review        Pre-PR peer review                    [review]
  │
  ├─ /pr-review          Respond to reviewer comments          [review]
  ├─ /safe-commit        Pre-commit validation                 [fast]
  ├─ /debug              RAG-grounded bug investigation        [review]
  └─ /refactor           Safe, scope-bounded refactor          [review]

✋ Gates require human approval — the agent does not self-approve.
```

Run the full pipeline with one command: `/controller TICKET-123`

---

## How the RAG Works

| Stage | Detail |
|-------|--------|
| **Chunking** | 2000 chars, 200 overlap, splits at logical boundaries (functions, classes, headers) |
| **Embedding** | `jinaai/jina-embeddings-v2-base-code` — 768d, code-aware, runs locally |
| **Storage** | Weaviate HNSW index with metadata: `module`, `doc_type`, `category`, `language` |
| **Retrieval** | Hybrid: cosine vector + BM25 keyword, fused via Reciprocal Rank Fusion |
| **Multi-query** | 2–3 query variants auto-generated and merged to reduce phrasing sensitivity |
| **Re-ranking** | `cross-encoder/ms-marco-MiniLM-L-12-v2` re-ranks top-20 → top-5 for precision |
| **Injection** | Top-5 chunks injected as grounded context into the LLM prompt |

All embedding and re-ranking runs **on-device** via ONNX. No API key. No cost per query.

---

## Supported Languages

| Language | Extensions indexed | Smart chunk boundaries |
|----------|--------------------|----------------------|
| TypeScript / JavaScript | `.ts`, `.tsx`, `.js`, `.jsx`, `.vue`, `.mjs` | `class`, `function`, `const`, decorators |
| Python | `.py` | `class`, `def`, `async def` |
| Java | `.java` | `class`, `interface`, `enum`, `record`, methods |
| Kotlin | `.kt`, `.kts` | `class`, `object`, `fun`, `data class` |
| PHP | `.php` | `class`, `interface`, `trait`, `function`, `namespace` |
| Go | `.go` | `func`, `type struct`, `type interface` |
| Ruby | `.rb`, `.erb` | `class`, `module`, `def` |
| Rust | `.rs` | `fn`, `struct`, `impl`, `enum`, `trait`, `mod` |
| C# | `.cs` | `class`, `interface`, `enum`, `struct`, `record` |
| Swift | `.swift` | `class`, `struct`, `enum`, `protocol`, `func` |
| Scala | `.scala` | `class`, `object`, `trait`, `def` |
| Config / Docs | `.yaml`, `.toml`, `.sql`, `.md` | Markdown headers |

---

## Module Classification

Each indexed chunk is tagged with metadata so agents can filter to the right feature area:

```
src/auth/auth.service.ts  →  module: auth  |  doc_type: service  |  category: business-logic
src/billing/invoice.go    →  module: payments  |  doc_type: service  |  category: business-logic
app/Http/Controllers/     →  module: (auto)  |  doc_type: controller  |  category: api-contract
```

Agents can scope queries to a module:
```bash
make query Q="token validation" PROJECT=myapp QUERY_ARGS="--module auth"
```

Pre-built patterns cover 30+ common modules: `auth`, `payments`, `orders`, `users`, `products`, `notifications`, `search`, `admin`, `scheduler`, and more. For projects with different directory structures, add patterns to `MODULE_PATTERNS` in `scripts/update_kb.py`.

---

## Make Commands

```bash
make help                                          # show all targets with descriptions

# Setup
make setup        PROJECT=myapp                   # one-command bootstrap
make docker-start PROJECT=myapp                   # use Docker for Weaviate instead

# Indexing
make index        REPO=../myproject PROJECT=myapp LANGUAGE=java
make full-index   REPO=../myproject PROJECT=myapp  # force re-embed everything
make index-standards REPO=../myproject PROJECT=myapp
make index-prs    PROJECT=myapp                   # requires: gh auth login

# Search
make query        Q="auth token logic" PROJECT=myapp
make stats        PROJECT=myapp
make status                                        # Weaviate health check

# Maintenance
make migrate      PROJECT=myapp                   # rebuild schema after model change
make prune        REPO=../myproject PROJECT=myapp  # remove deleted-file chunks
make stop                                          # stop Weaviate
make clean                                         # remove venv
```

---

## Project Structure

```
sdlc-agent-framework/
├── scripts/
│   ├── start_weaviate.py    Download + run local Weaviate binary (no Docker needed)
│   ├── update_kb.py         Index codebase + standards into Weaviate
│   ├── update_pr_kb.py      Index PR review comments into Weaviate
│   ├── query_rag.py         Hybrid search + re-ranking CLI + solution management
│   └── requirements.txt
├── claude/
│   ├── commands/            20 slash commands for Claude Code (/solution, /code, /review, …)
│   ├── settings-template.json
│   └── README.md
├── cursor/
│   ├── agents/              12 agent playbooks for Cursor
│   └── README.md
├── docs/
│   ├── getting-started.md   ← Start here for setup and language guides
│   ├── developer-guide.md   Step-by-step agent walkthrough
│   ├── rag-basics.md        RAG fundamentals and chunking
│   ├── vector-db-setup.md   Weaviate configuration
│   ├── embeddings.md        Module classification and metadata
│   ├── reranking.md         Cross-encoder re-ranking
│   ├── precision-tuning.md  Advanced tuning for large codebases
│   ├── team-scale.md        100+ developer team rollout
│   └── mcp-guide.md         Jira MCP + GitHub MCP
├── templates/
│   ├── CLAUDE.md            Template CLAUDE.md for any project
│   └── cursor-rules/        .cursor/rules/ templates
├── Makefile                 All commands behind `make`
├── docker-compose.yml       Docker alternative for Weaviate
└── .env.example             Environment variable template
```

---

## MCP Integrations

The agent playbooks integrate with Jira and GitHub via MCP servers for automatic context fetching:

**Jira MCP** — automatically pulled in `/solution` and `/controller`:
- Ticket title, description, acceptance criteria
- Linked issues and epics

**GitHub MCP** — automatically pulled in `/pr-review`:
- PR diff, changed files, existing review comments

Configure both in `claude/settings-template.json`. See [docs/mcp-guide.md](docs/mcp-guide.md).

---

## Team and Org-Wide Rollout

1. **Shared Weaviate** — point all projects at one Weaviate instance (Weaviate Cloud or self-hosted). Each project is namespaced via `--project <repo-name>`.
2. **PR review patterns** — run `make index-prs` weekly across all repos to build org-wide review intelligence.
3. **Standardise `CLAUDE.md`** — base template in this repo; each project extends it.
4. **Day-one context** — any new developer immediately has full RAG access to codebase, standards, and review history.

See [docs/team-scale.md](docs/team-scale.md) for a full rollout guide.

---

## Advanced Tuning

| Improvement | Impact |
|-------------|--------|
| `--multi-query` flag | Generates 3 query variants, merges results — better recall |
| `--module auth` scope | Narrows retrieval to one feature area — less noise |
| `--min-score 0.5` | Drops low-confidence results — higher precision |
| Class context injection | Method chunks carry class name — better service lookups |
| Per-collection alpha | `codebase=0.6`, `reviews=0.8` — tuned to each collection type |
| L-12 reranker | 12-layer cross-encoder vs default 6-layer — more accurate |

See [docs/precision-tuning.md](docs/precision-tuning.md).

---

## Documentation

| Doc | What it covers |
|-----|----------------|
| [docs/getting-started.md](docs/getting-started.md) | **Start here** — setup for every language, language-specific notes, troubleshooting |
| [docs/developer-guide.md](docs/developer-guide.md) | Step-by-step walkthrough of the full agent pipeline |
| [docs/rag-basics.md](docs/rag-basics.md) | How RAG works, chunking strategy, retrieval mechanics |
| [docs/vector-db-setup.md](docs/vector-db-setup.md) | Weaviate HNSW, BM25, hybrid search, index tuning |
| [docs/embeddings.md](docs/embeddings.md) | Module classification, doc_type taxonomy, metadata schema |
| [docs/reranking.md](docs/reranking.md) | Cross-encoder re-ranking — why and how |
| [docs/precision-tuning.md](docs/precision-tuning.md) | Advanced — multi-query, class context, per-collection alpha |
| [docs/team-scale.md](docs/team-scale.md) | Review patterns, org-wide rollout, 100+ dev teams |
| [docs/mcp-guide.md](docs/mcp-guide.md) | Jira MCP, GitHub MCP, tool use in agents |
| [claude/README.md](claude/README.md) | Claude Code IDE setup |
| [cursor/README.md](cursor/README.md) | Cursor IDE setup |

---

## Contributing

Contributions are welcome — new language support, agent playbooks, bug fixes, and documentation improvements.

1. Fork the repo and create a feature branch
2. Make your changes with clear commit messages
3. Test against at least one real project before submitting
4. Open a pull request — describe what you changed and why

Please read [CONTRIBUTING.md](CONTRIBUTING.md) if one exists, or open an issue first for large changes.

---

## License

MIT — see [LICENSE](LICENSE) for details.

---

<div align="center">
  <sub>Built for teams that want AI agents that actually know their codebase.</sub>
</div>
