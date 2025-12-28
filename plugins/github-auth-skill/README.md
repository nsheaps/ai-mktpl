# GitHub Authentication Skill Plugin

Enables Claude to guide users through GitHub CLI device code authentication, allowing Claude to take actions on their behalf in repositories they have access to.

## Overview

The GitHub Auth Skill provides Claude with the knowledge and workflow to authenticate users via GitHub's device code flow (`BROWSER=false gh auth login`). This is essential when Claude needs to perform GitHub operations that require user authentication, such as:

- Creating pull requests in external repositories
- Accessing private repositories
- Forking repos and contributing upstream
- Performing operations requiring the user's GitHub identity

## Features

- **Device Code Flow**: Uses `BROWSER=false gh auth login` for headless authentication
- **Cross-Repository Access**: Enables actions in repos outside the current workspace
- **Permission-Aware**: Respects GitHub's permission model
- **Scope Management**: Guides appropriate scope selection for different operations
- **Error Recovery**: Handles authentication errors and guides re-authentication

## Installation

### Via Claude Code Plugin Manager

1. Open Claude Code
2. Run `/plugin marketplace add nsheaps/.ai`
3. Find "GitHub Auth Skill" plugin
4. Click "Install now"
5. Restart Claude Code

### Manual Installation

```bash
# Navigate to skills directory
cd ~/.claude/skills

# Copy the skill
cp -r /path/to/marketplace/plugins/github-auth-skill ~/.claude/skills/

# Restart Claude Code
```

## How It Works

### The Device Code Flow

When Claude needs to perform authenticated GitHub operations:

1. **Detect Need**: Claude recognizes when authentication is required (permission errors, cross-repo operations)
2. **Initiate Flow**: Runs `BROWSER=false gh auth login`
3. **Display Code**: Shows the one-time code to the user
4. **User Authorization**: User visits `https://github.com/login/device` and enters the code
5. **Complete Auth**: Claude confirms authentication and proceeds with the operation

### Example Workflow

```
User: "Create a PR in facebook/react with my fix"

Claude:
1. Detects need to authenticate for cross-repo PR
2. Runs: BROWSER=false gh auth login
3. Shows: "Please visit https://github.com/login/device and enter code: ABCD-1234"
4. Waits for confirmation
5. Forks repository to user's account
6. Creates PR from fork to upstream
7. Reports PR URL
```

## Usage Examples

### Cross-Repository Pull Request

```
You: "Submit my changes as a PR to the upstream library"

Claude authenticates and:
- Forks the upstream repo
- Pushes your changes to the fork
- Creates PR from fork to upstream
```

### Private Repository Access

```
You: "Clone our team's private repo at company/internal-tool"

Claude authenticates and:
- Accesses the private repository
- Clones it to your local machine
- Sets up the development environment
```

### Organization Operations

```
You: "Create an issue in our org's repo about this bug"

Claude authenticates with org access and:
- Creates detailed issue
- Adds appropriate labels (if permitted)
- Reports the issue URL
```

## Security

### Token Storage

- Tokens stored in `~/.config/gh/hosts.yml` (standard gh CLI location)
- Claude uses existing `gh` authentication infrastructure
- No custom token storage or transmission

### Best Practices

- Request minimal scopes for each operation
- Verify critical operations before executing
- Transparent about what actions will be performed
- Users can revoke access at any time via GitHub settings

### Revoking Access

To revoke Claude's GitHub access:

1. Visit `https://github.com/settings/applications`
2. Find "GitHub CLI"
3. Click "Revoke access"

## Capabilities After Authentication

Claude can perform operations the authenticated user is permitted to do:

| Operation           | Scope Needed     |
| ------------------- | ---------------- |
| Create PR           | `repo`           |
| Create Issue        | `repo`           |
| Fork Repository     | `repo`           |
| Access Private Repo | `repo`           |
| Read Org Membership | `read:org`       |
| Manage Packages     | `write:packages` |

## Requirements

- **GitHub CLI**: `gh` must be installed ([installation guide](https://cli.github.com/))
- **Internet Access**: Required for authentication flow
- **User Interaction**: User must complete browser authorization step

## Limitations

- Cannot bypass GitHub permission restrictions
- SSO-protected organizations require additional browser authorization
- Some enterprise features may need extra configuration
- Token scopes fixed at authentication time

## Troubleshooting

### "gh: command not found"

Install GitHub CLI:

```bash
# macOS
brew install gh

# Ubuntu/Debian
sudo apt install gh

# Windows
winget install GitHub.cli
```

### "Resource not accessible"

- Verify you have access to the repository
- For org repos, ensure SSO is authorized
- May need additional scopes

### Device code expired

- Codes expire after 15 minutes
- Restart the authentication process

## Related Plugins

- **[Smart Commit Skill](../commit-skill)**: Intelligent commit management

## Support

- **Issues**: [GitHub Issues](https://github.com/nsheaps/.ai/issues)
- **Documentation**: [Main README](../../README.md)

## Changelog

### Version 1.0.0

- Initial release
- Device code authentication flow
- Cross-repository operation support
- Scope management guidance
- Error handling and troubleshooting

---

**Made with Claude Code** | Part of the [Claude Code Plugin Marketplace](../../README.md)
