# Data Serialization Plugin

Data format conversion and querying utilities for Claude Code.

## Overview

This plugin provides tools for converting between common data formats (YAML, JSON, TOON, XML/HTML) and querying structured data using industry-standard tools like `jq`, `yq`, and XPath.

**TOON (Token-Oriented Object Notation)** is a token-efficient serialization format designed for LLM contexts, achieving 30-60% token reduction vs JSON while maintaining full data fidelity.

## Features

- **Format Conversion**: Convert between YAML, JSON, TOON, and XML/HTML
- **Auto-Detection**: Automatically detects source format from file extension
- **Playwright Support**: Special handling for Playwright accessibility snapshots
- **Token Efficiency**: TOON format optimized for LLM context windows
- **Query Guidance**: Comprehensive examples for jq, yq, and XPath

## Installation

```bash
claude /plugin install data-serialization@nsheaps-claude-plugins
```

## Usage

### Converting Formats

```bash
# Using the convert.sh script
/path/to/plugins/data-serialization/scripts/convert.sh input.json yaml
/path/to/plugins/data-serialization/scripts/convert.sh config.yaml toon
/path/to/plugins/data-serialization/scripts/convert.sh data.toon json
/path/to/plugins/data-serialization/scripts/convert.sh page.html json

# With explicit source format
convert.sh data.txt json --from yaml

# Save to file
convert.sh input.json toon --output output.toon

# Playwright snapshots
convert.sh snapshot.md json --playwright
```

### Querying Data

See the skill documentation for comprehensive jq, yq, and XPath examples.

## Dependencies

- `jq` - JSON processor
- `yq` - YAML processor (mikefarah/yq)
- Python 3 with:
  - `toon_format` - TOON support (from GitHub)
  - `xmltodict` - XML to dict conversion (optional)
  - `dicttoxml` - Dict to XML conversion (optional)

Install on macOS:
```bash
brew install jq yq
pip install git+https://github.com/toon-format/toon-python.git xmltodict dicttoxml
```

## Format Recommendations

| Use Case | Recommended Format |
|----------|-------------------|
| LLM prompts/context | TOON (30-60% fewer tokens) |
| API data interchange | JSON |
| Config files humans edit | YAML |
| Enterprise integrations | XML |

## When to Use TOON

TOON excels with **uniform arrays of objects** - achieving CSV-like compactness while preserving structure for LLM parsing:

```
# JSON: 257 tokens
[{"id": 1, "name": "Alice"}, {"id": 2, "name": "Bob"}]

# TOON: 166 tokens (35% reduction)
users[2]{id,name}:
 1,Alice
 2,Bob
```

For deeply nested or non-uniform data, JSON may be more efficient.

## Skills Provided

- `data-serialization` - Main skill with conversion and querying guidance

## References

- [TOON Specification](https://github.com/toon-format/spec)
- [TOON Python Library](https://github.com/toon-format/toon-python)
- [jq Manual](https://jqlang.github.io/jq/manual/)
- [yq Documentation](https://mikefarah.gitbook.io/yq/)

## License

MIT
