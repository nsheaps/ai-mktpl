# Documentation References

When writing to `.claude/` documentation directories, always include external references.

## Applies To

Files in these locations:

- `.claude/prompts/`
- `.claude/plans/`
- `.claude/scratch/`
- `.claude/docs/`
- `.claude/skills/`

## Rule

Include references to external sources that validate claims, provide context, or support decisions. Every substantive claim should be traceable.

## Valid Reference Types

| Type            | Example                                                                    |
| --------------- | -------------------------------------------------------------------------- |
| GitHub PR/Issue | `[PR #123](https://github.com/org/repo/pull/123)`                          |
| GitHub comment  | `[Review comment](https://github.com/org/repo/pull/123#discussion_r12345)` |
| Slack permalink | `[Discussion](https://workspace.slack.com/archives/C123/p1234567890)`      |
| Blog post       | `[Article title](https://example.com/blog/post)`                           |
| Stack Overflow  | `[SO answer](https://stackoverflow.com/a/12345)`                           |
| Documentation   | `[Docs: Topic](https://docs.example.com/topic)`                            |
| Raw excerpt     | Blockquote with attribution                                                |

## Minimum Standard

- PR feedback prompts: Link to the actual review comments
- Plans: Link to relevant issues, discussions, or specifications
- Skills: Link to official documentation for tools/APIs referenced
- Scratch notes: At minimum, note the date and context of information

## How-To Guide

<!-- TODO: Create .ai/docs/how-to-write-references-in-docs.md with detailed examples and formatting guidance -->
