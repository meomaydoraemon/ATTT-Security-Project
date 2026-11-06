#!/bin/sh
# Chứng minh runtime: WAF prod luôn On; chỉ listener lab đổi được On <-> DetectionOnly.
# Mỗi kết luận đối chiếu theo X-Request-ID: (1) status + X-Blocked-By, (2) audit WAF cùng unique_id
# (is_interrupted), (3) backend của đúng môi trường có nhận request hay không.
# Request đối chứng tới route được proxy xuống backend: payload SQLi của Demo 3 vào
# POST /api/v1/secure/records/search (có token của chính môi trường đó).
# Cần: prod + lab đang chạy, lab đang On. Script luôn trả lab về On khi thoát.
. "$(dirname "$0")/common.sh"
PAYLOAD="' OR '1'='1"
LOAD_PID=""
cleanup() {
    code=$?; trap - EXIT
    [ -n "$LOAD_PID" ] && kill "$LOAD_PID" 2>/dev/null || true
    sh "$ROOT/scripts/waf-mode.sh" lab On >/dev/null || { echo "FAIL: không trả lab về On." >&2; code=1; }
    rm -rf "$TMP"; exit "$code"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# probe ENV BASE TOKEN BODY -> đặt S (status), BLK (X-Blocked-By), RID
probe() {
    S=$(req_on "$2" POST /api/v1/secure/records/search "$3" "$4"); BLK=$(header X-Blocked-By); RID=$(last_rid)
}
# interrupted RID -> true|false từ audit WAF (thiếu bản ghi là lỗi đo, không phải false)
interrupted() {
    sleep 1
    waf_audit "$1" | grep -o '"is_interrupted":[a-z]*' | head -1 | cut -d: -f2
}
# expect_blocked ENV BASE TOKEN MÔ_TẢ
expect_blocked() {
    probe "$1" "$2" "$3" "{\"keyword\":\"$PAYLOAD\"}"
    check "$4: status" 403 "$S"; check "$4: X-Blocked-By" waf "$BLK"
    check "$4: audit is_interrupted" true "$(interrupted "$RID")"
    check "$4: backend $1 không nhận request" 0 "$(backend_count "$RID" "$1")"
}
# expect_detected_passed ENV BASE TOKEN MÔ_TẢ
expect_detected_passed() {
    probe "$1" "$2" "$3" "{\"keyword\":\"$PAYLOAD\"}"
    check "$4: status (WAF cho qua)" 200 "$S"; check "$4: X-Blocked-By" "" "$BLK"
    check "$4: audit có phát hiện, is_interrupted" false "$(interrupted "$RID")"
    check "$4: backend $1 nhận request" 1 "$(backend_count "$RID" "$1")"
}
# benign ENV BASE TOKEN: kiểm tra dương, request lành tính tới backend của đúng môi trường
benign() {
    probe "$1" "$2" "$3" '{"keyword":"alpha"}'; sleep 1
    check "Kiểm tra dương $1: request lành tính" 200 "$S"
    check "Kiểm tra dương $1: backend nhận request" 1 "$(backend_count "$RID" "$1")"
}

title "WAF theo listener: chuẩn bị"
[ "$(sh "$ROOT/scripts/waf-mode.sh" | tr '\n' ' ')" = "WAF prod: On WAF lab: On " ] || fatal "Lab phải đang On trước khi đo."
TP=$(login_on "$PROD_BASE" "$USER_A" "$PASS_A") || exit 1
TL=$(login_on "$LAB_BASE" "$USER_A" "$PASS_A") || exit 1
benign prod "$PROD_BASE" "$TP"
benign lab "$LAB_BASE" "$TL"

title "Bước 0: cả hai On -> cả hai chặn"
expect_blocked prod "$PROD_BASE" "$TP" "Prod On"
expect_blocked lab "$LAB_BASE" "$TL" "Lab On"

title "Bước 1: lab -> DetectionOnly, prod nhận tải lành tính liên tục (<= 4 req/s)"
LOAD="$TMP/load.codes"; : > "$LOAD"
( while :; do curl -s -o /dev/null --cacert "$CA" --max-time 5 -w '%{http_code}\n' "$PROD_BASE/api/v1/posts" >> "$LOAD"; sleep 0.25; done ) &
LOAD_PID=$!
sleep 2
sh "$ROOT/scripts/waf-mode.sh" lab DetectionOnly | sed 's/^/  /'
check "waf-mode báo prod/lab" "WAF prod: On WAF lab: DetectionOnly " "$(sh "$ROOT/scripts/waf-mode.sh" | tr '\n' ' ')"

title "Bước 2: lab DetectionOnly -> lab cho qua và ghi nhận; prod VẪN chặn"
expect_detected_passed lab "$LAB_BASE" "$TL" "Lab DetectionOnly"
expect_blocked prod "$PROD_BASE" "$TP" "Prod khi lab DetectionOnly"

title "Bước 3: lab -> On, lab chặn lại"
sh "$ROOT/scripts/waf-mode.sh" lab On | sed 's/^/  /'
expect_blocked lab "$LAB_BASE" "$TL" "Lab On trở lại"
expect_blocked prod "$PROD_BASE" "$TP" "Prod sau khi lab On"
sleep 2
kill "$LOAD_PID" 2>/dev/null || true; wait "$LOAD_PID" 2>/dev/null || true; LOAD_PID=""

title "Bước 4: prod không gián đoạn trong lúc đổi chế độ lab"
TOTAL=$(grep -c . "$LOAD" || true); NON200=$(grep -vc '^200$' "$LOAD" || true)
note "tải lành tính prod: $TOTAL request, mã khác 200: $(grep -v '^200$' "$LOAD" | sort | uniq -c | tr '\n' ' ')"
[ "$TOTAL" -ge 10 ] || fatal "Tải nền quá ít request ($TOTAL) để kết luận."
check "Request lành tính prod khác 200 khi đổi chế độ lab" 0 "$NON200"

summary
