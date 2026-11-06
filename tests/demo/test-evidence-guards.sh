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
# Unknown Docker/absent mode is an error; explicit On/DetectionOnly are reported per listener.
# stub_docker EXIT [OUTPUT]: docker giả in OUTPUT rồi thoát EXIT. Không dùng printf với \" (dash không hỗ trợ).
stub_docker() {
    printf '%s
' "${2:-}" > "$suite/bin/docker.out"
    { echo '#!/bin/sh'; echo 'cat "$(dirname "$0")/docker.out"'; echo "exit $1"; } > "$suite/bin/docker"
    chmod +x "$suite/bin/docker"
}
stub_docker 1
expect_failure env PATH="$suite/bin:$PATH" sh "$repo/scripts/waf-mode.sh"
stub_docker 0 "missing engine directive"
expect_failure env PATH="$suite/bin:$PATH" sh "$repo/scripts/waf-mode.sh"
stub_docker 0 "SecRuleEngine On"
env PATH="$suite/bin:$PATH" sh "$repo/scripts/waf-mode.sh" | grep -q 'WAF lab: On'
stub_docker 0 "SecRuleEngine On
#--LAB--
modsecurity_rules 'SecRuleEngine DetectionOnly';"
env PATH="$suite/bin:$PATH" sh "$repo/scripts/waf-mode.sh" | grep -q 'WAF lab: DetectionOnly'
echo "PASS: 10 evidence/mode guard cases; missing evidence fails closed."
