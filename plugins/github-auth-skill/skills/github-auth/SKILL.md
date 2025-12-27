---
name: github-auth
description: Guide Claude through GitHub CLI authentication to enable actions on the user's behalf, especially useful for accessing repos or creating PRs where Claude doesn't have immediate access
---

# GitHub Authentication Skill

This skill enables Claude to guide users through GitHub CLI authentication using device code flow, allowing Claude to take actions on their behalf in repositories they have access to.

## When Claude Activates This Skill

Claude will use this skill when:

- **Creating PRs in External Repos**: User asks Claude to create a pull request in a repository where Claude doesn't have push access
- **Cross-Repository Actions**: User needs Claude to interact with repositories outside the current workspace
- **GitHub API Access Required**: User wants Claude to perform GitHub operations that require authentication
- **Permission Errors**: Claude encounters 403/404 errors when trying to access GitHub resources
- **User Account Operations**: User asks Claude to perform operations that require their GitHub identity

## The Device Code Flow Process

### Overview

The `BROWSER=false gh auth login` command initiates GitHub's device code flow, which:

1. Generates a one-time code
2. Provides a URL for the user to visit
3. User enters the code and authorizes access
4. Claude receives authentication to act on the user's behalf

### Step-by-Step Authentication

#### Step 1: Initiate Authentication

```bash
BROWSER=false gh auth login
```

This command outputs:

- A one-time code (e.g., `ABCD-1234`)
- A URL to visit: `https://github.com/login/device`

#### Step 2: User Authorization

The user must:

1. Open `https://github.com/login/device` in their browser
2. Enter the displayed code
3. Authorize the GitHub CLI application
4. Return to confirm completion

#### Step 3: Complete Authentication

Once authorized, Claude can:

- Access repositories the user has permission to access
- Create issues and pull requests
- Push to branches the user can push to
- Perform API operations on behalf of the user

## What This Skill Enables

### 1. Cross-Repository Pull Requests

```
User: "Create a PR in organization/external-repo with these changes"

Claude's workflow:
1. Attempts to access the repository
2. Detects permission issues
3. Initiates device code authentication
4. Guides user through authorization
5. Creates the pull request once authenticated
```

### 2. Fork and Contribute Workflow

```
User: "Fork this project and submit my changes as a PR"

Claude's workflow:
1. Authenticates with user's GitHub account
2. Forks the repository to user's account
3. Pushes changes to the fork
4. Creates PR from fork to upstream
```

### 3. Organization Access

```
User: "I need to create an issue in our company's private repo"

Claude's workflow:
1. Authenticates as the user
2. Accesses organization repositories
3. Creates the issue with proper permissions
```

### 4. GitHub API Operations

```
User: "List my open PRs across all repos"

Claude's workflow:
1. Authenticates with user's account
2. Queries GitHub API
3. Returns comprehensive PR list
```

## Authentication Command Details

### Basic Authentication

```bash
BROWSER=false gh auth login
```

Interactive prompts will ask:

- Account type: `GitHub.com` or `GitHub Enterprise Server`
- Preferred protocol: `HTTPS` or `SSH`
- Authentication method: This uses device code by default when browser is disabled

### Authentication with Options

```bash
# Authenticate to GitHub.com with HTTPS
BROWSER=false gh auth login --hostname github.com --git-protocol https

# Authenticate with specific scopes
BROWSER=false gh auth login --scopes "repo,read:org,write:packages"

# Authenticate to GitHub Enterprise
BROWSER=false gh auth login --hostname github.mycompany.com
```

### Common Scopes

| Scope              | Description                            |
| ------------------ | -------------------------------------- |
| `repo`             | Full control of private repositories   |
| `read:org`         | Read organization membership           |
| `write:org`        | Read and write organization membership |
| `read:packages`    | Download packages from GitHub Packages |
| `write:packages`   | Upload packages to GitHub Packages     |
| `admin:public_key` | Manage public keys                     |
| `gist`             | Create gists                           |
| `workflow`         | Update GitHub Action workflows         |

## Security Considerations

### What the User Should Know

1. **Token Storage**: The authentication token is stored in `~/.config/gh/hosts.yml`
2. **Scope Limitations**: Request only necessary scopes
3. **Token Expiration**: Tokens may expire and require re-authentication
4. **Revocation**: Users can revoke access at `https://github.com/settings/applications`

### Best Practices

- **Minimal Scopes**: Request only the permissions needed for the task
- **Verify Operations**: Confirm critical operations before executing
- **Transparent Actions**: Clearly communicate what actions will be performed
- **Session Awareness**: Remind users that authentication persists across sessions

## Usage Scenarios

### Scenario 1: PR to External Repository

