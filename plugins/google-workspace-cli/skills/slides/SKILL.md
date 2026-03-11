---
name: slides
description: >
  Use this skill when the user asks about creating, reading, or editing
  Google Slides presentations via the Google Workspace CLI. Trigger on
  tasks involving slides, presentations, or speaker notes.
---

# Google Slides via Google Workspace CLI

Use `gws slides` to manage Google Slides presentations from the command line.

## Common Operations

### Create Presentations

```bash
# Create a new presentation
gws slides create --title "Q1 Review"
```

### Read Presentations

```bash
# Get presentation metadata and structure
gws slides get <presentation-id>

# Get as JSON to inspect slide structure
gws slides get <presentation-id> --format json

# Get a specific page/slide
gws slides pages get <presentation-id> --page-id <page-id>
```

### Modify Presentations

```bash
# Add a new blank slide
gws slides batchUpdate <presentation-id> --requests '[
  {"createSlide": {"slideLayoutReference": {"predefinedLayout": "BLANK"}}}
]'

# Insert text into a text box
gws slides batchUpdate <presentation-id> --requests '[
  {"insertText": {
    "objectId": "<text-box-id>",
    "text": "Hello World",
    "insertionIndex": 0
  }}
]'

# Delete a slide
gws slides batchUpdate <presentation-id> --requests '[
  {"deleteObject": {"objectId": "<slide-id>"}}
]'
```

### Export Presentations

```bash
# Export as PDF via Drive API
gws drive files export <presentation-id> \
  --mime-type "application/pdf" --output ./presentation.pdf

# Export as PPTX
gws drive files export <presentation-id> \
  --mime-type "application/vnd.openxmlformats-officedocument.presentationml.presentation" \
  --output ./presentation.pptx
```

## Slide Layouts

Common predefined layouts for `createSlide`:

| Layout | Description |
|--------|-------------|
| `BLANK` | Empty slide |
| `TITLE` | Title slide |
| `TITLE_AND_BODY` | Title with body text |
| `TITLE_AND_TWO_COLUMNS` | Title with two columns |
| `TITLE_ONLY` | Title bar only |
| `SECTION_HEADER` | Section divider |

## Tips

- Presentation IDs are in the URL: `docs.google.com/presentation/d/<PRESENTATION_ID>/edit`
- Use `--format json` to discover object IDs for text boxes and shapes
- Complex modifications use `batchUpdate` with request arrays
- Use `gws drive files list` to find presentations by name
