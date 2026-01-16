# Claude Code Compact Customization Research

**Date:** 2026-01-15
**Status:** Documented limitation - feature request recommended

## Question

Is there any way to customize the compacting process in Claude Code to always use a specific model (e.g., Sonnet 1M context) instead of the currently configured model?

## Summary

**No, there is currently no way to configure a specific model for the compact operation.** Compact always uses whatever model is globally configured.

## Findings

### What Exists

#### Hooks

1. **`PreCompact` hook** - Fires before compact operation
   - Matchers: `"manual"` or `"auto"` (based on trigger type)
   - Input: `{ trigger: "manual" | "auto", custom_instructions?: string }`
   - **Limitation:** Can only observe/log, cannot modify the compact operation itself

2. **`SessionStart` hook** - Fires after compact completes
   - Matcher: `"compact"` (based on source)
   - Can be used to inject context or set environment variables via `CLAUDE_ENV_FILE`
   - This is the closest to a "post-compact" hook

#### Custom Instructions

The `/compact` command accepts optional instructions:

```bash
/compact "focus on TODO items and architectural decisions"
```

This influences what gets summarized but not how (model, parameters, etc.).

### What Doesn't Exist

- No `compactModel` setting in `settings.json`
- No `ANTHROPIC_COMPACT_MODEL` environment variable
- No per-operation model override mechanism
- No `PostCompact` hook
- No way to intercept and modify compact parameters via hooks

### Settings Schema Review

The complete `settings.json` schema was reviewed. Compact-related settings are limited to:

- Hook configuration for `PreCompact` event
- Hook configuration for `SessionStart` with `"compact"` source

No model or behavior overrides exist for compacting.

## Workaround

The only current option is to manually switch models before compacting:

```bash
/model sonnet[1m]
/compact
/model opus  # switch back if needed
```

This is manual and not automatable via hooks or settings.

## Recommendation

Submit a feature request via `/feedback` for one of:

1. **`compactModel` setting** in `settings.json`:

   ```json
   {
     "compactModel": "claude-sonnet-4-20250514"
   }
   ```

2. **Environment variable** `ANTHROPIC_COMPACT_MODEL` or `CLAUDE_COMPACT_MODEL`

3. **PreCompact hook enhancement** allowing return value to specify model override

## References

- [Claude Code Settings Reference](https://docs.anthropic.com/en/docs/claude-code/settings)
- [Claude Code Hooks Reference](https://docs.anthropic.com/en/docs/claude-code/hooks)
- [Claude Code CLI Reference](https://docs.anthropic.com/en/docs/claude-code/cli)
- [The /compact Command Guide](https://deepwiki.com/FlorianBruniaux/claude-code-ultimate-guide/3.2-the-compact-command)
