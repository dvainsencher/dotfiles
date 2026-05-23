#!/usr/bin/env bash
BRANCH=$(git branch --show-current 2>/dev/null)

if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"WORKFLOW REMINDER: You are on the main branch. Before editing files, you must: (1) propose a branch name based on the planned changes (use feat/, fix/, chore/ prefixes), (2) check the roadmap to suggest the right order if multiple changes are needed, (3) ask the user to confirm the name, (4) run git checkout -b <branch>. If the planned changes span multiple concerns, suggest splitting into separate focused PRs."}}'
fi

exit 0
