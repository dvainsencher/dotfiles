# dotfiles

Personal dotfiles for Ubuntu/Debian — shell, git, vim, Starship prompt, direnv, and Claude Code.

## Entry points

| Script | Use when |
|--------|----------|
| `bootstrap.sh` | Fresh machine — installs packages, tools, fonts, generates SSH key, then runs `install.sh` |
| `install.sh` | Dotfiles only — symlinks config files, clones git-hooks, installs claude-coworker-model, creates `~/.gitconfig.local` |

### Bootstrap a fresh machine

```sh
curl -fsSL https://raw.githubusercontent.com/dvainsencher/dotfiles/main/bootstrap.sh | bash
```

### Install dotfiles only

```sh
git clone https://github.com/dvainsencher/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

## Prerequisites

For `install.sh`: `git`, `curl`, `vim`

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

| File | Symlinked to | Description |
|------|-------------|-------------|
| `.claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | Global Claude Code instructions |
| `.claude/settings.json` | `~/.claude/settings.json` | Hooks and status line config |
| `.claude/settings.local.json` | `~/.claude/settings.local.json` | Tool permissions |
| `.claude/statusline-command.sh` | `~/.claude/statusline-command.sh` | Status line script (session usage, rate limits) |
| `.claude/commands/` | `~/.claude/commands/` | Global slash commands |
| `.claude/agents/` | `~/.claude/agents/` | Custom Claude Code subagents |

### Slash commands

| Command | Description |
|---|---|
| `/publish` | Push branch → create PR → merge (with strategy selection) → sync main |
| `/roadmap` | Manage a project roadmap — view next steps, track status, add items, plan implementation detail |

Run `/roadmap` with no args to see what's next, or pass natural language: `what's next`, `status`, `plan <item>`, etc. If no `ROADMAP.md` exists it walks you through creating one.

## Cheap-worker delegation (DeepSeek)

`install.sh` installs [claude-coworker-model](https://github.com/imkunal007219/claude-coworker-model) — three CLI tools (`ask-kimi`, `kimi-write`, `extract-chat`) that delegate bulk file reading and boilerplate generation to DeepSeek, saving Claude tokens.

`bashrc` exports `WORKER_BASE_URL` and `WORKER_MODEL` defaults. Add your API key to `~/.env.local` (already sourced by `bashrc`, not tracked by git):

```sh
export WORKER_API_KEY="your-deepseek-key"
```

## Personal git identity

`install.sh` copies `gitconfig.local.example` to `~/.gitconfig.local` if that file doesn't exist yet.
Edit it to set your name and email — it is not tracked by this repo:

```ini
[user]
    name = Your Name
    email = your@email.com
```
