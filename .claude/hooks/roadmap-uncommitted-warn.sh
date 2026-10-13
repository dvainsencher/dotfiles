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

# scrummy keeps one roadmap per project, in the primary checkout, and every worktree writes
# there (scrummy #74). So the changes to look for are in that checkout, not necessarily in
# this session's worktree. Same resolution as scrummy: SCRUMMY_ROOT, else the primary.
ROOT="${SCRUMMY_ROOT:-$(git worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')}"
[ -n "$ROOT" ] && [ -d "$ROOT/docs/roadmap" ] || exit 0

DIRTY=$(git -C "$ROOT" status --porcelain -- docs/roadmap ROADMAP.md 2>/dev/null)
[ -z "$DIRTY" ] && exit 0

{
  echo "Uncommitted scrummy roadmap changes are still in the roadmap checkout ($ROOT):"
  echo
  printf '%s\n' "$DIRTY" | sed 's/^/    /'
  echo
  echo "Commit them before finishing — left uncommitted they are easy to lose, and the next"
  echo "session in that checkout is blocked from switching branches until they land:"
  echo
  echo "    roadmap-commit"
  echo
  echo "(stages only docs/roadmap and ROADMAP.md there, commits, pulls --rebase, pushes to main;"
  echo "it refuses if that checkout is not on main — then tell the user instead.)"
  echo "If they were left by another session and are not yours, say so and stop."
} >&2

exit 2
