# Claude Code Enterprise Settings Brew Formula

**Priority:** High
**Status:** Draft

## Overview

Create a Homebrew formula for managing Claude Code Enterprise settings across teams.

## Requirements

- Formula should be similar to `nsheaps/homebrew-devsetup` meta-formula approach
- Should not install binaries, but run setup scripts
- Install enterprise configuration for Claude Code
- Sync team settings and preferences
- Install common MCP servers for enterprise use
- Set up default hooks and workflows

## Implementation Notes

The formula should:

1. Clone or download enterprise configuration repository
2. Install configuration to `~/.claude-code/enterprise/`
3. Symlink shared settings, hooks, and MCP server configurations
4. Provide uninstall/cleanup commands
5. Support updates via `brew upgrade`

## Example Structure

```ruby
class ClaudeCodeEnterpriseSettings < Formula
  desc "Enterprise settings and configuration for Claude Code"
  homepage "https://github.com/your-org/claude-enterprise-config"
  url "https://github.com/your-org/claude-enterprise-config/archive/refs/heads/main.tar.gz"
  version "latest"

  def install
    # Setup script that configures Claude Code
    # Install shared hooks, MCP servers, and settings
  end

  def caveats
    # Instructions for users
  end
end
```

## References

- See `nsheaps/homebrew-devsetup` for meta-formula patterns
- Claude Code docs for enterprise configuration paths
- MCP server installation guidelines