```
User: "Submit a PR to facebook/react with my bug fix"

Claude:
1. Detects need for authentication to fork/PR
2. Runs: BROWSER=false gh auth login
3. Displays one-time code to user
4. Waits for user to authorize
5. Forks repository to user's account
6. Creates branch with changes
7. Submits PR from fork to upstream
```

### Scenario 2: Access Private Organization Repo

```
User: "Clone and set up our team's private repo at mycompany/internal-tools"

Claude:
1. Attempts clone, receives 404 (private repo)
2. Initiates authentication
3. User authorizes with org access
4. Successfully clones repository
5. Sets up development environment
```

### Scenario 3: Create Issue in Another Repo

```
User: "Report this bug to the upstream library at vendor/library"

Claude:
1. Authenticates via device code flow
2. Creates detailed issue with reproduction steps
3. Reports issue URL back to user
```

### Scenario 4: Multiple Repository Operations

```
User: "Update dependencies across all my repositories"

Claude:
1. Authenticates once with appropriate scopes
2. Lists user's repositories
3. Creates PRs in each with dependency updates
4. Reports summary of all created PRs
```

## Handling Authentication States

### Already Authenticated

```bash
# Check current authentication status
gh auth status
```

If already authenticated, Claude will:

1. Verify existing authentication is sufficient
2. Proceed with the requested operation
3. Only re-authenticate if scopes are insufficient

### Authentication Expired

```bash
# Refresh authentication
BROWSER=false gh auth refresh
```

### Switch Accounts

```bash
# Login to a different account
BROWSER=false gh auth login
# or explicitly switch
gh auth switch --user username
```

### Logout

```bash
# Remove authentication
gh auth logout
```

## Error Handling

### Common Issues and Solutions

| Error          | Cause                           | Solution                               |
| -------------- | ------------------------------- | -------------------------------------- |
| `HTTP 401`     | Token expired or invalid        | Re-authenticate with `gh auth login`   |
| `HTTP 403`     | Insufficient permissions        | Re-authenticate with additional scopes |
| `HTTP 404`     | Private repo, not authenticated | Authenticate to access private repos   |
| `SSO Required` | Organization requires SSO       | User must authorize SSO in browser     |

### SSO Authorization

For organizations requiring SSO:

1. After device code authentication
2. Visit: `https://github.com/settings/applications`
3. Find "GitHub CLI" in authorized applications
4. Click "Configure SSO" next to your organization
5. Authorize the organization

## Output Format

When guiding users through authentication, Claude provides:

```
To authenticate with GitHub, please:

1. Run this command or let me run it for you:
   BROWSER=false gh auth login

2. You'll see a one-time code like: XXXX-XXXX

3. Visit: https://github.com/login/device

4. Enter the code and authorize access

5. Let me know when you've completed authorization

This will allow me to [specific action] on your behalf.
```

## Skill Capabilities

### Actions After Authentication

- Create and manage pull requests
- Create and manage issues
- Fork repositories
- Push to repositories (where user has access)
- Access private repositories
- Query GitHub API
- Manage releases
- Access organization resources (if authorized)

### Respects User Permissions

Claude can only perform actions the authenticated user is permitted to do:

- Cannot access repos user doesn't have access to
- Cannot push to protected branches without user's permissions
- Cannot modify organization settings beyond user's role
- Respects all GitHub permission models

## Integration with Other Skills

This skill works alongside:

- **Smart Commit**: Authenticate then commit and push
- **PR Creation**: Authenticate to create cross-repo PRs
- **Issue Management**: Authenticate to manage issues in any accessible repo

## Requirements

- **GitHub CLI**: `gh` must be installed
- **Internet Access**: Required for authentication flow
- **User Interaction**: User must complete browser authorization

## Limitations

- Cannot bypass GitHub permission restrictions
- SSO-protected orgs require additional browser steps
- Token scopes are fixed at authentication time
- Some enterprise features may require additional configuration

## Troubleshooting

**"gh: command not found"**

- Install GitHub CLI: `brew install gh` (macOS) or `sudo apt install gh` (Ubuntu)

**"Authentication required"**

- Run `BROWSER=false gh auth login` and complete authorization

**"Resource not accessible"**

- Verify user has access to the repository
- Check if additional scopes are needed
- For org repos, ensure SSO is authorized

**"Bad credentials"**

- Token may have been revoked; re-authenticate

**Device code expired**

- Codes expire after 15 minutes; restart authentication

## Privacy Note

Authentication tokens grant access to user's GitHub account. Claude:

- Only uses authentication for explicitly requested operations
- Does not store or transmit tokens beyond the session
- Respects user's repository and organization privacy
- Clearly communicates what actions require authentication
