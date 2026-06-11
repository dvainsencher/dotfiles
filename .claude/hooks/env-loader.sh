#!/usr/bin/env bash
# Prepends "source ~/.env.local" ONLY to commands that invoke a worker tool
# (ask-kimi, kimi-write, extract-chat), so they have WORKER_API_KEY etc. — without
# adding the source to every unrelated command (which is noise and wasted work).
# Safe to commit — contains no secrets; ~/.env.local is private.

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT")

if [ -z "$CMD" ]; then
  exit 0
fi

# Leave commands that don't use a worker tool untouched.
if ! grep -Eq '(ask-kimi|kimi-write|extract-chat)' <<<"$CMD"; then
  exit 0
fi

jq -c --arg cmd "source ~/.env.local 2>/dev/null; $CMD" \
  '.tool_input.command = $cmd | {hookSpecificOutput: {hookEventName: "PreToolUse", updatedInput: .tool_input}}' <<<"$INPUT"
