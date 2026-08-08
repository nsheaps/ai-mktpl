---
name: extract-builtins
description: >
  Use this skill when reproducing, updating, or auditing one of Claude Code's
  built-in slash commands from the compiled CLI binary — e.g. "pull the /usage
  command out of the binary", "re-extract the init prompt for the new version",
  "how were these built-ins extracted", or "the binary updated, refresh
  the extracted commands". Documents the exact, safe pipeline used to recover the
  built-ins in this plugin from the Bun-compiled binary WITHOUT reading the
  obfuscated source directly, and REQUIRES stamping every extraction with the
  binary version it came from.
---

# Extracting the built-ins from the Claude Code binary

Every command and prompt reproduced in this plugin was recovered from the
compiled `claude` binary. This skill is the method: how to locate a built-in
inside the binary, pull just that fragment out, make it readable, and — most
importantly — **record which binary build it came from** so the reproduction can
be trusted and re-verified later.

## Non-negotiable rules

1. **Never read the obfuscated/minified code directly.** Do not open the binary,
   the embedded bundle, or a raw `strings` dump wholesale in the editor or with
   Read. The dump is tens of megabytes of minified JS; reading it is both
   useless and a good way to blow up context.
2. **You may only read a fragment once it has been (a) extracted from the
   binary by byte offset into its own file, and (b) run through a beautifier.**
   Read the _formatted_ slice — never the raw slice.
3. **Use AST traversal, not eyeballing, for structure.** Once a slice is
   beautified, use an AST tool (acorn / `@babel/parser` walk, `ast-grep`) to
   find declarations, follow the minified symbol aliases, and confirm control
   flow. Grep locates; the AST confirms.
4. **Every extraction records the binary version.** No fragment enters the
   plugin without a provenance stamp (see below). A recovered command with no
   version is worthless — the binary changes constantly and the fragment is only
   correct relative to one build.

## Step 0 — Stamp the binary version FIRST

Before extracting anything, capture the identity of the binary you are working
from. This is the first step of every extraction, not an afterthought.

Let `ROOT="${CLAUDE_PLUGIN_ROOT}/skills/extract-builtins"` — a skill runs in the
session's cwd, and these scripts live under the skill dir, not the plugin-root
`scripts/` (which holds the collectors).

```bash
ROOT="${CLAUDE_PLUGIN_ROOT}/skills/extract-builtins"

CLAUDE_BIN=$(readlink -f "$(command -v claude)")
file "$CLAUDE_BIN"                    # confirm: ELF 64-bit (Bun binary) vs Node.js script (JS bundle)
"$ROOT/scripts/binary-version.sh"     # prints version / git sha / build time / sha256 / path
```

`$ROOT/scripts/binary-version.sh` emits a provenance block like:

```
- claude version: 2.1.223
- git sha:        4535f69721056abf01650c73ee8a91c69ba00838
- build time:     2026-08-05T18:12:31Z
- binary path:    /opt/claude-code/bin/claude
- binary sha256:  <sha>
- extracted on:   2026-08-06T00:00:00Z
```

Record this **per extracted command** — the exact build a given fragment was
pulled from — in that command's skill/prompt header or in
[`docs/command-inventory.md`](../../docs/command-inventory.md). When you
re-extract after a binary update, add a new stamp rather than overwriting the
old one, so the history of which build each reproduction tracks is preserved.

> Binary format transition: `v2.1.94`–`v2.1.112` shipped as a ~13MB JS bundle
> (`cli.js`, readable strings, easy grep); `v2.1.113`+ is a ~245MB Bun-compiled
> ELF binary. The offsets and beautify step below are for the Bun binary.

## Step 1 — Locate the fragment (offsets, done right)

Dump strings **with byte offsets** and grep for a stable marker — a command
name, description text, or an export mapping:

```bash
strings -t d -n 8 "$CLAUDE_BIN" > strings.txt      # -t d = decimal file offset in col 1
grep 'reload-plugins' strings.txt                  # the marker + its REAL offset in col 1
```

**The offset you want is the leading decimal column from `strings -t d`** — that
is the true byte offset into the binary. `grep -aob '<marker>' "$CLAUDE_BIN"`
gives the same true offset _if you grep the binary itself_. What you must never
do is take an offset out of an **intermediate stream** — `strings "$CLAUDE_BIN" | grep -b …`,
or the `-n` line number from `grep -n … strings.txt` — because those index the
dump, not the file, and will slice the wrong bytes.

