---
description: Read ROADMAP.md in the current project directory, then respond based on arguments
---

Read ROADMAP.md in the current project directory, then respond based on: $ARGUMENTS

## Roadmap format

ROADMAP.md is a flat list of items, each with a state marker:

```
- [ ] Item description   ← planned
- [>] Item description   ← in progress
- [x] Item description   ← done
```

File order is priority order. Keep it simple — no sections, no nesting required.

## Per-item detail files (optional)

For any item, a detail file may exist at `docs/roadmap/<slug>.md`, where the slug is the item description lowercased with spaces replaced by hyphens and non-alphanumeric characters removed. These files hold the implementation approach, acceptance criteria, and sub-tasks. They are optional — their absence is normal.

When answering questions about a specific item, check if its detail file exists and read it for context.

A `docs/roadmap/_template.md` file is created during initialization as a reference for the expected detail file structure.

## If ROADMAP.md does not exist

Guide the user to create one interactively:

1. Say: "There's no ROADMAP.md yet — want me to help you create one?"
2. If yes, ask in sequence (wait for each answer before continuing):
   - "What is this project for, in one sentence?"
   - "What has already been done? (List anything finished, or say 'nothing yet')"
   - "What's currently in progress?"
   - "What's planned next? List anything you have in mind."
3. Draft a ROADMAP.md using the format above: `[x]` for done, `[>]` for in progress, `[ ]` for planned. Order planned items by the sequence the user implied.
4. Show the draft and ask: "Does this look right? I'll write it once you confirm."
5. On confirmation:
   - Write ROADMAP.md to the project root.
   - Create `docs/roadmap/` if it doesn't exist.
   - Write `docs/roadmap/_template.md` with this content:
     ```markdown
     # <Item name>

     ## Goal
     One sentence on what done looks like.

     ## Approach
     How to implement it. Key decisions, constraints, or patterns to follow.

     ## Acceptance criteria
     - [ ] Criterion one
     - [ ] Criterion two

     ## Sub-tasks
     - [ ] Sub-task one
     - [ ] Sub-task two

     ## Notes
     Anything else relevant: links, risks, open questions.
     ```
   - Tell the user: "You can create a detail file for any item with `/roadmap plan <item name>`."

## Responding to $ARGUMENTS

Map the input to one of these modes by intent, not exact wording:

**No args / "what's next" / "next steps" / "what should I work on"**
Show any `[>]` in-progress items first. Then list the next 2–3 `[ ]` planned items in file order. For each, one line of rationale based on its position and any detail file content.

**"status" / "where are we" / "how's it going" / "progress"**
Show a count summary (X done, Y in progress, Z planned) then list in-progress items with any relevant detail.

**"all" / "review" / "show everything" / "full list"**
Display the complete roadmap grouped by state: In Progress → Planned → Done.

**"add <description>"**
Append a new `[ ]` item at the end of the planned items. Confirm the exact wording before writing. Mention the detail file path if the user wants to add more context later.

**"start <name>"**
Mark the closest matching `[ ]` item as `[>]`. Confirm the match before writing.

**"done <name>"**
Mark the closest matching `[>]` or `[ ]` item as `[x]`. Confirm the match before writing.

**"detail <name>"**
Show the content of `docs/roadmap/<slug>.md` if it exists. If it doesn't, offer to create it and ask what to put in it.

**"plan <name>"**
Create or update the detail file for the matching roadmap item.

1. Identify the closest matching item in ROADMAP.md. Confirm the match if ambiguous.
2. Check if `docs/roadmap/<slug>.md` already exists. If yes, show its current content and ask: "Want me to revise this, or start fresh?"
3. Read the project to understand context: scan directory structure, relevant source files, existing patterns, dependencies. Focus on what's most relevant to implementing this item.
4. Draft a detail file using the `_template.md` structure, filled in based on the project context:
   - **Goal**: what done looks like for this specific item
   - **Approach**: concrete implementation path given the actual codebase — files to change, patterns to follow, decisions to make
   - **Acceptance criteria**: specific, checkable outcomes
   - **Sub-tasks**: ordered steps to get there
   - **Notes**: risks, open questions, relevant links
5. Show the draft and ask: "Does this look right? I'll write it once you confirm."
6. On confirmation, write the file. Create `docs/roadmap/` if it doesn't exist.

**Other natural language** (e.g. "when will X be done?", "what are we building?", "remind me why we're doing Y")
Answer using the roadmap and any relevant detail files as context. If the answer can't be inferred, say so honestly.

When writing back to ROADMAP.md, preserve all existing lines exactly — only modify the targeted item's state marker or append a new line.
