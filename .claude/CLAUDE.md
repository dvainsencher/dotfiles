@RTK.md

## Workflow

**Branch first**: Before making any code change, propose a branch name and create it. Use prefixes `feat/`, `fix/`, `chore/`. If the planned work spans multiple roadmap items, suggest splitting into separate focused PRs and propose an order based on ROADMAP.md priority.

**Publish on completion**: After finishing a feature or fix, immediately run `/publish` to push, open a PR, get it reviewed, and merge. Do not accumulate uncommitted work.

**Docs check**: The `/publish` workflow includes a documentation review step. Update any docs that describe changed behavior before the PR is created.

**PR review**: The `/publish` workflow includes an automated code review step. If the review finds critical issues, resolve them before merging.
