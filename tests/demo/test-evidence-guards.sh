#!/bin/sh
# Offline regressions: no Docker mutation, no real log deletion, no HTTP.
set -eu
repo=$(cd "$(dirname "$0")/../.." && pwd)
suite=$(mktemp -d)
trap 'rm -rf "$suite"' EXIT
mkdir -p "$suite/logs/backend-node-1" "$suite/logs/backend-node-2" "$suite/bin"
printf 'unrelated log\n' > "$suite/logs/backend-node-1/audit.log"
printf 'unrelated log\n' > "$suite/logs/backend-node-2/audit.log"
common="$repo/tests/demo/common.sh"
RID=0123456789abcdef0123456789abcdef
export ROOT="$suite"
expect_failure() {
    if "$@" > "$suite/result" 2>&1; then
        echo "FAIL: expected missing evidence to fail" >&2; exit 1
    fi
}
# An unrelated but readable log legitimately proves zero occurrences.
[ "$(sh -c '. "$1"; backend_count "$2"' sh "$common" "$RID")" = 0 ]
# Missing one log, an empty log and an empty RID must not turn into count0.
mv "$suite/logs/backend-node-1/audit.log" "$suite/saved-log"
expect_failure sh -c '. "$1"; backend_count "$2"' sh "$common" "$RID"
mv "$suite/saved-log" "$suite/logs/backend-node-1/audit.log"
: > "$suite/logs/backend-node-1/audit.log"
expect_failure sh -c '. "$1"; backend_count "$2"' sh "$common" "$RID"
printf 'unrelated log\n' > "$suite/logs/backend-node-1/audit.log"
expect_failure sh -c '. "$1"; backend_count ""' sh "$common"
expect_failure sh -c '. "$1"; require_backend_received "$2"' sh "$common" "$RID"
printf '[reqId=%s] received\n' "$RID" >> "$suite/logs/backend-node-1/audit.log"
sh -c '. "$1"; require_backend_received "$2"' sh "$common" "$RID"
# Unknown Docker/absent mode is an error; explicit On/DetectionOnly are reported.
printf '#!/bin/sh\nexit 1\n' > "$suite/bin/docker"
chmod +x "$suite/bin/docker"
expect_failure env PATH="$suite/bin:$PATH" sh "$repo/scripts/waf-mode.sh"
printf '#!/bin/sh\nprintf \"missing engine directive\\n\"\n' > "$suite/bin/docker"
expect_failure env PATH="$suite/bin:$PATH" sh "$repo/scripts/waf-mode.sh"
printf '#!/bin/sh\nprintf \"SecRuleEngine On\\n\"\n' > "$suite/bin/docker"
env PATH="$suite/bin:$PATH" sh "$repo/scripts/waf-mode.sh" | grep -q 'chế độ: On'
printf '#!/bin/sh\nprintf \"SecRuleEngine On\\nSecRuleEngine DetectionOnly\\n\"\n' > "$suite/bin/docker"
env PATH="$suite/bin:$PATH" sh "$repo/scripts/waf-mode.sh" | grep -q 'chế độ: DetectionOnly'
echo "PASS: 10 evidence/mode guard cases; missing evidence fails closed."
