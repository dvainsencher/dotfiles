# Claude Code Environment Audit — 2026-06-11

Triggered by: feeling that the easy-nf dev loop was slow and burning tokens
faster than before, plus curiosity about community plugins (superpowers,
skill-creator, code-simplifier, feature-dev, typescript-lsp, ralph-loop,
claude-code-setup, pr-review-toolkit, Anthropic code-review).

## Headline finding: no bloat, three concrete leaks/habits

The existing setup (Haiku `review-triage` gating Sonnet `code-reviewer`,
`/publish` keeping diff bytes out of the parent context, rtk + ask-kimi offload,
cheap non-redundant hooks) is well-engineered. The pain traced to:

1. `opusplan` as the standing default model (Opus plans every session).
2. `/publish` run on every change instead of per coherent unit — each run pays
   a CI-poll wait + a Sonnet review spawn.
3. One context leak: `/publish` Step 3 Phase 2 read the full
   `git diff main..HEAD` into the *parent* context, contradicting the
   "diff never enters main context" rule it otherwise follows.

## Finding 0 — investigated and retracted

Initial hypothesis: the rtk-rewrite PreToolUse hook was being bypassed for most
Bash calls (based on `rtk discover` showing ~1.1M tokens/30 days of "missed
savings" vs `rtk gain`'s ~6,100 all-time rewrites).

**Disproved by direct test:** spawned a minimal Explore subagent running
`git log -1 --oneline`; `rtk gain --history` confirmed it was rewritten and
tracked (`rtk git log -1 --oneline`, 13:10). The hook fires correctly for
subagent Bash calls.

**Root cause of the discrepancy:** `.claude/hooks/rtk-rewrite.sh` was only
introduced 2026-05-23 (commit `9c08ffa`) — 19 days before this audit.
`rtk discover` scans the **last 30 days** of session transcripts, so roughly a
third of its window predates the hook entirely. Additionally, `rtk discover`
greps transcripts for literal `rtk `-prefixed commands, but transcripts record
the *pre-rewrite* command the assistant proposed (rewriting happens at the hook
layer) — so it likely can't detect successful rewrites at all. Its "Already
using RTK: 25/10174 (0%)" is a tooling limitation, not evidence of a live leak.

**Conclusion:** no action needed on the hook itself. It works.

## Changes applied

| # | Change | File | Why |
|---|---|---|---|
| 1 | `model: opusplan` → `sonnet` | `.claude/settings.json` | Opus was the default for *every* plan-mode session — the largest standing cost/latency lever. Sonnet handles ~90% of this work; Opus reserved on-demand. |
| 2 | Tier 3 / Subagent Model Strategy reworded | `.claude/CLAUDE.md` | Document Opus-on-demand: deep architecture, large multi-file redesigns, and anything touching `src/core/fiscal_authority.py` or `docs/fiscal/`. |
| 3 | New "When to spawn a subagent at all" section | `.claude/CLAUDE.md` | Subagents aren't free — startup/tool-definition overhead can exceed savings on small jobs. Spawn only for 3+ files / >400 lines / bulk-output isolation; otherwise act inline. Also: subagents must not re-read CLAUDE.md/agent files the parent already holds. |
| 4 | "Publish on completion" reworded to per-coherent-unit | `.claude/CLAUDE.md` | Matches `easy-nf/CLAUDE.md`'s "complete units, not minimal diffs" PR guidance. Commit locally as you go; `/publish` once per shippable unit, not per edit. |
| 5 | `/context` + `/usage` habit added to Workflow | `.claude/CLAUDE.md` | Cheapest feedback loop for catching context/cost bloat early. |
| 6 | `/publish` Step 3 Phase 2: `git diff main..HEAD` (full diff, parent context) → reuse the `--name-only` file list from Phase 1 | `.claude/commands/publish.md` | The one place the workflow violated its own diff-isolation rule. |
| 7 | Pruned 5 hyper-specific one-off `allow` entries (full SEFAZ SOAP curls with literal XML, exact `dynamodb create-table` for one table, two debug `echo` commands) | `easy-nf/.claude/settings.local.json` | These exact-string permissions will never match again; noise in a gitignored per-developer file. |
| 8 | Reconciled 3 memory files encoding "publish on every change" | `~/.claude/projects/.../memory/feedback_publish_*.md` | Updated to "per coherent unit" cadence while preserving "don't ask for confirmation" intent; cross-linked with `[[...]]`. |

## Plugins verdict

Of the 9 community plugins the user had been reading about, **none were
installed** — all exist only in the `claude-plugins-official` marketplace
catalog. Cross-checked against what's already running:

- `typescript-lsp` ↔ already covered by `cclsp` (LSP-over-MCP, project + global).
- `code-review` / `pr-review-toolkit` ↔ already covered by custom
  `code-reviewer` + `review-triage` agents (and would be *heavier*: Anthropic's
  `/code-review` runs 8+ LLM passes incl. 5 parallel Sonnet reviewers vs. 1).
- `ralph-loop` ↔ built-in `/loop` skill.
- `code-simplifier` ↔ built-in `/simplify` skill.
- `feature-dev` (~89k installs, the one genuinely mass-adopted match) is a
  structure/quality tool, not a token-saver — its parallel-agent 7-phase flow
  is heavier than the current Plan-agent flow. Not adopted; could be trialed
  for one large greenfield feature if curious, but not as the daily loop.

**Net: no plugin closes the identified gaps — the config changes above do.**

## Verification

- `/model` shows Sonnet at session start; `settings.json` parses.
- After a day of normal use, `rtk gain` continues tracking rewrites at the
  current rate (no regression from the settings.json edit).
- Next 2–3 related small edits: commit locally, run `/publish` once — one PR,
  one CI wait, one review (not three).
- Trigger a docs-relevant change and confirm Step 3 of `/publish` no longer
  dumps a full diff into the transcript (watch `/context`).
- `easy-nf/.claude/settings.local.json` still parses; routine `rtk`/`git`/
  `pytest` commands run without new permission prompts.
