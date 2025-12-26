# Claude Code Plugin Marketplace

A curated collection of high-quality plugins for Claude Code, focusing on git automation and intelligent development workflows.

**Key Resources:**
- Plugin Development: See `.claude/rules/plugin-development.md`
- CI/CD Conventions: See `.claude/rules/ci-cd/conventions.md`
- Versioning: See `.claude/rules/versioning.md`

**Before Making Changes:**
1. Read plugin-development.md (KISS & YAGNI principles)
2. Check versioning.md for version bump requirements
3. Run `just check` before pushing

**Quick Commands:**
```bash
just lint      # Run all linters
just validate  # Validate plugin structure
just check     # Run lint + validate
```