Built-in command definitions follow a recognizable shape, e.g.:

```
{type:"local",name:"reload-plugins",description:"…",supportsNonInteractive:!1,…}
```

Export mappings that reveal minified names follow `EXPORTNAME:()=>FUNCNAME` —
note the `FUNCNAME` and grep for its definition to follow the call chain.

## Step 2 — Slice out just that fragment

Slice a byte window around the marker into its own file. Start wide enough to
capture the whole declaration (command object + its handler); extend the window
if the fragment ends mid-string or mid-function.

```bash
# node "$ROOT/scripts/slice-binary.mjs" <binary> <out.js> <startOffset> <endOffset>
node "$ROOT/scripts/slice-binary.mjs" "$CLAUDE_BIN" chunks/reload.js 271783000 271788500
```

The slicer keeps printable ASCII + tab/newline and turns every other byte into a
newline, giving the beautifier clean token boundaries. **Do not Read
`chunks/reload.js` yet** — it is still raw.

## Step 3 — Beautify, THEN read

Format the raw slice. `js-beautify` tolerates minified/partial fragments where
`prettier` and bare `acorn` reject them:

```bash
npx js-beautify@1 chunks/reload.js -o fmt/reload.js
```

Now `fmt/reload.js` is an extracted, separated, formatted chunk — this is the
only artifact you are permitted to Read.

## Step 4 — Traverse with an AST, follow the aliases

Minification renames everything (`ecb`, `ncb`, `c0e`, `$Q`, `nj`, `ace`…). Use
an AST walk over the formatted slice to enumerate declarations and resolve what
each alias points at, rather than trusting a visual scan. Slice out and beautify
each referenced function the same way (Steps 1–3) until the behavior is fully
recovered.

## Step 5 — Reproduce only what's honest

Rebuild the command as a skill + optional collector script in this plugin,
driven by the verbatim prompt. If a built-in only toggles terminal UI or talks
to a native host / account backend, there is nothing to compute outside the
CLI — **do not fake it**; record it as non-reproducible in
[`docs/command-inventory.md`](../../docs/command-inventory.md) with the tier and
the reason.

### Describe the reproduction, don't grade it

State what a reproduction **is**, never how good it is. "Extracted verbatim from
the binary (v2.1.225)" is a checkable fact; "faithful extraction" is a
self-awarded grade that means nothing to a reader and violates the
relay-integrity principle (describe the thing, don't editorialize about it).

- **A prompt/command pulled out byte-for-byte:** say it is **verbatim** (with the
  binary version). Do **not** add a "faithful"/"faithful extraction"/"faithful
  reproduction" line — the fact is the version stamp, not an adjective.
- **Code we authored to stand in for something the binary does programmatically**
  (e.g. an HTML renderer the CLI assembles in-process, with no extractable
  source): describe it as an **equivalent** reimplementation and, if and only if
  a behavior could not be extracted or proven from the underlying logic, record
  the assumption where the doc type calls for it — a code comment in the script,
  a note in the skill — stating (a) **why** it couldn't be extracted, (b) **what
  to check on the next extraction pass** to see whether it has become
  extractable, and (c) the **assumption** made in the meantime. If the logic is
  functionally the same as the built-in, it **is** the same — add no comment and
  no "stand-in" caveat.

## Worked example: the reload-plugins / reload-skills investigation

A full application of Steps 0–4 — used to answer whether the model can force
`/reload-plugins` or `/reload-skills` — is written up in
[`docs/reload-mechanisms.md`](../../docs/reload-mechanisms.md), including the
recovered handler shapes, the minified symbol map, and the conclusion (all three
reload triggers are user/host/hook-driven, none model-invokable) with the
binary-patch fallback plan. Read that as a template for a rigorous extraction.

## Tooling notes / gotchas

- `strings -t d` leading field = real binary offset; so is `grep -aob` **on the
  binary itself**. An offset out of an intermediate stream (`strings … | grep -b`,
  or a `grep -n` line number from `strings.txt`) is NOT a file offset.
- `js-beautify@1` succeeds on minified fragments; `prettier`/raw `acorn` fail.
- Extend the byte window and re-slice if a fragment ends inside a template
  literal or mid-function — a real newline inside a `` `…` `` literal will
  truncate a naive read.
- Keep raw slices (`chunks/`) and formatted slices (`fmt/`) in a scratch
  directory outside the repo; only the recovered _artifact_ (skill, prompt,
  collector) plus its provenance stamp belongs in the plugin.
