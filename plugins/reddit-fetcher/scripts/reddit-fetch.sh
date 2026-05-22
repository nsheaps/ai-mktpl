#!/usr/bin/env bash
# reddit-fetch.sh — Fetch Reddit content via the public JSON API
# No authentication required. Outputs markdown formatted for LLM consumption.
#
# Usage: reddit-fetch.sh <subcommand> [args] [options]
#
# Subcommands:
#   subreddit <name>     List posts from a subreddit
#   post <url|id>        Fetch a post with comments
#   search <query>       Search Reddit
#   user <username>      Fetch a user's recent posts
#
# See --help for full options.

set -euo pipefail

# --- Configuration ---
# Read plugin name/version/repo from plugin.json so the UA stays current
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_PLUGIN_JSON="${_SCRIPT_DIR}/../.claude-plugin/plugin.json"
if [[ -f "$_PLUGIN_JSON" ]] && command -v jq >/dev/null 2>&1; then
  _PLUGIN_NAME="$(jq -r '.name' "$_PLUGIN_JSON")"
  _PLUGIN_VERSION="$(jq -r '.version' "$_PLUGIN_JSON")"
  _MARKETPLACE_URL="$(jq -r '.repository' "$_PLUGIN_JSON")"
else
  _PLUGIN_NAME="reddit-fetcher"
  _PLUGIN_VERSION="0.1.0"
  _MARKETPLACE_URL="https://github.com/nsheaps/ai-mktpl"
fi
_AGENT_NAME="${CLAUDE_AGENT_NAME:-${AGENT_NAME:-agent}}"
_AGENTS_REPO_URL="${AGENTS_REPO_URL:-}"
readonly USER_AGENT="agent:${_AGENT_NAME} (claude-code; interactive${_AGENTS_REPO_URL:+; +${_AGENTS_REPO_URL}}) ${_PLUGIN_NAME}@${_PLUGIN_VERSION} (claude-code-plugin; +${_MARKETPLACE_URL}/plugins/${_PLUGIN_NAME})"
readonly BASE_URL="https://www.reddit.com"
readonly MIN_REQUEST_GAP=6  # seconds between requests (Reddit rate limit for unauth)
readonly MAX_RETRIES=3
readonly MAX_COMMENT_DEPTH=3
readonly DEFAULT_LIMIT=15
readonly DEFAULT_SORT="hot"
readonly DEFAULT_TIME="month"
readonly MAX_POST_BODY=2000
readonly MAX_COMMENT_BODY=500

# Rate limiting state
LAST_REQUEST_TIME=0

# --- Helpers ---

die() {
  echo "Error: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: reddit-fetch.sh <subcommand> [args] [options]

Subcommands:
  subreddit <name>       List posts from a subreddit
  post <url>             Fetch a post with its comments
  search <query>         Search Reddit (or a specific subreddit)
  user <username>        Fetch a user's recent posts

Common options:
  --limit <n>            Number of results (default: 15, max: 100)
  --sort <type>          Sort: hot, new, top, rising, controversial (default: hot)
  --time <period>        Time filter for top/controversial: hour, day, week, month, year, all (default: month)
  --exclude-nsfw         Exclude NSFW posts (default: included)
  --after <cursor>       Pagination cursor — use the 'after' value from a previous response to fetch the next page
  --help                 Show this help

Subreddit-specific:
  reddit-fetch.sh subreddit ClaudeCode --sort top --time week --limit 5
  reddit-fetch.sh subreddit ClaudeCode --after t3_abc123  # next page

Post-specific:
  reddit-fetch.sh post "https://www.reddit.com/r/ClaudeCode/comments/abc123/title/"
  reddit-fetch.sh post "https://reddit.com/r/ClaudeCode/comments/abc123/"

Search-specific:
  --subreddit <name>     Restrict search to a subreddit
  reddit-fetch.sh search "claude code mcp" --subreddit ClaudeCode --limit 5
  reddit-fetch.sh search "claude code mcp" --after t3_abc123  # next page

User-specific:
  reddit-fetch.sh user someuser --limit 10 --sort new
  reddit-fetch.sh user someuser --after t3_abc123  # next page
EOF
  exit 0
}

check_deps() {
  command -v curl >/dev/null 2>&1 || die "curl is required but not installed"
  command -v jq >/dev/null 2>&1 || die "jq is required but not installed"
}

rate_limit() {
  local now
  now=$(date +%s)
  local elapsed=$(( now - LAST_REQUEST_TIME ))
  if (( elapsed < MIN_REQUEST_GAP )); then
    local wait=$(( MIN_REQUEST_GAP - elapsed ))
    sleep "$wait"
  fi
  LAST_REQUEST_TIME=$(date +%s)
}

