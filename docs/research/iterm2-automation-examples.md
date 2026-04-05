# iTerm2 Automation and Setup Examples

Complete code examples for automating iTerm2 profile creation and management.

## Setup Script: Bootstrap Profiles from JSON

### Bash Script

```bash
#!/usr/bin/env bash
# setup-iterm2-profiles.sh
# Creates DynamicProfiles folder and installs custom profiles

set -euo pipefail

PROFILES_DIR="${HOME}/Library/Application Support/iTerm2/DynamicProfiles"
DOTFILES_DIR="${HOME}/dotfiles/iterm2"

# Create directory if it doesn't exist
mkdir -p "$PROFILES_DIR"

# Copy profiles from dotfiles
if [ -d "$DOTFILES_DIR" ]; then
  cp "$DOTFILES_DIR"/*.json "$PROFILES_DIR/"
  echo "Profiles installed from dotfiles"
else
  echo "Warning: Dotfiles iterm2 directory not found at $DOTFILES_DIR"
fi

# Verify profiles loaded
sleep 1
echo "Installed profiles:"
ls -1 "$PROFILES_DIR"/*.json | xargs -I {} basename {}
```

### Usage

```bash
chmod +x setup-iterm2-profiles.sh
./setup-iterm2-profiles.sh
```

---

## Profile Generator: Create Profiles Programmatically

### Node.js Script

```typescript
// generate-profiles.js
// Generates iTerm2 profile JSON files

const fs = require("fs");
const path = require("path");
const { exec } = require("child_process");

interface ProfileColor {
  Red: number;
  Green: number;
  Blue: number;
  Alpha?: number;
}

interface Profile {
  Name: string;
  Guid: string;
  "Background Color": {
    "Red Component": number;
    "Green Component": number;
    "Blue Component": number;
    "Alpha Component"?: number;
    "Color Space"?: string;
  };
  "Text Color"?: {
    "Red Component": number;
    "Green Component": number;
    "Blue Component": number;
  };
}

// Generate UUID using macOS uuidgen
function generateUuid(): string {
  return require("child_process").execSync("uuidgen").toString().trim().toLowerCase();
}

// Convert hex to decimal (0-1 range)
function hexToDecimal(hex: string): number {
  return parseInt(hex, 16) / 255;
}

// Create profile object
function createProfile(name: string, bgColor: ProfileColor, textColor?: ProfileColor): Profile {
  return {
    Name: name,
    Guid: generateUuid(),
    "Background Color": {
      "Red Component": bgColor.Red,
      "Green Component": bgColor.Green,
      "Blue Component": bgColor.Blue,
      "Alpha Component": bgColor.Alpha || 1.0,
      "Color Space": "sRGB",
    },
    ...(textColor && {
      "Text Color": {
        "Red Component": textColor.Red,
        "Green Component": textColor.Green,
        "Blue Component": textColor.Blue,
      },
    }),
  };
}

// Main
const profiles: Profile[] = [
  createProfile(
    "Light Gray",
    { Red: 0.93, Green: 0.93, Blue: 0.93 },
    { Red: 0, Green: 0, Blue: 0 },
  ),
  createProfile(
    "Light Pink",
    { Red: 1.0, Green: 0.894, Blue: 0.882 },
    { Red: 0, Green: 0, Blue: 0 },
  ),
  createProfile(
    "Production",
    { Red: 1.0, Green: 0.894, Blue: 0.882 },
    { Red: 1, Green: 0, Blue: 0 },
  ),
  createProfile(
    "Development",
    { Red: 0.93, Green: 0.93, Blue: 0.93 },
    { Red: 0, Green: 0.5, Blue: 0 },
  ),
];

const output = { Profiles: profiles };

// Write to file
const outputPath = path.join(
  process.env.HOME!,
  "Library/Application Support/iTerm2/DynamicProfiles/custom-profiles.json",
);

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, JSON.stringify(output, null, 2));

console.log(`Profiles written to ${outputPath}`);
console.log(
  `Created ${profiles.length} profiles:`,
  profiles.map((p) => `- ${p.Name}`),
);
```

