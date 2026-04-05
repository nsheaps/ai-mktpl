# Documentation Linking

## Never Link to Non-Existent Documentation

**CRITICAL:** Do not add links to documentation, research files, or resources that do not exist yet.

### Why This Matters

- Dead links frustrate users and waste time
- "Will be created later" is a broken promise that often goes unfulfilled
- It creates technical debt disguised as helpfulness
- Future sessions may not have context about what was "planned"

### Correct Approach

1. **Create first, then link** - If documentation is needed, create it, then add the link
2. **Use TODO comments instead** - If you can't create it now, add a TODO rather than a dead link
3. **Link to existing resources** - Reference documentation that already exists (official docs, specs, etc.)

### Examples

**Wrong:**

```markdown
See [Research Document](./research/analysis.md) for details. <!-- File doesn't exist -->
```

**Correct:**

```markdown
<!-- TODO: Create research/analysis.md with implementation details -->
```

**Also Correct:**

```markdown
See the [official specification](https://example.com/spec) for details. <!-- External link that exists -->
```

### Applying This Rule

Before adding any documentation link:

1. Verify the target file/URL exists
2. If it doesn't exist and is needed, create it first
3. If you can't create it, use a TODO comment instead of a link