# Fetch a URL with retries and rate limiting
fetch_json() {
  local url="$1"
  local attempt=0
  local response

  while (( attempt < MAX_RETRIES )); do
    rate_limit
    attempt=$(( attempt + 1 ))

    local http_code
    local tmp_file
    tmp_file=$(mktemp)

    http_code=$(curl -s -o "$tmp_file" -w '%{http_code}' \
      -H "User-Agent: ${USER_AGENT}" \
      -L "$url" 2>&1) || {
        rm -f "$tmp_file"
        if (( attempt >= MAX_RETRIES )); then
          die "Network error fetching $url after $MAX_RETRIES attempts"
        fi
        sleep 2
        continue
      }

    case "$http_code" in
      200)
        cat "$tmp_file"
        rm -f "$tmp_file"
        return 0
        ;;
      429)
        rm -f "$tmp_file"
        echo "Rate limited (429), waiting before retry ($attempt/$MAX_RETRIES)..." >&2
        sleep $(( MIN_REQUEST_GAP * attempt ))
        ;;
      403)
        rm -f "$tmp_file"
        die "Forbidden (403). Reddit may be blocking this request. Check user-agent or try later."
        ;;
      404)
        rm -f "$tmp_file"
        die "Not found (404). The subreddit, post, or user does not exist: $url"
        ;;
      503)
        rm -f "$tmp_file"
        echo "Reddit unavailable (503), retrying ($attempt/$MAX_RETRIES)..." >&2
        sleep $(( 2 * attempt ))
        ;;
      *)
        rm -f "$tmp_file"
        die "HTTP $http_code fetching $url"
        ;;
    esac
  done

  die "Failed to fetch $url after $MAX_RETRIES attempts"
}

