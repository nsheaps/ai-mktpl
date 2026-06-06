---
name: contacts
description: >
  Use this skill when the user asks about managing Google Contacts like
  searching, creating, updating, or organizing contacts via the Google
  Workspace CLI.
---

# Google Contacts via Google Workspace CLI

Use `gws contacts` (via the People API) to manage Google Contacts from the command line.

## Common Operations

### List and Search Contacts

```bash
# List contacts
gws contacts list

# List with pagination
gws contacts list --limit 50

# Search contacts
gws contacts search "John"

# Search by email
gws contacts search "john@example.com"
```

### View Contact Details

```bash
# Get a specific contact
gws contacts get <resource-name>

# Get as JSON
gws contacts get <resource-name> --format json
```

### Create Contacts

```bash
# Create a new contact
gws contacts create \
  --given-name "John" \
  --family-name "Doe" \
  --email "john@example.com"

# Create with phone number
gws contacts create \
  --given-name "Jane" \
  --family-name "Smith" \
  --email "jane@example.com" \
  --phone "+1-555-0123"

# Create with organization
gws contacts create \
  --given-name "Bob" \
  --family-name "Johnson" \
  --email "bob@company.com" \
  --organization "Company Inc" \
  --title "Engineer"
```

### Update Contacts

```bash
# Update email
gws contacts update <resource-name> --email "newemail@example.com"

# Update phone
gws contacts update <resource-name> --phone "+1-555-9999"
```

### Delete Contacts

```bash
# Delete a contact
gws contacts delete <resource-name>
```

### Contact Groups

```bash
# List contact groups
gws contacts groups list

# Create a group
gws contacts groups create --name "Project Team"

# Add contact to group
gws contacts groups add <group-resource> <contact-resource>
```

## Tips

- Resource names follow the format `people/<person-id>`
- The People API is used behind the scenes for contacts
- Use `--format json` for structured output
- Contact search supports name, email, and phone number queries
