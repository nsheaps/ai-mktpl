# TOON (Token-Oriented Object Notation) Research Findings

**Research Date:** 2026-01-15
**Purpose:** Understanding TOON for data-serialization plugin implementation

## Executive Summary

TOON (Token-Oriented Object Notation) is a compact, human-readable serialization format designed specifically for LLM contexts. It achieves 30-60% token reduction compared to JSON while maintaining or improving LLM accuracy. The format combines YAML-like indentation for nested objects with CSV-style tabular layouts for uniform arrays.

## 1. Official Specification and Repositories

### Primary Resources

| Resource                                  | URL                                                   |
| ----------------------------------------- | ----------------------------------------------------- |
| **Official Spec**                         | https://github.com/toon-format/spec                   |
| **Spec Document**                         | https://github.com/toon-format/spec/blob/main/SPEC.md |
| **Reference Implementation (TypeScript)** | https://github.com/toon-format/toon                   |
| **Organization**                          | https://github.com/toon-format                        |

### Language Implementations

| Language           | Repository              | Package                                                          |
| ------------------ | ----------------------- | ---------------------------------------------------------------- |
| TypeScript/Node.js | toon-format/toon        | `@toon-format/toon` (npm)                                        |
| Python             | toon-format/toon-python | `pip install git+https://github.com/toon-format/toon-python.git` |
| .NET               | toon-format/toon-dotnet | NuGet (in development)                                           |
| Java               | toon-format/toon-java   | Maven (in development)                                           |
| Go                 | toon-format/toon-go     | (in development)                                                 |

### Alternative Python Packages

- `python-toon` (xaviviro/python-toon) - Community implementation
- `pytoony` - PyPI package with CLI

## 2. Syntax and Structure

### Core Design Principles

1. **Indentation-based hierarchy** (like YAML, no braces)
2. **Tabular arrays** (declare keys once, stream rows)
3. **Minimal quoting** (strings quoted only when necessary)
4. **Explicit length declarations** for arrays
5. **UTF-8 encoding only**

### File Format

- **Extension:** `.toon`
- **Media type:** `text/toon` (provisional)
- **Encoding:** UTF-8 (always)

### Primitive Encoding

```
# Strings - unquoted unless necessary
name: Alice
path: /usr/bin

# Strings that MUST be quoted:
empty: ""
reserved: "true"              # Matches true/false/null
numeric: "123"                # Matches number pattern
special: "hello: world"       # Contains colon
whitespace: "  padded  "      # Leading/trailing whitespace

# Numbers - canonical decimal form
count: 42
price: 19.99
large: 1000000                # Not 1e6

# Booleans and null
active: true
verified: false
data: null
```

### Object Encoding

```
# Simple object
server:
  host: localhost
  port: 8080
  ssl: true

# Nested objects
config:
  database:
    host: db.example.com
    port: 5432
  cache:
    enabled: true
    ttl: 3600
```

### Array Encoding

#### Primitive Arrays (inline)

```
# Comma-delimited (default)
tags[3]: admin,ops,dev

# Tab-delimited (use when values contain commas)
paths[2	]: /usr/bin,/opt/bin	/home/user

# Pipe-delimited
names[3|]: Alice|Bob|Charlie
```

#### Tabular Arrays (uniform objects)

```
# Declare field names once, then stream rows
users[3]{id,name,email}:
 1,Alice,alice@example.com
 2,Bob,bob@example.com
 3,Charlie,charlie@example.com
```

#### Expanded Arrays (non-uniform or nested)

```
# Use dash prefix for each element
items[3]:
 - simple_string
 - key: value
   other: data
 - nested[2]: a,b
```

### Delimiter Rules

| Symbol | Header Syntax | Usage                         |
| ------ | ------------- | ----------------------------- |
| Comma  | `[N]:`        | Default, no symbol needed     |
| Tab    | `[N\t]:`      | Values containing commas      |
| Pipe   | `[N\|]:`      | Values containing commas/tabs |

**Critical:** The same delimiter declared in the bracket MUST be used consistently throughout that scope.

### Indentation Rules

