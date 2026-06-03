#!/usr/bin/env bash
# Prepends "source ~/.env.local" to every bash command so worker tools
# (ask-kimi, kimi-write, extract-chat) have WORKER_API_KEY etc. available.
# Safe to commit — contains no secrets; ~/.env.local is private.

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT")

if [ -z "$CMD" ]; then
  exit 0
fi

jq -c --arg cmd "source ~/.env.local 2>/dev/null; $CMD" \
  '.tool_input.command = $cmd | {hookSpecificOutput: {hookEventName: "PreToolUse", updatedInput: .tool_input}}' <<<"$INPUT"
