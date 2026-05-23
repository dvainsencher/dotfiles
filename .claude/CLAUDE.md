@RTK.md

## Workflow

**Branch first**: Before making any code change, propose a branch name and create it. Use prefixes `feat/`, `fix/`, `chore/`. If the planned work spans multiple roadmap items, suggest splitting into separate focused PRs and propose an order based on ROADMAP.md priority.

**Publish on completion**: After finishing a feature or fix, immediately run `/publish` to push, open a PR, get it reviewed, and merge. Do not accumulate uncommitted work.

**Docs check**: The `/publish` workflow includes a documentation review step. Update any docs that describe changed behavior before the PR is created.

**PR review**: The `/publish` workflow includes an automated code review step. If the review finds critical issues, resolve them before merging.

**Bug fix TDD**: When you find a bug, first write a failing test that reproduces it, then fix the code, then run the test again to confirm it's green. Never fix a bug without a test.

**Roadmap sync**: Before opening a PR, mark the corresponding ROADMAP.md item `[x]` and include that change in the feature branch commit so it merges with the work.
