# Claude Code Sessions API - Reverse Engineered Documentation

> ⚠️ **DISCLAIMER**: This documentation was reverse-engineered from the Claude Code CLI binary (v2.0.59).
> These APIs are undocumented and may change without notice. Use at your own risk.

## Overview

Claude Code Web uses a Sessions API hosted at `api.anthropic.com` to manage coding sessions.
This enables the "teleport" feature that transfers sessions between Web and CLI.

**Internal Codename**: "Tengu"

## Authentication

All requests require OAuth authentication with a Claude.ai account (not just an API key).

### Required Headers

```http
Authorization: Bearer <oauth_access_token>
Content-Type: application/json
anthropic-version: 2023-06-01
x-organization-uuid: <org_uuid>
```

### Getting Credentials

Credentials are stored in `~/.claude/.credentials` after running `claude login`.

```json
{
  "claudeAiOauth": {
    "accessToken": "sk-ant-...",
    "refreshToken": "...",
    "organizationUuid": "org-..."
  }
}
```

Or via environment variables:
- `CLAUDE_CODE_OAUTH_TOKEN`
- `CLAUDE_ORG_UUID`

---

## API Endpoints

### List Sessions

```http
GET /v1/sessions
```

**Response**:
```json
{
  "data": [
    {
      "id": "session_011CUNPVCEo76Q5UFhpdUSfC",
      "title": "Implement feature X",
      "session_status": "idle|working|waiting|completed|archived|cancelled|rejected",
      "created_at": "2025-12-16T17:38:45.000Z",
      "updated_at": "2025-12-16T17:45:00.000Z",
      "session_context": {
        "sources": [
          {
            "type": "git_repository",
            "url": "https://github.com/owner/repo",
            "revision": "main"
          }
        ],
        "outcomes": [
          {
            "type": "git_repository",
            "git_info": {
              "branches": ["claude/feature-x-abc123"]
            }
          }
        ]
      }
    }
  ]
}
```

---

### Get Session Details

```http
GET /v1/sessions/{session_id}
```

Returns full session metadata including context and outcomes.

---

### Get Session Events (Messages)

```http
GET /v1/sessions/{session_id}/events
```

**Response**:
```json
{
  "data": [
    {
      "uuid": "88c66bb9-f4f5-4f4a-90ac-bd575fcab2fd",
      "session_id": "session_011CUNPVCEo76Q5UFhpdUSfC",
      "type": "user",
      "parent_tool_use_id": null,
      "message": {
        "role": "user",
        "content": "Help me implement feature X"
      }
    },
    {
      "uuid": "20ea3ff7-06b2-4a62-bbcc-9f726dd54174",
      "session_id": "session_011CUNPVCEo76Q5UFhpdUSfC",
      "type": "assistant",
      "parent_tool_use_id": null,
      "message": {
        "role": "assistant",
        "content": [
          {"type": "text", "text": "I'll help you implement..."},
          {"type": "tool_use", "id": "toolu_...", "name": "Read", "input": {...}}
        ]
      }
    }
  ]
}
```

---

### Post Events to Session

```http
POST /v1/sessions/{session_id}/events
```

**Request Body**:
```json
{
  "events": [
    {
      "uuid": "<random-uuid>",
      "session_id": "<session_id>",
      "type": "user",
      "parent_tool_use_id": null,
      "message": {
        "role": "user",
        "content": "Your message here"
      }
    }
  ]
}
```

**Note**: This endpoint exists and is used internally, but creating new sessions
or uploading full conversation history may require additional undocumented endpoints.

---

### List Environment Providers

```http
GET /v1/environment_providers
```

Returns available remote execution environments for Claude Code Web.

**Response** (inferred from binary analysis):
```json
{
  "environments": [
    {
      "environment_id": "env-abc123",
      "name": "Default Environment",
      "tier": "pro|max|enterprise"
    }
  ]
}
```

This is the **key** to understanding how Claude Code Web works:
- Sessions don't run on GitHub Actions
- They run on Anthropic-hosted **remote environments**
- These are sandboxed containers/VMs that execute code
- The `environment_providers` endpoint lists what's available to your account

---

## Environment Providers (Remote Execution)

### What Are Environment Providers?

Claude Code Web doesn't run code on your machine or via GitHub Actions. Instead, it uses
**remote execution environments** hosted by Anthropic. These are:

- Sandboxed containers (likely Firecracker microVMs or similar)
- Pre-configured with common development tools
- Connected to your GitHub repository
- Isolated per-session for security

### Key Telemetry Fields

From binary analysis, sessions track:
```javascript
{
  "is_claude_code_remote": true,
  "remote_environment_type": "sandbox|container|...",
  "claude_code_container_id": "container-xyz",
  "claude_code_remote_session_id": "session-abc"
}
```

### How Sessions Use Environments

1. **Session Creation**: When you start a Claude Code Web session, an environment is provisioned
2. **Code Execution**: All tool calls (Bash, Read, Write, etc.) run in this environment
3. **Git Integration**: Environment clones your repo from GitHub
4. **Persistence**: Environment state persists for the session duration
5. **Cleanup**: Environment is destroyed when session ends/archives

### Configuration

The CLI has a setting for default remote environment:
```
"Configure the default remote environment for teleport sessions"
```

This suggests you can choose which environment type to use for teleport operations.

### Checking Environment Availability

```javascript
// From binary: ZP2() - checkHasRemoteEnvironment
async function checkHasRemoteEnvironment() {
  try {
    return (await fetchEnvironmentProviders()).length > 0;
  } catch (error) {
    return false;
  }
}
```

If no environments are available, you'll see:
```
"No environments available for session creation"
```

