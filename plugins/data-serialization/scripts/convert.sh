#!/usr/bin/env bash
# convert.sh - Data format conversion utility
#
# Converts between YAML, JSON, TOON (Token-Oriented Object Notation), and XML/HTML
# formats with special handling for Playwright accessibility snapshots.
#
# TOON is a token-efficient format for LLM contexts, achieving 30-60% token
# reduction vs JSON. See https://github.com/toon-format/spec
#
# Usage:
#   convert.sh <input-file> <output-format> [options]
#
# Options:
#   --from <format>   Explicitly specify source format (yaml, json, toon, xml, html)
#   --playwright      Parse input as Playwright accessibility snapshot
#   --output <file>   Write to file instead of stdout
#   -h, --help        Show this help message
#
# Examples:
#   convert.sh data.json yaml
#   convert.sh config.yaml toon
#   convert.sh snapshot.md json --playwright
#   convert.sh data.txt json --from yaml

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
DEPS_DIR="$PLUGIN_DIR/.deps"

# Add plugin dependencies to PYTHONPATH
if [[ -d "$DEPS_DIR" ]]; then
    export PYTHONPATH="${PYTHONPATH:-}:$DEPS_DIR"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    cat << 'EOF'
Usage: convert.sh <input-file> <output-format> [options]

Supported formats: yaml, json, toon, xml, html

Options:
  --from <format>   Explicitly specify source format
  --playwright      Parse input as Playwright accessibility snapshot
  --output <file>   Write to file instead of stdout
  -h, --help        Show this help message

Examples:
  convert.sh data.json yaml           # JSON to YAML
  convert.sh config.yaml toon         # YAML to TOON (30-60% fewer tokens)
  convert.sh data.toon json           # TOON to JSON
  convert.sh data.xml json            # XML to JSON
  convert.sh page.html yaml           # HTML to YAML
  convert.sh snapshot.md json --playwright
EOF
}

error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

warn() {
    echo -e "${YELLOW}Warning: $1${NC}" >&2
}

info() {
    echo -e "${GREEN}$1${NC}" >&2
}

# Check for required tools
check_dependencies() {
    local missing=()

    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi

    if ! command -v yq &> /dev/null; then
        missing+=("yq")
    fi

    if ! python3 -c "from toon_format import encode, decode" 2>/dev/null; then
        missing+=("python3 toon_format module (pip install git+https://github.com/toon-format/toon-python.git)")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        warn "Missing dependencies: ${missing[*]}"
        warn "Some conversions may not work"
    fi
}

# Detect format from file extension
detect_format() {
    local file="$1"
    local ext="${file##*.}"

    case "$ext" in
        json)
            echo "json"
            ;;
        yaml|yml)
            echo "yaml"
            ;;
        toon)
            echo "toon"
            ;;
        xml)
            echo "xml"
            ;;
        html|htm)
            echo "html"
            ;;
        md|txt)
            # Could be Playwright snapshot - return empty to require explicit format
            echo ""
            ;;
        *)
            echo ""
            ;;
    esac
}

# Convert JSON to other formats
from_json() {
    local input="$1"
    local to_format="$2"

    case "$to_format" in
        json)
            jq '.' "$input"
            ;;
        yaml)
            yq -o=yaml -P '.' "$input"
            ;;
        toon)
            python3 << PYTHON
import json
from toon_format import encode

with open('$input') as f:
    data = json.load(f)

print(encode(data))
PYTHON
            ;;
        xml|html)
            python3 << PYTHON
import json
import sys
try:
    import dicttoxml
except ImportError:
    print("Error: dicttoxml module required. Install with: pip install dicttoxml", file=sys.stderr)
    sys.exit(1)

with open('$input') as f:
    data = json.load(f)

xml_bytes = dicttoxml.dicttoxml(data, custom_root='root', attr_type=False)
print(xml_bytes.decode('utf-8'))
PYTHON
            ;;
        *)
            error "Unknown output format: $to_format"
            ;;
    esac
}

# Convert YAML to other formats
from_yaml() {
    local input="$1"
    local to_format="$2"

    case "$to_format" in
        json)
            yq -o=json '.' "$input"
            ;;
        yaml)
            yq '.' "$input"
            ;;
        toon)
            # Convert via JSON intermediate
            local json_data
            json_data=$(yq -o=json '.' "$input")
            echo "$json_data" | python3 << 'PYTHON'
import json
import sys
from toon_format import encode

