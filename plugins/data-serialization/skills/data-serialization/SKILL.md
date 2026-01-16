---
name: data-serialization
description: >
  Data format conversion and querying utilities for YAML, JSON, TOON, and XML/HTML.
  Includes special handling for Playwright accessibility snapshots and comprehensive
  querying guidance using jq, yq, and native tools. TOON provides 30-60% token reduction
  for LLM contexts.
allowed-tools: Read, Edit, Write, Bash, Glob, Grep
---

# Data Serialization Skill

You are a data transformation specialist. Your job is to help convert between data formats and query structured data efficiently, with a focus on token efficiency for LLM contexts.

## Supported Formats

| Format   | Extension       | Best For                                    | Tools                |
| -------- | --------------- | ------------------------------------------- | -------------------- |
| **JSON** | `.json`         | Data interchange, APIs, tooling             | `jq`                 |
| **YAML** | `.yaml`, `.yml` | Human editing, config files                 | `yq`                 |
| **TOON** | `.toon`         | LLM prompts (30-60% fewer tokens)           | Python `toon_format` |
| **XML**  | `.xml`          | Legacy systems, SOAP, external requirements | `xmllint`            |
| **HTML** | `.html`         | Web content conversion                      | Python `xmltodict`   |

## When to Use Each Format

### JSON

**Pros:**

- Universal support across all languages
- Strict syntax reduces ambiguity
- Best tooling ecosystem (jq)
- Required by most APIs

**Cons:**

- No comments allowed
- Verbose for human editing
- No multi-line strings (must escape)
- ~40% of tokens are formatting (braces, quotes, commas)

**Use when:** API responses, data interchange, tool input/output

### YAML

**Pros:**

- Human-readable and editable
- Supports comments
- Multi-line strings with `|` or `>`
- Anchors and aliases for DRY configs

**Cons:**

- Significant whitespace (indentation matters)
- Security concerns with arbitrary YAML (code execution possible)
- Multiple ways to represent same data

**Use when:** Config files that humans edit, CI/CD pipelines, Kubernetes

**Security Note:** Never load untrusted YAML with `yaml.load()` - use `yaml.safe_load()`

### TOON (Token-Oriented Object Notation)

**Pros:**

