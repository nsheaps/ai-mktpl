# iTerm2 Profile Configuration Research

Comprehensive guide to creating, configuring, and managing iTerm2 profiles with background colors and automatic switching.

## 1. Creating New Profiles in iTerm2

### GUI Method (Recommended for Beginners)

1. Open iTerm2
2. Go to **iTerm → Preferences → Profiles**
3. Click the **+** button at the bottom to create a new profile
4. Enter a name for your profile
5. Configure settings across the tabs (General, Colors, Text, etc.)
6. Close the preferences window to save

### Dynamic Profiles Method (Programmatic)

Dynamic profiles allow you to define profiles in code and have them automatically loaded. This is the modern recommended approach for version control and automation.

**File Location:** `~/Library/Application Support/iTerm2/DynamicProfiles/`

iTerm2 monitors this directory and automatically reloads profiles whenever files change.

**File Format:** Apple Property Lists (JSON, XML, or binary)

**Basic JSON Structure:**

```json
{
  "Profiles": [
    {
      "Name": "My Profile",
      "Guid": "unique-uuid-here"
    }
  ]
}
```

**Generate Guid:**

```bash
uuidgen
```

This produces a UUID like `ba19744f-6af3-434d-aaa6-0a48e0969958`.

---

## 2. Setting Background Colors for Profiles

### GUI Method

1. Open **iTerm → Preferences → Profiles**
2. Select your profile
3. Click the **Colors** tab
4. Locate the **Background Color** section
5. Click the color well (the colored box) to open the color picker
6. Choose your desired color or enter hex values
7. Optionally use the system color picker by clicking the rectangular icon next to the eyedropper

### Dynamic Profile JSON Method

Colors in dynamic profiles use decimal RGB values (0 to 1 scale).

**Background Color Example:**

```json
{
  "Profiles": [
    {
      "Name": "Light Gray Background",
      "Guid": "ba19744f-6af3-434d-aaa6-0a48e0969958",
      "Background Color": {
        "Red Component": 0.93,
        "Green Component": 0.93,
        "Blue Component": 0.93
      }
    }
  ]
}
```

**Converting Hex to Decimal:**