### Usage

```bash
node generate-profiles.js
```

---

## Shell Hook: Directory-Based Profile Switching

### Zsh Integration

Add to `.zshrc`:

```bash
# iTerm2 Automatic Profile Switching via Shell Hook
_switch_iterm_profile() {
  local profile_name="Default"

  case "$PWD" in
    */production*|*/prod*|*/main*)
      profile_name="Light Pink"
      ;;
    */staging*|*/stage*)
      profile_name="Development"
      ;;
    */dev*|*/test*|*/local*)
      profile_name="Light Gray"
      ;;
  esac

  # Send escape sequence to iTerm2
  echo -ne "\033]50;SetProfile=${profile_name}\007"
}

# Trigger on directory change
chpwd_functions+=(_switch_iterm_profile)

# Also trigger when shell starts
_switch_iterm_profile
```

### Bash Integration

Add to `.bashrc`:

```bash
# iTerm2 Automatic Profile Switching
_switch_iterm_profile() {
  local profile_name="Default"

  case "$PWD" in
    */production*|*/prod*|*/main*)
      profile_name="Light Pink"
      ;;
    */staging*|*/stage*)
      profile_name="Development"
      ;;
    */dev*|*/test*|*/local*)
      profile_name="Light Gray"
      ;;
  esac

  echo -ne "\033]50;SetProfile=${profile_name}\007"
}

# Trigger before prompt display
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}_switch_iterm_profile"
```

---

## Dotfiles Integration: Complete Setup

### Directory Structure

```
~/dotfiles/
├── setup.sh                    # Main setup script
├── iterm2/
│   ├── profiles.json          # Dynamic profiles
│   ├── setup-iterm2.sh        # iTerm2-specific setup
│   └── README.md
└── shell/
    ├── .zshrc                 # Zsh config
    └── .bashrc                # Bash config
```

### Main Setup Script

```bash
#!/usr/bin/env bash
# ~/dotfiles/setup.sh

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"

# Setup iTerm2
echo "Setting up iTerm2..."
bash "${DOTFILES_DIR}/iterm2/setup-iterm2.sh"

# Link shell configs
echo "Linking shell configs..."
ln -sf "${DOTFILES_DIR}/shell/.zshrc" ~/.zshrc
ln -sf "${DOTFILES_DIR}/shell/.bashrc" ~/.bashrc

echo "Setup complete!"
echo "Restart your shell or run: source ~/.zshrc"
```

### iTerm2 Setup Script

```bash
#!/usr/bin/env bash
# ~/dotfiles/iterm2/setup-iterm2.sh

set -euo pipefail

ITERM_PROFILES_DIR="${HOME}/Library/Application Support/iTerm2/DynamicProfiles"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"

mkdir -p "$ITERM_PROFILES_DIR"

# Copy profiles
echo "Installing iTerm2 profiles..."
cp "${SCRIPT_DIR}/profiles.json" "$ITERM_PROFILES_DIR/"

# Optional: Enable preferences sync to dotfiles
echo "Setting up iTerm2 preferences sync..."
defaults write com.googlecode.iterm2.plist \
  PrefsCustomFolder -string "${HOME}/dotfiles/iterm2/prefs"
defaults write com.googlecode.iterm2.plist \
  LoadPrefsFromCustomFolder -bool true

echo "iTerm2 setup complete!"
```

---

## Git Workflow: Manage Profiles in Version Control

### Commit Hook for Profiles

```bash
#!/usr/bin/env bash
# .git/hooks/pre-commit
# Ensures iTerm2 profiles are properly formatted

PROFILES_DIR="iterm2"

# Check if profiles directory exists
if [ -d "$PROFILES_DIR" ]; then
  # Validate JSON
  for file in "$PROFILES_DIR"/*.json; do
    if ! jq empty "$file" 2>/dev/null; then
      echo "Error: Invalid JSON in $file"
      exit 1
    fi
  done

  # Stage changes
  git add "$PROFILES_DIR"/*.json
fi

exit 0
```

