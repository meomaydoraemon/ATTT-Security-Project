#!/bin/sh
# Hàm dùng chung cho các script demo. Được `. tests/demo/common.sh` nạp, không chạy trực tiếp.
# Không in mật khẩu, JWT hay refresh token ra màn hình.
set -eu

ROOT=${ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}
cd "$ROOT"
port=${HTTPS_PORT:-$(sed -n 's/^HTTPS_PORT=//p' .env 2>/dev/null | head -1 | tr -d '\r')}
BASE=${BASE:-https://localhost:${port:-443}}
printf '%s\n' "$BASE" | grep -Eq '^https://(localhost|127[.]0[.]0[.]1)(:[0-9]{1,5})?$' \
    || { echo "Demo chỉ được chạy qua HTTPS loopback." >&2; exit 1; }
CA="$ROOT/nginx/certs/server.crt"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Tài khoản thử nghiệm trong database/init/03-seed-data.sql
USER_A=user_a; PASS_A='UserA@Nhom9-2026'
USER_B=user_b; PASS_B='UserB@Nhom9-2026'

PASS_COUNT=0; FAIL_COUNT=0

title() { printf '\n==== %s ====\n' "$*"; }
note()  { printf '  %s\n' "$*"; }

# req METHOD PATH [TOKEN] [JSON_BODY]  -> in mã trạng thái, lưu body/header vào $TMP/body, $TMP/head
req() {
    _m=$1; _p=$2; _t=${3:-}; _d=${4:-}
    set -- -sS --connect-timeout 5 --max-time 15 --cacert "$CA" -X "$_m" -o "$TMP/body" -D "$TMP/head" -w '%{http_code}'
    [ -n "$_t" ] && set -- "$@" -H "Authorization: Bearer $_t"
    [ -n "$_d" ] && set -- "$@" -H 'Content-Type: application/json' --data-binary "$_d"
    curl "$@" "$BASE$_p"
}
header() { grep -i "^$1:" "$TMP/head" | head -1 | cut -d' ' -f2- | tr -d '\r'; }
body()   { cat "$TMP/body"; }

# check MÔ_TẢ KỲ_VỌNG THỰC_TẾ
check() {
    if [ "$2" = "$3" ]; then PASS_COUNT=$((PASS_COUNT+1)); printf '  [PASS] %s: %s\n' "$1" "$3"
    else FAIL_COUNT=$((FAIL_COUNT+1)); printf '  [FAIL] %s: mong đợi %s, nhận %s\n' "$1" "$2" "$3"; fi
}

# login USER PASS -> in access token (thử lại khi gặp rate limit 429 của Nginx).
# Cả cụm /secure và cụm lỗi /vuln đều dùng chung token này (2 node chung JWT secret và CSDL).
login() {
    for _i in 1 2 3 4 5 6; do
        _s=$(req POST /api/v1/auth/login "" "{\"username\":\"$1\",\"password\":\"$2\"}")
        if [ "$_s" = 200 ]; then
            _token=$(sed -n 's/.*"accessToken":"\([^"]*\)".*/\1/p' "$TMP/body")
            [ -n "$_token" ] || fatal "Login 200 nhưng thiếu token."
            printf '%s\n' "$_token"; return 0
        fi
        if [ "$_s" = 429 ]; then sleep 13; continue; fi
        echo "login $1 thất bại: HTTP $_s" >&2; return 1
    done
    echo "login $1: vẫn bị rate limit" >&2; return 1
}

# Mã request ID cuối cùng mà Nginx trả về
fatal() { echo "FAIL: $*" >&2; exit 1; }
require_rid() {
    printf '%s\n' "$1" | grep -Eq '^[0-9a-f]{32}$' || fatal "Request ID thiếu hoặc không hợp lệ."
}
last_rid() { _rid=$(header X-Request-ID); require_rid "$_rid"; printf '%s\n' "$_rid"; }
require_log() { [ -r "$1" ] && [ -s "$1" ] || fatal "Log thiếu, rỗng hoặc không đọc được: $1"; }

# Lệnh trong container nginx-waf. MSYS_NO_PATHCONV: Git Bash không đổi đường dẫn container thành Windows.
waf_exec() { MSYS_NO_PATHCONV=1 docker compose exec -T nginx-waf "$@"; }
# waf_audit RID -> dòng audit log ModSecurity có unique_id = RID
waf_audit() {
    require_rid "$1"
    waf_exec cat /var/log/modsecurity/audit/modsec_audit.log > "$TMP/waf.snapshot" \
        || fatal "Không đọc được WAF audit."
    require_log "$TMP/waf.snapshot"
    grep -F "\"unique_id\":\"$1\"" "$TMP/waf.snapshot" || fatal "Không tìm thấy WAF audit cho request ID."
}

# Log của 2 node backend (gom ở logs/backend-node-*/audit.log), đã bỏ mã màu ANSI
backend_logs() {
    require_log "$ROOT/logs/backend-node-1/audit.log"
    require_log "$ROOT/logs/backend-node-2/audit.log"
    cat "$ROOT/logs/backend-node-1/audit.log" "$ROOT/logs/backend-node-2/audit.log" > "$TMP/backend.raw" \
        || fatal "Không đọc đủ hai log backend."
    sed 's/\x1b\[[0-9;]*m//g' "$TMP/backend.raw"
}
backend_count() {
    require_rid "$1"
    backend_logs > "$TMP/backend.snapshot" || return 1
    awk -v rid="$1" 'index($0, "[reqId=" rid "]") {n++} END {print n+0}' "$TMP/backend.snapshot"
}
require_backend_received() {
    _count=$(backend_count "$1") || fatal "Không đủ bằng chứng backend."
    [ "$_count" -ge 1 ] || fatal "Thiếu positive control trong log backend."
}

# Access log Nginx (gom ở logs/nginx/access.log)
nginx_log() { require_log "$ROOT/logs/nginx/access.log"; cat "$ROOT/logs/nginx/access.log"; }

summary() {
    printf '\nKết quả: %s PASS, %s FAIL\n' "$PASS_COUNT" "$FAIL_COUNT"
    [ "$FAIL_COUNT" -eq 0 ]
}