### GitHub App Integration

The system also checks if the GitHub App is installed on your repo:
```http
GET /api/oauth/organizations/{org_uuid}/code/repos/{owner}/{repo}
```

Response includes:
```json
{
  "status": {
    "app_installed": true
  }
}
```

---

## Teleport Flow (Web → CLI)

### How `claude --teleport <session>` Works

1. **Parse Input**: Accept session ID or full URL
2. **Validate Repository**:
   - Fetch session metadata from `/v1/sessions/{id}`
   - Extract `session_context.sources` for git repository info
   - Verify local repo matches session's repo
3. **Fetch Events**: GET `/v1/sessions/{id}/events`
4. **Checkout Branch**: If session has outcomes with branch info, checkout that branch
5. **Resume Session**: Load events into local session and continue

### Environment Variables

```bash
# Override resume URL (used internally)
TELEPORT_RESUME_URL=https://...

# Pass additional headers as JSON
TELEPORT_HEADERS='{"X-Custom": "value"}'
```

---

## Local Session Format

Sessions are stored in `~/.claude/projects/<escaped-path>/<session-id>.jsonl`

Each line is a JSON object:

```json
{
  "parentUuid": "previous-message-uuid|null",
  "isSidechain": false,
  "userType": "external",
  "cwd": "/path/to/project",
  "sessionId": "c958eaa2-954d-48a8-b2e0-2251bd5959c6",
  "version": "2.0.59",
  "gitBranch": "main",
  "type": "user|assistant|queue-operation",
  "message": {
    "role": "user|assistant",
    "content": "string or array of content blocks",
    "model": "claude-opus-4-5-20251101",
    "id": "msg_..."
  },
  "uuid": "unique-message-uuid",
  "timestamp": "2025-12-16T17:38:45.159Z",
  "requestId": "req_..."
}
```

### Content Block Types

```typescript
type ContentBlock =
  | { type: "text"; text: string }
  | { type: "thinking"; thinking: string; signature: string }
  | { type: "tool_use"; id: string; name: string; input: object }
  | { type: "tool_result"; tool_use_id: string; content: string; is_error?: boolean };
```

---

## CLI → Web Transfer (Proposed Flow)

Based on the API surface, here's how a reverse teleport could work:

### Option 1: Append to Existing Session

1. List web sessions: `GET /v1/sessions`
2. Pick a session or create reference
3. Post events: `POST /v1/sessions/{id}/events`

### Option 2: Create New Session (Unverified)

```http
POST /v1/sessions
Content-Type: application/json

{
  "title": "CLI Transfer: <description>",
  "session_context": {
    "sources": [
      {
        "type": "git_repository",
        "url": "https://github.com/owner/repo",
        "revision": "main"
      }
    ]
  }
}
```

**Note**: Session creation may require going through the Claude.ai web UI first.

---

## Telemetry Events (Tengu)

The CLI emits these telemetry events for teleport operations:

| Event | Description |
|-------|-------------|
| `tengu_teleport_resume_success` | Teleport completed successfully |
| `tengu_teleport_resume_error` | Teleport failed |
| `tengu_teleport_error_no_url_or_session_id` | No session provided |
| `tengu_teleport_error_git_not_clean` | Working directory has changes |
| `tengu_teleport_error_branch_checkout_failed` | Git checkout failed |
| `tengu_teleport_error_repo_mismatch_sessions_api` | Local repo doesn't match session |
| `tengu_teleport_error_session_not_found_404` | Session ID not found |
| `tengu_teleport_cancelled` | User cancelled teleport |
| `tengu_web_tasks` | Web tasks related event |

---

## Limitations & Notes

1. **No Official Documentation**: These APIs are internal and undocumented
2. **OAuth Required**: API keys don't work; must use Claude.ai OAuth
3. **One-Way Teleport**: Only Web → CLI is officially supported
4. **GitHub Only**: Web sessions only work with GitHub repos (not GitLab)
5. **Session State**: Sessions include git branch context; local state must match
6. **Rate Limits**: Unknown; likely subject to standard API limits

---

## Related Files in Claude Code Binary

Key functions discovered through decompilation:

| Function | Purpose |
|----------|---------|
| `yRA(sessionId)` | Resume session by ID |
| `HP2(url, headers)` | Teleport from URL |
| `uf5(id, orgUUID, token)` | Fetch session events |
| `BP2(sessionId, message)` | Send message to session |
| `QP2()` | List all sessions |
| `hf5()` | Validate repo matches |
| `xRA(urlOrId)` | Parse teleport input |
| `IC(accessToken)` | Build auth headers |

---

## Example: Fetch Session via curl

```bash
# Get your OAuth token from ~/.claude/.credentials
TOKEN=$(jq -r '.claudeAiOauth.accessToken' ~/.claude/.credentials)
ORG=$(jq -r '.claudeAiOauth.organizationUuid' ~/.claude/.credentials)

# List sessions
curl -s "https://api.anthropic.com/v1/sessions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "anthropic-version: 2023-06-01" \
  -H "x-organization-uuid: $ORG" | jq .

# Get session events
curl -s "https://api.anthropic.com/v1/sessions/SESSION_ID/events" \
  -H "Authorization: Bearer $TOKEN" \
  -H "anthropic-version: 2023-06-01" \
  -H "x-organization-uuid: $ORG" | jq .
```

---

## References

- Claude Code CLI: `/opt/node22/lib/node_modules/@anthropic-ai/claude-code/cli.js`
- Local sessions: `~/.claude/projects/`
- Credentials: `~/.claude/.credentials`
- GitHub Issues: https://github.com/anthropics/claude-code/issues
