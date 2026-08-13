@RTK.md

## Estilo de escrita

Ao escrever em português, siga as diretrizes de estilo em
`~/.claude/styles/portugues.md` antes de produzir o texto final.
Priorize clareza e naturalidade acima de formalidade.

## Workflow

**Branch first**: Before making any code change, propose a branch name and create it. Use prefixes `feat/`, `fix/`, `chore/`. If the planned work spans multiple roadmap items, suggest splitting into separate focused PRs and propose an order based on priority — if the project tracks work with `scrummy` (a `docs/roadmap/issues.jsonl` exists, or the project's own CLAUDE.md says so), read that priority from `scrummy show`; otherwise from ROADMAP.md.

**Publish on completion**: Commit locally as you go. Run `/publish` once per coherent,
shippable unit of work (matching the project's "complete units, not minimal diffs" PR
guidance) — not after every small edit. Each `/publish` pays for a CI wait and a
Sonnet code review, so batch related changes into one PR rather than a string of
tiny ones. Do not accumulate *uncommitted* work, but accumulating local commits on
a branch until the unit is done is expected.

**Docs check**: The `/publish` workflow includes a documentation review step. Update any docs that describe changed behavior before the PR is created.

**PR review**: The `/publish` workflow includes a triage-routed code review (Step 5.6). A Haiku triage agent reads the diff stat and file names, then routes to one of three paths: `skip` (docs/config/lockfiles only), `standard` (one Sonnet reviewer applying all five lenses), or `deep` (standard review + `deep-review` label applied so the CI backstop runs asynchronously). Review principles: They should always be evaluated and criticized. If you agree that the points, no matter how critical they are, they should be resolved before merging. If you disagree justify it and don't work on them. Failling tests no matter when they were introduced should be attacked to. Do not sweep technical debt or improvements under the rug. The rule of thumb to resolve now or later is if their scope is too large or risky to be adressed togheter with the current context. When a finding is non-critical and in-scope, prefer fixing it now over filing it — the current session already has the context loaded, so a small valuable fix is cheaper in tokens now than re-deriving that context in a future session; only defer when scope/risk genuinely doesn't fit alongside the current change. Do not invoke `/code-review` manually on every PR — the triage router decides depth automatically. **If the code-reviewer agent fails for any reason (session limit, tool error, empty result), stop the publish pipeline and do not proceed to merge — retry the review until findings are presented.**

**Review follow-ups join the active sprint**: File only findings that are genuinely worth tracking eventually — don't create backlog noise for points that are trivial, already resolved by justification, or not worth anyone's future time. When filing a review finding as a deferred issue (via `scrummy-add-issue`/`scrummy` directly), also move it into the currently active sprint with `scrummy move <id> "<sprint-name>"` rather than leaving it in the backlog — unless it's clearly lower-priority cleanup unrelated to the sprint's goal, in which case leave it in the backlog and say so.

**TDD**: Write the test first, implement the minimum to pass, run once to confirm green.

**Bug fix TDD**: When you find a bug, first write a failing test that reproduces it, then fix the code, then run the test again to confirm it's green. Never fix a bug without a test.

**Roadmap sync**: Before opening a PR, mark the corresponding item done. If the
project tracks work with `scrummy` (a `docs/roadmap/issues.jsonl` exists, or the
project's own CLAUDE.md points at scrummy), run `scrummy set-status <id> done`
instead of editing any file directly — scrummy's CLI is the only writer to its own
`docs/roadmap/*`. Otherwise, mark the corresponding ROADMAP.md item `[x]` and
include that change in the feature branch commit so it merges with the work.

**Frontend design**: When creating or significantly redesigning frontend pages or components, invoke the `frontend-design:frontend-design` skill before writing any code.

**Context hygiene**: Before a large multi-file task, run `/context` to see what's
consuming the window; check `/usage` periodically to track spend. Cheapest way to
catch bloat early instead of after the session has already ballooned.

## Sprint Workflow

**Scrummy-managed projects:** use `scrummy show` to read backlog/sprint state and the
`scrummy-po`/`scrummy-suggest-batches`/etc. skills to plan and reorganize — don't read
or write `docs/sprints.md`/`ROADMAP.md` for that project at all.

**Scrummy mutations always happen on `main`, in an isolated worktree — never on
whatever branch the session happens to have checked out.** scrummy itself is
deliberately git-agnostic (it only writes files; an earlier version that shelled out
to git/`gh` for this auto-merged unreviewed PRs onto a consuming project's `main` and
was reverted). That means the calling agent is responsible for the git side, and doing
it in the session's current directory is wrong: a `scrummy add-issue`/`spec`/`move`
call run while a feature branch is checked out lands the roadmap files on that branch,
not `main` — and if that branch's next commit is an unrelated broad `git add`, the
roadmap files can get silently swept in and pushed bundled with unrelated work (this
happened for real, easy-nf issue #327, 2026-08-11). Every time:

1. `EnterWorktree` (fresh off `origin/main`) before running any mutating `scrummy`
   command (`add-issue`, `spec`, `move`, `set-status`, `edit-issue`, `remove-issue`,
   `create-sprint`, `edit-sprint`, `set-position`, `import`).
2. Do the scrummy calls and spec editing there.
3. Commit with a `chore(roadmap): ...` message and push the worktree branch straight
   to `main`: `git push origin <worktree-branch>:main`.
4. `ExitWorktree` with `action: "remove"` (`discard_changes: true` is safe once the
   commit is confirmed on `origin/main`), then `git fetch origin main:main` in the
   original directory so its local `main` ref isn't left stale.

**Exception — a branch syncing its own issue.** The "Roadmap sync" rule above (mark
the item `done` before opening its PR) is meant to travel *with* that branch's own
commit, not through a worktree — `scrummy set-status <id> done` or a `log-issue`
checkpoint for the issue this branch itself implements belongs there. The worktree
rule is about *unrelated* roadmap bookkeeping (a new issue, or someone else's) riding
along on a branch that has nothing to do with it.

`roadmap-commit-guard.sh` (PreToolUse/Bash, see `.claude/hooks/`) is the mechanical
backstop for this — it blocks a `git commit` from landing dirty `docs/roadmap`/
`ROADMAP.md` changes on a non-`main` branch outside a `.claude/worktrees/` worktree,
*unless* every dirty roadmap file's id matches the id embedded in the branch's own
name (`<prefix>/<id>-...`, e.g. `feat/284-...`) — that case is the exception above and
is let through. So a skipped instruction for genuinely unrelated bookkeeping fails
loudly instead of silently landing wrong, without blocking the routine same-issue sync.

**Non-scrummy projects:** read sprint items from `docs/sprints.md`. For any item that
explicitly requires planning, or where you are not 95% confident in scope or approach,
use `AskUserQuestion` to interview the user before starting. Mark each completed item
`[x]` in `ROADMAP.md` and include that change in the PR.
    
## Development Principles

**If there is a bug there should have a test to prevent it to happens in the future.**
**When solving a problem find out the root cause, not only a quick workaround.**
**Propose refactorings when the code becomes hard to test.**
**Keep the code clean. If some new implementation turns code obsolete, clean it.**
**When a bug is found look for root causes, not workarounds.**


## Tool & Model Routing Ladder

Consult this before every task. Route to the *cheapest* tool that can do the job.

### Tier 0 — Zero-token tools (always prefer over LLM calls)

**Code navigation — cclsp (LSP-over-MCP):** Use semantic tools *before* grep for any
symbol-level task in a project that has cclsp configured:

```
mcp__cclsp__find_definition     # jump to definition
mcp__cclsp__find_references     # all usages of a symbol
mcp__cclsp__rename_symbol       # safe cross-file rename (dry_run first)
mcp__cclsp__get_diagnostics     # type errors on changed .ts/.tsx before pushing
mcp__cclsp__restart_server      # cycle downstream LSP (not config — reconnect via /mcp)
```

**RTK proxy:** All shell commands are transparently rewritten to `rtk <cmd>` by the
PreToolUse hook — 60–90% token savings on dev ops with zero effort.

### Tier 1 — DeepSeek CLI tools (bulk I/O, boilerplate)

Use when the task is mostly reading or generating, not reasoning. These are free of
LLM-context tokens from Claude's perspective.

**`ask-kimi` — bulk reading.** For any file >400 lines OR when you'd read 3+ files:

```bash
ask-kimi --paths <file1> <file2>... --question "<specific question>"
```

Returns a structured summary. Use that instead of reading files directly.
Only read files yourself when you need exact line numbers for editing.

**Propagate to subagents.** When spawning Explore or research agents over large files or
logs, instruct them to use `ask-kimi`/`extract-chat` — keep bulk bytes out of the
subagent's context too, not just yours.

**`kimi-write` — boilerplate generation.** For tests, config files, repetitive patterns:

```bash
kimi-write --spec "<what to write>" --context <existing-similar-file> --target <output-path>
```

**`extract-chat` — transcript extraction.** Converts Claude Code JSONL session logs:

```bash
extract-chat <session.jsonl> -o /tmp/chat.txt
```

**When NOT to use Tier 1:**
- Tasks under ~2000 tokens (overhead not worth it)
- Architecture decisions, debugging, safety-critical code
- When exact line numbers are needed for editing

### Tier 2 — Sonnet subagents (most coding tasks)

| Subagent      | Model   | Tools                              | When                                              |
|---------------|---------|------------------------------------|---------------------------------------------------|
| Explore       | Haiku   | Read-only                          | grep, glob, find file, symbol lookup              |
| code-reviewer | Sonnet  | Read, Grep, Glob, gh, ask-kimi     | PR review, post-refactor quality check            |
| test-writer   | Sonnet  | Read, Write, Grep, Glob, Bash      | Writing or improving tests                        |
| docs-writer   | Sonnet  | Read, Write, Grep, Glob, ask-kimi  | Discover/write/audit READMEs and API docs         |
| Plan          | Inherit | Read-only                          | Codebase research before strategy                 |
| General-purpose | Inherit | All                              | Exploration + modification together               |

Sonnet handles ~90% of coding tasks without meaningful quality loss vs Opus.
Never route grep/glob/find to Opus — Explore (Haiku) handles these.
Boilerplate *writing* (docs, tests, config) → `kimi-write`. Reserve Opus for reasoning.

### Tier 3 — Opus (deep reasoning only)

Default session model: `sonnet`. Switch to Opus on demand (`/model opus`, or a
plan-mode pass) — don't leave it on as the default, it's the most expensive tier.

Use Opus for:
- Deep architecture decisions
- Large multi-file redesigns where a wrong first pass is expensive to undo
- Multi-step correctness reasoning across files
- Anything touching `src/core/fiscal_authority.py` or `docs/fiscal/` — fiscal
  rule changes are high-stakes and worth the extra reasoning depth

**Effort guidance:**
- Respond without deep thinking for: file reads, searches, directory listings, quick lookups.
- Use extended thinking for: architecture decisions, multi-file changes, anything where a
  wrong first pass is expensive to undo.


## Subagent Model Strategy

Default session model: `sonnet` for both planning and execution.
- Switch to Opus deliberately for the cases listed in Tier 3 (deep architecture,
  large multi-file redesigns, fiscal logic) — not as a standing default.
- Subagents keep their own `model:` frontmatter (Haiku for triage/Explore, Sonnet
  for code-reviewer/test-writer/docs-writer) regardless of the session model.

### When to spawn a subagent at all

Subagents aren't automatically cheaper — their startup + tool-definition overhead
can exceed the savings on small jobs. Spawn one only when it earns its keep:
- You'd otherwise read **3+ files or >400 lines** into the main context, or
- You need to isolate bulk/noisy output (logs, diffs, search sweeps) that the
  parent doesn't need verbatim.

For a quick lookup, single-file edit, or one-shot command, do it inline — don't
delegate for delegation's sake.

**Subagents must not re-derive context the parent already holds.** Don't have a
subagent `cat`/read `CLAUDE.md`, agent definition files, or other config the
parent has already read — pass the relevant conclusions in the prompt instead.
Combined with the payload-discipline rule (hand over commands/paths, not pasted
bytes — see memory `feedback-subagent-payload-discipline`), this keeps the same
bytes from occupying two contexts in either direction.

### Custom subagents (`~/.claude/agents/`)

Invoke by typing `@agent-name` in conversation, or invoked from slash commands.

| Agent         | Model  | When to use                                      |
|---------------|--------|--------------------------------------------------|
| code-reviewer | Sonnet | PR review, post-refactor quality check           |
| test-writer   | Sonnet | Writing or improving tests for existing code     |
| docs-writer   | Sonnet | Discover doc inventory, write, or audit READMEs and API reference docs |


## Cheap-Worker Delegation

See **Tier 1** in the Routing Ladder above for `ask-kimi`, `kimi-write`, `extract-chat`.

Quick reference:
- `ask-kimi --paths <files> --question "<q>"` — bulk read (>400 lines or 3+ files)
- `kimi-write --spec "<spec>" --context <ref> --target <out>` — generate boilerplate
- `extract-chat <session.jsonl> -o <out.txt>` — extract transcript
