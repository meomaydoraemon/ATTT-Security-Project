#!/bin/sh
# Demo 6 - Cô lập lab khỏi production ở chế độ Local.
#   X-01 token chéo môi trường, X-02 prod không có route lab, X-03 lab không chạm được DB prod,
#   INV-01/02 cổng, INV-03 cấu hình node prod, INV-05 secret tách biệt, INV-09 không công khai,
#   INV-10 canary và không lộ token, INV-12 dữ liệu prod không đổi.
# Cần: docker compose up -d --wait và sh scripts/lab.sh up.
# Không in token, mật khẩu hay secret: chỉ in mã HTTP, số lượng, kết quả so sánh và giá trị hash.
. "$(dirname "$0")/common.sh"

dexec() { MSYS_NO_PATHCONV=1 docker exec "$@"; }
# direct NODE METHOD PATH [TOKEN] [JSON]: gọi thẳng cổng 8080 của một node từ trong nginx-waf (bỏ qua Nginx)
direct() {
    _n=$1; _m=$2; _p=$3; _t=${4:-}; _d=${5:-}
    set -- curl -s -o /dev/null -w '%{http_code}' --max-time 5 -X "$_m"
    [ -n "$_t" ] && set -- "$@" -H "Authorization: Bearer $_t"
    [ -n "$_d" ] && set -- "$@" -H 'Content-Type: application/json' --data-binary "$_d"
    dexec nginx-waf "$@" "http://$_n:8080$_p" || true
}
. "$(dirname "$0")/netprobe.sh"   # np_tcp / np_resolves / np_network: được | không | LỖI ĐO
# Hash SHA256 của JWT_SECRET trong container; container thiếu biến thì in EMPTY
secret_hash() {
    _h=$(dexec "$1" sh -c 'test -n "${JWT_SECRET:-}" && printf %s "$JWT_SECRET"' | sha256sum | cut -d' ' -f1) || true
    [ "$_h" = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 ] && _h=EMPTY
    printf '%s\n' "$_h"
}
same() { [ "$1" != EMPTY ] && [ "$1" = "$2" ] && echo "GIỐNG NHAU" || echo "KHÁC NHAU"; }

title "Demo 6: cô lập lab khỏi production"
[ "$(docker inspect -f '{{.State.Health.Status}}' lab-backend 2>/dev/null)" = healthy ] \
    || fatal "Lab chưa chạy hoặc chưa healthy. Bật bằng: sh scripts/lab.sh up"
BEFORE=${PROD_CHECKSUM_BEFORE:-$(sh "$ROOT/tests/demo/prod-checksum.sh")}

title "INV-01/02: chỉ nginx-waf publish cổng, và chỉ trên 127.0.0.1"
for c in nginx-waf backend-node-1 backend-node-2 database lab-backend lab-db; do
    docker port "$c" > "$TMP/ports" 2>/dev/null || fatal "Không đọc được cổng của $c."
    n=$(grep -c . "$TMP/ports" || true)
    bad=$(grep -v -- '-> 127\.0\.0\.1:' "$TMP/ports" | grep -c . || true)
    case $c in
        nginx-waf) check "$c publish 2 cổng, cổng không phải loopback" "2 0" "$n $bad" ;;
        *) check "$c không publish cổng ra host" 0 "$n" ;;
    esac
done

title "INV-03: node prod chỉ có profile integration, flag lab tắt"
for n in backend-node-1 backend-node-2; do
    check "$n SPRING_PROFILES_ACTIVE" integration "$(dexec $n printenv SPRING_PROFILES_ACTIVE | tr -d '\r')"
    check "$n SQLI_DEMO_ENABLED" false "$(dexec $n printenv SQLI_DEMO_ENABLED | tr -d '\r')"
done

title "INV-05: secret ký JWT của lab khác prod (chỉ so hash)"
P1=$(secret_hash backend-node-1); P2=$(secret_hash backend-node-2); L=$(secret_hash lab-backend)
check "JWT secret của 2 node prod" "GIỐNG NHAU" "$(same "$P1" "$P2")"
check "JWT secret prod và lab (runtime)" "KHÁC NHAU" "$( [ "$P1" != EMPTY ] && [ "$L" != EMPTY ] && same "$P1" "$L" || echo 'THIẾU BIẾN')"
EP=$(envval JWT_SECRET | sha256sum | cut -d' ' -f1); EL=$(envval LAB_JWT_SECRET | sha256sum | cut -d' ' -f1)
check "JWT_SECRET và LAB_JWT_SECRET trong .env" "KHÁC NHAU" "$(same "$EP" "$EL")"

title "X-01: token của môi trường này bị môi trường kia từ chối"
TP=$(login_on "$PROD_BASE" "$USER_A" "$PASS_A") || exit 1
TL=$(login_on "$LAB_BASE" "$USER_A" "$PASS_A") || exit 1
check "Token prod gọi prod /posts/me (kiểm tra dương)" 200 "$(req_on "$PROD_BASE" GET /api/v1/posts/me "$TP")"
check "Response không chứa token đã dùng" 0 "$(grep -cF "$TP" "$TMP/body" || true)"
check "Token lab gọi lab /posts/me (kiểm tra dương)" 200 "$(req_on "$LAB_BASE" GET /api/v1/posts/me "$TL")"
check "X-01 token lab gọi prod /posts/me" 401 "$(req_on "$PROD_BASE" GET /api/v1/posts/me "$TL")"
check "Response lỗi không chứa token" 0 "$(grep -cF "$TL" "$TMP/body" || true)"
check "X-01 token prod gọi lab /posts/me" 401 "$(req_on "$LAB_BASE" GET /api/v1/posts/me "$TP")"

