# Clean filter for .claude/settings.json (see .gitattributes and the
# `claude-settings` filter in gitconfig). Strips what the harness, Orca and
# /model write into the live file per session, so git never stores it:
#   - autoMode: harness-generated, local paths and other-repo details
#   - model:    changed per session with /model
#   - hook entries whose command runs ~/.orca/agent-hooks/* (Orca's status
#     reporting); hook events left empty after that are dropped too
del(.autoMode, .model)
| if .hooks then .hooks |= (
    map_values(
      map(.hooks |= map(select((.command // "") | contains(".orca/agent-hooks") | not)))
      | map(select((.hooks | length) > 0))
    ) | with_entries(select(.value | length > 0))
  ) else . end
