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

used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Build status line
printf "\033[0;33m%s@%s\033[0m \033[0;34m%s\033[0m" "$user" "$host" "$short_cwd"

if [ -n "$git_branch" ]; then
  printf " \033[0;35m %s\033[0m" "$git_branch"
fi

if [ -n "$model" ]; then
  printf " \033[0;36m%s\033[0m" "$model"
fi

if [ -n "$used_pct" ]; then
  printf " \033[0;32mctx:%.0f%%\033[0m" "$used_pct"
fi

printf "\n"
