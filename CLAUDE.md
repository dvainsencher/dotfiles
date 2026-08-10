# CLAUDE.md — dotfiles repo

## Repo purpose
Personal dotfiles for Ubuntu/Debian. Two entry points:
- `install.sh` — symlinks dotfiles, clones git-hooks, installs claude-coworker-model, creates `~/.gitconfig.local`, installs/updates rtk, sets up gdrive-bisync Google Drive sync
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
- gdrive-bisync and dotfiles-private are separate repos (not vendored here) cloned into
  `~/prj/git/` by `setup-gdrive-bisync.sh` — kept separate so private folder names/paths never
  land in this public repo. Both the private clone and the gdrive-bisync install step are
  explicitly non-fatal on failure (manual steps — SSH key on GitHub, `rclone config` — may not be
  done yet), matching the `GITHUB_PAT`-missing pattern already used for GitHub MCP registration.

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
| `setup-gdrive-bisync.sh` | not symlinked — run directly or via `install.sh` | Clones gdrive-bisync + dotfiles-private into `~/prj/git/`, wires up periodic Google Drive sync |
| `setup-rtk.sh` | not symlinked — run directly or via `install.sh` | Installs/updates rtk to `~/.local/bin/rtk` via its official installer, removes any stray `cargo install` copy |

## gdrive-bisync / dotfiles-private integration
- Clone destinations: `~/prj/git/gdrive-bisync` (public tool, HTTPS clone) and
  `~/prj/git/dotfiles-private` (private config, SSH clone — no HTTPS-credential story exists in
  this codebase for private repos).
- `setup-gdrive-bisync.sh` installs `rclone` itself if missing, via `curl
  https://rclone.org/install.sh | sudo bash` (not apt — apt lags upstream, and `bisync`
  reliability depends on a recent release). `bootstrap.sh` does NOT apt-install rclone; this
  script is the single source of truth for getting rclone onto the machine.
- `setup-gdrive-bisync.sh` runs `gdrive-bisync/install.sh --config
  dotfiles-private/config/gdrive-bisync.sh` and maps its exit codes to a friendly `warn()`/`ok()`
  message: `0` success, `1` rclone missing (shouldn't happen given the step above, but the mapping
  stays as a fallback), `2` rclone remote not configured, `3` config missing/invalid. Codes 1-3 are
  non-fatal — the script warns and exits 0 so `install.sh` (which runs under `set -e`) isn't
  aborted.
- The script is directly runnable and testable in isolation (`bash
  ~/dotfiles/setup-gdrive-bisync.sh [--dry-run]`), independent of every other `install.sh` step —
  same pattern as `.claude/cclsp/setup-cclsp.sh`.
- No new file is symlinked into `$HOME` for this feature (nothing to add to the symlink-target
  column beyond the new `setup-gdrive-bisync.sh` row above).
- Final step, best-effort/non-fatal: if the private config sets `GDRIVE_FOLDER_ICON` (a local,
  non-git-tracked image path), applies it as a custom GNOME/Nautilus folder icon on every synced
  folder via `gio set <folder> metadata::custom-icon`. Silently skipped if unset or if `gio` isn't
  available — purely cosmetic, never blocks the rest of setup.
- Interactive/credential-affecting commands (`rclone config`, OAuth flows) are never run by Claude
  on the user's behalf — only the exact command to run is handed over, even when technically
  runnable via the Bash tool. Established after `rclone config update` unexpectedly triggered a
  browser OAuth prompt during an earlier session.

## rtk (token-saving CLI proxy) integration
- rtk was previously installed by hand (curl official installer + a stray, shadowed `cargo install
  --git`) and untracked by this repo — `setup-rtk.sh` makes install/update a tracked, repeatable
  step instead.
- `setup-rtk.sh` always re-runs rtk's official installer
  (`curl .../rtk-ai/rtk/refs/heads/master/install.sh | sh`) to `~/.local/bin/rtk` — unlike most
  other `install.sh` steps it does not skip if already present, since the whole point is to fetch
  the latest release each time. It also removes any `cargo install`-built copy from
  `~/.cargo/bin/rtk`: `~/.local/bin` comes first on `$PATH`, so a cargo-built copy is silently
  shadowed rather than actually used, and only causes confusion about which binary is running.
- `install.sh` runs it on every invocation (`maybe_run "install/update rtk..."`) — re-running
  `install.sh` is the update mechanism. Also directly runnable/testable in isolation (`bash
  ~/dotfiles/setup-rtk.sh [--dry-run]`), same pattern as `setup-gdrive-bisync.sh` /
  `.claude/cclsp/setup-cclsp.sh`.
- Both the installer and the cargo-cleanup step are non-fatal — a failure warns and moves on
  rather than aborting, so the script always exits 0. `install.sh` runs under `set -e`, so
  without this a network hiccup here would kill every step after it (git-hooks clone,
  gdrive-bisync setup, etc.) — same non-fatal contract as `setup-gdrive-bisync.sh`.
- rtk itself is not vendored — upstream is `github.com/rtk-ai/rtk`.

## Documentation

| Doc | Covers | Update when |
|-----|--------|-------------|
| `README.md` | `install.sh`, `bootstrap.sh`, all dotfiles, `.claude/commands/` slash commands, `.claude/agents/`, `gitconfig.local.example`, gdrive-bisync Google Drive sync, rtk install/update | New dotfile added or removed, symlink targets change, new slash command added, new agent added, bootstrap package list changes, gdrive-bisync wiring changes, `setup-rtk.sh` behavior changes |
| `CLAUDE.md` | Repo purpose, `install.sh`, `bootstrap.sh`, all tracked dotfiles and `.claude/` files, commit conventions, key design decisions, gdrive-bisync/dotfiles-private integration, rtk integration | New dotfile added, symlink target changes, bootstrap conventions change, `.claude/` directory gains or loses a tracked file, `setup-gdrive-bisync.sh` or `setup-rtk.sh` behavior changes |
| `.claude/CLAUDE.md` | Global Claude Code workflow rules, subagent model strategy, `.claude/agents/` agent roster | New agent added, agent model or role changes, workflow rules change |
| `.claude/commands/README.md` | `.claude/commands/publish.md`, `.claude/commands/roadmap.md`, slash command setup and usage | New command added or removed, setup steps change |
| `.claude/commands/publish.md` | Full publish workflow — git, `gh pr`, merge strategy, docs audit, code review | Steps added or reordered, doc-impacting file classification changes, subagent prompts change |
| `.claude/commands/roadmap.md` | `ROADMAP.md` format, per-item detail files, all `/roadmap` modes | New mode added, roadmap format changes |
| `.claude/agents/docs-writer.md` | Docs-writer agent — Discover, Write, and Audit modes, README and API reference templates | Agent modes change, checklist or templates change |
| `.claude/agents/code-reviewer.md` | Code-reviewer agent — review checklist and output format | Checklist or output format changes |
| `.claude/agents/test-writer.md` | Test-writer agent — coverage strategy, rules, output expectations | Coverage strategy or rules change |