- Use **spaces only** (tabs forbidden for indentation)
- Default: 2 spaces per level (configurable)
- Single space required after `:` in key-value pairs

### Escaping (in quoted strings)

| Escape | Character       |
| ------ | --------------- |
| `\\`   | Backslash       |
| `\"`   | Double quote    |
| `\n`   | Newline         |
| `\r`   | Carriage return |
| `\t`   | Tab             |

No other escape sequences are valid.

### When Strings Must Be Quoted

1. Empty strings: `""`
2. Leading/trailing whitespace
3. Reserved words: `true`, `false`, `null`
4. Numeric patterns: `-?\d+(\.\d+)?(e[+-]?\d+)?`
5. Contains: `:`, `"`, `\`, `[`, `]`, control characters

## 3. CLI Tools

### TypeScript/npm CLI

```bash
# Installation
npm install -g @toon-format/cli
# Or use without installing
npx @toon-format/cli

# JSON to TOON
npx @toon-format/cli input.json -o output.toon

# TOON to JSON
npx @toon-format/cli data.toon -o output.json

# Stdin/stdout pipeline
cat data.json | npx @toon-format/cli > data.toon
echo '{"x": 1}' | npx @toon-format/cli

# Token statistics
npx @toon-format/cli data.json --stats

# Auto-detects format from file extension
```

### Python CLI

```bash
# Installation (from source currently recommended)
pip install git+https://github.com/toon-format/toon-python.git

# Usage
toon input.json -o output.toon      # Encode
toon data.toon -o output.json       # Decode
echo '{"x": 1}' | toon -            # Stdin/stdout

# Options
toon data.json --encode --delimiter "\t" --length-marker
toon data.toon --decode --no-strict
```

## 4. Library APIs

### TypeScript/JavaScript

```typescript
import { encode, decode, encodeLines, decodeStream } from "@toon-format/toon";

// Basic encoding
const toon = encode({ users: [{ id: 1, name: "Alice" }] });

// Basic decoding
const data = decode(toonString);

// Streaming for large datasets
for (const line of encodeLines(largeData)) {
  process.stdout.write(`${line}\n`);
}

// With replacer (like JSON.stringify)
encode(data, {
  replacer: (key, value) => (key === "password" ? undefined : value),
});
```

### Python

```python
from toon_format import encode, decode

# Encoding
toon = encode({"name": "Alice", "age": 30})
# Returns: name: Alice\nage: 30

# Tabular array encoding
toon = encode([{"id": 1, "name": "Alice"}, {"id": 2, "name": "Bob"}])
# Returns: [2,]{id,name}:\n1,Alice\n2,Bob

# Decoding
data = decode("items[2]: apple,banana")
# Returns: {'items': ['apple', 'banana']}
```

## 5. Token Efficiency Benchmarks

### Overall Comparison

| Format           | Accuracy | Tokens | Efficiency (acc%/1K tokens) |
| ---------------- | -------- | ------ | --------------------------- |
| **TOON**         | 73.9%    | 2,744  | **26.9**                    |
| JSON compact     | 70.7%    | 3,081  | 22.9                        |
| YAML             | 69.0%    | 3,719  | 18.6                        |
| JSON (formatted) | 69.7%    | 4,545  | 15.3                        |
| XML              | 67.1%    | 5,167  | 13.0                        |

### Token Reduction vs JSON

| Data Type            | Reduction vs JSON          |
| -------------------- | -------------------------- |
| Uniform tabular data | **39.6%**                  |
| Mixed-structure data | **21.8%**                  |
| Deeply nested data   | 0-10% (JSON may be better) |

### Key Findings

1. TOON achieves **30-60% token reduction** vs JSON in typical use cases
2. **Improved accuracy**: 73.9% vs 70.7% (JSON compact) likely due to reduced punctuation noise
3. **Best for**: Uniform arrays of objects (tabular data)
4. **Not ideal for**: Deeply nested, non-uniform structures

### Benchmark Methodology

- **Models tested:** Claude Haiku 4.5, Gemini 2.5 Flash, GPT-5 Nano, Grok-4 Fast
- **Dataset:** 209 data retrieval questions across 11 datasets
- **Token counting:** GPT-5 o200k_base tokenizer
- **Total LLM calls:** 5,016 across all tests

## 6. Nested Structures and Special Cases

### Deeply Nested Objects

```
company:
  departments[2]{name,budget}:
   Engineering,500000
   Marketing,300000
  locations[3]:
   - city: New York
     employees: 150
   - city: London
     employees: 80
   - city: Tokyo
     employees: 60
