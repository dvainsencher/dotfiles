@RTK.md

## Workflow

**Branch first**: Before making any code change, propose a branch name and create it. Use prefixes `feat/`, `fix/`, `chore/`. If the planned work spans multiple roadmap items, suggest splitting into separate focused PRs and propose an order based on ROADMAP.md priority.

**Publish on completion**: After finishing a feature or fix, immediately run `/publish` to push, open a PR, get it reviewed, and merge. Do not accumulate uncommitted work.

**Docs check**: The `/publish` workflow includes a documentation review step. Update any docs that describe changed behavior before the PR is created.

**PR review**: The `/publish` workflow includes an automated code review step. If the review finds critical issues, resolve them before merging.

**TDD**: Write the test first, implement the minimum to pass, run once to confirm green.

**Bug fix TDD**: When you find a bug, first write a failing test that reproduces it, then fix the code, then run the test again to confirm it's green. Never fix a bug without a test.

**Roadmap sync**: Before opening a PR, mark the corresponding ROADMAP.md item `[x]` and include that change in the feature branch commit so it merges with the work.

**Frontend design**: When creating or significantly redesigning frontend pages or components, invoke the `frontend-design:frontend-design` skill before writing any code.

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

Default session model: `opusplan` (Opus plans/architects, Sonnet executes).

Use Opus for:
- Deep architecture decisions
- Large multi-file redesigns where a wrong first pass is expensive to undo
- Multi-step correctness reasoning across files

**Effort guidance:**
- Respond without deep thinking for: file reads, searches, directory listings, quick lookups.
- Use extended thinking for: architecture decisions, multi-file changes, anything where a
  wrong first pass is expensive to undo.


## Subagent Model Strategy

Default session model: `opusplan`
- Opus handles planning and architecture decisions
- Sonnet handles implementation and execution
- No manual model switching needed for most tasks

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
