---
name: sheets
description: >
  Use this skill when the user asks about reading, writing, or managing
  Google Sheets data via the Google Workspace CLI. Trigger on spreadsheet
  tasks like reading cell ranges, updating data, creating sheets, or
  working with formulas.
---

# Google Sheets via Google Workspace CLI

Use `gws sheets` to interact with Google Sheets from the command line.

## Common Operations

### Read Data

```bash
# Read a range of cells
gws sheets get <spreadsheet-id> --range "Sheet1!A1:D10"

# Read entire sheet
gws sheets get <spreadsheet-id> --range "Sheet1"

# Read as JSON
gws sheets get <spreadsheet-id> --range "Sheet1!A1:D10" --format json

# Read with value render option
gws sheets get <spreadsheet-id> --range "Sheet1!A1:D10" --value-render "FORMATTED_VALUE"
```

### Write Data

```bash
# Update a range
gws sheets update <spreadsheet-id> --range "Sheet1!A1" --values '[["Name","Email"],["Alice","alice@example.com"]]'

# Append rows to a sheet
gws sheets append <spreadsheet-id> --range "Sheet1!A1" --values '[["Bob","bob@example.com"]]'

# Clear a range
gws sheets clear <spreadsheet-id> --range "Sheet1!A1:D10"
```

### Create Spreadsheets

```bash
# Create a new spreadsheet
gws sheets create --title "Budget 2026"

# Create with initial sheet names
gws sheets create --title "Budget 2026" --sheets "Q1,Q2,Q3,Q4"
```

### Manage Sheets (Tabs)

```bash
# List sheets in a spreadsheet
gws sheets list <spreadsheet-id>

# Add a new sheet
gws sheets add-sheet <spreadsheet-id> --title "New Tab"

# Delete a sheet
gws sheets delete-sheet <spreadsheet-id> --sheet-id <sheet-id>

# Rename a sheet
gws sheets rename-sheet <spreadsheet-id> --sheet-id <sheet-id> --title "Renamed"
```

### Batch Operations

```bash
# Batch update multiple ranges
gws sheets batchUpdate <spreadsheet-id> --data '[
  {"range": "Sheet1!A1", "values": [["Header1", "Header2"]]},
  {"range": "Sheet1!A2", "values": [["Data1", "Data2"]]}
]'

# Batch get multiple ranges
gws sheets batchGet <spreadsheet-id> --ranges "Sheet1!A1:B5,Sheet2!A1:C3"
```

## Value Input Options

| Option         | Behavior                                            |
| -------------- | --------------------------------------------------- |
| `RAW`          | Values stored as-is (no parsing)                    |
| `USER_ENTERED` | Values parsed as if user typed them (formulas work) |

```bash
# Write with formula support
gws sheets update <spreadsheet-id> --range "Sheet1!C1" \
  --values '[["=SUM(A1:B1)"]]' --value-input "USER_ENTERED"
```

## Common Patterns

### Export to CSV

```bash
gws drive files export <spreadsheet-id> --mime-type "text/csv" --output ./data.csv
```

### Read and Process with jq

```bash
# Get values as JSON and extract specific column
gws sheets get <spreadsheet-id> --range "Sheet1!A:A" --format json | jq '.[].values[][]'
```

## Tips

- Spreadsheet IDs are in the URL: `docs.google.com/spreadsheets/d/<SPREADSHEET_ID>/edit`
- Use `A1` notation for ranges: `Sheet1!A1:D10`, `Sheet1!A:A` (full column), `Sheet1` (full sheet)
- Use `--value-input USER_ENTERED` when writing formulas
- Use `gws drive files list` to find spreadsheets by name