# Truncate text to max length
truncate_text() {
  local text="$1"
  local max="$2"
  if (( ${#text} > max )); then
    echo "${text:0:$max}... [truncated]"
  else
    echo "$text"
  fi
}

# Validate and clamp --limit: must be a positive integer, capped at 100
validate_limit() {
  local limit="$1"
  [[ "$limit" =~ ^[0-9]+$ ]] || die "--limit must be a positive integer, got: $limit"
  limit=$(( 10#$limit ))  # normalize to base-10, avoids octal trap on leading zeros
  (( limit < 1 )) && die "--limit must be at least 1"
  (( limit > 100 )) && limit=100
  echo "$limit"
}

# Format epoch timestamp to readable date
format_date() {
  local epoch="$1"
  # Remove decimal portion if present
  epoch="${epoch%%.*}"
  date -d "@${epoch}" '+%Y-%m-%d %H:%M UTC' 2>/dev/null || date -r "${epoch}" '+%Y-%m-%d %H:%M UTC' 2>/dev/null || echo "unknown"
}

# --- Formatters ---

format_post_listing() {
  local json="$1"
  local subreddit_name="$2"
  local sort_type="$3"
  local exclude_nsfw="$4"

  local filter='.data.children[]'
  if [[ "$exclude_nsfw" == "true" ]]; then
    filter="${filter} | select(.data.over_18 != true)"
  fi

  local count
  count=$(echo "$json" | jq "[${filter}] | length")
  if (( count == 0 )); then
    echo "No posts found."
    return
  fi

  local after_cursor
  after_cursor=$(echo "$json" | jq -r '.data.after // ""')

  echo "# r/${subreddit_name} - ${sort_type} Posts"
  echo ""

  local i=1
  while IFS= read -r post; do
    local title author score num_comments created_utc permalink is_self selftext url_link
    title=$(echo "$post" | jq -r '.data.title')
    author=$(echo "$post" | jq -r '.data.author')
    score=$(echo "$post" | jq -r '.data.score')
    num_comments=$(echo "$post" | jq -r '.data.num_comments')
    created_utc=$(echo "$post" | jq -r '.data.created_utc')
    permalink=$(echo "$post" | jq -r '.data.permalink')
    is_self=$(echo "$post" | jq -r '.data.is_self')
    selftext=$(echo "$post" | jq -r '.data.selftext // ""')
    url_link=$(echo "$post" | jq -r '.data.url // ""')

    local date_str
    date_str=$(format_date "$created_utc")
    local post_type="link"
    [[ "$is_self" == "true" ]] && post_type="self"

    echo "## ${i}. ${title} (Score: ${score}, Comments: ${num_comments})"
    echo "**Author**: u/${author} | **Posted**: ${date_str} | **Type**: ${post_type}"
    echo "**Link**: ${BASE_URL}${permalink}"

    if [[ "$post_type" == "link" && -n "$url_link" ]]; then
      echo "**URL**: ${url_link}"
    fi

    if [[ -n "$selftext" && "$selftext" != "null" ]]; then
      echo ""
      truncate_text "$selftext" "$MAX_POST_BODY"
    fi

    echo ""
    echo "---"
    echo ""
    i=$(( i + 1 ))
  done < <(echo "$json" | jq -c "[${filter}][]")

  if [[ -n "$after_cursor" ]]; then
    echo "_Next page: \`reddit-fetch.sh subreddit ${subreddit_name} --after ${after_cursor}\`_"
  fi
}

format_search_results() {
  local json="$1"
  local query="$2"
  local exclude_nsfw="$3"

  local filter='.data.children[]'
  if [[ "$exclude_nsfw" == "true" ]]; then
    filter="${filter} | select(.data.over_18 != true)"
  fi

  local count
  count=$(echo "$json" | jq "[${filter}] | length")
  if (( count == 0 )); then
    echo "No results found for: ${query}"
    return
  fi

  local after_cursor
  after_cursor=$(echo "$json" | jq -r '.data.after // ""')

  echo "# Reddit Search: \"${query}\""
  echo ""

  local i=1
  while IFS= read -r post; do
    local title author score num_comments subreddit created_utc permalink selftext
    title=$(echo "$post" | jq -r '.data.title')
    author=$(echo "$post" | jq -r '.data.author')
    score=$(echo "$post" | jq -r '.data.score')
    num_comments=$(echo "$post" | jq -r '.data.num_comments')
    subreddit=$(echo "$post" | jq -r '.data.subreddit')
    created_utc=$(echo "$post" | jq -r '.data.created_utc')
    permalink=$(echo "$post" | jq -r '.data.permalink')
    selftext=$(echo "$post" | jq -r '.data.selftext // ""')

    local date_str
    date_str=$(format_date "$created_utc")

    echo "## ${i}. ${title} (Score: ${score}, Comments: ${num_comments})"
    echo "**Subreddit**: r/${subreddit} | **Author**: u/${author} | **Posted**: ${date_str}"
    echo "**Link**: ${BASE_URL}${permalink}"

    if [[ -n "$selftext" && "$selftext" != "null" ]]; then
      echo ""
      truncate_text "$selftext" "$MAX_POST_BODY"
    fi

    echo ""
    echo "---"
    echo ""
    i=$(( i + 1 ))
  done < <(echo "$json" | jq -c "[${filter}][]")

  if [[ -n "$after_cursor" ]]; then
    echo "_Next page: \`reddit-fetch.sh search \"${query}\" --after ${after_cursor}\`_"
  fi
}

format_comments() {
  local json="$1"
  local depth="$2"

  if (( depth > MAX_COMMENT_DEPTH )); then
    return
  fi

  local blockquote=""
  for (( d=0; d<depth; d++ )); do
    blockquote="${blockquote}> "
  done

  while IFS= read -r comment; do
    local kind
    kind=$(echo "$comment" | jq -r '.kind // ""')
    [[ "$kind" != "t1" ]] && continue

    local author body score created_utc
    author=$(echo "$comment" | jq -r '.data.author // "[deleted]"')
    body=$(echo "$comment" | jq -r '.data.body // ""')
    score=$(echo "$comment" | jq -r '.data.score // 0')
    created_utc=$(echo "$comment" | jq -r '.data.created_utc // 0')

    [[ "$author" == "[deleted]" && ( -z "$body" || "$body" == "[deleted]" || "$body" == "[removed]" ) ]] && continue

    local date_str
    date_str=$(format_date "$created_utc")
    local truncated_body
    truncated_body=$(truncate_text "$body" "$MAX_COMMENT_BODY")

    echo "${blockquote}### u/${author} (Score: ${score}) - ${date_str}"
    # Indent the body with blockquote prefix
    while IFS= read -r line; do
      echo "${blockquote}${line}"
    done <<< "$truncated_body"
    echo ""

    # Process replies recursively
    local replies
    replies=$(echo "$comment" | jq -c '.data.replies // ""')
    if [[ -n "$replies" && "$replies" != '""' && "$replies" != "null" ]]; then
      while IFS= read -r child; do
        [[ -z "$child" ]] && continue
        format_comments "[$child]" $(( depth + 1 ))
      done < <(echo "$replies" | jq -c '.data.children[]?')
    fi
  done < <(echo "$json" | jq -c '.[]?')
}

format_post_with_comments() {
  local json="$1"
  local exclude_nsfw="$2"

  # Post is the first listing, comments are the second
  local post_data comment_data
  post_data=$(echo "$json" | jq '.[0].data.children[0].data')
  comment_data=$(echo "$json" | jq '.[1].data.children')

  local title author score num_comments created_utc subreddit permalink selftext is_nsfw
  title=$(echo "$post_data" | jq -r '.title')
  author=$(echo "$post_data" | jq -r '.author')
  score=$(echo "$post_data" | jq -r '.score')
  num_comments=$(echo "$post_data" | jq -r '.num_comments')
  created_utc=$(echo "$post_data" | jq -r '.created_utc')
  subreddit=$(echo "$post_data" | jq -r '.subreddit')
  permalink=$(echo "$post_data" | jq -r '.permalink')
  selftext=$(echo "$post_data" | jq -r '.selftext // ""')
  is_nsfw=$(echo "$post_data" | jq -r '.over_18 // false')

  if [[ "$is_nsfw" == "true" && "$exclude_nsfw" == "true" ]]; then
    echo "This post is marked NSFW. Remove --exclude-nsfw to view."
    return
  fi

  local date_str
  date_str=$(format_date "$created_utc")

  echo "# ${title}"
  echo "**Author**: u/${author} | **Score**: ${score} | **Posted**: ${date_str}"
  echo "**Subreddit**: r/${subreddit} | **Comments**: ${num_comments}"
  echo "**Link**: ${BASE_URL}${permalink}"
  echo ""

  if [[ -n "$selftext" && "$selftext" != "null" ]]; then
    truncate_text "$selftext" "$MAX_POST_BODY"
    echo ""
  fi

  echo "---"
  echo ""

  local shown_comments
  shown_comments=$(echo "$comment_data" | jq '[.[] | select(.kind == "t1")] | length')
  echo "## Comments (${num_comments} total, showing ${shown_comments})"
  echo ""

  format_comments "$comment_data" 0
}

format_user_posts() {
  local json="$1"
  local username="$2"
  local exclude_nsfw="$3"

  local filter='.data.children[] | select(.kind == "t3")'
  if [[ "$exclude_nsfw" == "true" ]]; then
    filter="${filter} | select(.data.over_18 != true)"
  fi

  local count
  count=$(echo "$json" | jq "[${filter}] | length")

  local after_cursor
  after_cursor=$(echo "$json" | jq -r '.data.after // ""')

  echo "# Posts by u/${username}"
  echo ""

  if (( count == 0 )); then
    echo "No posts found for this user."
    return
  fi

  local i=1
  while IFS= read -r post; do
    local title subreddit score num_comments created_utc permalink
    title=$(echo "$post" | jq -r '.data.title')
    subreddit=$(echo "$post" | jq -r '.data.subreddit')
    score=$(echo "$post" | jq -r '.data.score')
    num_comments=$(echo "$post" | jq -r '.data.num_comments')
    created_utc=$(echo "$post" | jq -r '.data.created_utc')
    permalink=$(echo "$post" | jq -r '.data.permalink')

    local date_str
    date_str=$(format_date "$created_utc")

    echo "## ${i}. ${title} (Score: ${score}, Comments: ${num_comments})"
    echo "**Subreddit**: r/${subreddit} | **Posted**: ${date_str}"
    echo "**Link**: ${BASE_URL}${permalink}"
    echo ""
    echo "---"
    echo ""
    i=$(( i + 1 ))
  done < <(echo "$json" | jq -c "[${filter}][]")

  if [[ -n "$after_cursor" ]]; then
    echo "_Next page: \`reddit-fetch.sh user ${username} --after ${after_cursor}\`_"
  fi
}

# --- Subcommands ---

cmd_subreddit() {
  local name=""
  local sort="$DEFAULT_SORT"
  local time="$DEFAULT_TIME"
  local limit="$DEFAULT_LIMIT"
  local exclude_nsfw="false"
  local after=""

  while (( $# > 0 )); do
    case "$1" in
      --sort) sort="$2"; shift 2 ;;
      --time) time="$2"; shift 2 ;;
      --limit) limit="$2"; shift 2 ;;
      --exclude-nsfw) exclude_nsfw="true"; shift ;;
      --after) after="$2"; shift 2 ;;
      --help) usage ;;
      -*) die "Unknown option: $1" ;;
      *) name="$1"; shift ;;
    esac
  done

  [[ -z "$name" ]] && die "Subreddit name is required. Usage: reddit-fetch.sh subreddit <name>"
  limit=$(validate_limit "$limit")

  local url="${BASE_URL}/r/${name}/${sort}.json?limit=${limit}&raw_json=1"
  [[ -n "$time" ]] && url="${url}&t=${time}"
  [[ -n "$after" ]] && url="${url}&after=${after}"

  local json
  json=$(fetch_json "$url")
  format_post_listing "$json" "$name" "$sort" "$exclude_nsfw"
}

