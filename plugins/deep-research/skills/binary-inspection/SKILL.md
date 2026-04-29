---
name: binary-inspection
description: |
  Use this skill when investigating compiled programs, executables, shared libraries, or any binary file where you need to understand its structure, embedded content, or build-time decisions.

  Trigger when:
  - User asks to inspect, analyze, or reverse engineer a binary
  - Finding hardcoded values, URLs, config keys, or strings in a compiled program
  - Understanding what libraries a binary links against
  - Investigating build-time decisions embedded in an executable
  - Extracting embedded resources or metadata from compiled code
  - Checking what symbols/functions a library exports

  Do NOT trigger for:
  - Text files, YAML, JSON, scripts (read directly with Read tool)
  - Running or executing binaries (binary-inspector is read-only)
  - Dynamic analysis, tracing, or debugging (strace/gdb are out of scope)
---

# Binary Inspection Skill

Use the `binary-inspector` agent from the deep-research plugin to analyze binary files without modifying them.

## When to Use

- Investigating a compiled program's internals (embedded strings, URLs, config keys)
- Understanding which shared libraries an executable depends on
- Finding function names and exported symbols in a library
- Examining the structure of an ELF binary (sections, segments, dynamic entries)
- Extracting readable content from any non-text file

## How to Invoke

Spawn the binary-inspector agent with a clear goal and output path:

```
Agent(binary-inspector, "Inspect <path/to/binary>. Goal: <what you're looking for>. Save findings to docs/research/<topic>-binary-inspection.md")
```

Always specify:

1. The full path to the binary
2. What you're trying to find or understand
3. Where to save the findings

## Common Tasks

### Find hardcoded strings or config values

```
Agent(binary-inspector, "Inspect /usr/local/bin/claude. Goal: find any hardcoded channel names, URL allowlists, or API endpoint strings. Save findings to docs/research/claude-binary-strings.md")
```

### Check linked libraries

```
Agent(binary-inspector, "Inspect /usr/lib/libssl.so. Goal: show all shared library dependencies and exported symbols. Save findings to docs/research/libssl-dependencies.md")
```

### Identify file type and architecture

```
Agent(binary-inspector, "Inspect /path/to/unknown-binary. Goal: identify file type, architecture, and whether it is stripped. Save findings to docs/research/unknown-binary-identity.md")
```

### Find exported function names

```
Agent(binary-inspector, "Inspect /usr/local/lib/libfoo.so. Goal: list all exported function names, especially those related to authentication. Save findings to docs/research/libfoo-symbols.md")
```

## Example: Inspecting Claude Code for Channel Logic

One concrete use case is inspecting the Claude Code binary (`/usr/local/bin/claude`) to understand behavior that is not documented — for example, finding what channels or URLs are baked into the binary at build time.

```
Agent(binary-inspector, "Inspect /usr/local/bin/claude. Goal: find any strings related to channel names, API endpoints, authentication URLs, or allowlists. Pay special attention to strings containing 'api.anthropic.com', 'claude.ai', or channel identifiers. Save full findings to docs/research/claude-binary-channel-analysis.md and raw strings output to .claude/tmp/claude-binary-strings-raw.txt")
```

The agent will:

1. Run `file` to confirm it is a valid executable
2. Extract strings with `strings -n 8`
3. Filter for keywords relevant to channels and URLs
4. Check `readelf -d` for linked libraries
5. Attempt `nm` for symbol names (may be empty if stripped)
6. Save structured findings to the specified output path

## Output

The binary-inspector saves a structured Markdown report to the path you specify. The report includes:

- File identity (type, architecture, linkage, stripped status)
- Strings of interest (filtered and annotated)
- Symbol analysis (if available)
- Library dependencies
- Key findings summary
- Gaps and limitations

Large raw outputs (full strings list, nm output) are saved as companion files in `.claude/tmp/` to keep the main report readable.

## Limitations

The binary-inspector performs **static analysis only**:

- Cannot trace runtime behavior (use `strace`, `ltrace`, or a debugger for that)
- Cannot recover function names from stripped binaries (strings and hexdump are the fallback)
- Cannot analyze obfuscated or packed binaries without unpacking first
- Requires standard Unix tools (`file`, `strings`, `xxd`, `readelf`, `nm`, `ldd`) — note if any are missing

## After Inspection

Per the research-output rules, commit inspection findings to `docs/research/` on the main branch. Binary inspection results have lasting value for understanding tool internals and should not be left in `.claude/tmp/`.
