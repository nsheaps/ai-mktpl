# GitHub App Token Lifecycle Plugin — Design Document

**Status**: Superseded — see [`../specs/setup-hook-static-config-split.md`](../specs/setup-hook-static-config-split.md) for the current design.

---

This document originally described a multi-source secret-resolution architecture
where the plugin itself read `op://`, `env-file://`, and `secrets.*` config keys
and resolved them at SessionStart. That design has been **superseded** as of
0.4.0.

## Current design (0.4.0+)

Static credentials (`GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`,
`GITHUB_APP_PRIVATE_KEY_PATH`) are no longer the plugin's responsibility. The
agent launcher (`bin/agent`) sources the agent's `.env` / `.env.local` chain
before exec'ing `claude`, so the vars are in process env at hook time. The
plugin fails loudly if any required var is missing.

For the full current specification — lifecycle, paths, migration, runtime vs
static split, BUG-19 background — see:

**[`plugins/github-app/specs/setup-hook-static-config-split.md`](../specs/setup-hook-static-config-split.md)**

For end-user documentation (configuration, troubleshooting, agent isolation),
see the plugin [`README.md`](../README.md) and the
[`github-app-token` skill](../skills/github-app-token/SKILL.md).
