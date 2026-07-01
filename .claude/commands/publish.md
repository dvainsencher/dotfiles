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
2. Using the inventory table and the changed-file list from Phase 1 (paths only —
   do not read the full diff into this context), map each changed file to the
   docs that cover it by path/pattern. List:
   - `<doc-file>` — reason it needs updating
3. If nothing maps: print `Docs are up to date.` and go to Step 4.
4. Otherwise show the list and ask: "Update these docs before publishing, or skip?"
   - Update: make the changes, commit them, then continue.
   - Skip: go to Step 4.

## Step 3.5 — Local verification gate

**If the project has a pre-push hook** (check `.git/hooks/pre-push`): skip this
step entirely — the hook runs the same checks automatically when Step 4 pushes.
Note that to the user and continue.

**If there is no pre-push hook**: verify the work builds and passes tests locally
before pushing. Use the changed-file list from Step 3 and run only the checks that
match (skip those that don't apply):

- Backend / Python (`*.py`, `src/`, `tests/`): the project's test command, e.g.
  `venv/bin/pytest -q`.
- Frontend (`frontend/**`, `*.ts`, `*.tsx`, `package.json`): the project's build +
  test, e.g. `cd frontend && npm test`.
- GitHub Actions workflows (`.github/workflows/*.yml`): the project's workflow
  linter, e.g. `~/.local/bin/actionlint`.

Consult the project's `CLAUDE.md` for the exact commands; the above are defaults.

If a matching check **fails**: STOP. Report it and fix before pushing — never push
known-broken work. If the project defines no matching toolchain, note that and continue.

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
PR_NUM=$(gh pr view --json number -q .number)
while gh pr checks "$PR_NUM" | grep -q "pending"; do sleep 15; done
gh pr checks "$PR_NUM"
```

Poll every 15 seconds until no checks remain pending, then print the final status.
- If all checks show `pass`: continue to Step 5.6.
- If any check shows `fail`: report which check failed and stop. Do not proceed to review or merge.

## Step 5.6 — Triage-routed code review

Do NOT run `gh pr diff` yourself — the diff bytes should never enter the main context.

### 5.6.1 — Triage (Haiku, near-zero cost)

Run the following two commands and pass their output to a `review-triage` agent:

```
git diff main..HEAD --stat
git diff main..HEAD --name-only
```

The triage agent responds with exactly one line: `ROUTE: <skip|standard|deep> — <reason>`.

### 5.6.2 — Act on the route

**`ROUTE: skip`**
Print: `Step 5.6 — Review skipped: <triage reason>` and go to Step 6.

**`ROUTE: standard`**
1. Capture the PR number: `gh pr view --json number -q .number`.
2. Read `~/.claude/agents/code-reviewer.md` to get the review checklist.
3. Read `CLAUDE.md` in the project root (not `~/.claude/CLAUDE.md`) and extract any project-specific rules.
4. Spawn one Sonnet `code-reviewer` agent with this fully-assembled prompt:

   > "Review PR #\<number\>. Fetch the diff yourself by running `gh pr diff \<number\>`.
   > Apply **all lenses** from the review checklist (lenses 7–9 are conditional on
   > whether the diff modifies existing lines — check before using them).
   >
   > ## Project-specific rules
   > \<extracted rules from CLAUDE.md\>
   >
   > ## Review checklist
   > \<full contents of code-reviewer.md\>"

5. Present findings to the user. If there are **🔴 Critical** findings: stop and ask how to proceed before continuing.

**`ROUTE: deep`**
1. Follow the same steps 1–5 as `standard` above (local fast-feedback review first).
2. After presenting findings (stop on 🔴 as above), also apply the `deep-review` label:
   ```
   gh pr edit --add-label deep-review
   ```
3. Inform the user: "Deep-review label applied — no async CI backstop is deployed; the local review above is the sole backstop."
4. Continue to Step 6 without waiting for CI.

## Step 6 — Choose merge strategy

Run: `git log main..HEAD --oneline` (or `master..HEAD`)

Apply this decision tree directly and proceed without asking:
- **1 clean commit** → rebase: `gh pr merge --rebase --delete-branch`
- **Multiple commits on a feature/fix branch** → squash: `gh pr merge --squash --delete-branch`
- **Long-lived or release branch** → merge commit: `gh pr merge --merge --delete-branch`

State which strategy you chose and why (commit count), then immediately run Step 7 — do not ask for confirmation.

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
