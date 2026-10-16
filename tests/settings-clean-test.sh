#!/usr/bin/env bash
# Fixture checks for .claude/settings-clean.jq. Run: tests/settings-clean-test.sh
set -euo pipefail
JQ_FILE="$(cd "$(dirname "$0")/.." && pwd)/.claude/settings-clean.jq"
fail=0

check() {
    local name="$1" input="$2" expected="$3" got
    got=$(printf '%s' "$input" | jq -S -c -f "$JQ_FILE") || { echo "FAIL $name: jq error"; fail=1; return; }
    expected=$(printf '%s' "$expected" | jq -S -c .)
    if [[ "$got" == "$expected" ]]; then echo "ok   $name"; else echo "FAIL $name"; echo "  got:      $got"; echo "  expected: $expected"; fail=1; fi
}

O='{"type":"command","command":"sh ~/.orca/agent-hooks/claude-hook.sh"}'
K='{"type":"command","command":"/home/x/keep.sh"}'

check strips-autoMode-and-model '{"model":"opus","autoMode":{"environment":["x"]},"theme":"dark"}' '{"theme":"dark"}'
check drops-orca-only-event "{\"hooks\":{\"Stop\":[{\"hooks\":[$O]}]},\"theme\":\"dark\"}" '{"hooks":{},"theme":"dark"}'
check keeps-other-hooks-same-entry "{\"hooks\":{\"Stop\":[{\"hooks\":[$K,$O]}]}}" "{\"hooks\":{\"Stop\":[{\"hooks\":[$K]}]}}"
check keeps-other-entries "{\"hooks\":{\"Stop\":[{\"hooks\":[$K]},{\"hooks\":[$O]}]}}" "{\"hooks\":{\"Stop\":[{\"hooks\":[$K]}]}}"
check no-hooks-key '{"theme":"dark"}' '{"theme":"dark"}'
check entry-without-hooks-key-kept '{"hooks":{"A":[{"matcher":"x"}]}}' '{"hooks":{"A":[{"matcher":"x"}]}}'
check hook-without-command-kept '{"hooks":{"A":[{"hooks":[{"type":"prompt"}]}]}}' '{"hooks":{"A":[{"hooks":[{"type":"prompt"}]}]}}'

exit $fail
