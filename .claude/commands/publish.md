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

**Never run bare `gh pr create --fill`.** `--fill` only pulls the title from the
branch's own commit message when there is **exactly one** commit ahead of the base
branch. With two or more (the normal case — this workflow's own Step 2/CLAUDE.md
convention is to accumulate local commits until a unit is done), `--fill` silently
falls back to **the branch name, humanized**, as the title — e.g.
`feat/315-portal-source-watch` → "feat/315 portal source watch". This is not
hypothetical: it happened (easy-nf PR #383) and the bad title became the
squash-merge commit subject on `main` permanently, since GitHub defaults a squash
commit's message to the PR title.

1. Detect this repo's actual PR-title convention from its own history — don't
   assume Conventional Commits, confirm it: `git log --oneline -10 main`. Most
   projects here use `type(scope): summary (#issue)` (e.g. `fix(ops): contain
   self-hosted runner OOM ... (#349)`). If the sample doesn't show a clear
   convention, ask the user once rather than guessing.
2. Construct an explicit title matching that convention, derived from the
   branch's own commit messages (never the branch name) — with the issue number
   if the branch name embeds one (`feat/315-...` → `#315`) or one is otherwise known.
3. Run: `gh pr create --title "<constructed title>" --fill` — `--fill` still
   populates the **body** from the commit list; `--title` overrides only the
   title, so the branch-name fallback never triggers regardless of commit count.
4. **Verify, don't assume.** `gh pr view --json title -q .title` and check it
   against the convention. If it's still wrong, fix it now —
   `gh pr edit --title "..."` — before Step 7. After merge, the title can still be
   edited cosmetically, but the squash-merge commit subject already baked into
   `main` cannot be (that requires rewriting `main`'s history — never do this
   unilaterally; only if the user explicitly asks).

If PR creation fails because a PR already exists: run `gh pr view --json url -q .url`
to get the URL, then still run step 4's title check on it.

Show the PR URL **and title** to the user.

## Step 5.5 — Wait for CI

**Use this exact command — do not substitute a `--json`-based poll.** `gh pr checks`
does not support `--json` in this environment (confirmed: `gh pr checks <n> --json
name,bucket` returns `unknown flag: --json`, not JSON). A custom Monitor/poll loop
built around that flag will fail every call, and if the loop's error handling
swallows the failure (e.g. `... || echo "[]"`), "command is failing" becomes
indistinguishable from "still pending" — the loop silently retries until it times
out, even long after checks actually passed. The plain-text form below has no such
failure mode.

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

## Step 5.7 — Detect a parallel-issue worktree

Run: `git worktree list`

If the base branch (`main`/`master`) is checked out at a **different path** than
the current directory, this is a parallel-issue worktree (see the project's
"Parallel issues → worktrees" convention, if it has one — sibling worktrees, one
per issue). Note this for Steps 7 and 8 below: `git checkout main` cannot succeed
here (git refuses the same branch checked out in two worktrees at once — confirmed
error: `fatal: 'main' is already used by worktree`), and forcing it would defeat
why this worktree exists. Otherwise, proceed normally in both steps.

## Step 6 — Choose merge strategy

Run: `git log main..HEAD --oneline` (or `master..HEAD`)

Apply this decision tree directly and proceed without asking:
- **1 clean commit** → rebase: `gh pr merge --rebase --delete-branch`
- **Multiple commits on a feature/fix branch** → squash: `gh pr merge --squash --delete-branch`
- **Long-lived or release branch** → merge commit: `gh pr merge --merge --delete-branch`

State which strategy you chose and why (commit count), then immediately run Step 7 — do not ask for confirmation.

## Step 7 — Merge the PR

**If Step 5.7 found a parallel-issue worktree**: drop `--delete-branch` from the
Step 6 command before running it. `gh pr merge --delete-branch` merges via the API
first, then tries a local `git checkout <base>` + branch delete to clean up — which
fails here for the same reason as Step 8, and leaves the *remote* branch undeleted
too (confirmed: easy-nf PR #383 needed a manual follow-up). After a successful
merge, delete the remote branch explicitly instead:
```
git push origin --delete <branch-name>
```

Otherwise, run the merge command chosen in Step 6 as-is.

If it fails because of a real conflict or a genuinely failing required check:
report the error and stop. Do not attempt auto-resolution.

If it fails because GitHub reports the PR as blocked/`REVIEW_REQUIRED` by
branch-protection state that isn't a real problem with the diff (e.g. a
review-approval requirement nobody on the repo can satisfy) — report the
specific blocking reason to the user and **stop**. Never pass `--admin` or
otherwise force the merge on your own initiative: bypassing branch protection
is a human decision about that specific PR, not a merge mechanic, and an
agent assuming it silently is exactly the failure mode that caused
easy-nf's #375-377 (merged with zero human review — see
`docs/OPERATIONS.md` § "Branch protection" there for the writeup). Only use
`--admin` if the user explicitly authorizes it for this PR, this time.

## Step 8 — Sync main

**If Step 5.7 found a parallel-issue worktree**: don't check out `main` here —
it can't succeed, and this worktree is only useful while its own branch is
unmerged. Now that the PR is merged, clean it up automatically using
`git -C <primary-path>` (never `cd` — leaves this shell's cwd alone), where
`<primary-path>` is the `main` worktree's path from Step 5.7's `git worktree list`
output and `<this-worktree-path>` is the current directory:
```
git -C <primary-path> pull --ff-only
git -C <primary-path> worktree remove --force <this-worktree-path>
git -C <primary-path> branch -D <branch-name>
```
- `pull --ff-only` first, so the primary checkout picks up the merge commit
  before anything else touches it.
- `--force` on `worktree remove` is expected and safe: the only "dirty" state a
  parallel-issue worktree normally carries is CLAUDE.md's symlinked `venv`/
  `node_modules`, not real uncommitted work (Step 2 already gated on that). If
  `git status --short` here shows anything beyond known symlinks, stop and ask
  instead of forcing.
- `-D` (not `-d`) is required: a squash-merge commit isn't a descendant of the
  local branch tip, so git can't detect it as "merged" via ancestry even though
  GitHub fully absorbed its content.

Report the new commit (`git -C <primary-path> log -1 --oneline`) and tell the
user this worktree directory is gone — further work on this issue needs a new
worktree or the primary checkout.

**Otherwise** (normal single-checkout repo):
```
git checkout main
git pull
```
Show the latest commit: `git log -1 --oneline`

---

## Summary

Print:
- Branch: `<branch-name>`
- PR: `<url>` — title: `<title>`
- Merge: `<squash | rebase | merge>`
- Now on: `main` at `<commit-hash>` (normal case) — or, if Step 5.7 found a
  parallel-issue worktree: `main` fetched to `<commit-hash>` (not checked out
  here; still on `<branch-name>` in this worktree)
