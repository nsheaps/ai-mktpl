# Merge Conflict Resolution Guide

Detailed guidance for analyzing and resolving merge conflicts when synchronizing branches.

## Conflict Categories

### Obvious Conflicts (Resolve Directly)

These conflicts have clear, mechanical resolutions:

| Conflict Type             | Resolution                                                                         |
| ------------------------- | ---------------------------------------------------------------------------------- |
| Whitespace/formatting     | Accept the version with correct formatting                                         |
| Import statement ordering | Combine both sets of imports, remove duplicates                                    |
| Simple additions          | Include both additions if they don't overlap semantically                          |
| Deleted vs modified       | If deletion was intentional, delete; if modification adds value, keep modification |
| Version bumps             | Take the higher version unless there's a reason not to                             |
| Auto-generated code       | Regenerate after merge, or take newer version                                      |

**Example - Import ordering conflict:**

```diff
<<<<<<< HEAD
import { foo } from './foo';
import { bar } from './bar';
=======
import { bar } from './bar';
import { baz } from './baz';
>>>>>>> origin/main
```

**Resolution:** Combine imports alphabetically:

```javascript
import { bar } from "./bar";
import { baz } from "./baz";
import { foo } from "./foo";
```

### Non-Obvious Conflicts (Use Explore/Plan Agents)

These conflicts require understanding intent:

| Conflict Type           | Why It's Non-Obvious              |
| ----------------------- | --------------------------------- |
| Business logic changes  | Both sides may have valid reasons |
| API signature changes   | Breaking change implications      |
| Database schema changes | Data migration considerations     |
| Configuration changes   | Environment-specific concerns     |
| Test modifications      | Coverage implications             |
| Security-related code   | Risk assessment needed            |

## Using Explore Agent for Conflict Analysis

When encountering a non-obvious conflict, delegate to the Explore agent with specific questions:

```
Use Explore agent to investigate:
1. What is the purpose of the changes on the base branch?
2. What is the purpose of the changes on the feature branch?
3. Do these changes have overlapping intent or separate concerns?
4. Are there related files that inform how to resolve this?
5. Is there test coverage that indicates expected behavior?
```

**Information to gather:**

- Git history: `git log --oneline -10 -- <conflicting-file>`
- Commit messages explaining the changes
- Related file changes in both branches
- Test files that exercise the conflicting code
- Documentation that may clarify intent

## Using Plan Agent for Resolution Strategy

After gathering information, use the Plan agent to determine resolution:

```
Use Plan agent to determine:
1. Can both changes coexist? If so, how to merge them?
2. Does one change supersede the other?
3. Is a hybrid approach needed?
4. What tests should verify the resolution?
5. Are there downstream effects to consider?
```

**Resolution strategies:**

| Strategy       | When to Use                                    |
| -------------- | ---------------------------------------------- |
| Accept base    | Feature change is obsolete or superseded       |
| Accept feature | Base change was intermediate, feature is final |
| Merge both     | Changes are additive and compatible            |
| Rewrite        | Neither version is correct post-merge          |
| Defer          | Need human decision - document and continue    |

## Resolution Workflow

### Step 1: Identify Conflict Type

```bash
# List conflicting files
git diff --name-only --diff-filter=U

# Show conflict markers in a file
grep -n "<<<<<<< HEAD" <file>
```

### Step 2: Categorize Conflict

For each conflicting section, determine:

- Is this obvious (formatting, imports, simple additions)?
- Or non-obvious (logic, API, security)?

### Step 3: Resolve Obvious Conflicts

Edit the file directly, removing conflict markers and keeping the correct content.

```bash
# After manual resolution
git add <file>
```

### Step 4: Delegate Non-Obvious Conflicts

```
For <file> conflict at lines X-Y:

Explore agent: Investigate the intent of both changes
- Base branch commit: <hash>
- Feature branch commit: <hash>
- What problem does each solve?

Plan agent: Given the Explore findings, determine:
- The correct resolution strategy
- How to implement it
- What to verify after
```

### Step 5: Execute Resolution

After receiving the plan:

1. Implement the resolution
2. Remove conflict markers
3. Stage the file
4. Verify no remaining conflicts

```bash
git add <file>
git diff --check  # Ensure no conflict markers remain
```

### Step 6: Verify Resolution

```bash
# Run tests if available
npm test  # or appropriate test command

# Check for regressions
git diff HEAD~1 --stat
```

## Common Conflict Patterns

### Package.json Conflicts

```diff
<<<<<<< HEAD
"dependencies": {
  "lodash": "^4.17.21",
  "express": "^4.18.2"
}
=======
"dependencies": {
  "lodash": "^4.17.21",
  "axios": "^1.4.0"
}
>>>>>>> origin/main
```

**Resolution:** Merge dependencies (unless versions conflict):

```json
"dependencies": {
  "axios": "^1.4.0",
  "express": "^4.18.2",
  "lodash": "^4.17.21"
}
```

### Function Signature Conflicts

```diff
<<<<<<< HEAD
function processUser(user: User, options?: ProcessOptions): Result {
=======
function processUser(user: User, metadata: Metadata): Result {
>>>>>>> origin/main
```

**This is non-obvious.** Use Explore agent to understand:

- What does `options` provide?
- What does `metadata` provide?
- Are callers expecting different signatures?

### Configuration Conflicts

```diff
<<<<<<< HEAD
DATABASE_URL=postgres://localhost:5432/mydb
REDIS_URL=redis://localhost:6379
=======
DATABASE_URL=postgres://localhost:5432/mydb_v2
LOG_LEVEL=debug
>>>>>>> origin/main
```

**Resolution:** Merge environment variables (be careful with renamed/removed vars):

```
DATABASE_URL=postgres://localhost:5432/mydb_v2  # Take newer
LOG_LEVEL=debug  # New addition
REDIS_URL=redis://localhost:6379  # Keep from feature
```

## Documenting Decisions

For non-obvious resolutions, document the decision:

```bash
git commit -m "Merge origin/main into feature-branch

Resolved conflicts in:
- src/api/users.ts: Combined both permission checks (base added admin check, feature added rate limiting)
- package.json: Merged dependencies from both branches
- config/settings.ts: Kept feature branch's timeout value (300s) over base's (60s) per discussion with team
"
```

## When to Escalate

Some conflicts should not be auto-resolved:

- **Security-sensitive code**: Alert the user before resolving
- **Database migrations**: Order matters, may need manual sequencing
- **Breaking API changes**: May need coordination with consumers
- **License/legal files**: Require human review
- **Heavily refactored files**: May need architectural decision

In these cases, document the conflict and ask the user for guidance:

```
I've encountered a conflict in <file> that involves <description>.

This appears to be <security/architectural/migration> related.

Options:
1. <option A> - <tradeoffs>
2. <option B> - <tradeoffs>
3. Defer to user decision

Which approach should I take?
```

## Post-Resolution Verification

After resolving all conflicts:

```bash
# Verify no conflict markers remain
git diff --check

# Run the test suite
npm test  # or appropriate command

# Verify build succeeds
npm run build  # or appropriate command

# Check for obvious issues
git diff origin/main...HEAD --stat
```

Only proceed with push after verification passes.