data = json.load(sys.stdin)
print(encode(data))
PYTHON
            ;;
        xml|html)
            local json_data
            json_data=$(yq -o=json '.' "$input")
            echo "$json_data" | python3 << 'PYTHON'
import json
import sys
try:
    import dicttoxml
except ImportError:
    print("Error: dicttoxml module required. Install with: pip install dicttoxml", file=sys.stderr)
    sys.exit(1)

data = json.load(sys.stdin)
xml_bytes = dicttoxml.dicttoxml(data, custom_root='root', attr_type=False)
print(xml_bytes.decode('utf-8'))
PYTHON
            ;;
        *)
            error "Unknown output format: $to_format"
            ;;
    esac
}

# Convert TOON to other formats
from_toon() {
    local input="$1"
    local to_format="$2"

    case "$to_format" in
        json)
            python3 << PYTHON
import json
from toon_format import decode

with open('$input') as f:
    data = decode(f.read())

print(json.dumps(data, indent=2))
PYTHON
            ;;
        yaml)
            local json_data
            json_data=$(python3 << PYTHON
import json
from toon_format import decode

with open('$input') as f:
    data = decode(f.read())

print(json.dumps(data))
PYTHON
)
            echo "$json_data" | yq -o=yaml -P '.'
            ;;
        toon)
            cat "$input"
            ;;
        xml|html)
            local json_data
            json_data=$(python3 << PYTHON
import json
from toon_format import decode

with open('$input') as f:
    data = decode(f.read())

print(json.dumps(data))
PYTHON
)
            echo "$json_data" | python3 << 'PYTHON'
import json
import sys
try:
    import dicttoxml
except ImportError:
    print("Error: dicttoxml module required. Install with: pip install dicttoxml", file=sys.stderr)
    sys.exit(1)

data = json.load(sys.stdin)
xml_bytes = dicttoxml.dicttoxml(data, custom_root='root', attr_type=False)
print(xml_bytes.decode('utf-8'))
PYTHON
            ;;
        *)
            error "Unknown output format: $to_format"
            ;;
    esac
}

# Convert XML to other formats
from_xml() {
    local input="$1"
    local to_format="$2"

    case "$to_format" in
        json)
            python3 << PYTHON
import json
import sys
try:
    import xmltodict
except ImportError:
    print("Error: xmltodict module required. Install with: pip install xmltodict", file=sys.stderr)
    sys.exit(1)

with open('$input') as f:
    data = xmltodict.parse(f.read())

print(json.dumps(data, indent=2))
PYTHON
            ;;
        yaml)
            local json_data
            json_data=$(python3 << PYTHON
import json
import sys
try:
    import xmltodict
except ImportError:
    print("Error: xmltodict module required. Install with: pip install xmltodict", file=sys.stderr)
    sys.exit(1)

with open('$input') as f:
    data = xmltodict.parse(f.read())

print(json.dumps(data))
PYTHON
)
            echo "$json_data" | yq -o=yaml -P '.'
            ;;
        toon)
            local json_data
            json_data=$(python3 << PYTHON
import json
import sys
try:
    import xmltodict
except ImportError:
    print("Error: xmltodict module required. Install with: pip install xmltodict", file=sys.stderr)
    sys.exit(1)

with open('$input') as f:
    data = xmltodict.parse(f.read())

print(json.dumps(data))
PYTHON
)
            echo "$json_data" | python3 << 'PYTHON'
import json
import sys
from toon_format import encode

data = json.load(sys.stdin)
print(encode(data))
PYTHON
            ;;
        xml|html)
            cat "$input"
            ;;
        *)
            error "Unknown output format: $to_format"
            ;;
    esac
}

# Convert HTML to other formats (treats HTML as XML-like)
from_html() {
    local input="$1"
    local to_format="$2"

    # HTML is handled similarly to XML using xmltodict
    # Note: This works best with well-formed HTML
    from_xml "$input" "$to_format"
}

