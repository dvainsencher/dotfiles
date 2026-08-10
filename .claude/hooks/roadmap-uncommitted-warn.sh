#!/usr/bin/env bash
# Stop hook: don't let a session go idle leaving scrummy roadmap edits uncommitted.
#
# Uncommitted roadmap state is what makes parallel sessions painful — another session in
# the same clone hits "your local changes would be overwritten by checkout" and is tempted
# to stash them away (see roadmap-stash-guard.sh). Committing at the end of a planning
# session removes the problem at the source.
#
# Blocks once, then gets out of the way: if Claude is already continuing because this hook
# blocked, stop_hook_active is true and we exit 0. Without that check a session that
# genuinely cannot commit would loop forever.
set -uo pipefail

INPUT=$(cat)

[ "$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ] && exit 0

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
[ -d "$(git rev-parse --show-toplevel 2>/dev/null)/docs/roadmap" ] || exit 0

DIRTY=$(git status --porcelain -- docs/roadmap ROADMAP.md 2>/dev/null)
[ -z "$DIRTY" ] && exit 0

{
  echo "Uncommitted scrummy roadmap changes are still in the working tree:"
  echo
  printf '%s\n' "$DIRTY" | sed 's/^/    /'
  echo
  echo "Commit them before finishing — another session in this clone will be blocked from"
  echo "switching branches until they land, and left uncommitted they are easy to lose:"
  echo
  echo "    git add docs/roadmap ROADMAP.md && git commit -m 'scrummy: backlog update'"
  echo
  echo "If they belong with code changes you are already committing, include them there."
  echo "If they were left by another session and are not yours, say so and stop."
} >&2

exit 2
