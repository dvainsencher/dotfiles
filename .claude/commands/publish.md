---
description: Push branch, create PR, merge with appropriate strategy, and sync main
allowed-tools: Bash(git *), Bash(gh *), Agent
---

# Publish Workflow

You are executing a full publish workflow. Follow each step carefully, stop on any error, and always confirm before destructive actions.

## Step 1 — Check current branch

Run: `git branch --show-current`

If the current branch is **`main`** (or `master`):
- Inspect the staged/unstaged changes and recent commits to understand what work is being published.
- Based on that context, suggest a descriptive branch name (e.g. `feat/improve-hero-section`, `fix/cta-text`, `chore/update-dependencies`).
- Ask the user: "You're on `main`. I suggest creating a new branch `<suggested-name>` before publishing. Create it now, or enter a different name? (Leave blank to push from `main` anyway.)"
- If the user provides or accepts a branch name, run:
  ```
  git checkout -b <branch-name>
  ```
  Then continue to Step 2.
- If the user explicitly chooses to push from `main`, continue to Step 2 without switching branches.

## Step 2 — Check for uncommitted changes

Run: `git status --short`

If there are uncommitted changes, warn the user and ask whether to:
- (a) Abort and let them commit first
- (b) Proceed anyway (only the already-committed changes will be pushed)

## Step 3 — Verify documentation

Run: `git diff main..HEAD --name-only` (or `master..HEAD` if applicable) to see all changed files.

Review the diff and determine if any documentation should be updated. Look for:
- New features, flags, or configuration options that aren't yet documented
- Removed or renamed features that are referenced in existing docs
- Changed behavior that existing docs describe incorrectly
- New files or scripts that lack a corresponding entry in a README or table

If documentation updates seem warranted, describe what's missing or outdated and ask the user: "Should I update the docs before publishing, or do you want to skip this?"
- If yes, make the documentation changes and commit them before continuing.
- If no, continue to Step 4.

If no documentation changes are needed, note that briefly and continue.

## Step 4 — Push the branch

Run: `git push --set-upstream origin $(git branch --show-current)`

If the push fails because the remote already has diverging commits, report the error clearly and ask the user how they want to resolve it (rebase, force-push, or abort). Do NOT force-push without explicit confirmation.

## Step 5 — Create a Pull Request

Run: `gh pr create --fill`

- `--fill` uses the branch name and commit messages to auto-populate title and body.
- If the command fails because a PR already exists, retrieve its URL with `gh pr view --json url -q .url` and continue to Step 6.
- If the repo has a PR template, `--fill` will respect it.

Capture the PR URL and show it to the user.

## Step 5.5 — Automated code review

Before merging, get an automated review of the PR diff.

Run: `gh pr diff`

Use the Agent tool (general-purpose subagent) with this prompt:
"Review this GitHub PR diff. Check for:
1. Logic or correctness errors
2. Security issues (injection, hardcoded secrets, missing validation)
3. Test coverage gaps — new code paths with no corresponding test
4. Documentation gaps — public APIs, config options, or new behaviors not documented
5. Project-specific rules from CLAUDE.md (route naming, TDD pattern, no AWS imports in core/)

Rate each finding: **critical** (block merge), **warning** (should fix), **notice** (optional).
If no issues found, say 'LGTM'."

Present the review to the user. If there are **critical** findings, stop and ask how to proceed before continuing to Step 6.


## Step 6 — Choose merge strategy

Inspect the branch name and number of commits to suggest the appropriate strategy, then confirm with the user:

Run: `git log main..HEAD --oneline` (or `master..HEAD` if applicable)

**Decision logic:**
- **Squash merge** (`gh pr merge --squash --delete-branch`) — recommended when there are multiple small/WIP commits on a feature branch (most common for feature work).
- **Rebase merge** (`gh pr merge --rebase --delete-branch`) — recommended when all commits are clean, well-scoped, and the team values linear history.
- **Merge commit** (`gh pr merge --merge --delete-branch`) — recommended when preserving full branch history matters (e.g., long-lived release branches).

Present your recommendation with a brief rationale based on commit count and branch name, then ask the user to confirm or choose a different strategy before merging.

## Step 7 — Merge the PR

Execute the merge command chosen in Step 6.

Wait for the merge to succeed. If it fails (e.g., merge conflicts, required checks failing), report the error and stop — do not attempt to resolve conflicts automatically.

## Step 8 — Switch to main and pull

Run:
```
git checkout main
git pull
```

Confirm to the user that they are now on an up-to-date `main` branch and show the latest commit with `git log -1 --oneline`.

---

## Summary output

At the end, print a short summary:
- Branch published: `<branch-name>`
- PR: `<url>`
- Merge strategy used: `<squash | rebase | merge>`
- Now on: `main` at `<commit-hash>`
