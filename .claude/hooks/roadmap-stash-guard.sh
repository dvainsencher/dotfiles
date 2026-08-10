#!/usr/bin/env bash
# Block commands that would discard or bury uncommitted scrummy roadmap changes.
#
# Why: a planning session leaves roadmap edits uncommitted. An execution session in the
# same clone tries to switch branches, git refuses ("your local changes would be
# overwritten by checkout" — usually naming the generated ROADMAP.md, which differs on
# every branch), and the agent clears the way with `git stash`. The planning work is now
# in a stash nobody will look at.
#
# `git stash` is recoverable in principle and invisible in practice, which is the worst
# combination. `git checkout -f` and `git restore` are outright destructive. Both get
# stopped here while roadmap files are dirty; committing is the way through.
#
# Only fires in repos that actually use scrummy (docs/roadmap/ present) and only when
# those files are dirty, so it is silent everywhere else.
set -uo pipefail

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
[ -d "$(git rev-parse --show-toplevel 2>/dev/null)/docs/roadmap" ] || exit 0

# Uncommitted roadmap state, tracked or not. ROADMAP.md is generated but still tracked,
# and it is the file that usually triggers the checkout refusal in the first place.
DIRTY=$(git status --porcelain -- docs/roadmap ROADMAP.md 2>/dev/null)
[ -z "$DIRTY" ] && exit 0

# `git stash list/show/pop/apply/drop/branch` are read-only or restorative — only the
# push forms (bare `git stash`, `git stash push`, `git stash save`) hide working state.
is_stash_push() {
  printf '%s' "$1" | grep -Eq '(^|[;&|]|\s)git\s+stash\s*($|[;&|])' && return 0
  printf '%s' "$1" | grep -Eq '(^|[;&|]|\s)git\s+stash\s+(push|save|-)' && return 0
  return 1
}

# Force-checkout / force-switch / restore overwrite the working tree outright.
is_forced_discard() {
  printf '%s' "$1" | grep -Eq '(^|[;&|]|\s)git\s+(checkout|switch)\s+.*(-f|--force)(\s|$)' && return 0
  printf '%s' "$1" | grep -Eq '(^|[;&|]|\s)git\s+restore(\s|$)' && return 0
  printf '%s' "$1" | grep -Eq '(^|[;&|]|\s)git\s+checkout\s+--\s' && return 0
  return 1
}

REASON=""
if is_stash_push "$COMMAND"; then
  REASON="stash away"
elif is_forced_discard "$COMMAND"; then
  REASON="discard"
fi
[ -z "$REASON" ] && exit 0

{
  echo "BLOCKED: this would $REASON uncommitted scrummy roadmap changes:"
  echo
  printf '%s\n' "$DIRTY" | sed 's/^/    /'
  echo
  echo "These are backlog edits from a planning session, and a stash is somewhere no one"
  echo "looks. Commit them instead — they are their own coherent change:"
  echo
  echo "    git add docs/roadmap ROADMAP.md && git commit -m 'scrummy: backlog update'"
  echo
  echo "If ROADMAP.md alone is blocking a branch switch, it is generated — commit it, or"
  echo "regenerate it after switching with 'scrummy roadmap'."
} >&2

exit 2
