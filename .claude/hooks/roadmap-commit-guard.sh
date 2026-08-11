#!/usr/bin/env bash
# Block `git commit` from landing an *unrelated* scrummy roadmap change on the wrong
# branch — but let a branch sync its own issue's status/log, which belongs there.
#
# Why: scrummy itself never touches git (a prior version that did caused a real
# cross-project incident — an auto-merge onto a consuming project's main — and was
# reverted). That leaves the calling agent responsible for keeping *unrelated* roadmap
# commits on main. Without a mechanical check, a `scrummy add-issue`/`spec`/`move` call
# made while some unrelated feature branch happens to be checked out lands the roadmap
# files there instead — and the next broad `git add` on that branch can silently sweep
# them into an unrelated commit and push it. This happened for real on 2026-08-11
# (easy-nf issue #327 landed inside a feat/284 fiscal-docs commit and had to be reverted).
#
# But NOT every dirty docs/roadmap file on a feature branch is that failure mode.
# CLAUDE.md's "Roadmap sync" rule explicitly wants `scrummy set-status <id> done` (and
# similarly `log-issue` checkpoints) committed *with* the feature branch that closes it,
# so the roadmap update merges together with the code via the normal PR flow — that is
# correct, not the bug. The distinguishing signal isn't "is docs/roadmap dirty on a
# non-main branch" but "does the dirty issue belong to THIS branch": branches in this
# repo are named `<prefix>/<id>-description` (feat/284-..., fix/323-...), so a dirty
# `docs/roadmap/issues/<id>.json` (or its spec/progress files) whose id matches the
# branch's own id is this branch syncing its own status — allowed. A dirty file for any
# OTHER id (most obviously a brand-new issue, whose id can never match — ids are
# monotonic, see scrummy's docs/architecture.md) is unrelated backlog bookkeeping and
# still needs the worktree path.
#
# The fix for anything this doesn't wave through is EnterWorktree (fresh off
# origin/main) before the scrummy mutation, then `git push origin <branch>:main` — see
# CLAUDE.md's Roadmap section. This hook is the mechanical backstop for when that
# workflow isn't followed for an unrelated item: it blocks the `git commit` itself, at
# the moment it would actually happen, rather than relying on the instruction being
# remembered.
#
# Only fires in repos that actually use scrummy (docs/roadmap/ present), only when
# those paths are dirty, and only when no escape hatch applies: main/master directly,
# inside a `.claude/worktrees/` worktree (EnterWorktree's own isolation — see
# roadmap-stash-guard.sh for the sibling check that protects that state from being
# stashed away instead of committed), or every dirty roadmap id matching this branch's
# own id.
set -uo pipefail

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null)
[ -d "$TOPLEVEL/docs/roadmap" ] || exit 0

# Only a `git commit` invocation is in scope — reads/status/diff are never blocked.
printf '%s' "$COMMAND" | grep -Eq '(^|[;&|]|\s)git\s+commit(\s|$)' || exit 0

# Escape hatch 1: inside an EnterWorktree-created worktree — that's the isolation
# mechanism itself, always fine regardless of its (non-"main") branch name.
case "$TOPLEVEL" in
  */.claude/worktrees/*) exit 0 ;;
esac

# Escape hatch 2: committing directly on main/master.
BRANCH=$(git branch --show-current 2>/dev/null)
[ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ] && exit 0

# Roadmap state dirty (staged or not — `git commit -a`/`-am` picks up unstaged tracked
# changes too, so this deliberately doesn't restrict to `--cached` only).
DIRTY=$(git status --porcelain -- docs/roadmap ROADMAP.md 2>/dev/null)
[ -z "$DIRTY" ] && exit 0

# Escape hatch 3: every dirty roadmap file belongs to the id this branch is named for.
# Extract the id straight from `<prefix>/<id>-...`; if the branch doesn't follow that
# convention, BRANCH_ID is empty and this hatch simply doesn't open (falls through to
# blocking, the safe default — a false block just costs a worktree detour, a false
# allow would silently repeat the original bug).
BRANCH_ID=$(printf '%s' "$BRANCH" | grep -oE '^[a-zA-Z]+/[0-9]+' | grep -oE '[0-9]+$')
DIRTY_IDS=$(printf '%s\n' "$DIRTY" | grep -oE '/[0-9]+\.[A-Za-z0-9]+$' | grep -oE '[0-9]+' | sort -u)

if [ -n "$BRANCH_ID" ]; then
  if [ -z "$DIRTY_IDS" ]; then
    exit 0  # only ROADMAP.md or a non-issue-numbered path is dirty — low risk, allow
  fi
  OTHER_IDS=$(printf '%s\n' "$DIRTY_IDS" | grep -v -x "$BRANCH_ID")
  [ -z "$OTHER_IDS" ] && exit 0  # every dirty id is this branch's own issue — allow
fi

{
  echo "BLOCKED: this commit would land scrummy roadmap changes on branch '$BRANCH',"
  echo "not main, for an issue that doesn't match this branch's own id:"
  echo
  printf '%s\n' "$DIRTY" | sed 's/^/    /'
  echo
  if [ -n "$BRANCH_ID" ]; then
    echo "This branch is issue #$BRANCH_ID's own — syncing status/log for #$BRANCH_ID"
    echo "here is fine and expected. The files above reference a different id, which"
    echo "reads as unrelated backlog bookkeeping riding along on this branch."
  else
    echo "Couldn't determine an issue id from branch '$BRANCH' (expected <prefix>/<id>-...,"
    echo "e.g. feat/284-...) to confirm these files belong to this branch's own work."
  fi
  echo
  echo "Unrelated roadmap bookkeeping belongs on main, isolated from feature branches —"
  echo "otherwise it can get swept into that branch's next unrelated commit and pushed"
  echo "bundled with it (this happened for real: easy-nf #327). Use an isolated worktree:"
  echo
  echo "    EnterWorktree (fresh off origin/main)"
  echo "    <scrummy commands + spec editing there>"
  echo "    git commit -m 'chore(roadmap): ...'"
  echo "    git push origin <worktree-branch>:main"
  echo "    ExitWorktree"
  echo
  echo "See CLAUDE.md's Sprint Workflow section for the full sequence."
} >&2

exit 2