```

### Mixed Arrays (uniform + nested)

```
products[3]:
 - id: 1
   name: Widget
   tags[2]: hardware,popular
 - id: 2
   name: Gadget
   specs:
     weight: 2.5
     dimensions[3]: 10,20,30
 - id: 3
   name: Thing
   tags[0]:
```

### Empty Structures

```
# Empty object
{}

# Empty array
items[0]:

# Null value
data: null
```

### Special Characters in Values

```
# Colon in value - must quote
message: "Error: connection failed"

# Quotes in value - must escape
quote: "He said \"hello\""

# Newlines - must escape
multiline: "line1\nline2"
```

## 7. When to Use TOON vs Other Formats

### Use TOON When:

- Data is predominantly **tabular** (arrays of uniform objects)
- **Token cost** is a primary concern
- Working with **LLM prompts** or context
- Data structure is **relatively flat**

### Use JSON/YAML When:

- Data is **deeply nested** or **non-uniform**
- Need broad **ecosystem compatibility**
- **Schema validation** is critical
- Exact numeric precision required (JSON spec compliance)

### Use CSV When:

- Data is **purely flat** (single table)
- Maximum compactness needed
- No structural metadata required

## 8. Implementation Notes for Plugin

### Conversion Matrix

| From/To | TOON          | JSON   | YAML         | XML         |
| ------- | ------------- | ------ | ------------ | ----------- |
| TOON    | -             | Decode | Decode->YAML | Decode->XML |
| JSON    | Encode        | -      | Direct       | Direct      |
| YAML    | Parse->Encode | Parse  | -            | Parse->XML  |
| XML     | Parse->Encode | Parse  | Parse->YAML  | -           |

### Recommended Approach

1. Use **@toon-format/toon** as the reference implementation
2. JSON as the **intermediate format** for conversions
3. Leverage existing YAML/XML parsers (js-yaml, xml2js, etc.)

### Considerations

- TOON Python is still beta (v0.9.x) - TypeScript is more stable
- Maintain JSON as canonical intermediate representation
- Consider token counting feature for plugin statistics

## Sources

### Primary Sources

- [Official TOON Specification](https://github.com/toon-format/spec)
- [TOON Reference Implementation (TypeScript)](https://github.com/toon-format/toon)
- [TOON Python Implementation](https://github.com/toon-format/toon-python)
- [npm: @toon-format/toon](https://www.npmjs.com/package/@toon-format/toon)
- [npm: @toon-format/cli](https://www.npmjs.com/package/@toon-format/cli)

### Articles and Guides

- [TOON: The Token-Efficient Data Format for LLM Applications](https://abdulkadersafi.com/blog/toon-the-token-efficient-data-format-for-llm-applications-complete-guide-2025)
- [What the TOON Format Is](https://openapi.com/blog/what-the-toon-format-is-token-oriented-object-notation)
- [TOON: Save 60% on Tokens](https://www.analyticsvidhya.com/blog/2025/11/toon-token-oriented-object-notation/)
- [TOON vs JSON vs YAML Comparison](https://medium.com/@ffkalapurackal/toon-vs-json-vs-yaml-token-efficiency-breakdown-for-llm-5d3e5dc9fb9c)
- [Token-Efficient LLM Workflows with TOON](https://betterstack.com/community/guides/ai/toon-explained/)
- [TOON vs JSON: Reduce LLM Token Costs](https://jsontoon.com/toon-vs-json)
- [InfoQ: TOON Reduces Token Consumption](https://www.infoq.com/news/2025/11/toon-reduce-llm-cost-tokens/)
