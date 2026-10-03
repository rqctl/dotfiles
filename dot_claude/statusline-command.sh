#!/usr/bin/env bash
# Claude Code status line — inspired by Powerlevel10k p10k.zsh segments:
# dir, vcs, context (user@host), gcloud, kubecontext, time, model

input=$(cat)

# Uncomment to debug: writes the raw JSON to /tmp for inspection
# echo "$input" > /tmp/statusline-debug.json

# --- Data extraction from Claude Code JSON ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
repo_owner=$(echo "$input" | jq -r '.workspace.repo.owner // empty')
repo_name=$(echo "$input" | jq -r '.workspace.repo.name // empty')
git_worktree=$(echo "$input" | jq -r '.workspace.git_worktree // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
session_id=$(echo "$input" | jq -r '.session_id // empty')

# --- Rate limits ---
session_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
session_resets_at=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
weekly_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
weekly_resets_at=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# --- Token counts ---
cur_input=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // empty')
cur_output=$(echo "$input" | jq -r '.context_window.current_usage.output_tokens // empty')
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // empty')

# Persist last-query cost: current_usage is non-zero while the model is working,
# then resets to 0 when the answer is delivered. Save it so we can display it at rest.
LAST_QUERY_FILE="/tmp/claude-statusline-last-query-tokens"
cur_total=0
[ -n "$cur_input" ] && cur_total=$(( cur_total + cur_input ))
[ -n "$cur_output" ] && cur_total=$(( cur_total + cur_output ))
if [ "$cur_total" -gt 0 ] 2>/dev/null; then
  echo "$cur_total" > "$LAST_QUERY_FILE"
fi
last_query_total=""
[ -f "$LAST_QUERY_FILE" ] && last_query_total=$(cat "$LAST_QUERY_FILE")

# Session token count: sum all assistant message usage in the current session JSONL.
# Cached for 10s — short enough to stay fresh during active work.
SESSION_CACHE_FILE="/tmp/claude-statusline-session-cache"
session_tokens=""
sess_cache_valid=0
if [ -n "$session_id" ] && [ -f "$SESSION_CACHE_FILE" ]; then
  read -r sc_sid sc_ts sc_val < "$SESSION_CACHE_FILE" 2>/dev/null
  now_ts=$(date +%s)
  [ "$sc_sid" = "$session_id" ] && [ $(( now_ts - sc_ts )) -lt 10 ] && sess_cache_valid=1
fi
if [ "$sess_cache_valid" = "1" ]; then
  session_tokens=$sc_val
elif [ -n "$session_id" ]; then
  session_tokens=$(python3 - "$session_id" <<'PYEOF' 2>/dev/null
import json, sys
from pathlib import Path
session_id = sys.argv[1]
total = 0
seen = set()
for f in Path.home().glob(f'.claude/projects/**/{session_id}.jsonl'):
    try:
        for line in open(f):
            try:
                obj = json.loads(line)
                if obj.get('type') != 'assistant': continue
                mid = obj.get('message', {}).get('id', '')
                if mid in seen: continue
                seen.add(mid)
                u = obj.get('message', {}).get('usage', {})
                total += u.get('input_tokens', 0) + u.get('output_tokens', 0)
                total += u.get('cache_creation_input_tokens', 0)
                total += u.get('cache_read_input_tokens', 0)
            except: pass
    except: pass
print(total)
PYEOF
  )
  echo "$session_id $(date +%s) ${session_tokens:-0}" > "$SESSION_CACHE_FILE"
fi

# Daily token count: sum all assistant message usage from today's project JSONL files.
# Cached for 30s in /tmp to avoid scanning on every statusline refresh.
DAILY_CACHE_FILE="/tmp/claude-statusline-daily-cache"
today=$(date +%Y-%m-%d)
daily_tokens=""
cache_valid=0
if [ -f "$DAILY_CACHE_FILE" ]; then
  read -r cache_date cache_ts cache_val < "$DAILY_CACHE_FILE" 2>/dev/null
  now_ts=$(date +%s)
  [ "$cache_date" = "$today" ] && [ $(( now_ts - cache_ts )) -lt 30 ] && cache_valid=1
fi
if [ "$cache_valid" = "1" ]; then
  daily_tokens=$cache_val
else
  daily_tokens=$(python3 - "$today" <<'PYEOF' 2>/dev/null
import json, sys
from pathlib import Path
today = sys.argv[1]
total = 0
seen = set()
for f in Path.home().glob('.claude/projects/**/*.jsonl'):
    try:
        for line in open(f):
            try:
                obj = json.loads(line)
                if obj.get('type') != 'assistant': continue
                if not obj.get('timestamp','').startswith(today): continue
                mid = obj.get('message', {}).get('id', '')
                if mid in seen: continue
                seen.add(mid)
                u = obj.get('message', {}).get('usage', {})
                total += u.get('input_tokens', 0) + u.get('output_tokens', 0)
                total += u.get('cache_creation_input_tokens', 0)
                total += u.get('cache_read_input_tokens', 0)
            except: pass
    except: pass
print(total)
PYEOF
  )
  echo "$today $(date +%s) ${daily_tokens:-0}" > "$DAILY_CACHE_FILE"
fi

# --- Helper: human-readable countdown from a Unix epoch ---
reset_countdown() {
  local resets_at="$1"
  [ -z "$resets_at" ] && return
  local now diff d h m
  now=$(date +%s)
  diff=$(( resets_at - now ))
  [ "$diff" -le 0 ] && echo "now" && return
  d=$(( diff / 86400 ))
  h=$(( (diff % 86400) / 3600 ))
  m=$(( (diff % 3600) / 60 ))
  if [ "$d" -gt 0 ]; then
    echo "${d}d${h}h"
  elif [ "$h" -gt 0 ]; then
    echo "${h}h${m}m"
  else
    echo "${m}m"
  fi
}

# --- Helper: format token count with k/M units ---
fmt_tokens() {
  local t="$1"
  [ -z "$t" ] && return
  if [ "$t" -ge 1000000 ] 2>/dev/null; then
    awk "BEGIN{printf \"%.1fM\", $t/1000000}"
  elif [ "$t" -ge 1000 ] 2>/dev/null; then
    awk "BEGIN{printf \"%.1fk\", $t/1000}"
  else
    echo "$t"
  fi
}

# --- Colors (ANSI, works in terminal with dimmed rendering) ---
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[36m'
YELLOW='\033[33m'
GREEN='\033[32m'
BLUE='\033[34m'
MAGENTA='\033[35m'
WHITE='\033[37m'

# --- user@host ---
user=$(whoami)
host=$(hostname -s)
printf "${DIM}${CYAN}%s@%s${RESET}" "$user" "$host"

# --- directory ---
if [ -n "$cwd" ]; then
  display_dir="${cwd/#$HOME/~}"
  printf " ${BOLD}${BLUE}%s${RESET}" "$display_dir"
fi

# --- git branch / repo ---
git_branch=""
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  git_branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null \
               || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
fi

if [ -n "$git_branch" ]; then
  printf " ${GREEN}(%s)${RESET}" "$git_branch"
fi

if [ -n "$repo_owner" ] && [ -n "$repo_name" ]; then
  printf " ${DIM}${WHITE}%s/%s${RESET}" "$repo_owner" "$repo_name"
fi

if [ -n "$git_worktree" ]; then
  printf " ${DIM}${MAGENTA}[worktree:%s]${RESET}" "$git_worktree"
fi

# --- model ---
if [ -n "$model" ]; then
  printf " ${DIM}${MAGENTA}[%s]${RESET}" "$model"
fi

# --- context window: ctx:45%-90.4k ---
ctx_t_total=0
[ -n "$total_input" ] && ctx_t_total=$(( ctx_t_total + total_input ))
[ -n "$total_output" ] && ctx_t_total=$(( ctx_t_total + total_output ))
if [ -n "$used_pct" ] && [ "$ctx_t_total" -gt 0 ] 2>/dev/null; then
  printf " ${DIM}ctx:%.0f%%-$(fmt_tokens "$ctx_t_total")${RESET}" "$used_pct"
elif [ -n "$used_pct" ]; then
  printf " ${DIM}ctx:%.0f%%${RESET}" "$used_pct"
fi

# --- session (5h) rate limit ---
if [ -n "$session_pct" ]; then
  session_cd=$(reset_countdown "$session_resets_at")
  if [ -n "$session_cd" ]; then
    printf " ${YELLOW}5h:%.0f%%%s${RESET}" "$session_pct" "(rst:${session_cd})"
  else
    printf " ${YELLOW}5h:%.0f%%${RESET}" "$session_pct"
  fi
fi

# --- weekly (7d) rate limit ---
if [ -n "$weekly_pct" ]; then
  weekly_cd=$(reset_countdown "$weekly_resets_at")
  if [ -n "$weekly_cd" ]; then
    printf " ${MAGENTA}7d:%.0f%%%s${RESET}" "$weekly_pct" "(rst:${weekly_cd})"
  else
    printf " ${MAGENTA}7d:%.0f%%${RESET}" "$weekly_pct"
  fi
fi

# --- last query tokens → session tokens → daily tokens ---
if [ -n "$last_query_total" ] && [ "$last_query_total" -gt 0 ] 2>/dev/null; then
  printf " ${DIM}last:$(fmt_tokens "$last_query_total")${RESET}"
fi


if [ -n "$session_tokens" ] && [ "$session_tokens" -gt 0 ] 2>/dev/null; then
  printf " ${DIM}sess:$(fmt_tokens "$session_tokens")${RESET}"
fi

if [ -n "$daily_tokens" ] && [ "$daily_tokens" -gt 0 ] 2>/dev/null; then
  printf " ${GREEN}day:$(fmt_tokens "$daily_tokens")${RESET}"
fi

# --- time ---
printf " ${DIM}%s${RESET}" "$(date +%H:%M:%S)"

printf "\n"
