---
name: drive
description: >
  Use this skill when the user asks about Google Drive operations like listing
  files, uploading, downloading, searching, sharing, or managing files and
  folders via the Google Workspace CLI.
---

# Google Drive via Google Workspace CLI

Use `gws drive` to manage files and folders in Google Drive from the command line.

## Common Operations

### List Files

```bash
# List files in My Drive root
gws drive files list

# List with pagination
gws drive files list --params '{"pageSize": 25}'

# List files in a specific folder
gws drive files list --params '{"q": "'\''<folder-id>'\'' in parents"}'

# List only specific file types
gws drive files list --params '{"q": "mimeType='\''application/vnd.google-apps.spreadsheet'\''"}'
```

### Search Files

```bash
# Search by name
gws drive files list --params '{"q": "name contains '\''report'\''"}'

# Search by type and name
gws drive files list --params '{"q": "mimeType='\''application/vnd.google-apps.document'\'' and name contains '\''Q1'\''"}'

# Search recently modified files
gws drive files list --params '{"q": "modifiedTime > '\''2026-03-01T00:00:00'\''", "orderBy": "modifiedTime desc"}'
```

### Download Files

```bash
# Download a file
gws drive files get <file-id> --download --output ./local-file.pdf

# Export a Google Doc as PDF
gws drive files export <file-id> --mime-type "application/pdf" --output ./document.pdf

# Export a Google Sheet as CSV
gws drive files export <file-id> --mime-type "text/csv" --output ./data.csv
```

### Upload Files

```bash
# Upload a file
gws drive files create --upload ./report.pdf --name "Q1 Report"

# Upload to a specific folder
gws drive files create --upload ./report.pdf --name "Q1 Report" --parents "<folder-id>"
```

### Create Files/Folders

```bash
# Create a folder
gws drive files create --name "Project Files" --mime-type "application/vnd.google-apps.folder"

# Create a Google Doc
gws drive files create --name "Meeting Notes" --mime-type "application/vnd.google-apps.document"

# Create a Google Sheet
gws drive files create --name "Budget" --mime-type "application/vnd.google-apps.spreadsheet"
```

### Share Files

```bash
# Share with a user (editor)
gws drive permissions create <file-id> \
  --type user --role writer --email "user@example.com"

# Share with a user (viewer)
gws drive permissions create <file-id> \
  --type user --role reader --email "user@example.com"

# Share with anyone who has the link
gws drive permissions create <file-id> \
  --type anyone --role reader

# List permissions
gws drive permissions list <file-id>

# Remove a permission
gws drive permissions delete <file-id> <permission-id>
```

### Move and Rename

```bash
# Rename a file
gws drive files update <file-id> --name "New Name"

# Move a file to a different folder
gws drive files update <file-id> --add-parents "<new-folder-id>" --remove-parents "<old-folder-id>"
```

### Delete Files

```bash
# Move to trash
gws drive files trash <file-id>

# Permanently delete
gws drive files delete <file-id>

# Empty trash
gws drive trash empty
```

## Google Drive MIME Types

| Type | MIME Type |
|------|-----------|
| Folder | `application/vnd.google-apps.folder` |
| Document | `application/vnd.google-apps.document` |
| Spreadsheet | `application/vnd.google-apps.spreadsheet` |
| Presentation | `application/vnd.google-apps.presentation` |
| Form | `application/vnd.google-apps.form` |

## JSON Output

```bash
gws drive files list --format json | jq '.[].name'
```
