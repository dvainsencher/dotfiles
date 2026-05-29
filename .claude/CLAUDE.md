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

## Cheap-Worker Delegation

Three CLI tools delegate bulk I/O to DeepSeek to save Claude tokens. Use them
when the task is mostly reading or generating boilerplate, not reasoning.

### ask-kimi — bulk reading
For reading files >400 lines, or when you'd otherwise read 3+ files:

```bash
ask-kimi --paths <file1> <file2>... --question "<specific question>"
```

Returns a structured summary. Use that instead of reading files directly.
Only read files yourself when you need exact line numbers for editing.

### kimi-write — boilerplate generation
For generating tests, config files, or repetitive code patterns:

```bash
kimi-write --spec "<what to write>" --context <existing-similar-file> --target <output-path>
```

### extract-chat — chat transcript extraction
Converts a Claude Code JSONL session log to human-readable text:

```bash
extract-chat <session.jsonl> -o /tmp/chat.txt
```

### When NOT to delegate
- Tasks under ~2000 tokens (overhead not worth it)
- Architecture decisions, debugging, safety-critical code
- When exact line numbers are needed for editing

## Subagent Model Strategy

Default session model: `opusplan`
- Opus handles planning and architecture decisions
- Sonnet handles implementation and execution
- No manual model switching needed for most tasks

### Built-in subagents (automatic, no config needed)

| Agent             | Model   | Tools      | When Claude uses it                        |
|-------------------|---------|------------|--------------------------------------------|
| Explore           | Haiku   | Read-only  | grep, glob, find file, symbol lookup       |
| Plan              | Inherit | Read-only  | codebase research before strategy          |
| General-purpose   | Inherit | All        | exploration + modification together        |
| Claude Code Guide | Inherit | Read-only  | questions about Claude Code itself         |

### Custom subagents (`~/.claude/agents/`)

Invoke by typing `@agent-name` in conversation, or they are invoked from slash commands.

| Agent         | Model  | When to use                                      |
|---------------|--------|--------------------------------------------------|
| code-reviewer | Sonnet | PR review, post-refactor quality check           |
| test-writer   | Sonnet | Writing or improving tests for existing code     |
| docs-writer   | Sonnet | Discover doc inventory, write, or audit READMEs and API reference docs |

### Effort guidance

Respond without deep thinking for:
- File reads, searches, directory listings, quick lookups

Use extended thinking for:
- Architecture decisions, multi-file changes, anything where a wrong
  first pass is expensive to undo

### Cost rules

- Never route grep/glob/find tasks to Opus — Explore (Haiku) handles these
- Sonnet handles ~90% of coding tasks without meaningful quality loss vs Opus
- Opus is reserved for: deep architecture decisions and large multi-file
  redesigns where correctness on the first pass matters significantly
