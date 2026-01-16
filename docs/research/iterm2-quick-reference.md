# iTerm2 Configuration Quick Reference

Actionable steps for common iTerm2 setup tasks.

## Quick Setup: Light Gray Profile

### GUI Method (5 minutes)

1. Open iTerm → Preferences → Profiles
2. Click + to create profile, name it "Light Gray"
3. Click Colors tab
4. Click Background Color well
5. RGB: 237, 237, 237
6. Click Colors tab
7. Close preferences

### JSON Method (1 minute)

Create `~/Library/Application\ Support/iTerm2/DynamicProfiles/profiles.json`:

```json
{
  "Profiles": [
    {
      "Name": "Light Gray",
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

Profile loads automatically within 1 second.

---

## Quick Setup: Light Pink Profile

### JSON Method

Add to same `profiles.json`:

```json
{
  "Name": "Light Pink",
  "Guid": "c02a855f-7c44-425d-bbb7-1b59ac2d9cf1",
  "Background Color": {
    "Red Component": 1.0,
    "Green Component": 0.894,
    "Blue Component": 0.882
  }
}
```

---

## Quick Setup: Auto-Switch on Directory

### Requirements

- Install Shell Integration: **iTerm → Install Shell Integration**

### Configuration

1. Open Preferences → Profiles → (select a profile) → Advanced
2. Locate **Automatic Profile Switching**
3. Add rule:
   - **Hostname:** (leave empty)
   - **Username:** (leave empty)
   - **Path:** `/production/*`
4. **Switch to Profile:** Light Pink

Now whenever you `cd` into `/production/` directories, profile switches automatically.

---

## Color Conversion Cheat Sheet

| Color        | Hex     | Red  | Green | Blue  |
| ------------ | ------- | ---- | ----- | ----- |
| Light Gray   | #EEEEEE | 0.93 | 0.93  | 0.93  |
| Light Pink   | #FFE4E1 | 1.0  | 0.894 | 0.882 |
| White        | #FFFFFF | 1.0  | 1.0   | 1.0   |
| Black        | #000000 | 0.0  | 0.0   | 0.0   |
| Light Blue   | #E6F2FF | 0.90 | 0.95  | 1.0   |
| Light Yellow | #FFFACD | 1.0  | 0.98  | 0.80  |
| Light Green  | #E8F5E9 | 0.91 | 0.96  | 0.91  |

**Formula:** Decimal = Hex / 255 (example: 0xEE / 255 = 0.93)

---

## Key File Paths

```
~/Library/Application Support/iTerm2/DynamicProfiles/     # Profile files
~/Library/Preferences/com.googlecode.iterm2.plist         # Standard settings
~/.iterm2/                                                # Shell integration
```

---

## Generate UUID for Profiles

```bash
uuidgen
```

Output example: `ba19744f-6af3-434d-aaa6-0a48e0969958`

---

## Common Tasks

### Export Current Profile

1. Preferences → Profiles → (select profile)
2. Other Actions → Save Profile as JSON

### Import Profile

1. Paste JSON into `DynamicProfiles/` folder
2. Loads automatically within 1 second

### View All Profiles

```bash
ls ~/Library/Application\ Support/iTerm2/DynamicProfiles/
```

### Edit Profile JSON Directly

```bash
nano ~/Library/Application\ Support/iTerm2/DynamicProfiles/profiles.json
```

Changes apply immediately.

---

## Troubleshooting

| Problem                    | Solution                                                 |
| -------------------------- | -------------------------------------------------------- |
| Profile doesn't appear     | Check JSON syntax, verify file in DynamicProfiles folder |
| Colors look wrong          | Ensure RGB values are between 0 and 1 (not 0-255)        |
| Changes not reflecting     | Wait 1-2 seconds or close/reopen preferences             |
| Profile switch not working | Verify Shell Integration installed (iTerm → menu)        |
| Invalid UUID               | Run `uuidgen` to generate valid UUID                     |