title "X-02 / INV-04: prod không có route lab, kể cả với token prod hợp lệ"
check "Gọi thẳng backend-node-1 route thường (kiểm tra dương đường gọi thẳng)" 200 "$(direct backend-node-1 GET /api/v1/posts/1)"
for mp in "GET /api/v1/vuln/posts/3" "PUT /api/v1/vuln/posts/3" "DELETE /api/v1/vuln/posts/3" "POST /api/v1/vuln/records/search"; do
    m=${mp%% *}; p=${mp#* }
    case $m in PUT) d='{"title":"x"}' ;; POST) d='{"keyword":"alpha"}' ;; *) d='' ;; esac
    check "Gateway prod $m $p" 404 "$(req_on "$PROD_BASE" "$m" "$p" "$TP" "$d")"
    for n in backend-node-1 backend-node-2; do
        check "Gọi thẳng $n $m $p" 404 "$(direct "$n" "$m" "$p" "$TP" "$d")"
    done
done
check "Gọi thẳng backend-node-1 GET /api/v1/vuln/posts/3 không token" 404 "$(direct backend-node-1 GET /api/v1/vuln/posts/3)"

title "INV-09: Swagger, OpenAPI, actuator (trừ health) không công khai"
for b in "$PROD_BASE" "$LAB_BASE"; do
    for p in /swagger-ui/index.html /v3/api-docs /actuator/env; do
        check "$b$p" 404 "$(req_on "$b" GET "$p")"
    done
done
for n in backend-node-1 backend-node-2; do
    check "Gọi thẳng $n /v3/api-docs" 404 "$(direct "$n" GET /v3/api-docs)"
done

title "X-03 / INV-06: lab_net cô lập với DB prod (đo trong chính container kiểm tra)"
PROJECT=$(np_project); LAB_NET=$(np_network "$PROJECT" lab_net); PROD_NET=$(np_network "$PROJECT" internal_net)
note "project=$PROJECT lab_net=$LAB_NET internal_net=$PROD_NET"
check "Xác định được network lab/prod qua label của project" "có có"     "$([ -n "$LAB_NET" ] && echo có || echo 'LỖI ĐO') $([ -n "$PROD_NET" ] && echo có || echo 'LỖI ĐO')"
DBIP=$(np_ip database "$PROD_NET"); LABDBIP=$(np_ip lab-db "$LAB_NET")
note "IP database@internal_net=$DBIP, lab-db@lab_net=$LABDBIP"
check "IP database trên internal_net hợp lệ" có "$(np_ipv4 "$DBIP" && echo có || echo 'LỖI ĐO')"
check "IP lab-db trên lab_net hợp lệ" có "$(np_ipv4 "$LABDBIP" && echo có || echo 'LỖI ĐO')"
# Kiểm tra dương và âm cùng container, cùng công cụ
check "Kiểm tra dương: lab-backend phân giải 'lab-db'" được "$(np_resolves lab-backend lab-db)"
check "Kiểm tra dương: lab-backend mở TCP tới lab-db:5432" được "$(np_tcp lab-backend "$LABDBIP" 5432)"
check "X-03a lab-backend phân giải tên 'database'" không "$(np_resolves lab-backend database)"
check "X-03b lab-backend mở TCP tới IP thật của database:5432" không "$(np_tcp lab-backend "$DBIP" 5432)"
check "Kiểm tra dương: backend-node-1 phân giải 'database'" được "$(np_resolves backend-node-1 database)"
check "Kiểm tra dương: backend-node-1 mở TCP tới database:5432" được "$(np_tcp backend-node-1 "$DBIP" 5432)"
check "X-03d backend-node-1 phân giải tên 'lab-db'" không "$(np_resolves backend-node-1 lab-db)"
check "X-03d backend-node-1 mở TCP tới lab-db:5432" không "$(np_tcp backend-node-1 "$LABDBIP" 5432)"
MULTI=""
for c in nginx-waf backend-node-1 backend-node-2 database lab-backend lab-db; do
    nets=$(np_networks "$c")
    [ -n "$nets" ] || nets="LỖI ĐO"
    [ "$(echo $nets | wc -w)" -gt 1 ] && MULTI="$MULTI $c"
    case $c in lab-backend|lab-db) check "X-03c tập network của $c đúng bằng {lab_net}" "${LAB_NET:-?}" "$nets" ;; esac
done
check "X-03c container gắn nhiều mạng" " nginx-waf" "$MULTI"

title "INV-10: mật khẩu và token không lọt vào log"
CANARY="canary$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
for _i in 1 2 3 4 5 6; do
    s=$(req_on "$LAB_BASE" POST /api/v1/auth/login "" "{\"username\":\"$USER_A\",\"password\":\"Wrong-$CANARY\"}")
    [ "$s" = 429 ] && { sleep 13; continue; }; break
done
RID=$(last_rid)
check "Đăng nhập lab với mật khẩu sai chứa canary" 401 "$s"
sleep 1
require_backend_received "$RID" lab
waf_exec cat /var/log/modsecurity/audit/modsec_audit.log > "$TMP/waf.all" || fatal "Không đọc được WAF audit."
{ nginx_log; cat "$TMP/waf.all"; backend_logs lab; backend_logs prod; } > "$TMP/all.log"
check "Chuỗi canary trong log nginx/WAF/backend" 0 "$(grep -cF "$CANARY" "$TMP/all.log" || true)"
check "Mẫu JWT trong log nginx/WAF/backend" 0 "$(grep -cE 'eyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}' "$TMP/all.log" || true)"

title "INV-12: dữ liệu posts/comments của DB prod không đổi sau các demo lab"
AFTER=$(sh "$ROOT/tests/demo/prod-checksum.sh")
note "trước=$BEFORE sau=$AFTER"
check "Checksum dữ liệu prod" "$BEFORE" "$AFTER"

summary
