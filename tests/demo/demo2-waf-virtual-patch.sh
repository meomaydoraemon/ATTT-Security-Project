#!/bin/sh
# Demo 2 - Vá ảo tại tầng biên (Virtual Patching / Integrity).
# Endpoint /api/v1/vuln/records/search CÓ LỖI SQLi (nối chuỗi), chỉ có trên lab-backend (listener lab).
# Bật WAF: payload bị chặn 403 tại Nginx, request không tới được code Java, dù code chưa được vá.
# Cần: docker compose up -d, sh scripts/lab.sh up, WAF lab On (sh scripts/waf-mode.sh).
DEMO_TARGET=lab   # listener lab (https://localhost:9443), log từ lab-backend
. "$(dirname "$0")/common.sh"
PAYLOAD="' OR '1'='1"

title "Demo 2: Virtual Patching tại WAF"
TA=$(login "$USER_A" "$PASS_A") || exit 1
note "User A đăng nhập qua Nginx."

title "Bước 1: request bình thường đi qua WAF"
s=$(req POST /api/v1/vuln/records/search "$TA" '{"keyword":"alpha"}')
note "keyword=alpha -> HTTP $s, body: $(body)"
check "Request hợp lệ tới được backend" 200 "$s"
NORMAL_RID=$(last_rid); sleep 1
require_backend_received "$NORMAL_RID"

title "Bước 2: tiêm SQLi  keyword=$PAYLOAD"
s=$(req POST /api/v1/vuln/records/search "$TA" "{\"keyword\":\"$PAYLOAD\"}")
RID=$(last_rid)
note "HTTP $s, X-Blocked-By: $(header X-Blocked-By), rid $RID"
note "body: $(body)"
check "WAF chặn payload SQLi" 403 "$s"
check "Header đánh dấu do WAF chặn (không phải backend)" waf "$(header X-Blocked-By)"

title "Bước 3: bằng chứng trong audit log ModSecurity (unique_id = rid)"
sleep 1
ENTRY=$(waf_audit "$RID")
RULES=$(echo "$ENTRY" | grep -o '"ruleId":"[0-9]*"' | cut -d'"' -f4 | sort -u | tr '\n' ' ')
note "Luật đã khớp: $RULES"
echo "$ENTRY" | grep -o '"message":"[^"]*"' | sort -u | sed 's/^/  /'
case " $RULES " in *" 100100 "*) R=có ;; *) R=không ;; esac
check "Custom rule vá ảo 100100 có trong audit log" có "$R"

title "Bước 4: backend không hề nhận request bị chặn"
N=$(backend_count "$RID")
check "Số dòng log backend có rid của request bị chặn" 0 "$N"

title "Bước 5: OWASP CRS cũng chặn payload này ở route secure (luật chung, không cần biết lỗ hổng)"
s=$(req POST /api/v1/secure/records/search "$TA" "{\"keyword\":\"$PAYLOAD\"}"); RID2=$(last_rid)
check "403 secure do WAF" waf "$(header X-Blocked-By)"
sleep 1
RULES2=$(waf_audit "$RID2" \
    | grep -o '"ruleId":"[0-9]*"' | cut -d'"' -f4 | sort -u | tr '\n' ' ')
note "HTTP $s, luật CRS đã khớp: $RULES2"
check "CRS chặn SQLi ở route secure" 403 "$s"
case " $RULES2 " in *" 942100 "*) R=có ;; *) R=không ;; esac
check "CRS SQLi rule 942100 có evidence" có "$R"
check "Secure SQLi không tới backend" 0 "$(backend_count "$RID2")"

summary
