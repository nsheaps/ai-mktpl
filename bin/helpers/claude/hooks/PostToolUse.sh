#!/bin/bash

# Claude Code PostToolUse Hook
# Processes JSON input from stdin and closes telemetry spans
# Usage: Called automatically by Claude Code after tool execution

set -euo pipefail

### PostToolUse looks like
# {
#   "session_id": "df6b3953-ca48-4185-8023-f3bbe93b3d52",
#   "transcript_path": "/Users/nheaps/.claude/projects/-Users-nheaps-src-gather-town-v2/df6b3953-ca48-4185-8023-f3bbe93b3d52.jsonl",
#   "cwd": "/Users/nheaps/src/gather-town-v2",
#   "hook_event_name": "PostToolUse",
#   "tool_name": "WebSearch",
#   "tool_input": {
#     "query": "breaking news today July 22 2025 past 6 hours"
#   },
#   "tool_response": {
#     "query": "breaking news today July 22 2025 past 6 hours",
#     "results": [
#       {
#         "tool_use_id": "srvtoolu_01FzFMqJgjedA1Gaw6vPBMej",
#         "content": [
#           {
#             "title": "Palace suspends July 23 classes, gov’t work in Metro Manila, dozens of provinces | ABS-CBN News",
#             "url": "https://www.abs-cbn.com/news/weather-traffic/2025/7/22/-walangpasok-class-suspensions-on-wednesday-july-23-1344"
#           },
#           {
#             "title": "Class suspensions for Tuesday, July 22, 2025 | GMA News Online",
#             "url": "https://www.gmanetwork.com/news/serbisyopubliko/walangpasok/953290/class-suspensions-for-tuesday-july-22-2025/story/"
#           },
#           {
#             "title": "LIVE LIST: Flooded areas in Metro Manila on July 22 due to habagat | Philstar.com",
#             "url": "https://www.philstar.com/nation/2025/07/22/2459834/live-list-flooded-areas-metro-manila-july-22-due-habagat"
#           },
#           {
#             "title": "#WalangPasok: Classes, gov’t work suspended on Tuesday, July 22",
#             "url": "https://newsinfo.inquirer.net/2085026/walangpasok-classes-govt-work-suspended-on-tuesday-july-22"
#           },
#           {
#             "title": "Today's front page, Tuesday, July 22, 2025 Subscribe to the paper: https://philstarsubscribe.com/ Subscribe to our social media channels: Facebook: facebook.com/PhilippineSTAR X (Twitter): x.com/PhilippineStar Instagram: instagram.com/philippinestar TikTo",
#             "url": "https://www.facebook.com/PhilippineSTAR/posts/todays-front-page-tuesday-july-22-2025-subscribe-to-the-paper-httpsphilstarsubsc/1214151637415380/"
#           },
#           {
#             "title": "July 2, 2025 – PBS News Hour full episode | PBS News",
#             "url": "https://www.pbs.org/newshour/show/july-2-2025-pbs-news-hour-full-episode"
#           },
#           {
#             "title": "Department Press Briefing – July 2, 2025 - United States Department of State",
#             "url": "https://www.state.gov/briefings/department-press-briefing-july-2-2025/"
#           },
#           {
#             "title": "5 things to know for July 2: USAID, Ukraine munitions, Trump megabill, Climate change, Paramount settlement. | CNN",
#             "url": "https://www.cnn.com/2025/07/02/us/5-things-to-know-for-july-2-usaid-ukraine-munitions-trump-megabill-climate-change-paramount-settlement"
#           },
#           {
#             "title": "PBS News Hour | Season 2025 | July 2, 2025 - PBS News Hour full episode | PBS",
#             "url": "https://www.pbs.org/video/july-2-2025-pbs-news-hour-full-episode-1751428801/"
#           },
#           {
#             "title": "Headlines for July 02, 2025 | Democracy Now!",
#             "url": "https://www.democracynow.org/2025/7/2/headlines"
#           }
#         ]
#       },
#       "Based on the search results from July 22, 2025, here are the key breaking news stories from the past 6 hours:\n\n## Weather-Related Emergency in the Philippines\n\nMalacanang has suspended classes and government work in Metro Manila and dozens of provinces on July 23, Wednesday due to heavy rains from the southwest monsoon or habagat (reported 4 hours ago).\n\nParts of Metro Manila are experiencing floods on Tuesday, July 22, due to inclement weather caused by southwest monsoon (habagat.) The flooding has affected various areas throughout the capital region.\n\nClasses for Tuesday, July 22, 2025 have been suspended in some areas due to the weather, and all classes and government work are suspended on Tuesday, July 22, in Metro Manila and 10 other provinces, said the Department of the Interior and Local Government (DILG).\n\nThe search results show that the primary breaking news today relates to severe weather conditions in the Philippines, specifically heavy flooding caused by the southwest monsoon (habagat) affecting Metro Manila and surrounding provinces. This has prompted government authorities to suspend classes and work for public safety.\n\nThe other search results are from older dates (primarily July 2, 2025, which is 3 weeks ago) and don't fall within the requested timeframe of the past 6 hours on July 22, 2025."
#     ],
#     "durationSeconds": 14.627338750000003
#   }
# }

# Parse JSON input from stdin
INPUT=$(cat)

# Extract key fields for consistent hashing (same as PreToolUse)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
CWD=$(echo "$INPUT" | jq -r '.cwd // "unknown"')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')
DURATION=$(echo "$INPUT" | jq -r 'if .tool_response | type == "object" then .tool_response.durationSeconds // "unknown" else "unknown" end')

# Create consistent SHA based on session_id+cwd+tool_name+tool_input (matches PreToolUse)
HASH_DATA="${SESSION_ID}${CWD}${TOOL_NAME}${TOOL_INPUT}"
SOCKET_NAME=$(echo "$HASH_DATA" | sha256sum | cut -d' ' -f1 | cut -c1-10)

# Print parsed data and shasum
echo "=== PARSED DATA ===" >&2
echo "Session ID: $SESSION_ID" >&2
echo "Tool Name: $TOOL_NAME" >&2
echo "Tool Input: $TOOL_INPUT" >&2
echo "Tool Response Duration: ${DURATION}s" >&2
echo "CWD: $CWD" >&2
echo "=== SHASUM ===" >&2
echo "Hash SHA256 (10-char): $SOCKET_NAME" >&2
echo "=================" >&2

# Check if otel-cli is available
if ! command -v otel-cli >/dev/null 2>&1; then
    echo "otel-cli not available, skipping telemetry" >&2
    exit 0
fi
SOCKET_DIR="/tmp/otel-sockets/$SOCKET_NAME"

source "$SOCKET_DIR/data.env" || true
echo "Loaded span data from $SOCKET_DIR/data.env" >&2
echo "TOOL_NAME=\"$TOOL_NAME\"" >&2
echo "ATTRS=\"$ATTRS\"" >&2
echo "START_TIME=\"$START_TIME\"" >&2
END_TIME=$(date +%s.%N)
echo "END_TIME=\"$END_TIME\"" >&2
ELAPSED_TIME=$(echo "$END_TIME - $START_TIME" | bc)
echo "Elapsed Time: $ELAPSED_TIME seconds" >&2

# Close the span with completion status
# ref: https://github.com/equinix-labs/otel-cli
otel-cli span \
    --start "$START_TIME" \
    --end "$END_TIME" \
    --name "$TOOL_NAME" \
    --service "${OTEL_SERVICE_NAME:-claude-code}" \
    --attrs "tool.result=completed,$ATTRS" || true

echo "[TELEMETRY 👀] Closed telemetry span for tool: $TOOL_NAME" >&2
