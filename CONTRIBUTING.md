# Contributing

Thank you for your interest in improving the SDLC Agent Framework.

## What's welcome

- **New language support** — boundary patterns, doc_type rules, skip lists
- **New agent playbooks** — Cursor agents or Claude Code commands for new workflows
- **Bug fixes** — especially in chunking, classification, or Weaviate client calls
- **Documentation** — clearer explanations, real-world examples, corrections

## How to contribute

1. **Open an issue first** for anything non-trivial. Describe the problem or feature before writing code.

2. **Fork and branch:**
   ```bash
   git checkout -b feat/go-boundary-patterns
   ```

3. **Test against a real project** before submitting. For script changes, index at least one codebase and run a few queries to verify results.

4. **Keep changes focused.** One fix or feature per PR.

5. **Submit a pull request** with a clear description of what changed and why.

## Code style

- Python scripts: follow the existing style (type hints, docstrings on non-obvious functions)
- Markdown: match the heading hierarchy and table format of existing docs
- Shell/Makefile: keep targets self-contained with a `## comment` for `make help`

## Reporting bugs

Open an issue with:
- What you did (exact command)
- What you expected
- What actually happened (error message or output)
- Language and framework of the project you were indexing
