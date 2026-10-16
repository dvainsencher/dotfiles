# Clean filter for .claude/settings.json (see .gitattributes and the
# `claude-settings` filter in gitconfig). Strips what the harness, Orca and
# /model write into the live file per session, so git never stores it:
#   - autoMode: harness-generated, local paths and other-repo details
#   - model:    changed per session with /model
#   - hook entries whose command runs ~/.orca/agent-hooks/* (Orca's status
#     reporting); an entry left with no hooks, and an event left with no
#     entries, are dropped too. Entries that never had a `hooks` key are kept.
def orca: (.command // "") | contains(".orca/agent-hooks");
def strip_entry:
  if has("hooks") then .hooks |= map(select(orca | not)) else . end;
def emptied: has("hooks") and (.hooks | length) == 0;

del(.autoMode, .model)
| if .hooks then .hooks |= (
    map_values(map(strip_entry) | map(select(emptied | not)))
    | with_entries(select(.value | length > 0))
  ) else . end