- 30-60% token reduction vs JSON
- Lossless conversion to/from JSON
- YAML-like indentation (human-readable)
- CSV-style tabular arrays (compact)
- Explicit `[N]` lengths and `{fields}` headers help LLMs parse reliably
- Improves LLM accuracy (73.9% vs JSON's 69.7% in benchmarks)

**Cons:**

- Less tooling than JSON/YAML (newer format)
- Less efficient for deeply nested, non-uniform data
- Requires Python library for conversion

**Use when:**

- Sending structured data to LLMs
- Reducing API costs (fewer input tokens)
- Maximizing context window usage
- Tabular data with uniform structure

**Best for:** Uniform arrays of objects (same fields across items)

### XML/HTML

**Pros:**

- Schema validation (XSD)
- Namespaces for complex documents
- XPath for powerful querying
- Required by many enterprise systems

**Cons:**

- Verbose syntax
- Complex to parse and generate
- Falling out of favor for new projects

**Use when:** SOAP APIs, enterprise integrations, document formats (Office, SVG)

## TOON Format Guide

### Basic Syntax

**Objects** use key-value pairs with colon-space separation:

```
name: Alice
age: 30
active: true
```

**Nested objects** use indentation:

```
user:
  id: 123
  profile:
    role: admin
```

**Primitive arrays** (inline):

```
tags[3]: admin,ops,dev
```

**Tabular arrays** (uniform objects - TOON's sweet spot):

```
users[2]{id,name,role}:
 1,Alice,admin
 2,Bob,user
```

**Expanded lists** (mixed types):

```
tasks[2]:
 - Complete report
 - Review code
```

### TOON Token Savings Example

**JSON (257 tokens):**

```json
{
  "users": [
    { "id": 1, "name": "Alice", "role": "admin" },
    { "id": 2, "name": "Bob", "role": "user" },
    { "id": 3, "name": "Carol", "role": "guest" }
  ]
}
```

**TOON (166 tokens - 35% reduction):**

```
users[3]{id,name,role}:
 1,Alice,admin
 2,Bob,user
 3,Carol,guest
```

### When NOT to Use TOON

- **Deeply nested hierarchies**: JSON may be more compact
- **Non-uniform data**: Mixed object shapes reduce efficiency
- **Flat tabular data**: CSV is more compact (no TOON metadata)

## Conversion Guide

### Using the convert.sh Script

The plugin provides a `convert.sh` script for format conversion:

```bash
# Basic usage
/path/to/plugins/data-serialization/scripts/convert.sh <input-file> <output-format>

# Examples
convert.sh data.json yaml      # JSON to YAML
convert.sh config.yaml toon    # YAML to TOON
convert.sh data.toon json      # TOON to JSON
convert.sh data.xml json       # XML to JSON
convert.sh page.html yaml      # HTML to YAML

# With explicit source format (if auto-detect fails)
convert.sh data.txt json --from yaml

# Playwright accessibility snapshot conversion
convert.sh playwright-snapshot.md json --playwright
convert.sh playwright-snapshot.md toon --playwright
```

### Manual Conversion Commands

**JSON to YAML:**

```bash
yq -P '.' input.json > output.yaml
```

**YAML to JSON:**

```bash
yq -o=json '.' input.yaml > output.json
```

**JSON to TOON:**

```bash
python3 -c "
from toon_format import encode
import json
with open('input.json') as f:
    data = json.load(f)
print(encode(data))
" > output.toon
```

**TOON to JSON:**

```bash
python3 -c "
from toon_format import decode
import json
with open('input.toon') as f:
    data = decode(f.read())
print(json.dumps(data, indent=2))
" > output.json
```

**XML to JSON:**

```bash
python3 -c "
import json, xmltodict
with open('input.xml') as f:
    data = xmltodict.parse(f.read())
print(json.dumps(data, indent=2))
" > output.json
```

**HTML to JSON:**

```bash
python3 -c "
import json, xmltodict
from html.parser import HTMLParser
with open('input.html') as f:
    # Parse HTML as XML-like structure
    data = xmltodict.parse(f.read())
print(json.dumps(data, indent=2))
" > output.json
```

## Querying Data

### jq for JSON

**Basic selection:**

```bash
# Get a field
jq '.fieldName' data.json

# Get nested field
jq '.parent.child' data.json

# Get array element
jq '.[0]' data.json
jq '.items[0]' data.json
```

**Filtering:**

```bash
# Select objects matching condition
jq '.[] | select(.status == "active")' data.json

# Multiple conditions
jq '.[] | select(.age > 18 and .country == "US")' data.json

# Null-safe filtering
jq '.[] | select(.optional // empty)' data.json
```

**Transformation:**

```bash
# Extract specific fields
jq '.[] | {name, email}' data.json

# Rename fields
jq '.[] | {userName: .name, userEmail: .email}' data.json

# Create arrays
jq '[.[] | .name]' data.json
```

**Aggregation:**

```bash
# Count items
jq 'length' data.json
jq '[.[] | select(.active)] | length' data.json

# Sum values
jq '[.[] | .price] | add' data.json

# Group by field
jq 'group_by(.category)' data.json
```

### yq for YAML

yq uses the same syntax as jq:

```bash
# Basic queries work the same
yq '.fieldName' data.yaml
yq '.[] | select(.status == "active")' data.yaml

# Output as JSON
yq -o=json '.' data.yaml

# Edit in place
yq -i '.version = "2.0"' data.yaml
```

### XPath for XML

**Using xmllint:**

```bash
# Get element text
xmllint --xpath '//element/text()' data.xml

# Get attribute
xmllint --xpath 'string(//element/@attr)' data.xml

# Count elements
xmllint --xpath 'count(//item)' data.xml

# Get multiple elements
xmllint --xpath '//item/name/text()' data.xml
```

### Querying TOON

For TOON, convert to JSON first, then use jq:

```bash
python3 -c "
from toon_format import decode
import json
with open('data.toon') as f:
    print(json.dumps(decode(f.read())))
" | jq '.users[] | select(.role == "admin")'
```

## Playwright Accessibility Snapshots

Playwright MCP returns accessibility snapshots in a YAML-like format. These can be converted for querying.

### Snapshot Format

Playwright snapshots look like:

```
- button "Submit" [ref=s1e2]
- link "Home" [ref=s1e3]
  - text "Home"
- textbox "Email" [ref=s1e4]
```

### Converting Snapshots

Use the convert script with `--playwright` flag:

```bash
convert.sh snapshot.md json --playwright
convert.sh snapshot.md toon --playwright  # For token efficiency
```

This produces queryable JSON:

```json
[
  { "role": "button", "name": "Submit", "ref": "s1e2" },
  {
    "role": "link",
    "name": "Home",
    "ref": "s1e3",
    "children": [{ "role": "text", "name": "Home" }]
  },
  { "role": "textbox", "name": "Email", "ref": "s1e4" }
]
```

### Querying Playwright Data

**Find all buttons:**

```bash
jq '[.. | objects | select(.role == "button")]' snapshot.json
```

**Find element by name:**

```bash
jq '.. | objects | select(.name == "Submit")' snapshot.json
```

**Get all refs:**

```bash
jq '[.. | objects | .ref // empty]' snapshot.json
```

**Find clickable elements:**

```bash
jq '[.. | objects | select(.role == "button" or .role == "link")]' snapshot.json
```

## Best Practices

1. **Use TOON for LLM input** - 30-60% token savings on structured data
2. **Save API/tool output to files first** before querying
3. **Use JSON as intermediate format** when converting between formats
4. **Validate before converting** - malformed input causes cryptic errors
5. **Preserve original files** during conversion experiments
6. **For deeply nested data**, stick with JSON (TOON overhead increases)

## Tool Installation

Ensure these tools are available:

```bash
# macOS
brew install jq yq

# Python dependencies (for TOON and XML)
pip install git+https://github.com/toon-format/toon-python.git xmltodict dicttoxml

# Verify
jq --version
yq --version
python3 -c "from toon_format import encode; print('toon_format OK')"
```

## References

- [TOON Specification](https://github.com/toon-format/spec) - Official format spec
- [TOON Python Library](https://github.com/toon-format/toon-python) - Python implementation
- [jq Manual](https://jqlang.github.io/jq/manual/) - JSON query language
- [yq Documentation](https://mikefarah.gitbook.io/yq/) - YAML processor
- [XPath Reference](https://developer.mozilla.org/en-US/docs/Web/XPath) - XML query language
- [Playwright Accessibility](https://playwright.dev/docs/accessibility-testing) - Accessibility snapshots

## Plugin Location

This skill is part of the `data-serialization` plugin.

**Sources:**

- **GitHub**: `https://github.com/nsheaps/.ai`
- **Local Path**: `~/src/nsheaps/ai/plugins/data-serialization`
