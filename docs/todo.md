# TODO

## High Priority

### Claude Code Enterprise Settings Brew Formula

Create a Homebrew formula for managing Claude Code Enterprise settings across teams.

**Requirements:**

- Formula should be similar to `nsheaps/homebrew-devsetup` meta-formula approach
- Should not install binaries, but run setup scripts
- Install enterprise configuration for Claude Code
- Sync team settings and preferences
- Install common MCP servers for enterprise use
- Set up default hooks and workflows

**Implementation Notes:**

The formula should:

1. Clone or download enterprise configuration repository
2. Install configuration to `~/.claude-code/enterprise/`
3. Symlink shared settings, hooks, and MCP server configurations
4. Provide uninstall/cleanup commands
5. Support updates via `brew upgrade`

**Example Structure:**

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

**Reference:**

- See `nsheaps/homebrew-devsetup` for meta-formula patterns
- Claude Code docs for enterprise configuration paths
- MCP server installation guidelines

## Medium Priority

### Additional Plugin Ideas

- **auto-test-runner**: Automatically run relevant tests when files change
- **pr-description-generator**: Generate PR descriptions from commits
- **semantic-release**: Automated semantic versioning and changelog generation
- **code-coverage-tracker**: Track and report code coverage changes in PRs

### Documentation Improvements

- Add plugin development guide
- Create contribution guidelines
- Document marketplace setup process
- Add examples for custom hooks and workflows

### CI/CD Enhancements

- Add performance benchmarking in CI
- Implement automated security scanning
- Add dependency update automation (Dependabot or Renovate)
- Create release automation workflow

## Low Priority

### Marketplace Features

- Add plugin search and filtering
- Create plugin categories and tags system
- Implement plugin ratings and reviews
- Add plugin usage analytics

### Developer Experience

- Create plugin scaffolding CLI tool
- Add plugin testing framework
- Implement local marketplace testing
- Create plugin debugging utilities

## Completed

- ✅ Initial marketplace structure
- ✅ Commit command plugin
- ✅ Commit skill plugin
- ✅ Basic CI/CD workflows
- ✅ Homebrew formula for marketplace distribution

## Notes

- Keep plugin interface simple and consistent
- Prioritize developer experience
- Maintain backwards compatibility when possible
- Document all breaking changes
- Follow semantic versioning strictly