### GitHub Actions: Validate Profiles

```yaml
# .github/workflows/validate-iterm2.yml
name: Validate iTerm2 Profiles

on:
  push:
    paths:
      - "iterm2/**.json"
  pull_request:
    paths:
      - "iterm2/**.json"

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Validate JSON
        run: |
          for file in iterm2/*.json; do
            echo "Validating $file..."
            jq empty "$file"
          done

      - name: Check required fields
        run: |
          for file in iterm2/*.json; do
            echo "Checking $file for required fields..."
            jq '.Profiles[] | select(.Guid == null or .Name == null)
                | error("Missing Guid or Name")' "$file"
          done
```

---

## Function: Convert Any Color to iTerm2 Format

### Python Converter

```python
#!/usr/bin/env python3
# color_converter.py
# Converts hex colors to iTerm2 decimal format

import sys
import re

def hex_to_decimal(hex_value: str) -> float:
    """Convert hex color component to decimal (0-1)"""
    # Remove # if present
    hex_value = hex_value.lstrip('#')

    # If it's a 6-digit hex like EEEEEE
    if len(hex_value) == 6:
        r = int(hex_value[0:2], 16) / 255
        g = int(hex_value[2:4], 16) / 255
        b = int(hex_value[4:6], 16) / 255
        return r, g, b
    else:
        raise ValueError(f"Invalid hex color: {hex_value}")

def rgb_to_hex(r: int, g: int, b: int) -> str:
    """Convert RGB (0-255) to hex"""
    return f"#{r:02x}{g:02x}{b:02x}"

def iterm2_json(name: str, hex_color: str, guid: str = None):
    """Generate iTerm2 profile JSON for a color"""
    import uuid

    if guid is None:
        guid = str(uuid.uuid4())

    r, g, b = hex_to_decimal(hex_color)

    profile = {
        "Name": name,
        "Guid": guid,
        "Background Color": {
            "Red Component": round(r, 3),
            "Green Component": round(g, 3),
            "Blue Component": round(b, 3),
            "Alpha Component": 1.0,
            "Color Space": "sRGB"
        }
    }

    import json
    return json.dumps(profile, indent=2)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: color_converter.py <name> <hex_color>")
        print("Example: color_converter.py 'Light Purple' '#E6D7FF'")
        sys.exit(1)

    name = sys.argv[1]
    hex_color = sys.argv[2]

    print(iterm2_json(name, hex_color))
```

### Usage

```bash
python3 color_converter.py "My Color" "#EEEEEE"
```

Output:

```json
{
  "Name": "My Color",
  "Guid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "Background Color": {
    "Red Component": 0.933,
    "Green Component": 0.933,
    "Blue Component": 0.933,
    "Alpha Component": 1.0,
    "Color Space": "sRGB"
  }
}
```

---

## Complete Example: Profile with All Options

```json
{
  "Profiles": [
    {
      "Name": "Production",
      "Guid": "ba19744f-6af3-434d-aaa6-0a48e0969958",

      "Background Color": {
        "Red Component": 1.0,
        "Green Component": 0.894,
        "Blue Component": 0.882,
        "Alpha Component": 1.0,
        "Color Space": "sRGB"
      },

      "Text Color": {
        "Red Component": 0.0,
        "Green Component": 0.0,
        "Blue Component": 0.0
      },

      "Bold Color": {
        "Red Component": 0.5,
        "Green Component": 0.0,
        "Blue Component": 0.0
      },

      "Cursor Color": {
        "Red Component": 1.0,
        "Green Component": 0.0,
        "Blue Component": 0.0
      },

      "Font Name": "Monaco",
      "Font Size": 12,

      "Columns": 120,
      "Rows": 40,

      "Use Non-ASCII Font": false
    }
  ]
}
```
