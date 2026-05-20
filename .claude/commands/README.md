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
| `/roadmap` | Manage a project roadmap — view next steps, track status, add items, plan implementation detail |

### `/roadmap` modes

| Invocation | What it does |
|---|---|
| `/roadmap` | Shows in-progress items, then the next 2–3 planned items with rationale |
| `/roadmap status` | Count summary (done / in progress / planned) with in-progress detail |
| `/roadmap all` | Full roadmap grouped by state |
| `/roadmap add <description>` | Appends a new planned item |
| `/roadmap start <name>` | Marks an item as in progress |
| `/roadmap done <name>` | Marks an item as done |
| `/roadmap plan <name>` | Reads the codebase and drafts a detail file for the item (`docs/roadmap/<slug>.md`) |
| `/roadmap detail <name>` | Shows the detail file for an item, or offers to create one |

Natural language also works: "what's next", "how's it going", "what are we building?", etc.

If no `ROADMAP.md` exists, `/roadmap` walks you through creating one interactively and sets up the `docs/roadmap/` structure.

## Invocation

Commands installed here are available globally as `/command-name` in any Claude Code session.

```
/publish
/roadmap
/roadmap plan "user authentication"
```
