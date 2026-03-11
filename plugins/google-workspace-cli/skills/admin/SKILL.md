---
name: admin
description: >
  Use this skill when the user asks about Google Workspace administration
  tasks like managing users, groups, organizational units, or domain
  settings via the Google Workspace CLI. Requires admin privileges.
---

# Google Admin via Google Workspace CLI

Use `gws admin` to manage Google Workspace domain administration from the command line.

**Note:** Admin operations require Google Workspace admin privileges.

## Common Operations

### Users

```bash
# List users in the domain
gws admin users list

# List with pagination
gws admin users list --limit 100

# Get a specific user
gws admin users get "user@example.com"

# Create a user
gws admin users create \
  --email "newuser@example.com" \
  --given-name "New" \
  --family-name "User" \
  --password "temporary-password"

# Update a user
gws admin users update "user@example.com" \
  --given-name "Updated"

# Suspend a user
gws admin users update "user@example.com" --suspended true

# Unsuspend a user
gws admin users update "user@example.com" --suspended false

# Delete a user
gws admin users delete "user@example.com"
```

### Groups

```bash
# List groups
gws admin groups list

# Get group details
gws admin groups get "group@example.com"

# Create a group
gws admin groups create \
  --email "team@example.com" \
  --name "Team" \
  --description "Team group"

# Add a member to a group
gws admin groups members add "group@example.com" --email "user@example.com" --role "MEMBER"

# List group members
gws admin groups members list "group@example.com"

# Remove a member
gws admin groups members remove "group@example.com" --email "user@example.com"

# Delete a group
gws admin groups delete "group@example.com"
```

### Organizational Units

```bash
# List organizational units
gws admin orgunits list

# Create an organizational unit
gws admin orgunits create --name "Engineering" --parent "/"

# Move a user to an OU
gws admin users update "user@example.com" --org-unit "/Engineering"
```

### Roles

| Role | Description |
|------|-------------|
| `OWNER` | Group owner |
| `MANAGER` | Group manager |
| `MEMBER` | Regular member |

## Tips

- Admin API requires domain admin or delegated admin credentials
- User operations use primary email as the identifier
- Use `--format json` for structured output
- Bulk operations should use batch requests when available
