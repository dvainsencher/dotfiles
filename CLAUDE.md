# CLAUDE.md — dotfiles repo

## Repo purpose
Personal dotfiles for Ubuntu/Debian. Two entry points:
- `install.sh` — symlinks dotfiles, clones git-hooks, installs claude-coworker-model, creates `~/.gitconfig.local`
- `bootstrap.sh` — full fresh-machine setup (packages, tools, fonts, SSH key, then runs install.sh)

## Commit conventions
Conventional commits are enforced by git-hooks. Every commit message must follow:
```
type(scope): description
```
Valid types: `feat fix docs style refactor perf test build ci chore revert`

Do NOT add `Co-Authored-By` trailers to commit messages.

## Key design decisions
- `~/.gitconfig.local` holds `[user]` identity — not tracked, created from `gitconfig.local.example`
- `gitconfig` uses `hooksPath = ~/.config/git-hooks` (cloned from `dvainsencher/git-hooks`)
- Starship replaces PS1 entirely — no manual prompt config in bashrc
- direnv hook is initialized before starship in bashrc

## bootstrap.sh conventions
- All installs are idempotent — check before installing, skip if already present
- Use apt repos (with GPG keys) for tools that provide them (gh, vscode, claude-desktop, chrome)
- Use official install scripts for: starship, uv, node (NodeSource)
- Track results in `INSTALLED` and `SKIPPED` arrays, print summary at end
- SSH key is generated as `ed25519`; public key is printed so user can add it to GitHub

## Files and what they do
| File | Symlinked to | Purpose |
|------|-------------|---------|
| `bashrc` | `~/.bashrc` | Shell config |
| `gitconfig` | `~/.gitconfig` | Git config (no identity) |
| `vimrc` | `~/.vimrc` | Vim config |
| `inputrc` | `~/.inputrc` | Readline config |
| `profile` | not symlinked | Login shell PATH + cargo env |
| `gitconfig.local.example` | — | Template for `~/.gitconfig.local` |
| `starship.toml` | `~/.config/starship.toml` | Starship prompt config |
| `.claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | Global Claude Code config |
| `.claude/settings.json` | `~/.claude/settings.json` | Claude hooks and statusLine |
| `.claude/settings.local.json` | `~/.claude/settings.local.json` | Claude permissions |
| `.claude/statusline-command.sh` | `~/.claude/statusline-command.sh` | Status line script |
| `.claude/commands/` | `~/.claude/commands/` | Claude slash commands |
| `.claude/agents/` | `~/.claude/agents/` | Custom Claude Code subagents |
| `.claude/hooks/env-loader.sh` | `~/.claude/hooks/env-loader.sh` | Pre-tool-use hook: prepends `source ~/.env.local` to bash commands |
| *(generated)* `~/.claude/RTK.md` | — | RTK usage docs, auto-created by `install.sh` if `rtk` is installed |

## Documentation

| Doc | Covers | Update when |
|-----|--------|-------------|
| `README.md` | `install.sh`, `bootstrap.sh`, all dotfiles, `.claude/commands/` slash commands, `.claude/agents/`, `gitconfig.local.example` | New dotfile added or removed, symlink targets change, new slash command added, new agent added, bootstrap package list changes |
| `CLAUDE.md` | Repo purpose, `install.sh`, `bootstrap.sh`, all tracked dotfiles and `.claude/` files, commit conventions, key design decisions | New dotfile added, symlink target changes, bootstrap conventions change, `.claude/` directory gains or loses a tracked file |
| `.claude/CLAUDE.md` | Global Claude Code workflow rules, subagent model strategy, `.claude/agents/` agent roster | New agent added, agent model or role changes, workflow rules change |
| `.claude/commands/README.md` | `.claude/commands/publish.md`, `.claude/commands/roadmap.md`, slash command setup and usage | New command added or removed, setup steps change |
| `.claude/commands/publish.md` | Full publish workflow — git, `gh pr`, merge strategy, docs audit, code review | Steps added or reordered, doc-impacting file classification changes, subagent prompts change |
| `.claude/commands/roadmap.md` | `ROADMAP.md` format, per-item detail files, all `/roadmap` modes | New mode added, roadmap format changes |
| `.claude/agents/docs-writer.md` | Docs-writer agent — Discover, Write, and Audit modes, README and API reference templates | Agent modes change, checklist or templates change |
| `.claude/agents/code-reviewer.md` | Code-reviewer agent — review checklist and output format | Checklist or output format changes |
| `.claude/agents/test-writer.md` | Test-writer agent — coverage strategy, rules, output expectations | Coverage strategy or rules change |
