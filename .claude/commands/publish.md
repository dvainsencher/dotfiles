---
description: Push branch, create PR, merge with appropriate strategy, and sync main
allowed-tools: Bash(git *), Bash(gh *), Bash(grep *), Bash(ask-kimi *), Read, Agent
---

# Publish Workflow

You are executing a fixed publish pipeline. Each step has a defined input and output — run them in sequence, stop on error, and confirm before destructive actions.

## Step 1 — Check current branch

Run: `git branch --show-current`

If the branch is `main` or `master`:
- Run `git diff HEAD --stat && git log -5 --oneline` to understand the work.
- Suggest a branch name using prefix `feat/`, `fix/`, or `chore/`.
- Ask: "You're on `main`. Suggest branch `<name>` — create it, enter a different name, or press enter to push from main anyway."
- If a name is given: run `git checkout -b <name>` and continue.
- If blank: continue without switching.

## Step 2 — Check for uncommitted changes

Run: `git status --short`

If there are uncommitted changes, warn the user and ask:
- **(a)** Abort so I can commit first
- **(b)** Proceed (only committed changes will be pushed)

On (a): stop. On (b): continue.

## Step 3 — Documentation audit

Run:
```
git diff main..HEAD --name-only
git diff main..HEAD --diff-filter=A --name-only
```

**Phase 1 — Classify (no subagent).** A file is doc-impacting if it matches any of:
- Any newly added file (`--diff-filter=A` output)
- `*.sh`, `*.py`, `*.ts`, `*.js`, files under `src/` or `lib/`
- `*.toml`, `*.json` (excluding `package-lock.json`, `yarn.lock`, `Cargo.lock`)
- `install.sh`, `bootstrap.sh`
- Existing `*.md` files

Not doc-impacting (skip-only): test files, `.github/`, `.gitignore`, `.eslintrc*`, `.prettierrc*`, lock files.

If **no** doc-impacting files changed: print `Step 3 — No doc-impacting files changed, skipping docs audit.` and go to Step 4.

**Phase 2 — Inline audit (only if triggered).**

1. Run `grep -A 50 "## Documentation" CLAUDE.md` to get the doc inventory table.
2. Run `git diff main..HEAD` to get the full diff.
3. Using the inventory table and the diff, map each changed file to the docs that cover it. List:
   - `<doc-file>` — reason it needs updating
4. If nothing maps: print `Docs are up to date.` and go to Step 4.
5. Otherwise show the list and ask: "Update these docs before publishing, or skip?"
   - Update: make the changes, commit them, then continue.
   - Skip: go to Step 4.

## Step 4 — Push the branch

Run: `git push --set-upstream origin $(git branch --show-current)`

If the push fails due to diverging commits: report the error and ask whether to rebase, force-push, or abort. Do NOT force-push without explicit confirmation.

## Step 5 — Create a Pull Request

Run: `gh pr create --fill`

If it fails because a PR already exists: run `gh pr view --json url -q .url` to get the URL.

Show the PR URL to the user.

## Step 5.5 — Wait for CI

Run:
```
gh pr checks --watch --fail-fast
```

`--watch` blocks until every check finishes; `--fail-fast` exits immediately on the first failure.
- Exit code 0: all checks passed — continue to Step 5.6.
- Exit code non-zero: show the output, report which check failed, and stop. Do not proceed to review or merge.

## Step 5.6 — Code review

Do NOT run `gh pr diff` yourself — the diff bytes should never enter the main context. Let the subagent fetch them.

1. Capture the PR number: `gh pr view --json number -q .number`.
2. Read `~/.claude/agents/code-reviewer.md` to get the review checklist.
3. Read `CLAUDE.md` in the project root (not `~/.claude/CLAUDE.md`) and extract any project-specific rules.

Spawn a Sonnet agent with this fully-assembled prompt (substitute actual content for the placeholders):

> "Review PR #\<number\> against the checklist. Fetch the diff yourself by running `gh pr diff \<number\>`. Rate each finding: **critical** (block merge), **warning** (should fix), **suggestion** (optional). If no issues, respond with 'LGTM' only.
>
> ## Project-specific rules
> \<extracted rules from CLAUDE.md\>
>
> ## Review checklist
> \<full contents of code-reviewer.md\>"

Present the review to the user. If there are **critical** findings, stop and ask how to proceed before continuing.

## Step 6 — Choose merge strategy

Run: `git log main..HEAD --oneline` (or `master..HEAD`)

Apply this decision tree directly:
- **1 clean commit** → rebase: `gh pr merge --rebase --delete-branch`
- **Multiple commits on a feature/fix branch** → squash: `gh pr merge --squash --delete-branch`
- **Long-lived or release branch** → merge commit: `gh pr merge --merge --delete-branch`

State your recommendation with the commit count, then ask the user to confirm or choose differently before proceeding.

## Step 7 — Merge the PR

Run the merge command chosen in Step 6.

If it fails (conflicts, required checks): report the error and stop. Do not attempt auto-resolution.

## Step 8 — Sync main

Run:
```
git checkout main
git pull
```

Show the latest commit: `git log -1 --oneline`

---

## Summary

Print:
- Branch: `<branch-name>`
- PR: `<url>`
- Merge: `<squash | rebase | merge>`
- Now on: `main` at `<commit-hash>`
