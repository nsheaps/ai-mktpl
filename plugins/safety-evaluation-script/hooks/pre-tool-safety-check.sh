#!/bin/bash
#
# Pre-tool-call safety evaluation hook
# Uses Claude CLI with haiku model to evaluate the safety of tool calls
# before they are executed, providing an AI-powered safety layer.
#

set -euo pipefail

# Configuration
MODEL="${SAFETY_EVAL_MODEL:-claude-3-5-haiku-latest}"
TIMEOUT="${SAFETY_EVAL_TIMEOUT:-30}"
LOG_FILE="${SAFETY_EVAL_LOG:-}"

# System prompt for safety evaluation
SYSTEM_PROMPT='You are a security-focused AI assistant evaluating the safety of tool calls in a development environment.

Your task is to analyze tool calls and determine if they are safe to execute. Consider:

1. **Destructive Operations**: Does the command delete, overwrite, or modify critical files/systems?
2. **Data Exfiltration**: Could this leak sensitive data (credentials, API keys, personal info)?
3. **Network Security**: Does it make suspicious network calls or expose services?
4. **Privilege Escalation**: Does it attempt to gain elevated permissions?
5. **Code Injection**: Could it execute arbitrary or malicious code?
6. **Resource Abuse**: Could it consume excessive resources (fork bombs, infinite loops)?

IMPORTANT: Respond with ONLY a JSON object in this exact format:
{
  "decision": "allow" | "block",
  "reason": "Brief explanation of your decision",
  "risk_level": "low" | "medium" | "high" | "critical"
}

Be conservative but practical:
- Allow normal development operations (git, npm, file editing, etc.)
- Block obviously dangerous operations (rm -rf /, credential theft, etc.)
- For ambiguous cases, consider the development context

Do NOT include any text outside the JSON object.'

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Extract tool information
TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // "unknown"')
TOOL_INPUT=$(echo "$HOOK_INPUT" | jq -c '.tool_input // {}')

# Skip evaluation for read-only/safe tools to reduce latency
SAFE_TOOLS=("read" "glob" "grep" "websearch")
for safe_tool in "${SAFE_TOOLS[@]}"; do
    if [[ "${TOOL_NAME,,}" == "$safe_tool" ]]; then
        echo '{"decision":"allow","reason":"Read-only tool - automatically approved"}'
        exit 0
    fi
done

# Prepare the evaluation prompt
EVAL_PROMPT="Evaluate the safety of this tool call:

Tool: ${TOOL_NAME}
Input: ${TOOL_INPUT}

Analyze this operation and provide your safety assessment."

# Log the evaluation request if logging is enabled
if [[ -n "$LOG_FILE" ]]; then
    echo "[$(date -Iseconds)] Evaluating: ${TOOL_NAME}" >> "$LOG_FILE"
    echo "  Input: ${TOOL_INPUT}" >> "$LOG_FILE"
fi

# Call Claude CLI for safety evaluation
EVAL_RESULT=$(timeout "$TIMEOUT" claude --model "$MODEL" --system "$SYSTEM_PROMPT" --print --no-input "$EVAL_PROMPT" 2>/dev/null || echo '{"decision":"allow","reason":"Safety evaluation timed out or failed - allowing with caution","risk_level":"medium"}')

# Extract the JSON from the response (in case there's extra text)
JSON_RESULT=$(echo "$EVAL_RESULT" | grep -o '{[^}]*}' | head -1 || echo '{"decision":"allow","reason":"Could not parse evaluation response","risk_level":"medium"}')

# Validate and extract decision
DECISION=$(echo "$JSON_RESULT" | jq -r '.decision // "allow"')
REASON=$(echo "$JSON_RESULT" | jq -r '.reason // "No reason provided"')
RISK_LEVEL=$(echo "$JSON_RESULT" | jq -r '.risk_level // "unknown"')

# Log the result if logging is enabled
if [[ -n "$LOG_FILE" ]]; then
    echo "  Decision: ${DECISION} (risk: ${RISK_LEVEL})" >> "$LOG_FILE"
    echo "  Reason: ${REASON}" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
fi

# Return the hook response
if [[ "$DECISION" == "block" ]]; then
    echo "{\"decision\":\"block\",\"reason\":\"Safety evaluation blocked this operation: ${REASON} (Risk level: ${RISK_LEVEL})\"}"
else
    echo "{\"decision\":\"allow\"}"
fi

exit 0
