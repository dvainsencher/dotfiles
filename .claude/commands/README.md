# claude-commands

Personal [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) global slash commands — available across all projects.

## Setup

Clone directly into `~/.claude/commands`:

```bash
# First time — if ~/.claude/commands doesn't exist yet
git clone git@github.com:dvainsencher/claude-commands.git ~/.claude/commands

# First time — if ~/.claude/commands already exists (back it up first)
mv ~/.claude/commands ~/.claude/commands.bak
git clone git@github.com:dvainsencher/claude-commands.git ~/.claude/commands
```

That's it. Claude Code picks up commands from that directory automatically.

## Updating

Pull the latest commands on any machine:

```bash
cd ~/.claude/commands && git pull
```

## Adding a new command

```bash
cd ~/.claude/commands
# create your command file
vim my-command.md
git add my-command.md
git commit -m "feat: add my-command"
git push
```

## Commands

| Command | Description |
|---|---|
| `/publish` | Push branch → create PR → merge (with strategy selection) → sync main |

## Invocation

Commands installed here are available globally as `/command-name` in any Claude Code session.

```
/publish
```
