# Bash Chaining Alternatives

This skill teaches you how to work around the bash command chaining restriction enforced by this plugin.

## Why Chaining is Blocked

The `bash-command-rejection` plugin blocks these operators:

| Operator | Name       | Why Blocked                                                                         |
| -------- | ---------- | ----------------------------------------------------------------------------------- |
| `&&`     | AND chain  | Runs cmd2 only if cmd1 succeeds - can't check permissions for conditional execution |
| `\|`     | Pipe       | Streams output to another command - can't review what the receiving command does    |
| `;`      | Sequential | Runs multiple commands - each should be reviewed separately                         |

**Allowed:** `||` (OR/fallback) is permitted because it's error handling, not output chaining.

## Alternative Approaches

### 1. Run Commands Separately

Instead of:

```bash
npm install && npm run build
```

Do:

```bash
npm install
```

Then in a separate call:

```bash
npm run build
```

### 2. Redirect Output to File

Instead of:

```bash
cat file.txt | grep "pattern"
```

Do:

```bash
cat file.txt > /tmp/output.txt
```

Then use the **Grep tool** or **Read tool** to examine the output.

Or if you must use bash:

```bash
grep "pattern" /tmp/output.txt
```

### 3. Use Built-in Claude Code Tools

Claude Code has dedicated tools that are safer than bash pipes:

| Instead of                  | Use                          |
| --------------------------- | ---------------------------- |
| `cat file \| grep pattern`  | **Grep tool** with file path |
| `find . -name "*.js"`       | **Glob tool** with pattern   |
| `cat file.txt`              | **Read tool**                |
| `sed -i 's/old/new/g' file` | **Edit tool**                |

### 4. Write a Reviewable Script

For complex multi-step operations, write a shell script:

```bash
#!/bin/bash
# deploy.sh - Production deployment script

set -euo pipefail

echo "Running tests..."
npm test

echo "Building..."
npm run build

echo "Deploying..."
rsync -av ./dist/ server:/var/www/app/
```

Save the script, let the user review it, then:

```bash
bash deploy.sh
```

### 5. Acknowledge and Bypass (Last Resort)

If chaining is truly necessary and safe, add an acknowledgment comment:

```bash
# CHAINED: Building inside docker container, both commands needed atomically
docker build -t myapp . && docker run myapp
```

**Only use this when:**

- Commands must run atomically
- You can explain why it's safe
- The user understands the combined behavior

## Best Practices

1. **Prefer sequential separate calls** - Most readable and safest
2. **Use output files as intermediaries** - Creates audit trail
3. **Leverage Claude Code tools** - They're designed for these tasks
4. **Write scripts for complex operations** - Allows human review
5. **Reserve bypass for edge cases** - Document why it's needed

## Examples

### Git Operations

Instead of:

```bash
git add . && git commit -m "message" && git push
```

Do each step separately:

```bash
git add .
```

```bash
git commit -m "message"
```

```bash
git push
```

### Testing and Building

Instead of:

```bash
npm test && npm run build
```

Run tests:

```bash
npm test
```

If tests pass, build:

```bash
npm run build
```

### Checking Command Output

Instead of:

```bash
ls -la | grep "\.js$"
```

Use the Glob tool with pattern `*.js`, or:

```bash
ls -la > /tmp/files.txt
```

Then use Grep tool to search `/tmp/files.txt`.
