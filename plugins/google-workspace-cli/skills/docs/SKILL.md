---
name: docs
description: >
  Use this skill when the user asks about creating, reading, or editing
  Google Docs via the Google Workspace CLI. Trigger on tasks involving
  document content, formatting, or collaboration on Google Docs.
---

# Google Docs via Google Workspace CLI

Use `gws docs` to create and manage Google Docs from the command line.

## Common Operations

### Create Documents

```bash
# Create a new document
gws docs create --title "Meeting Notes"

# Create with initial content
gws docs create --title "Project Plan" --body "Initial project outline"
```

### Read Documents

```bash
# Get document content
gws docs get <document-id>

# Get as JSON
gws docs get <document-id> --format json

# Get document metadata
gws docs get <document-id> --metadata
```

### Update Documents

```bash
# Append text to a document
gws docs update <document-id> --append "New section content"

# Insert text at a specific index
gws docs update <document-id> --insert "Header text" --index 1
```

### Batch Updates

The Docs API supports batch updates for complex document modifications:

```bash
# Apply batch updates via JSON
gws docs batchUpdate <document-id> --requests '[
  {
    "insertText": {
      "location": {"index": 1},
      "text": "New Title\n"
    }
  },
  {
    "updateTextStyle": {
      "range": {"startIndex": 1, "endIndex": 10},
      "textStyle": {"bold": true},
      "fields": "bold"
    }
  }
]'
```

### Export Documents

```bash
# Export via Drive API as PDF
gws drive files export <document-id> --mime-type "application/pdf" --output ./doc.pdf

# Export as plain text
gws drive files export <document-id> --mime-type "text/plain" --output ./doc.txt

# Export as DOCX
gws drive files export <document-id> --mime-type "application/vnd.openxmlformats-officedocument.wordprocessingml.document" --output ./doc.docx
```

## Working with Document Structure

Google Docs uses a structured model with:

- **Body** containing structural elements
- **Paragraphs** with text runs
- **Tables** with rows and cells
- **Lists** with nesting levels

Use `--format json` to inspect document structure:

```bash
gws docs get <document-id> --format json | jq '.body.content'
```

## Tips

- Document IDs can be found in the URL: `docs.google.com/document/d/<DOCUMENT_ID>/edit`
- Use `gws drive files list` to find documents by name
- Combine with `gws drive` for file management (move, share, delete)
