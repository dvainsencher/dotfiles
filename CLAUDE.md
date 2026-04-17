# CLAUDE.md — dotfiles repo

## Repo purpose
Personal dotfiles for Ubuntu/Debian. Two entry points:
- `install.sh` — symlinks dotfiles, clones git-hooks, creates `~/.gitconfig.local`
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
- bash-sensible is inlined directly (no external dependency)
- `~/.claude/commands` is where `dvainsencher/claude-commands` gets cloned

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
