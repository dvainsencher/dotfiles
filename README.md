# dotfiles

Personal dotfiles for Ubuntu/Debian — shell, git, vim, Starship prompt, direnv, and Claude Code.

## Entry points

| Script | Use when |
|--------|----------|
| `bootstrap.sh` | Fresh machine — installs packages, tools, fonts, generates SSH key, then runs `install.sh` |
| `install.sh` | Dotfiles only — symlinks config files, installs cheap-worker tools, installs+registers cclsp, clones git-hooks, sets up gdrive-bisync Google Drive sync |

### Bootstrap a fresh machine

```sh
curl -fsSL https://raw.githubusercontent.com/dvainsencher/dotfiles/main/bootstrap.sh | bash
```

### Install dotfiles only

```sh
git clone https://github.com/dvainsencher/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

Then add secrets to `~/.env.local` (see [Secrets](#secrets) below) and re-run `install.sh` to
register the GitHub MCP server.

## Prerequisites

For `install.sh`: `git`, `curl`, `vim`, `node` (for cclsp MCP registration). `rclone` is installed
automatically by `setup-gdrive-bisync.sh` if missing.

For `bootstrap.sh`: just `curl` — everything else is installed automatically, including:
gh, fzf, tmux, jq, ripgrep, direnv, uv, Node.js, Starship, nerd fonts, VS Code, Chrome, Claude Desktop, Claude Code.

## What's included

| File | Symlinked to | Description |
|------|-------------|-------------|
| `bashrc` | `~/.bashrc` | Shell config: history, aliases, completion, direnv, Starship prompt, DeepSeek worker defaults |
| `gitconfig` | `~/.gitconfig` | Aliases (`co`, `br`, `ci`, `st`, `lg`, `ps`, `pl`), colors, hooks |
| `gitconfig.local.example` | — | Template for `~/.gitconfig.local` (name + email, not tracked) |
| `vimrc` | `~/.vimrc` | Indentation, search, statusline, paste toggle |
| `inputrc` | `~/.inputrc` | Word navigation, history search, case-insensitive completion |
| `profile` | not symlinked | Login shell PATH + cargo env |
| `starship.toml` | `~/.config/starship.toml` | Starship prompt config (nerd-font symbols, command duration) |

## Claude Code

### Config (symlinked from dotfiles)

| File | Symlinked to | Description |
|------|-------------|-------------|
| `.claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | Global instructions: workflow, routing ladder, delegation rules |
| `.claude/RTK.md` | `~/.claude/RTK.md` | RTK token-proxy reference (imported by CLAUDE.md via `@RTK.md`) |
| `.claude/settings.json` | `~/.claude/settings.json` | Hooks, model (`opusplan`), plugins, statusline |
| `.claude/settings.local.json` | `~/.claude/settings.local.json` | Tool permission allowlist |
| `.claude/statusline-command.sh` | `~/.claude/statusline-command.sh` | Status line: session usage, rate limits, active pauta sprint |
| `.claude/commands/` | `~/.claude/commands/` | Global slash commands (`/publish`, `/roadmap`) |
| `.claude/agents/` | `~/.claude/agents/` | Custom subagents: code-reviewer, test-writer, docs-writer (all Sonnet) |
| `.claude/hooks/` | `~/.claude/hooks/` | PreToolUse hooks: rtk-rewrite, env-loader, check-main-branch |

### Slash commands

| Command | Description |
|---|---|
| `/publish` | Push branch → create PR → review → merge → sync main |
| `/roadmap` | Manage a project roadmap — view next, track status, plan items |

### Token efficiency: Tool & Model Routing Ladder

See `.claude/CLAUDE.md` for the full ladder. Summary:

| Tier | Tool | When |
|------|------|------|
| 0 | **cclsp** — LSP-over-MCP semantic nav | Symbol lookup, find_references, diagnostics (before grep) |
| 0 | **RTK proxy** | All shell commands — auto-rewritten, 60-90% token savings |
| 1 | **ask-kimi** (DeepSeek) | Bulk read: files >400 lines or 3+ files at once |
| 1 | **kimi-write** (DeepSeek) | Boilerplate generation: tests, config, repetitive patterns |
| 1 | **extract-chat** | Parse Claude Code JSONL session logs to text |
| 2 | **Sonnet subagents** | Most coding tasks (code-reviewer, test-writer, docs-writer) |
| 3 | **Opus** | Deep architecture, costly multi-file redesigns only |

