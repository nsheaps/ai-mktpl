# claude-powerline-rust

## Overview

| Attribute      | Value                                                                                       |
| -------------- | ------------------------------------------------------------------------------------------- |
| **Name**       | claude-powerline-rust                                                                       |
| **Repository** | [david-strejc/claude-powerline-rust](https://github.com/david-strejc/claude-powerline-rust) |
| **Stars**      | N/A                                                                                         |
| **Language**   | Rust                                                                                        |
| **Install**    | `cargo build --release && sudo cp target/release/claude-powerline /usr/local/bin/`          |

## Summary

Ultra-fast Rust statusline for Claude Code - 8.4x faster than TypeScript implementations with real-time usage tracking. Features SIMD-accelerated JSON parsing, memory-mapped I/O, and parallel processing with rayon. Execution time is 150ms vs 1.26s for TypeScript equivalents.

## Key Features

- 8.4x performance improvement (150ms vs 1.26s)
- SIMD-accelerated JSON parsing
- Memory-mapped I/O
- Parallel processing with rayon
- 5 beautiful themes
- Cross-platform Windows support

## Installation

```bash
cargo build --release && sudo cp target/release/claude-powerline /usr/local/bin/
```
