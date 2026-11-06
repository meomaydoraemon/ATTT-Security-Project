#!/bin/sh
# Demo 3 - Phòng thủ chiều sâu tại CSDL (Defense in Depth).
# Chủ động chuyển WAF của RIÊNG listener lab sang DetectionOnly (chỉ ghi log, không chặn) để đo các lớp sau;
# listener prod vẫn On suốt demo (có assertion kiểm chứng). Payload lọt vào backend lab. So sánh:
#   - cụm lỗi /api/v1/vuln (nối chuỗi)             -> payload đổi câu SQL, lộ toàn bộ dữ liệu giả
#   - cụm vá  /api/v1/secure (Parameterized Query) -> payload chỉ là chuỗi thường, không lộ gì
# Script tự trả lab về On khi kết thúc, kể cả khi bị Ctrl+C/TERM. Bị kill -9 thì preflight/run-all phát hiện.
DEMO_TARGET=lab   # listener lab (https://localhost:9443), log từ lab-backend
. "$(dirname "$0")/common.sh"
PAYLOAD="' OR '1'='1"

restore_waf() { sh "$ROOT/scripts/waf-mode.sh" lab On; }
cleanup() {
    code=$?; trap - EXIT
    if ! restore_waf; then echo "FAIL: không trả WAF lab về On. Chạy: sh scripts/waf-mode.sh lab On" >&2; code=1; fi
    rm -rf "$TMP"; exit "$code"
}

title "Demo 3: Defense in Depth"
title "Bước 1: thí nghiệm không chặn tại WAF của listener lab -> DetectionOnly"
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
sh "$ROOT/scripts/waf-mode.sh" lab DetectionOnly

TA=$(login "$USER_A" "$PASS_A") || exit 1

title "Bước 2: payload lọt vào cụm LỖI /api/v1/vuln/records/search"
s=$(req POST /api/v1/vuln/records/search "$TA" "{\"keyword\":\"$PAYLOAD\"}")
ROWS=$(body | grep -o '"id"' | wc -l | tr -d ' ')
note "HTTP $s, X-Blocked-By: '$(header X-Blocked-By)', số dòng trả về: $ROWS"
note "body: $(body)"
check "WAF không chặn (đang DetectionOnly)" 200 "$s"
check "SQLi thành công ở bản lỗi: lộ cả 3 dòng thay vì 0" 3 "$ROWS"

title "Bước 3: cùng payload vào cụm VÁ /api/v1/secure/records/search"
s=$(req POST /api/v1/secure/records/search "$TA" "{\"keyword\":\"$PAYLOAD\"}"); RID=$(last_rid)
note "HTTP $s, body: $(body)"
check "Backend nhận request (WAF không chặn)" 200 "$s"
check "Parameterized Query: payload là chuỗi literal, không khớp Record nào" "[]" "$(body)"

title "Bước 4: SQLi ở bản lỗi KHÔNG chạm được bảng users của blogdb (database riêng)"
s=$(req POST /api/v1/vuln/records/search "$TA" "{\"keyword\":\"x' UNION SELECT id, username FROM public.users --\"}")
note "UNION sang public.users -> HTTP $s, body: $(body)"
check "Bảng users không có trong datasource lab (cần thêm ACL evidence)" 400 "$s"

title "Bước 5: WAF vẫn ghi nhận tấn công dù không chặn (bằng chứng cho đội vận hành)"
sleep 1
s=$(req POST /api/v1/secure/records/search "$TA" "{\"keyword\":\"$PAYLOAD\"}"); RID=$(last_rid); sleep 1
ENTRY=$(waf_audit "$RID")
note "is_interrupted: $(echo "$ENTRY" | grep -o '"is_interrupted":[a-z]*' | cut -d: -f2)"
note "luật đã khớp: $(echo "$ENTRY" | grep -o '"ruleId":"[0-9]*"' | cut -d'"' -f4 | sort -u | tr '\n' ' ')"
check "Audit log có bản ghi phát hiện" 1 "$(echo "$ENTRY" | grep -c unique_id)"
check "WAF phát hiện nhưng không ngắt request" false "$(echo "$ENTRY" | grep -o '"is_interrupted":[a-z]*' | cut -d: -f2)"
require_backend_received "$RID"

title "Bước 5b: trong lúc lab DetectionOnly, listener PROD vẫn chặn cùng payload"
TP=$(login_on "$PROD_BASE" "$USER_A" "$PASS_A") || exit 1
s=$(req_on "$PROD_BASE" POST /api/v1/secure/records/search "$TP" "{\"keyword\":\"$PAYLOAD\"}"); PRID=$(last_rid)
check "Prod chặn SQLi khi lab DetectionOnly" 403 "$s"
check "403 của prod do WAF" waf "$(header X-Blocked-By)"
sleep 1
check "Audit prod: is_interrupted" true "$(waf_audit "$PRID" | grep -o '"is_interrupted":[a-z]*' | head -1 | cut -d: -f2)"
check "Backend prod không nhận request bị chặn" 0 "$(backend_count "$PRID" prod)"

title "Bước 6: trả WAF lab về chế độ On"
restore_waf
trap 'rm -rf "$TMP"' EXIT
s=$(req POST /api/v1/secure/records/search "$TA" "{\"keyword\":\"$PAYLOAD\"}")
check "WAF chặn lại như bình thường" 403 "$s"

summary
