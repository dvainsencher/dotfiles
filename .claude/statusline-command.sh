#!/usr/bin/env bash
# Claude Code status line — mirrors Starship-style prompt info
# Receives JSON on stdin from Claude Code

input=$(cat)

user=$(whoami)
host=$(hostname -s)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')

# Shorten home directory to ~
home="$HOME"
short_cwd="${cwd/#$home/\~}"

# Git branch from workspace (worktree branch takes precedence)
git_branch=$(echo "$input" | jq -r '.worktree.branch // .workspace.git_worktree // ""')
if [ -z "$git_branch" ]; then
  git_branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || true)
fi

model=$(echo "$input" | jq -r '.model.display_name // ""')

# pauta sprint status — requires docs/roadmap/issues.jsonl and pauta installed
# locally as a project dependency; call the local bin directly (not npx) so a
# missing install fails instantly instead of falling through to a registry lookup
pauta_status=""
pauta_bin="$cwd/node_modules/.bin/pauta"
if [ -f "$cwd/docs/roadmap/issues.jsonl" ] && [ -x "$pauta_bin" ]; then
  pauta_status=$( (cd "$cwd" && timeout 1 "$pauta_bin" status) 2>/dev/null )
fi

sess_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_d=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Build status line
printf "\033[0;33m%s@%s\033[0m \033[0;34m%s\033[0m" "$user" "$host" "$short_cwd"

if [ -n "$git_branch" ]; then
  printf " \033[0;35m %s\033[0m" "$git_branch"
fi

if [ -n "$model" ]; then
  printf " \033[0;36m%s\033[0m" "$model"
fi

if [ -n "$pauta_status" ] && [ "$pauta_status" != "no active sprint" ]; then
  printf " \033[0;32m%s\033[0m" "$pauta_status"
fi

if [ -n "$five_h" ]; then
  printf " \033[0;33m5h:%.0f%%\033[0m" "$five_h"
fi

if [ -n "$seven_d" ]; then
  printf " \033[0;33m7d:%.0f%%\033[0m" "$seven_d"
fi

if [ -n "$sess_pct" ]; then
  printf " \033[0;32msess:%.0f%%\033[0m" "$sess_pct"
fi

printf "\n"
