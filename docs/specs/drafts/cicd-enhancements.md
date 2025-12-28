# CI/CD Enhancements

**Priority:** Medium
**Status:** Draft

## Overview

Improvements to the CI/CD pipeline.

## Planned Enhancements

### Performance Benchmarking

- Add performance tests in CI
- Track benchmark results over time
- Alert on performance regressions

### Automated Security Scanning

- Integrate security scanning tools
- Scan for vulnerabilities in dependencies
- Check for secrets in commits
- SAST for plugin code

### Dependency Update Automation

- Renovate is already configured
- Extends `nsheaps/renovate-config`
- Auto-merge minor/patch updates
- Group related updates
- **TODO:** Have Renovate manage mise version in `.claude/hooks/SessionStart/hook.sh`

### Release Automation Workflow

- Automated releases on version bump
- Generate release notes from commits
- Publish to Homebrew tap
- Notify on successful releases
