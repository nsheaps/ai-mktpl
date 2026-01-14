# Claude Code Statusline Tools - Summary

> Research compiled: 2026-01-14
> Total tools found: 33

This document catalogs all known Claude Code statusline tools available on GitHub. Each tool provides status information for the Claude Code CLI, typically displaying usage metrics, git status, cost tracking, and other contextual information.

## All Tools Sorted by Stars (Descending)

| Repository                                                                                                    | Stars  | Summary                                                                                                                                                                                                                                              |
| ------------------------------------------------------------------------------------------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [sirmalloc/ccstatusline](https://github.com/sirmalloc/ccstatusline)                                           | ~2,300 | Beautiful highly customizable statusline for Claude Code CLI with powerline support, themes, and interactive Terminal UI configuration. Built with React and Ink, featuring smart width detection and Windows optimization with Bun runtime.         |
| [Haleclipse/CCometixLine](https://github.com/Haleclipse/CCometixLine)                                         | ~1,300 | High-performance Rust statusline with Git integration, usage tracking, and interactive TUI configuration. Cross-platform support with real-time usage tracking and Claude Code enhancement utilities.                                                |
| [Owloops/claude-powerline](https://github.com/Owloops/claude-powerline)                                       | ~678   | Vim-style powerline statusline with real-time usage tracking and git integration. Features 6 themes (dark, light, nord, tokyo-night, rose-pine, gruvbox), 3 styles (minimal, powerline, capsule), and zero dependencies. 5,170 weekly npm downloads. |
| [chongdashu/cc-statusline](https://github.com/chongdashu/cc-statusline)                                       | ~360   | Bash-first native shell execution for maximum speed with execution under 100ms (typically 45-80ms). Features zero dependencies, privacy-first design, and ccusage integration for live usage stats.                                                  |
| [Ido-Levi/claude-code-tamagotchi](https://github.com/Ido-Levi/claude-code-tamagotchi)                         | ~240   | A unique digital pet that lives in your statusline with real-time behavioral enforcement. Monitors AI actions, detects violations, and can interrupt operations when violations are detected. The pet reacts to code activity.                       |
| [wolfdenpublishing/pyccsl](https://github.com/wolfdenpublishing/pyccsl)                                       | ~81    | Python Claude Code Status Line (pronounced "pixel") with multiple themes, powerline style support, and performance metrics. Highly configurable through environment variables with multiple display modes.                                           |
| [ersinkoc/claude-statusline](https://github.com/ersinkoc/claude-statusline)                                   | ~68    | Python statusline with background daemon mode, analytics, and interactive theme browser. Features database analytics for historical tracking, security patches for Windows, and all local data processing.                                           |
| [spences10/claude-statusline-powerline](https://github.com/spences10/claude-statusline-powerline)             | N/A    | Powerline-style statusline with git integration, session tracking, and cost monitoring. Optimized for Victor Mono font with SQLite database for usage analytics and Settings IntelliSense support.                                                   |
| [ryoppippi/ccusage](https://github.com/ryoppippi/ccusage)                                                     | N/A    | CLI tool for analyzing Claude Code usage from local JSONL files with statusline integration (Beta). Provides daily/monthly/session reports, 5-hour billing windows tracking, and colorful table display.                                             |
| [rz1989s/claude-code-statusline](https://github.com/rz1989s/claude-code-statusline)                           | N/A    | Atomic precision statusline with 18 components across 1-9 configurable lines. Unique features include Islamic prayer times, MCP server monitoring, and multiple themes (classic, garden, catppuccin).                                                |
| [hagan/claudia-statusline](https://github.com/hagan/claudia-statusline)                                       | N/A    | High-performance Rust statusline with SQLite persistence, 11 embedded themes, 5 layout presets, and optional Turso cloud sync. Features context progress bars and burn rate calculation.                                                             |
| [david-strejc/claude-powerline-rust](https://github.com/david-strejc/claude-powerline-rust)                   | N/A    | Ultra-fast Rust implementation - 8.4x faster than TypeScript (150ms vs 1.26s). Features SIMD-accelerated JSON parsing, memory-mapped I/O, parallel processing with rayon, and 5 beautiful themes.                                                    |
| [MaurUppi/CCstatus](https://github.com/MaurUppi/CCstatus)                                                     | N/A    | Rust statusline with network detection showing P95 statistics including DNS, TCP, TLS, and TTFB metrics. Features git integration, JSONL log collection, and cross-platform support.                                                                 |
| [khoi/cc-statusline-rs](https://github.com/khoi/cc-statusline-rs)                                             | N/A    | Lightweight Rust statusline based on steipete's gist with cost tracking, git status, and fast execution (~85ms). A simple but effective Rust implementation.                                                                                         |
| [ding113/ccline-packycc](https://github.com/ding113/ccline-packycc)                                           | N/A    | Rust statusline for PackyCode with API quota monitoring, real-time quota tracking, TUI configuration mode, and daily spending tracking.                                                                                                              |
| [gabriel-dehan/claude_monitor_statusline](https://github.com/gabriel-dehan/claude_monitor_statusline)         | N/A    | The only Ruby implementation with git status, model display, usage tracking with plan limits, and multiple display modes. Features manual mock testing support.                                                                                      |
| [illumin8ca/claude-statusline](https://github.com/illumin8ca/claude-statusline)                               | N/A    | Highly configurable git integration with SHA display, working tree status, operation indicators, tag display, and stash count. Supports environment variable configuration and custom shell extensions.                                              |
| [hell0github/claude-statusline](https://github.com/hell0github/claude-statusline)                             | N/A    | Lightweight bash statusline with multi-layer progress visualization and weekly usage tracking. Features ccusage integration and support for macOS and Linux.                                                                                         |
| [levz0r/claude-code-statusline](https://github.com/levz0r/claude-code-statusline)                             | N/A    | Bash statusline with real-time token tracking, model-specific cost calculation, color-coded display, git status, and transcript parsing for accurate usage metrics.                                                                                  |
| [aaronvstory/claude-code-enhanced-statusline](https://github.com/aaronvstory/claude-code-enhanced-statusline) | N/A    | Unique integrations including weather (wttr.in API), Bitcoin price (Coinbase API), git status, and token tracking. Features HTTP connection pooling and smart caching.                                                                               |
| [jarrodwatts/claude-hud](https://github.com/jarrodwatts/claude-hud)                                           | N/A    | Multi-line HUD plugin showing context usage, active tools, running agents, and todo progress. No tmux required, with rate limit consumption tracking and context health display.                                                                     |
| [melon-hub/claude-hud](https://github.com/melon-hub/claude-hud)                                               | N/A    | Fork of jarrodwatts/claude-hud with context usage, active tools, running agents, and todo progress display. Community-maintained variant with potential enhancements.                                                                                |
| [leeguooooo/claude-code-usage-bar](https://github.com/leeguooooo/claude-code-usage-bar)                       | N/A    | Python statusline showing token usage, remaining budget, burn rate, and depletion time estimation. Helps predict when you'll run out of API budget with auto-updates daily.                                                                          |
| [Wzh0718/CCstatusline](https://github.com/Wzh0718/CCstatusline)                                               | N/A    | Python statusline powered by ccusage displaying model name, cost, and remaining time until reset. Includes Windows batch file support for easy execution.                                                                                            |
| [syou6162/ccstatusline](https://github.com/syou6162/ccstatusline)                                             | N/A    | Go statusline with unique YAML configuration approach. Features template syntax for JSON data access, shell command execution, TTL-based caching, and XDG compliance.                                                                                |
| [Veraticus/cc-tools](https://github.com/Veraticus/cc-tools)                                                   | N/A    | High-performance Go utilities with statusline and MCP management. Features environment context (K8s, AWS), token usage bars, and no daemon requirement.                                                                                              |
| [vibe-log/vibe-log-cli](https://github.com/vibe-log/vibe-log-cli)                                             | N/A    | Session logging and analysis CLI with statusline integration providing actionable guidance. Features parallel session analysis, standup summaries, and automatic config backup.                                                                      |
| [fcakyon/claude-codex-settings](https://github.com/fcakyon/claude-codex-settings)                             | N/A    | Statusline plugin using official usage API for account-wide block usage and reset time. Shows session context percentage, cost tracking, and git branch info.                                                                                        |
| [pchalasani/claude-code-tools](https://github.com/pchalasani/claude-code-tools)                               | N/A    | Productivity tools including tmux-cli for terminal automation. Enables interactive script testing, debugger integration, and Claude-to-Claude communication.                                                                                         |
| [steipete (Gist)](https://gist.github.com/steipete/8396e512171d31e934f0013e5651691e)                          | N/A    | Popular status bar script averaging ~85ms execution time. Inspired the cc-statusline-rs Rust version. Features git status (optional), session time, and cost tracking.                                                                               |
| [JuanjoFuchs/ccburn](https://github.com/JuanjoFuchs/ccburn)                                                   | N/A    | Usage limits TUI with burn-up charts, compact mode for statusbars, JSON output for automation, budget pace calculation, and SQLite historical analysis.                                                                                              |
| [Maciek-roboblog/Claude-Code-Usage-Monitor](https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor)     | N/A    | Real-time terminal monitoring with ML-based predictions for session limits. Features Rich terminal UI, burn rate analysis, cost analysis, and intelligent usage predictions.                                                                         |

## Tools by Language

### Rust (6 tools)

High-performance implementations with excellent execution times:

- Haleclipse/CCometixLine
- hagan/claudia-statusline
- david-strejc/claude-powerline-rust
- MaurUppi/CCstatus
- khoi/cc-statusline-rs
- ding113/ccline-packycc

### TypeScript/JavaScript (8+ tools)

Popular choice with npm ecosystem integration:

- sirmalloc/ccstatusline
- Owloops/claude-powerline
- spences10/claude-statusline-powerline
- Ido-Levi/claude-code-tamagotchi
- jarrodwatts/claude-hud
- illumin8ca/claude-statusline
- ryoppippi/ccusage
- aaronvstory/claude-code-enhanced-statusline

### Python (5 tools)

Accessible implementations with rich features:

- ersinkoc/claude-statusline
- wolfdenpublishing/pyccsl
- leeguooooo/claude-code-usage-bar
- Wzh0718/CCstatusline
- Maciek-roboblog/Claude-Code-Usage-Monitor

### Go (2 tools)

Fast, compiled alternatives:

- syou6162/ccstatusline
- Veraticus/cc-tools

### Shell/Bash (5+ tools)

Lightweight, dependency-free options:

- chongdashu/cc-statusline
- rz1989s/claude-code-statusline
- hell0github/claude-statusline
- levz0r/claude-code-statusline
- steipete (Gist)

### Ruby (1 tool)

- gabriel-dehan/claude_monitor_statusline

## Unique Features Highlights

| Feature                | Tool                                        |
| ---------------------- | ------------------------------------------- |
| Weather integration    | aaronvstory/claude-code-enhanced-statusline |
| Bitcoin price          | aaronvstory/claude-code-enhanced-statusline |
| Islamic prayer times   | rz1989s/claude-code-statusline              |
| Virtual pet/Tamagotchi | Ido-Levi/claude-code-tamagotchi             |
| ML-based predictions   | Maciek-roboblog/Claude-Code-Usage-Monitor   |
| Cloud sync (Turso)     | hagan/claudia-statusline                    |
| YAML configuration     | syou6162/ccstatusline                       |
| Behavioral enforcement | Ido-Levi/claude-code-tamagotchi             |

## Related Resources

- [awesome-claude-code (hesreallyhim)](https://github.com/hesreallyhim/awesome-claude-code) - Curated list of Claude Code tools
- [awesome-claude-code (jqueryscript)](https://github.com/jqueryscript/awesome-claude-code) - Another curated list
- [Claude Code Official Statusline Docs](https://code.claude.com/docs/en/statusline) - Official documentation
- [ccusage.com](https://ccusage.com/guide/statusline) - ccusage statusline guide
- [claudepluginhub.com](https://www.claudepluginhub.com/) - Plugin directory

---

_Individual tool documentation files are available in the `statusline-tools/` directory._