- Light gray (#EEEEEE): Red: 0.93, Green: 0.93, Blue: 0.93
- Light pink (#FFE4E1): Red: 1.0, Green: 0.894, Blue: 0.882
- White (#FFFFFF): Red: 1.0, Green: 1.0, Blue: 1.0
- Black (#000000): Red: 0.0, Green: 0.0, Blue: 0.0

**Formula:** Decimal = Hex / 255

For example, light pink (hex #FFE4E1):

- FF / 255 = 1.0 (red)
- E4 / 255 ≈ 0.894 (green)
- E1 / 255 ≈ 0.882 (blue)

### Complete Color Component Structure

In dynamic profiles, you can also specify alpha channel and color space:

```json
"Background Color": {
  "Alpha Component": 1.0,
  "Blue Component": 0.93,
  "Color Space": "sRGB",
  "Green Component": 0.93,
  "Red Component": 0.93
}
```

### Color Presets

iTerm2 provides built-in color presets and supports importing custom schemes:

1. Click the **Color Presets** popup menu in the Colors tab
2. Choose a preset or select **Import** to load a `.itermcolors` file
3. Presets are assigned names based on their filename when imported

**Online Color Gallery:** [iTerm2 Color Schemes](https://iterm2colorschemes.com/) provides over 425 community-created presets.

---

## 3. Configuration Methods: GUI vs CLI vs Files

### Method 1: GUI (Preferences Window)

**Pros:**

- Visual color picker
- No need to calculate RGB values
- Instant preview
- All settings accessible

**Cons:**

- Not scriptable
- Hard to version control
- Not easily reproducible on other machines

### Method 2: Dynamic Profiles (JSON Files)

**Location:** `~/Library/Application Support/iTerm2/DynamicProfiles/`

**Pros:**

- Version control friendly
- Scriptable and repeatable
- Reusable across machines
- Changes picked up in real-time
- Can be committed to dotfiles

**Cons:**

- Must use decimal RGB format
- Requires understanding JSON structure
- Need to generate GUIDs

**File Naming:** Files load alphabetically by filename. Use naming like:

- `01-parent-profile.json`
- `02-derived-profile.json`

This ensures parent profiles load before child profiles that reference them.

### Method 3: Preferences Synchronization

**Command-line Setup:**

```bash
defaults write com.googlecode.iterm2.plist PrefsCustomFolder -string "~/dotfiles/iterm2"
defaults write com.googlecode.iterm2.plist LoadPrefsFromCustomFolder -bool true
```

This enables automatic syncing when you modify iTerm2 configuration through the GUI, and changes will be saved to your custom folder.

**Standard Preferences File:** `com.googlecode.iterm2.plist` (stored in `~/Library/Preferences/`)

**Important Limitation:** Changes made through the Settings UI won't update dynamic profile files unless the profile is marked as rewritable.

**Making Profiles Rewritable:**

```json
{
  "Profiles": [
    {
      "Name": "Editable Profile",
      "Guid": "...",
      "Rewritable": true
    }
  ]
}
```

---

## 4. Best Practices for Managing iTerm2 Profiles

### Use Dynamic Profiles with Dotfiles

The modern best practice combines dynamic profiles with version control:

1. Create a `iterm2/` directory in your dotfiles repository
2. Store profile JSON files there
3. Place the directory in `~/Library/Application Support/iTerm2/DynamicProfiles/`

**Option A: Direct Storage (Recommended)**

```bash
ln -s ~/dotfiles/iterm2 ~/Library/Application\ Support/iTerm2/DynamicProfiles
```

**Option B: Copy and Sync**

```bash
cp ~/dotfiles/iterm2/*.json ~/Library/Application\ Support/iTerm2/DynamicProfiles/
```

### Profile Inheritance

Use parent profiles to reduce duplication:

```json
{
  "Profiles": [
    {
      "Name": "Base Profile",
      "Guid": "base-guid-here",
      "Background Color": {
        "Red Component": 0.1,
        "Green Component": 0.1,
        "Blue Component": 0.1
      }
    },
    {
      "Name": "Production Profile",
      "Guid": "prod-guid-here",
      "Dynamic Profile Parent Name": "Base Profile"
    }
  ]
}
```

### File Organization

```
~/dotfiles/
├── iterm2/
│   ├── 01-base-profile.json
│   ├── 02-production-profile.json
│   └── 03-dev-profile.json
└── setup-iterm2.sh
```

### Avoid Symlinks for Plist Files

macOS no longer allows symlinks for `.plist` files. Use direct copies or the DynamicProfiles folder approach instead.

### Shell Integration

For full functionality including automatic profile switching, [install Shell Integration](https://iterm2.com/documentation-shell-integration.html):

1. **iTerm → Install Shell Integration**
2. Choose your shell (Zsh, Bash, Fish, etc.)
3. The installer automatically modifies your shell configuration

---

## 5. Automatic Profile Switching Based on Directory

### Requirements

- **Shell Integration must be installed** on all machines where you use automatic profile switching
- Install via **iTerm → Install Shell Integration** in the menu
- Available for: Zsh, Bash, Fish, and other shells

### Path Rule Configuration

1. Open **iTerm → Preferences → Profiles → Advanced**
2. Locate **Automatic Profile Switching** section
3. Create rules with three optional components:
   - **User name:** (optional)
   - **Hostname:** (optional)
   - **Path:** (required if used)

### Path Rule Format

**Basic rules:**

```
/users/george
/users/*
/production/*
/home/*/projects
```

**With hostname and user:**

```
george@*:/users/george
iterm2.com:/users/george
user@hostname:/path/to/directory
```

**Wildcard matching:**

- Exact path match = 1 point (higher priority)
- Wildcard match = 0 points (lower priority)

### Rule Evaluation

When multiple rules match:

1. Highest-scoring rule wins
2. Exact paths score higher than wildcards
3. More specific rules take precedence

### Sticky Rules

Prefix a rule with `!` to make it "sticky" (profile stays even after rule no longer applies):

```
!/production/*
```

This keeps the production profile active until a higher-scoring rule matches.

### Example Configuration

**Scenario:** Switch to "Production" profile when in `/var/www/prod/` directories

1. Create a "Production" profile with a distinct background color (e.g., light pink)
2. Go to **Advanced** settings for a base profile
3. Add Automatic Profile Switching rule:
   - **Path:** `/var/www/prod/*`
4. Specify the target profile: **Production**

**Scenario: Sticky Production**

```
!/var/www/prod/*
/var/www/staging/*
/var/www/dev/*
```

When you enter `/var/www/prod/`, the Production profile stays active until you enter staging or dev directories.

### Shell Hook Alternative (Manual)

If you prefer shell hooks over iTerm's built-in switching:

**Add to `.zshrc` or `.bashrc`:**

```bash
_switch_iterm_profile() {
  case "$PWD" in
    /production/*) echo -ne "\033]50;SetProfile=Production\007" ;;
    /staging/*)   echo -ne "\033]50;SetProfile=Staging\007" ;;
    /dev/*)       echo -ne "\033]50;SetProfile=Development\007" ;;
    *)            echo -ne "\033]50;SetProfile=Default\007" ;;
  esac
}

# Call on directory change
chpwd_functions+=(_switch_iterm_profile)
```

This uses iTerm's escape sequence to switch profiles on `cd`.

---

## 6. Complete Example: Light Gray and Light Pink Profiles

### Dynamic Profile JSON

Save this as `~/Library/Application Support/iTerm2/DynamicProfiles/custom-profiles.json`:

```json
{
  "Profiles": [
    {
      "Name": "Light Gray",
      "Guid": "ba19744f-6af3-434d-aaa6-0a48e0969958",
      "Background Color": {
        "Alpha Component": 1.0,
        "Blue Component": 0.93,
        "Color Space": "sRGB",
        "Green Component": 0.93,
        "Red Component": 0.93
      },
      "Text Color": {
        "Red Component": 0.0,
        "Green Component": 0.0,
        "Blue Component": 0.0
      }
    },
    {
      "Name": "Light Pink",
      "Guid": "c02a855f-7c44-425d-bbb7-1b59ac2d9cf1",
      "Background Color": {
        "Alpha Component": 1.0,
        "Blue Component": 0.882,
        "Color Space": "sRGB",
        "Green Component": 0.894,
        "Red Component": 1.0
      },
      "Text Color": {
        "Red Component": 0.0,
        "Green Component": 0.0,
        "Blue Component": 0.0
      }
    }
  ]
}
```

### GUI Setup

1. Open **iTerm → Preferences → Profiles**
2. Click **+** to create "Light Gray"
3. Click **Colors** tab
4. Click the Background Color well
5. Enter RGB values: R: 237, G: 237, B: 237
6. Repeat for "Light Pink": R: 255, G: 228, B: 225

---

## 7. Key File Locations

| Item                      | Location                                                |
| ------------------------- | ------------------------------------------------------- |
| Dynamic Profiles          | `~/Library/Application Support/iTerm2/DynamicProfiles/` |
| Standard Preferences      | `~/Library/Preferences/com.googlecode.iterm2.plist`     |
| Shell Integration Scripts | `~/.iterm2/` (auto-installed)                           |
| Color Schemes (imported)  | `~/Library/Application Support/iTerm2/ColorSchemes/`    |

---

## 8. References

- [iTerm2 Colors Documentation](https://iterm2.com/documentation-preferences-profiles-colors.html)
- [iTerm2 Dynamic Profiles Documentation](https://iterm2.com/documentation-dynamic-profiles.html)
- [iTerm2 Automatic Profile Switching](https://iterm2.com/documentation-automatic-profile-switching.html)
- [iTerm2 Advanced Profile Settings](https://iterm2.com/documentation-preferences-profiles-advanced.html)
- [Syncing Profiles with Dotfiles](http://stratus3d.com/blog/2015/02/28/sync-iterm2-profile-with-dotfiles-repository/)
- [iTerm2 Color Schemes Gallery](https://iterm2colorschemes.com/)
- [mbadolato/iTerm2-Color-Schemes](https://github.com/mbadolato/iTerm2-Color-Schemes)
