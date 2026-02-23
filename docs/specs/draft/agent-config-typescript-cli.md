# Implementation Plan: Converting agent-config Shell Scripts to TypeScript CLI

## Executive Summary

This plan outlines the conversion of the `agent-config` shell scripts to a TypeScript CLI using Bun. The implementation will preserve all existing behavior including dry-run mode, colored output, and symlink handling, while providing better type safety, testability, and maintainability.

## 1. Project Structure

### Recommended Directory Layout

```
/Users/nathan.heaps/src/nsheaps/ai/
├── bin/
│   ├── agent-config           # Shim script that runs TypeScript
│   └── lib/
│       ├── agent-config/      # Archive shell scripts (renamed)
│       │   ├── common.sh
│       │   ├── sync.sh
│       │   └── unlink.sh
│       └── stdlib.sh          # KEEP - used by other scripts
├── src/
│   └── agent-config/          # TypeScript source
│       ├── index.ts           # Main entry point
│       ├── cli.ts             # CLI definition (Commander setup)
│       ├── commands/
│       │   ├── sync.ts        # Sync subcommand
│       │   └── unlink.ts      # Unlink subcommand
│       └── lib/
│           ├── config.ts      # Configuration (BASE_SYNC_PATH, UPSTREAM_FOLDER)
│           ├── logger.ts      # Colored output (info, error, dryrun, success)
│           ├── symlinks.ts    # Symlink creation/removal utilities
│           └── paths.ts       # Path resolution utilities
├── package.json               # Project dependencies
├── tsconfig.json              # TypeScript configuration
└── mise.toml                  # Already has bun = "latest"
```

### Key Constraints

