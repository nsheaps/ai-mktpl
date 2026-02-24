# fix-pr

Relentlessly fix a PR until CI passes. Iterates through review, fix, push cycles until the PR is green or a valid reason is found why it can't be.

## Commands

### `/relentlessly-fix [pr or instructions]`

Continuously iterates on a PR:

1. Fetches PR comments and CI status
2. Plans fixes using Explore and Plan agents
3. Implements fixes via sub-agents
4. Pushes and re-checks CI
5. Repeats until green

## Usage

```bash
/relentlessly-fix           # Fix the PR for the current branch
/relentlessly-fix #123      # Fix a specific PR
/relentlessly-fix "make the linting pass"  # Custom instructions
```