## cclsp — Semantic Code Navigation

`install.sh` runs `.claude/cclsp/setup-cclsp.sh` which installs LSP servers and registers cclsp
as a user-scoped Claude Code MCP server. cclsp gives Claude symbol-aware navigation
(`find_definition`, `find_references`, `rename_symbol`, `get_diagnostics`) without an IDE.

**Global config:** `~/.config/claude/cclsp.json` — generic TS/JS/Py/Bash LSPs, no project root.
Source: `.claude/cclsp/cclsp.json` (versioned here).

**Per-project opt-in:** add `.claude/.mcp.json` and `.claude/cclsp.json` with project-specific
LSP roots. Example: point the TS server at a `frontend/` subdirectory when the repo root is Python.

> **Note:** after editing `cclsp.json` reconnect via `/mcp` in Claude Code — `restart_server`
> only cycles the downstream LSP, not the cclsp config itself.

## Cheap-worker delegation (DeepSeek)

`install.sh` installs [claude-coworker-model](https://github.com/imkunal007219/claude-coworker-model) — three CLI tools that delegate bulk I/O to DeepSeek, saving Claude tokens:

| Tool | Use |
|------|-----|
| `ask-kimi --paths <files> --question "<q>"` | Read/summarize large or multiple files |
| `kimi-write --spec "<spec>" --context <ref> --target <out>` | Generate boilerplate |
| `extract-chat <session.jsonl> -o <out.txt>` | Extract a Claude Code session transcript |

`bashrc` exports `WORKER_BASE_URL` and `WORKER_MODEL` defaults (DeepSeek). The `env-loader.sh`
hook auto-injects the key when these tools are invoked.

## Google Drive sync (gdrive-bisync)

`install.sh` runs `setup-gdrive-bisync.sh`, which clones two external repos into `~/prj/git/`,
installs `rclone` if missing (via its official installer, not apt — apt lags upstream and
`bisync` needs a recent release), and wires up periodic two-way sync (every 15 min, via cron)
between a local folder and a Google Drive folder:

- [gdrive-bisync](https://github.com/dvainsencher/gdrive-bisync) — public, generic, config-driven
  `rclone bisync` tool.
- [dotfiles-private](https://github.com/dvainsencher/dotfiles-private) — private, holds the actual
  folder pairs (e.g. `~/work` <-> Drive folder `work`), kept out of this public repo.

Two manual one-time steps are required before sync actually starts, and both are non-fatal if
not yet done (the step warns and skips, rest of `install.sh` continues):

1. Your SSH public key must already be added to GitHub (`bootstrap.sh` generates it) — needed to
   clone the private `dotfiles-private` repo.
2. Run `rclone config` interactively once to authorize the `gdrive` remote — this needs your
   Google login + consent in a browser and genuinely can't be scripted. See
   [rclone's Google Drive guide](https://rclone.org/drive/) for the exact prompts.

**Check status:** `bash ~/prj/git/gdrive-bisync/status.sh`
**Retry after clearing a blocker:** re-run `~/dotfiles/install.sh`, or test the step in isolation
with `bash ~/dotfiles/setup-gdrive-bisync.sh`.

## Secrets

Create `~/.env.local` (gitignored, sourced by `~/.bashrc` and the env-loader hook):

```sh
export WORKER_API_KEY="your-deepseek-key"      # ask-kimi / kimi-write
export GITHUB_PAT="your-github-pat"             # GitHub MCP server
```

Run `~/dotfiles/install.sh` after adding secrets — it registers MCP servers that were skipped.

## Personal git identity

`install.sh` copies `gitconfig.local.example` to `~/.gitconfig.local` if that file doesn't exist yet.
Edit it to set your name and email — it is not tracked by this repo:

```ini
[user]
    name = Your Name
    email = your@email.com
```
