#!/usr/bin/env bash
# Block `git commit` from landing scrummy roadmap changes on the wrong branch.
#
# Why: scrummy itself never touches git (a prior version that did caused a real
# cross-project incident — an auto-merge onto a consuming project's main — and was
# reverted). That leaves the calling agent responsible for keeping roadmap commits on
# main. Without a mechanical check, a `scrummy add-issue`/`spec`/`move` call made while
# some unrelated feature branch happens to be checked out lands the roadmap files there
# instead — and the next broad `git add` on that branch can silently sweep them into an
# unrelated commit and push it. This happened for real on 2026-08-11 (easy-nf issue
# #327 landed inside a feat/284 fiscal-docs commit and had to be reverted).
#
# The fix is EnterWorktree (fresh off origin/main) before any scrummy mutation, then
# `git push origin <worktree-branch>:main` — see CLAUDE.md's Roadmap section. This hook
# is the mechanical backstop for when that workflow isn't followed: it blocks the
# `git commit` itself, at the moment it would actually happen, rather than relying on
# the instruction being remembered.
#
# Only fires in repos that actually use scrummy (docs/roadmap/ present), only when
# those paths are dirty, and only when neither escape hatch applies: being on
# main/master directly, or inside a `.claude/worktrees/` worktree (EnterWorktree's own
# isolation — see roadmap-stash-guard.sh for the sibling check that protects that state
# from being stashed away instead of committed).
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

{
  echo "BLOCKED: this commit would land scrummy roadmap changes on branch '$BRANCH',"
  echo "not main:"
  echo
  printf '%s\n' "$DIRTY" | sed 's/^/    /'
  echo
  echo "Roadmap bookkeeping belongs on main, isolated from whatever feature branch is"
  echo "checked out — otherwise these files can get swept into that branch's next"
  echo "unrelated commit and pushed bundled with it (this happened for real: easy-nf #327)."
  echo
  echo "Use an isolated worktree instead:"
  echo
  echo "    EnterWorktree (fresh off origin/main)"
  echo "    <scrummy commands + spec editing there>"
  echo "    git commit -m 'chore(roadmap): ...'"
  echo "    git push origin <worktree-branch>:main"
  echo "    ExitWorktree"
  echo
  echo "See CLAUDE.md's Roadmap section for the full sequence."
} >&2

exit 2
