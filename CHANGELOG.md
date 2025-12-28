# Changelog

All notable changes to this project will be documented in this file. See [commit-and-tag-version](https://github.com/absolute-version/commit-and-tag-version) for commit guidelines.

## 1.1.0 (2025-12-27)

### Features

- add additional Bash commands for GitHub pull request management in settings.json ([b264c2e](https://github.com/nsheaps/.ai/commit/b264c2e05fd20e8bf6ed92720386d52076b97d87))
- add Claude Code GitHub Action for PR interactions ([daea187](https://github.com/nsheaps/.ai/commit/daea18744e39735299842651cf275bdeb3499cb2))
- add Claude Code web support and skills-maintenance plugin ([3cd5f04](https://github.com/nsheaps/.ai/commit/3cd5f0422678bc7a416e15ebbec9e6dca26a5ab0))
- add command-help skill for slash command discovery ([0e71ec5](https://github.com/nsheaps/.ai/commit/0e71ec5047a25e10adf4afe389457aa3594a6a98))
- add comprehensive ci/cd workflows and github actions ([797e0b7](https://github.com/nsheaps/.ai/commit/797e0b7f49cb966ee1db16f21c7289c08b6d0fd5))
- add conversation-history-search agent ([83f0ab7](https://github.com/nsheaps/.ai/commit/83f0ab7b20a2c204751c561f1c58447f660968f6))
- add correct-behavior command plugin ([65ecf60](https://github.com/nsheaps/.ai/commit/65ecf60c5c24b4980f2195b27e22bd909ff43062))
- add GitHub Actions CI/CD workflows and custom actions ([14646ce](https://github.com/nsheaps/.ai/commit/14646ce324b3540804ce81335019a76da24ddfa0))
- add guidelines for Claude Code configuration and project mantras ([152b895](https://github.com/nsheaps/.ai/commit/152b895b952163bcd01ea5aa370fef137f067771))
- add linear-mcp-sync plugin with hash validation hooks ([71432db](https://github.com/nsheaps/.ai/commit/71432dba6e083163734918c06f1588cba51f9e3b))
- add markdownlint configuration ([e9ff9b3](https://github.com/nsheaps/.ai/commit/e9ff9b38c7be79541e762f49e2bde4efa05510c5))
- add memory-manager plugin for intelligent CLAUDE.md management ([7dc5cb6](https://github.com/nsheaps/.ai/commit/7dc5cb64fbd31df2c59c577eff60fedd33b8dcbf))
- add mise development environment configuration ([1897667](https://github.com/nsheaps/.ai/commit/1897667591377cc61e87b967cc4820bd99bc51f7))
- add mise tool management and simplify session hook ([f050ebe](https://github.com/nsheaps/.ai/commit/f050ebe4084bc3a2ebf0c21c2aa75141bc0456b4))
- add new plugins and update existing plugins ([4538c13](https://github.com/nsheaps/.ai/commit/4538c13eaa829a98e8ffcd07eaa430c456621444))
- add permission gates for git force push operations ([7e013b8](https://github.com/nsheaps/.ai/commit/7e013b867ec63fb3a092dc16167aaad4898a3820))
- add prettier config file ([d4f9b59](https://github.com/nsheaps/.ai/commit/d4f9b59ffcf1426c3ddb6e108d0c804c3280558b))
- add reusable Claude authentication GitHub action ([5a371ff](https://github.com/nsheaps/.ai/commit/5a371ff14b669613b75f7e14ff3f782f67c67b4a))
- add reusable claude-debug GitHub action ([77fed09](https://github.com/nsheaps/.ai/commit/77fed092a25e1062654cc7a1864714ce4b7bbc35))
- add rule to capture user messages mid-task ([bef7d6b](https://github.com/nsheaps/.ai/commit/bef7d6bd44ec27e9d6a39f6c5835a2fcbdb8a327))
- add todo management rule requiring todos before any tool use ([26326ec](https://github.com/nsheaps/.ai/commit/26326ec3364a58c29a3af7f47248484915318bf3))
- add user behavior rules in .ai/rules/ ([4874187](https://github.com/nsheaps/.ai/commit/48741876e3fc2097ab771cdac6b1cb9ee298a7a8))
- configure PATH in settings.json for mise tools ([379f41b](https://github.com/nsheaps/.ai/commit/379f41be951ec6475987dcffc5be4d026f6e9b56))
- expand scope options for correct-behavior command ([ef48184](https://github.com/nsheaps/.ai/commit/ef481846a95111b4f5e05ba0bb31f2b6e81000f1))
- initialize Claude Code plugin marketplace with commit automation plugins ([74ed3db](https://github.com/nsheaps/.ai/commit/74ed3dbf4eb49e2c38dbc8329ea35204806e61be))
- use Claude CLI validator for plugin validation ([6795c82](https://github.com/nsheaps/.ai/commit/6795c82e026570e0988c8cc16643cf4887b54c79))

### Bug Fixes

- add file lookup behavior rule - search before giving up ([ebd2ee6](https://github.com/nsheaps/.ai/commit/ebd2ee6b1334d388e500c141868c7b6de75df7fd))
- **ci:** add fallback for GITHUB_PAT_TOKEN_NSHEAPS ([6dfe6b4](https://github.com/nsheaps/.ai/commit/6dfe6b431d3cad02436dc2c22ab5445582fddc2d))
- **ci:** replace non-existent delete-comment action with gh api ([429125e](https://github.com/nsheaps/.ai/commit/429125e22fad6338fb5b99c40f63b5727d0e578d))
- make mise installation fail gracefully when network restricted ([181ef78](https://github.com/nsheaps/.ai/commit/181ef780f8db51dffa196733c9f2d268d6f3f355))
- remove curl from mise.toml (not a mise tool) ([bded44f](https://github.com/nsheaps/.ai/commit/bded44ffef9c228a6810bd37e890ffcec8513c5d))
- remove incorrect shift in pbe function ([4211978](https://github.com/nsheaps/.ai/commit/42119784ef32811a318aba4663ac9791d4cfdfc7))
- remove PATH override from settings.json ([ec92eab](https://github.com/nsheaps/.ai/commit/ec92eab0691c5f389ad4a53bf80f454825948442))
- resolve all linting errors in workflows and actions ([6df1be4](https://github.com/nsheaps/.ai/commit/6df1be4c8ec8f432b0272d2f13cc1aa6becd868e))
- update file permissions to include remote URL retrieval and mkdir command ([86c7da6](https://github.com/nsheaps/.ai/commit/86c7da6743d75733b17353149cebd75efaee553d))
- update lint action output condition and CI workflow step for better error handling ([6e782e9](https://github.com/nsheaps/.ai/commit/6e782e99f91eb01f7d01dcbf5a43e1035dfe23a7))
- use marketplace actions for git operations, add memory-manager README ([2eb3ad4](https://github.com/nsheaps/.ai/commit/2eb3ad4f3d0034dfb2303857d12af39e02b5fb19))
- use NEWPATH instead of PATH in settings.json ([0169c57](https://github.com/nsheaps/.ai/commit/0169c5744d7309130eb4bdf3216df6ffd31f90bc))