# Parse Playwright accessibility snapshot to JSON
parse_playwright_snapshot() {
    local input="$1"

    python3 << PYTHON
import re
import json
import sys

def parse_snapshot(content):
    """Parse Playwright accessibility snapshot format to JSON."""
    lines = content.strip().split('\n')
    result = []
    stack = [(result, -1)]  # (current list, indent level)

    # Pattern: - role "name" [ref=xxx] or just - role "name"
    # Also handles: - role "name" [disabled] [ref=xxx]
    pattern = re.compile(r'^(\s*)-\s+(\w+)(?:\s+"([^"]*)")?(.*)$')

    for line in lines:
        if not line.strip() or line.strip().startswith('#'):
            continue

        match = pattern.match(line)
        if not match:
            continue

        indent = len(match.group(1))
        role = match.group(2)
        name = match.group(3) or ""
        rest = match.group(4).strip()

        # Parse ref and other attributes from brackets
        ref = None
        attributes = {}
        bracket_matches = re.findall(r'\[([^\]]+)\]', rest)
        for attr in bracket_matches:
            if attr.startswith('ref='):
                ref = attr[4:]
            elif '=' in attr:
                key, value = attr.split('=', 1)
                attributes[key] = value
            else:
                # Boolean attribute like [disabled]
                attributes[attr] = True

        node = {
            "role": role,
            "name": name,
        }
        if ref:
            node["ref"] = ref
        if attributes:
            node["attributes"] = attributes

        # Find correct parent based on indent
        while len(stack) > 1 and stack[-1][1] >= indent:
            stack.pop()

        current_list, _ = stack[-1]
        current_list.append(node)

        # Prepare for children
        node["children"] = []
        stack.append((node["children"], indent))

    # Clean up empty children arrays
    def cleanup(nodes):
        for node in nodes:
            if "children" in node:
                if node["children"]:
                    cleanup(node["children"])
                else:
                    del node["children"]

    cleanup(result)
    return result

with open('$input') as f:
    content = f.read()

result = parse_snapshot(content)
print(json.dumps(result, indent=2))
PYTHON
}

# Main function
main() {
    local input_file=""
    local output_format=""
    local source_format=""
    local output_file=""
    local playwright_mode=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            --from)
                source_format="$2"
                shift 2
                ;;
            --output)
                output_file="$2"
                shift 2
                ;;
            --playwright)
                playwright_mode=true
                shift
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                if [[ -z "$input_file" ]]; then
                    input_file="$1"
                elif [[ -z "$output_format" ]]; then
                    output_format="$1"
                else
                    error "Too many arguments"
                fi
                shift
                ;;
        esac
    done

    # Validate arguments
    if [[ -z "$input_file" ]]; then
        usage
        error "Missing input file"
    fi

    if [[ -z "$output_format" ]]; then
        usage
        error "Missing output format"
    fi

    if [[ ! -f "$input_file" ]]; then
        error "Input file not found: $input_file"
    fi

    # Normalize output format
    output_format=$(echo "$output_format" | tr '[:upper:]' '[:lower:]')
    case "$output_format" in
        yml) output_format="yaml" ;;
        htm) output_format="html" ;;
    esac

    # Check dependencies
    check_dependencies

    # Handle Playwright mode
    if $playwright_mode; then
        if [[ "$output_format" != "json" ]]; then
            # First convert to JSON, then to target format
            local json_data
            json_data=$(parse_playwright_snapshot "$input_file")

            local temp_file
            temp_file=$(mktemp)
            echo "$json_data" > "$temp_file"

            local result
            result=$(from_json "$temp_file" "$output_format")
            rm -f "$temp_file"

            if [[ -n "$output_file" ]]; then
                echo "$result" > "$output_file"
                info "Wrote $output_file"
            else
                echo "$result"
            fi
        else
            local result
            result=$(parse_playwright_snapshot "$input_file")

            if [[ -n "$output_file" ]]; then
                echo "$result" > "$output_file"
                info "Wrote $output_file"
            else
                echo "$result"
            fi
        fi
        exit 0
    fi

    # Auto-detect source format if not specified
    if [[ -z "$source_format" ]]; then
        source_format=$(detect_format "$input_file")
        if [[ -z "$source_format" ]]; then
            error "Cannot auto-detect format for $input_file. Use --from to specify."
        fi
    fi

    # Normalize source format
    source_format=$(echo "$source_format" | tr '[:upper:]' '[:lower:]')
    case "$source_format" in
        yml) source_format="yaml" ;;
        htm) source_format="html" ;;
    esac

    # Perform conversion
    local result
    case "$source_format" in
        json)
            result=$(from_json "$input_file" "$output_format")
            ;;
        yaml)
            result=$(from_yaml "$input_file" "$output_format")
            ;;
        toon)
            result=$(from_toon "$input_file" "$output_format")
            ;;
        xml)
            result=$(from_xml "$input_file" "$output_format")
            ;;
        html)
            result=$(from_html "$input_file" "$output_format")
            ;;
        *)
            error "Unknown source format: $source_format"
            ;;
    esac

    # Output result
    if [[ -n "$output_file" ]]; then
        echo "$result" > "$output_file"
        info "Wrote $output_file"
    else
        echo "$result"
    fi
}

main "$@"