cmd_post() {
  local post_url=""
  local exclude_nsfw="false"

  while (( $# > 0 )); do
    case "$1" in
      --exclude-nsfw) exclude_nsfw="true"; shift ;;
      --help) usage ;;
      -*) die "Unknown option: $1" ;;
      *) post_url="$1"; shift ;;
    esac
  done

  [[ -z "$post_url" ]] && die "Post URL is required. Usage: reddit-fetch.sh post <url>"

  # Normalize the URL: strip trailing slash, ensure .json suffix
  post_url="${post_url%/}"

  # Extract the path from a full URL or use as-is if it's already a path
  local path
  if [[ "$post_url" =~ ^https?:// ]]; then
    # Extract path from full URL, removing domain
    path=$(echo "$post_url" | sed -E 's|^https?://[^/]+||')
  else
    path="$post_url"
  fi

  # Remove existing .json suffix if present
  path="${path%.json}"

  local url="${BASE_URL}${path}.json?raw_json=1&limit=50"

  local json
  json=$(fetch_json "$url")
  format_post_with_comments "$json" "$exclude_nsfw"
}

cmd_search() {
  local query=""
  local subreddit=""
  local sort="$DEFAULT_SORT"
  local time="$DEFAULT_TIME"
  local limit="$DEFAULT_LIMIT"
  local exclude_nsfw="false"
  local after=""

  while (( $# > 0 )); do
    case "$1" in
      --subreddit) subreddit="$2"; shift 2 ;;
      --sort) sort="$2"; shift 2 ;;
      --time) time="$2"; shift 2 ;;
      --limit) limit="$2"; shift 2 ;;
      --exclude-nsfw) exclude_nsfw="true"; shift ;;
      --after) after="$2"; shift 2 ;;
      --help) usage ;;
      -*) die "Unknown option: $1" ;;
      *) query="$1"; shift ;;
    esac
  done

  [[ -z "$query" ]] && die "Search query is required. Usage: reddit-fetch.sh search <query>"
  limit=$(validate_limit "$limit")

  local encoded_query
  encoded_query=$(printf '%s' "$query" | jq -sRr @uri)

  local url
  if [[ -n "$subreddit" ]]; then
    url="${BASE_URL}/r/${subreddit}/search.json?q=${encoded_query}&restrict_sr=1&sort=${sort}&limit=${limit}&raw_json=1"
  else
    url="${BASE_URL}/search.json?q=${encoded_query}&sort=${sort}&limit=${limit}&raw_json=1"
  fi
  [[ -n "$time" ]] && url="${url}&t=${time}"
  [[ -n "$after" ]] && url="${url}&after=${after}"

  local json
  json=$(fetch_json "$url")
  format_search_results "$json" "$query" "$exclude_nsfw"
}

