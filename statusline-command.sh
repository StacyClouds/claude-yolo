#!/usr/bin/env bash
# Claude Code status line
# Shows: model | ctx% | git branch | cwd (basename)
# Uses Hack Nerd Font glyphs and ANSI colors

input=$(cat)

# ANSI color helpers (reset at end of each segment)
reset='\033[0m'
cyan='\033[36m'
yellow='\033[33m'
magenta='\033[35m'
blue='\033[34m'

# Nerd Font glyphs (literal UTF-8 characters — avoids \uXXXX expansion issues)
glyph_model='󰚩'   # nf-md-robot
glyph_acct='󰄪'    # nf-md-chart_line — account-wide usage
glyph_ctx='󰈙'     # nf-md-file-document — main chat context usage
glyph_branch='󰘬'  # nf-md-source_branch
glyph_folder='󰝰'  # nf-md-folder_open

# Model: strip "Claude " prefix to get e.g. "Sonnet 4.6"
model=$(echo "$input" | jq -r '.model.display_name // empty' | sed 's/^[Cc]laude //;s/^claude //')

# Account-wide usage percentage (5-hour rate limit window, shared across sessions)
acct_used=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
if [ -n "$acct_used" ]; then
  acct_val="$(printf '%.0f' "$acct_used")%"
else
  acct_val="-%"
fi

# Main chat (this session's) context window usage percentage
ctx_used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$ctx_used" ]; then
  ctx_val="$(printf '%.0f' "$ctx_used")%"
else
  ctx_val="-%"
fi

# Countdown to the 5-hour rate limit reset, e.g. "2h15m"
RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
RESET_FMT=""
if [ -n "$RESET" ] && [ "$RESET" != "null" ]; then
  now_epoch=$(date +%s)
  diff=$(( RESET - now_epoch ))
  if [ "$diff" -lt 0 ]; then
    diff=0
  fi
  RESET_FMT=$(printf '%dh%02dm' "$(( diff / 3600 ))" "$(( (diff % 3600) / 60 ))")
fi

# CWD from session data
cwd_full=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')

# Git branch (skip optional locks to avoid contention)
branch=""
if [ -n "$cwd_full" ]; then
  branch=$(git -C "$cwd_full" --no-optional-locks branch --show-current 2>/dev/null)
fi

# CWD basename
cwd_base=$(basename "$cwd_full")

# Assemble with colored glyphs, sections separated by two spaces
out=""
[ -n "$model" ]    && out="$(printf "${cyan}${glyph_model}${reset} ${cyan}%s${reset}" "$model")"
[ -n "$acct_val" ] && out="${out}  $(printf "${yellow}${glyph_acct}${reset} ${yellow}%s${reset}" "$acct_val")"
[ -n "$RESET_FMT" ]  && out="${out}  $(printf "${yellow}⏰${reset} ${yellow}%s${reset}" "$RESET_FMT")"
[ -n "$ctx_val" ]  && out="${out}  $(printf "${cyan}${glyph_ctx}${reset} ${cyan}%s${reset}" "$ctx_val")"
[ -n "$branch" ]   && out="${out}  $(printf "${magenta}${glyph_branch}${reset} ${magenta}%s${reset}" "$branch")"
[ -n "$cwd_base" ] && out="${out}  $(printf "${blue}${glyph_folder}${reset} ${blue}%s${reset}" "$cwd_base")"

printf "%b" "$out"
