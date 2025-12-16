#!/bin/bash
# Claude Code Sessions API - Shell Script Interface
#
# Usage:
#   ./claude-session-api.sh list              # List web sessions
#   ./claude-session-api.sh get <session_id>  # Get session details
#   ./claude-session-api.sh events <session_id>  # Get session events
#   ./claude-session-api.sh send <session_id> "message"  # Send message to session
#   ./claude-session-api.sh local             # List local sessions

set -e

# Configuration
API_BASE="https://api.anthropic.com"
CRED_FILE="$HOME/.claude/.credentials"
PROJECTS_DIR="$HOME/.claude/projects"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get OAuth credentials
get_credentials() {
    if [[ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]]; then
        TOKEN="$CLAUDE_CODE_OAUTH_TOKEN"
        ORG="${CLAUDE_ORG_UUID:-}"
    elif [[ -f "$CRED_FILE" ]]; then
        TOKEN=$(jq -r '.claudeAiOauth.accessToken // .accessToken // empty' "$CRED_FILE" 2>/dev/null)
        ORG=$(jq -r '.claudeAiOauth.organizationUuid // .organizationUuid // empty' "$CRED_FILE" 2>/dev/null)
    fi

    if [[ -z "$TOKEN" ]]; then
        echo -e "${RED}Error: No OAuth credentials found${NC}"
        echo "Run 'claude login' or set CLAUDE_CODE_OAUTH_TOKEN"
        exit 1
    fi
}

# Make API request
api_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"

    local args=(
        -s
        -X "$method"
        -H "Authorization: Bearer $TOKEN"
        -H "Content-Type: application/json"
        -H "anthropic-version: 2023-06-01"
    )

    if [[ -n "$ORG" ]]; then
        args+=(-H "x-organization-uuid: $ORG")
    fi

    if [[ -n "$data" ]]; then
        args+=(-d "$data")
    fi

    curl "${args[@]}" "${API_BASE}${endpoint}"
}

# List web sessions
list_sessions() {
    echo -e "${GREEN}📋 Web Sessions:${NC}\n"
    api_request GET "/v1/sessions" | jq -r '
        .data[]? |
        "  \(.id)\n    Title: \(.title // "Untitled")\n    Status: \(.session_status)\n    Updated: \(.updated_at)\n"
    ' 2>/dev/null || echo "No sessions found or API error"
}

# Get session details
get_session() {
    local session_id="$1"
    echo -e "${GREEN}📄 Session Details: $session_id${NC}\n"
    api_request GET "/v1/sessions/$session_id" | jq .
}

# Get session events
get_events() {
    local session_id="$1"
    echo -e "${GREEN}💬 Session Events: $session_id${NC}\n"
    api_request GET "/v1/sessions/$session_id/events" | jq -r '
        .data[]? |
        "[\(.type)] \(.message.role): \(.message.content | if type == "string" then .[0:100] else (.[0].text // .[0].type) end)...\n"
    ' 2>/dev/null || api_request GET "/v1/sessions/$session_id/events" | jq .
}

# Send message to session
send_message() {
    local session_id="$1"
    local message="$2"
    local uuid=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)

    local payload=$(jq -n \
        --arg uuid "$uuid" \
        --arg sid "$session_id" \
        --arg msg "$message" \
        '{
            events: [{
                uuid: $uuid,
                session_id: $sid,
                type: "user",
                parent_tool_use_id: null,
                message: {
                    role: "user",
                    content: $msg
                }
            }]
        }')

    echo -e "${GREEN}📤 Sending message to: $session_id${NC}\n"
    echo "Message: $message"
    echo ""

    result=$(api_request POST "/v1/sessions/$session_id/events" "$payload")

    if echo "$result" | jq -e '.error' >/dev/null 2>&1; then
        echo -e "${RED}Error:${NC}"
        echo "$result" | jq .
    else
        echo -e "${GREEN}✅ Message sent successfully${NC}"
        echo "$result" | jq .
    fi
}

# List local sessions
list_local() {
    echo -e "${GREEN}📁 Local Sessions:${NC}\n"

    if [[ ! -d "$PROJECTS_DIR" ]]; then
        echo "No local sessions found"
        return
    fi

    for dir in "$PROJECTS_DIR"/*/; do
        if [[ -d "$dir" ]]; then
            dirname=$(basename "$dir")
            echo "  $dirname/"

            for file in "$dir"*.jsonl; do
                if [[ -f "$file" ]]; then
                    filename=$(basename "$file" .jsonl)
                    size=$(du -h "$file" | cut -f1)
                    lines=$(wc -l < "$file")
                    echo "    - $filename ($size, $lines messages)"
                fi
            done
        fi
    done
}

# Export local session to JSON
export_local() {
    local session_id="$1"

    # Find session file
    local session_file=""
    for dir in "$PROJECTS_DIR"/*/; do
        if [[ -f "${dir}${session_id}.jsonl" ]]; then
            session_file="${dir}${session_id}.jsonl"
            break
        fi
    done

    if [[ -z "$session_file" ]]; then
        echo -e "${RED}Session not found: $session_id${NC}"
        exit 1
    fi

    echo -e "${GREEN}📤 Exporting: $session_file${NC}\n"

    # Convert JSONL to web events format
    jq -s '
        [.[] | select(.type == "user" or .type == "assistant") | select(.message != null)] |
        map({
            uuid: .uuid,
            session_id: .sessionId,
            type: .type,
            parent_tool_use_id: null,
            message: {
                role: .message.role,
                content: .message.content
            }
        })
    ' "$session_file"
}

# Main
main() {
    local cmd="${1:-help}"

    case "$cmd" in
        list)
            get_credentials
            list_sessions
            ;;
        get)
            get_credentials
            get_session "$2"
            ;;
        events)
            get_credentials
            get_events "$2"
            ;;
        send)
            get_credentials
            send_message "$2" "$3"
            ;;
        local)
            list_local
            ;;
        export)
            export_local "$2"
            ;;
        help|--help|-h)
            echo "Claude Code Sessions API"
            echo ""
            echo "Usage: $0 <command> [args]"
            echo ""
            echo "Commands:"
            echo "  list              List web sessions"
            echo "  get <id>          Get session details"
            echo "  events <id>       Get session events/messages"
            echo "  send <id> <msg>   Send message to session"
            echo "  local             List local CLI sessions"
            echo "  export <id>       Export local session to JSON"
            echo ""
            echo "Environment:"
            echo "  CLAUDE_CODE_OAUTH_TOKEN   OAuth access token"
            echo "  CLAUDE_ORG_UUID           Organization UUID"
            echo ""
            echo "Examples:"
            echo "  $0 list"
            echo "  $0 events session_011CUNPVCEo76Q5UFhpdUSfC"
            echo "  $0 send session_011CUNPVCEo76Q5UFhpdUSfC 'Continue with the task'"
            ;;
        *)
            echo -e "${RED}Unknown command: $cmd${NC}"
            echo "Run '$0 help' for usage"
            exit 1
            ;;
    esac
}

main "$@"