cmd_user() {
  local username=""
  local sort="new"
  local limit="$DEFAULT_LIMIT"
  local exclude_nsfw="false"
  local after=""

  while (( $# > 0 )); do
    case "$1" in
      --sort) sort="$2"; shift 2 ;;
      --limit) limit="$2"; shift 2 ;;
      --exclude-nsfw) exclude_nsfw="true"; shift ;;
      --after) after="$2"; shift 2 ;;
      --help) usage ;;
      -*) die "Unknown option: $1" ;;
      *) username="$1"; shift ;;
    esac
  done

  [[ -z "$username" ]] && die "Username is required. Usage: reddit-fetch.sh user <username>"
  limit=$(validate_limit "$limit")

  local url="${BASE_URL}/user/${username}/submitted.json?sort=${sort}&limit=${limit}&raw_json=1"
  [[ -n "$after" ]] && url="${url}&after=${after}"

  local json
  json=$(fetch_json "$url")
  format_user_posts "$json" "$username" "$exclude_nsfw"
}

# --- Main ---

main() {
  check_deps

  if (( $# == 0 )); then
    usage
  fi

  local subcommand="$1"
  shift

  case "$subcommand" in
    subreddit) cmd_subreddit "$@" ;;
    post) cmd_post "$@" ;;
    search) cmd_search "$@" ;;
    user) cmd_user "$@" ;;
    --help|-h|help) usage ;;
    *) die "Unknown subcommand: $subcommand. Use --help for usage." ;;
  esac
}

main "$@"
