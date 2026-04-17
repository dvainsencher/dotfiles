# dotfiles

Personal dotfiles for bash, git, vim, and readline.

## Bootstrap a fresh machine

```sh
curl -fsSL https://raw.githubusercontent.com/dvainsencher/dotfiles/main/bootstrap.sh | bash
```

## Install dotfiles only

```sh
git clone https://github.com/dvainsencher/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

## Prerequisites

- Ubuntu / Debian
- `git`, `curl`, `vim`
- [Starship](https://starship.rs) prompt (installed automatically by `bootstrap.sh`)

## What's included

| File | Description |
|------|-------------|
| `bashrc` | Shell config: history, aliases, completion, Starship prompt |
| `gitconfig` | Aliases (`co`, `br`, `ci`, `st`, `lg`, `ps`, `pl`), colors, hooks |
| `vimrc` | Indentation, search, statusline, paste toggle |
| `inputrc` | Word navigation, history search, case-insensitive completion |

## Personal git identity

`install.sh` copies `gitconfig.local.example` to `~/.gitconfig.local` if that file doesn't exist yet.
Edit it to set your name and email — it is not tracked by this repo:

```ini
[user]
    name = Your Name
    email = your@email.com
```