- **DO NOT DELETE `bin/lib/stdlib.sh`**: Used by other scripts
- Archive (don't delete) shell scripts after migration

## 2. Dependencies

### package.json

```json
{
  "name": "@nsheaps/agent-config",
  "version": "1.0.0",
  "type": "module",
  "main": "src/agent-config/index.ts",
  "bin": {
    "agent-config": "./bin/agent-config"
  },
  "scripts": {
    "dev": "bun run src/agent-config/index.ts",
    "typecheck": "bun x tsc --noEmit",
    "test": "bun test"
  },
  "dependencies": {
    "commander": "^14.0.0",
    "picocolors": "^1.1.0"
  },
  "devDependencies": {
    "@types/bun": "latest",
    "typescript": "^5.7.0"
  }
}
```

| Package        | Rationale                                                      |
| -------------- | -------------------------------------------------------------- |
| **commander**  | Industry-standard CLI framework, excellent TypeScript support  |
| **picocolors** | Lightweight (3.8KB), faster than chalk, all needed ANSI colors |

## 3. Build Strategy

### Development: Shim Script (Recommended)

Create `bin/agent-config` as a thin shim:

```bash
#!/usr/bin/env bash
exec bun run "$(dirname "$0")/../src/agent-config/index.ts" "$@"
```

- No build step needed
- Changes take effect immediately
- Requires Bun (already managed by mise)

### Alternative: Compiled Binary (For Distribution)

```bash
bun build src/agent-config/index.ts --compile --outfile bin/agent-config --minify
```

## 4. Implementation Files

### 4.1 `src/agent-config/lib/logger.ts`

Matches stdlib.sh logging:

```typescript
import pc from "picocolors";

export const info = (msg: string) => console.log(`${pc.blue("[INFO]")} ${msg}`);
export const error = (msg: string) => console.error(`${pc.red("ERROR:")} ${msg}`);
export const success = (msg: string) => console.log(pc.green(msg));
export const debug = (msg: string) => console.log(pc.gray(msg));
export const dryrun = (msg: string) => console.log(`${pc.yellow("[DRY]")} ${msg}`);
export const warn = (msg: string) => console.error(pc.yellow(msg));
```

### 4.2 `src/agent-config/lib/config.ts`

Configuration and UPSTREAM_FOLDER derivation:

```typescript
export const BASE_SYNC_PATH = ".ai";

function deriveUpstreamFolder(rootDir: string, homeDir: string): string {
  const relativePath = rootDir.startsWith(homeDir) ? rootDir.slice(homeDir.length + 1) : rootDir;
  return `upstream--${relativePath.replace(/\//g, "-")}`;
}

async function findGitRoot(): Promise<string> {
  const proc = Bun.spawn(["git", "rev-parse", "--show-toplevel"], { stdout: "pipe" });
  return (await new Response(proc.stdout).text()).trim();
}

export async function loadConfig() {
  const homeDir = process.env.HOME ?? "";
  const rootDir = process.env.ROOT_DIR ?? (await findGitRoot());
  return {
    baseSyncPath: BASE_SYNC_PATH,
    upstreamFolder: deriveUpstreamFolder(rootDir, homeDir),
    rootDir,
    homeDir,
  };
}
```

### 4.3 `src/agent-config/lib/symlinks.ts`

Symlink utilities matching stdlib.sh behavior:

```typescript
import { existsSync, lstatSync, readlinkSync, mkdirSync, symlinkSync, rmSync } from "fs";
import { dirname } from "path";
import * as log from "./logger";

export function createDirSymlink(source: string, target: string, dryRun: boolean) {
  const stat = lstatSync(target, { throwIfNoEntry: false });

  if (stat?.isSymbolicLink()) {
    const existing = readlinkSync(target);
    if (existing === source) return { created: false, existed: true };
    return { created: false, existed: true, error: `Points to different target: ${existing}` };
  }

  if (existsSync(target)) {
    return { created: false, existed: true, error: `Not a symlink: ${target}` };
  }

  if (dryRun) {
    log.dryrun(`Would create: ${target} -> ${source}`);
    return { created: false, existed: false };
  }

  mkdirSync(dirname(target), { recursive: true });
  symlinkSync(source, target);
  log.success(`Created: ${target} -> ${source}`);
  return { created: true, existed: false };
}

export function unlinkItem(path: string, itemType: string, dryRun: boolean): boolean {
  const stat = lstatSync(path, { throwIfNoEntry: false });
  if (!stat) return false;

  const name = path.split("/").pop() ?? path;

  if (stat.isSymbolicLink()) {
    const linkTarget = readlinkSync(path);
    if (dryRun) log.dryrun(`Would remove ${itemType}: ${name} -> ${linkTarget}`);
    else {
      rmSync(path);
      log.success(`Removed ${itemType}: ${name}`);
    }
    return true;
  }

  if (stat.isFile()) {
    if (dryRun) log.dryrun(`Would remove ${itemType}: ${name}`);
    else {
      rmSync(path);
      log.success(`Removed ${itemType}: ${name}`);
    }
    return true;
  }

  return false;
}
```

### 4.4 `src/agent-config/cli.ts`

Commander.js CLI setup:

```typescript
import { Command } from "commander";
import { loadConfig } from "./lib/config";
import { syncCommand } from "./commands/sync";
import { unlinkCommand } from "./commands/unlink";

export function createCLI(): Command {
  const program = new Command()
    .name("agent-config")
    .description("Manage AI agent configuration")
    .version("1.0.0");

  program
    .command("sync")
    .description("Sync .ai content to Claude Code directories")
    .argument("[types...]", "Types: rules, agents, commands, _all")
    .option("-T, --target <path>", "Target directory", "~/.claude")
    .option("-d, --dry-run", "Show what would be done (default)", true)
    .option("-n, --no-dry-run", "Actually perform the sync")
    .action(async (types, options) => {
      const config = await loadConfig();
      await syncCommand(
        { ...options, types, target: options.target.replace("~", config.homeDir) },
        config,
      );
    });

  program
    .command("unlink")
    .description("Remove symlinks created by sync")
    .argument("<dir>", "Target directory to unlink")
    .option("-d, --dry-run", "Show what would be done (default)", true)
    .option("-n, --no-dry-run", "Actually perform the unlink")
    .action(async (dir, options) => {
      const config = await loadConfig();
      await unlinkCommand({ ...options, target: dir.replace("~", config.homeDir) });
    });

  return program;
}
```

### 4.5 `src/agent-config/index.ts`

Entry point:

```typescript
#!/usr/bin/env bun
import { createCLI } from "./cli";
await createCLI().parseAsync(process.argv);
```

## 5. Migration Path

### Phase 1: Parallel Implementation

1. Create TypeScript implementation in `src/agent-config/`
2. Rename shell `bin/agent-config` to `bin/lib/agent-config-legacy.sh`
3. Create new `bin/agent-config` shim that runs TypeScript

### Phase 2: Validation

1. Run parity tests comparing outputs
2. Manual testing of all commands
3. User approval

### Phase 3: Cleanup

1. Archive shell scripts (don't delete)
2. Update documentation

## 6. mise/justfile Integration

### justfile recipes

```just
# Link agent-config to ~/.local/bin for global access
install-agent-config:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "$HOME/.local/bin"
    ln -sf "{{root_dir}}/bin/agent-config" "$HOME/.local/bin/agent-config"
    echo "Linked: ~/.local/bin/agent-config -> {{root_dir}}/bin/agent-config"

uninstall-agent-config:
    rm -f "$HOME/.local/bin/agent-config"
```

### mise.toml tasks

```toml
[tasks.install-agent-config]
run = "just install-agent-config"
description = "Install agent-config CLI globally"
```

## 7. Implementation Order

1. Set up package.json, tsconfig.json
2. Implement `lib/logger.ts`, `lib/config.ts`
3. Implement `lib/symlinks.ts`
4. Implement `commands/sync.ts`
5. Implement `commands/unlink.ts`
6. Implement `cli.ts`, `index.ts`
7. Create shim script, rename legacy scripts
8. Add justfile recipes for global install
9. Testing and validation
