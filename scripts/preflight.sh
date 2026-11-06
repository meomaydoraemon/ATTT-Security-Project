#!/bin/sh
# Kiểm tra nhanh trước khi trình bày / chấm bài. Chạy từ thư mục gốc repo (Git Bash):
#   sh scripts/preflight.sh
# In [PASS] / [WARN] / [FAIL] cho từng mục kèm cách sửa. Thoát mã 1 nếu có mục FAIL.
# Chỉ đọc trạng thái, không sửa gì (ngoại lệ: 1 lần đăng nhập thử và 1 request XSS mẫu để kiểm tra WAF).
set -u
cd "$(dirname "$0")/.."
CA=nginx/certs/server.crt
HDR=$(mktemp)
trap 'rm -f "$HDR"' EXIT
# Git Bash: không đổi "/etc/..." thành "C:/Program Files/Git/etc/..." khi truyền vào container.
# Chỉ áp cho lệnh docker exec; curl trên Windows vẫn cần Git Bash đổi đường dẫn file tạm.
dexec() { MSYS_NO_PATHCONV=1 docker compose exec -T "$@"; }
http() { curl -sS --connect-timeout 3 --max-time 15 "$@"; }
P=0; W=0; F=0
pass() { P=$((P+1)); printf '  [PASS] %s\n' "$1"; }
warn() { W=$((W+1)); printf '  [WARN] %s\n         -> %s\n' "$1" "$2"; }
fail() { F=$((F+1)); printf '  [FAIL] %s\n         -> %s\n' "$1" "$2"; }
info() { printf '  [INFO] %s\n' "$1"; }
envval() { grep "^$1=" .env 2>/dev/null | head -1 | cut -d= -f2-; }
port=${HTTPS_PORT:-$(envval HTTPS_PORT | tr -d '\r')}
BASE=${BASE:-https://localhost:${port:-443}}
lab_port=${LAB_HTTPS_PORT:-$(envval LAB_HTTPS_PORT | tr -d '\r')}
LAB_BASE=${LAB_BASE:-https://localhost:${lab_port:-9443}}
for b in "$BASE" "$LAB_BASE"; do
    printf '%s\n' "$b" | grep -Eq '^https://(localhost|127[.]0[.]0[.]1)(:[0-9]{1,5})?$' \
        || { echo "BASE/LAB_BASE phải là HTTPS loopback." >&2; exit 2; }
done

echo "== Máy và Docker"
if docker info >/dev/null 2>&1; then pass "Docker đang chạy"; else
    fail "Không kết nối được Docker" "Mở Docker Desktop, chờ biểu tượng chuyển xanh rồi chạy lại"; echo; echo "Kết quả: $P PASS, $W WARN, $F FAIL"; exit 1; fi
images=$(docker compose images -q 2>/dev/null)
[ -n "$images" ] || warn "Chưa đọc được image của project hiện tại" "Kiểm tra Compose project và dựng hệ thống."
for img in $images; do
    if docker image inspect "$img" >/dev/null 2>&1; then pass "Có sẵn image ${img%%@*}"; else
        warn "Chưa có image ${img%%@*} trên máy" "Lần dựng tới cần Internet: chạy 'docker compose up -d --build --wait' trước buổi trình bày"; fi
done

echo "== Cấu hình"
if [ -f .env ]; then
    miss=""; for k in DB_ADMIN_PASSWORD APP_DB_USERNAME APP_DB_PASSWORD JWT_SECRET SQLI_LAB_READER_PASSWORD \
                      LAB_JWT_SECRET LAB_DB_ADMIN_PASSWORD LAB_APP_DB_PASSWORD LAB_SQLI_READER_PASSWORD; do
        [ -n "$(envval $k)" ] || miss="$miss $k"; done
    if [ -z "$miss" ]; then pass ".env có đủ biến"; else fail ".env thiếu:$miss" "Bổ sung theo .env.example; giữ secrets tương ứng dữ liệu hiện có, không xóa volume."; fi
    [ "$(envval APP_DB_PASSWORD | tr -d '\r' | wc -c)" -ge 24 ] && pass "APP_DB_PASSWORD đủ 24 ký tự" \
        || fail "APP_DB_PASSWORD ngắn hơn 24 ký tự" "Sinh lại .env bằng scripts/init-env.sh"
    jb=$(envval JWT_SECRET | tr -d '\r' | openssl base64 -d -A 2>/dev/null | wc -c)
    [ "$jb" -ge 32 ] && pass "JWT_SECRET là Base64 của $jb byte" \
        || fail "JWT_SECRET không phải Base64 >= 32 byte (backend sẽ không khởi động)" "Sinh lại .env bằng scripts/init-env.sh"
    grep -q '^WAF_MODE=' .env && info "WAF_MODE trong .env đã ngừng dùng: prod luôn On, lab đổi bằng scripts/waf-mode.sh lab"
    grep -q '^SQLI_DEMO_ENABLED=' .env && info "SQLI_DEMO_ENABLED trong .env đã ngừng dùng (không service nào đọc); có thể xóa dòng này"
else
    fail "Chưa có file .env" "Chạy: sh scripts/init-env.sh"
fi
if [ -f "$CA" ] && [ -f nginx/certs/server.key ]; then
    if openssl x509 -in "$CA" -noout -checkend 604800 >/dev/null 2>&1; then pass "Chứng chỉ còn hạn trên 7 ngày"; else
        warn "Chứng chỉ hết hạn trong 7 ngày tới" "FORCE=1 sh nginx/certs/generate-cert.sh rồi 'docker compose restart nginx-waf'"; fi
else
    fail "Chưa có chứng chỉ" "Chạy: sh nginx/certs/generate-cert.sh"
fi
if [ -d logs/nginx ] && [ -d logs/waf ] && [ -d logs/backend-node-1 ] && [ -d logs/backend-node-2 ] && [ -d logs/lab-backend ]; then pass "Có đủ thư mục logs/"; else
    warn "Thiếu thư mục logs/" "Chạy: sh scripts/init-env.sh (bắt buộc trên Linux)"; fi

echo "== Hệ thống đang chạy"
st=$(docker compose ps --format '{{.Service}}={{.Health}}' 2>/dev/null)
bad=""; for s in nginx-waf backend-node-1 backend-node-2 database; do
    echo "$st" | grep -qx "$s=healthy" || bad="$bad $s"; done
if [ -n "$bad" ]; then
    fail "Container chưa healthy:$bad" "Đọc docker compose logs và cấu hình; nếu cần lab sạch hãy dùng project/volume mới, không xóa dữ liệu project khác."
    echo; echo "Kết quả: $P PASS, $W WARN, $F FAIL"; exit 1
fi
pass "4 container healthy"
LAB_RESTORE="sh scripts/waf-mode.sh lab On"
if mode=$(sh scripts/waf-mode.sh 2>/dev/null); then
    case "$mode" in *"WAF prod: On"*) pass "Cấu hình WAF prod: On" ;; *) fail "Cấu hình WAF prod không phải On" "Kiểm tra nginx/modsecurity/modsecurity.conf" ;; esac
    case "$mode" in
        *"WAF lab: On"*) pass "Cấu hình WAF lab: On" ;;
        *"WAF lab: DetectionOnly"*) fail "WAF lab đang DetectionOnly ngoài Demo 3 (thường do Demo 3 bị ngắt cứng)" "Chạy: $LAB_RESTORE" ;;
        *) fail "Không xác định được WAF lab" "Chạy: $LAB_RESTORE" ;;
    esac
else
    fail "Không đọc được WAF mode" "Kiểm tra Docker/container; không suy diễn thành On."
fi
for n in backend-node-1 backend-node-2; do
    case "$(dexec $n printenv SQLI_DEMO_ENABLED | tr -d '\r')" in
        false) pass "$n: API cố ý lỗi tắt (SQLI_DEMO_ENABLED=false)" ;;
        true) fail "$n: API cố ý lỗi đang BẬT trên node prod" "Node prod phải có SQLI_DEMO_ENABLED=false (docker-compose.yml); dựng lại: docker compose up -d --wait" ;;
        *) fail "$n: không đọc được SQLI_DEMO_ENABLED" "Kiểm tra container và docker-compose.yml." ;;
    esac
    case ",$(dexec $n printenv SPRING_PROFILES_ACTIVE | tr -d '\r')," in
        *,sqli-lab,*) fail "$n: profile prod có sqli-lab" "Node prod chỉ dùng profile integration" ;;
        ,,) fail "$n: không đọc được SPRING_PROFILES_ACTIVE" "Kiểm tra container." ;;
        *) pass "$n: profile không chứa sqli-lab" ;;
    esac
done
if MSYS_NO_PATHCONV=1 docker exec nginx-waf nginx -t >/dev/null 2>&1; then pass "nginx -t: cấu hình Nginx hợp lệ"; else
    fail "nginx -t báo lỗi cấu hình" "Chạy: docker exec nginx-waf nginx -t để xem chi tiết"; fi

db_prod() { dexec database psql -U postgres_admin -d blogdb -tAc "$1" 2>/dev/null | tr -d '\r'; }

echo "== Lab (profile lab: lab-db, lab-backend)"
lab_st=""; for c in lab-db lab-backend; do
    lab_st="$lab_st $(docker inspect -f '{{.State.Health.Status}}' "$c" 2>/dev/null || echo absent)"; done
case "$lab_st" in
    " healthy healthy")
        pass "2 container lab healthy"
        labdb() { MSYS_NO_PATHCONV=1 docker exec lab-db psql -U postgres_admin -d blogdb -tAc "$1" 2>/dev/null | tr -d '\r'; }
        [ "$(labdb "select 1 from pg_database where datname='sqli_lab'")" = 1 ] && pass "lab-db có database sqli_lab cho cụm /vuln" \
            || fail "lab-db thiếu database sqli_lab" "Tạo lại lab: sh scripts/lab.sh reset"
        case "$(labdb "select status || '|' || title from posts where id = 3")" in
            "DRAFT|Bản nháp bí mật của User A") pass "Dữ liệu lab còn nguyên (bài 3 là nháp gốc của User A)" ;;
            "") warn "lab-db không còn bài 3 (đã bị xóa)" "Demo 4 cần bài 3: sh scripts/lab.sh reset" ;;
            *) warn "Bài 3 của lab đã bị sửa (thường do chạy demo IDOR)" "Về dữ liệu gốc: sh scripts/lab.sh reset" ;;
        esac
        s=$(http --cacert "$CA" -o /dev/null -D "$HDR" -w '%{http_code}' "$LAB_BASE/api/v1/posts/search?q=%3Cscript%3Ealert(1)%3C%2Fscript%3E")
        [ "$s" = 403 ] && grep -qi '^x-blocked-by: waf' "$HDR" && pass "Runtime: WAF lab chặn request XSS mẫu (403, X-Blocked-By: waf)" \
            || fail "Runtime: WAF lab không chặn request XSS mẫu (HTTP $s)" "Chạy: $LAB_RESTORE"
        sh_hash() { MSYS_NO_PATHCONV=1 docker exec "$1" sh -c 'test -n "${JWT_SECRET:-}" && printf %s "$JWT_SECRET"' 2>/dev/null | sha256sum | cut -d' ' -f1; }
        hp=$(sh_hash backend-node-1); hl=$(sh_hash lab-backend); empty=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
        if [ "$hp" != "$empty" ] && [ "$hl" != "$empty" ] && [ "$hp" != "$hl" ]; then pass "JWT secret prod và lab khác nhau"; else
            fail "JWT secret prod và lab giống nhau hoặc thiếu" "Đặt LAB_JWT_SECRET khác JWT_SECRET trong .env rồi: sh scripts/lab.sh reset"; fi
        ;;
    " absent absent") warn "Lab đang tắt (Demo 2, 3, 4, 6 cần lab)" "Bật lab: sh scripts/lab.sh up" ;;
    *) fail "Lab chưa healthy:$lab_st (lab-db lab-backend)" "Xem: docker compose --profile lab logs lab-db lab-backend; tạo lại: sh scripts/lab.sh reset" ;;
esac

echo "== Qua Nginx ($BASE)"
nodes=""; ok=0
for i in 1 2 3 4; do
    s=$(http --cacert "$CA" -o /dev/null -D "$HDR" -w '%{http_code}' "$BASE/actuator/health")
    [ "$s" = 200 ] && ok=$((ok+1)); nodes="$nodes $(grep -i '^x-upstream' "$HDR" | tr -d '\r' | cut -d' ' -f2)"
done
[ "$ok" = 4 ] && pass "HTTPS qua Nginx trả 200 (chứng chỉ hợp lệ)" || fail "HTTPS qua Nginx lỗi ($ok/4 lần 200)" "Xem logs/nginx/error.log"
[ "$(echo $nodes | tr ' ' '\n' | sort -u | grep -c .)" -ge 2 ] && pass "Cả 2 node backend đang nhận request" \
    || warn "Chỉ 1 node nhận request" "Có thể một node đang tắt (sau Demo 1): docker compose start backend-node-1"
s=$(http --cacert "$CA" -o /dev/null -D "$HDR" -w '%{http_code}' "$BASE/api/v1/posts/search?q=%3Cscript%3Ealert(1)%3C%2Fscript%3E")
[ "$s" = 403 ] && grep -qi '^x-blocked-by: waf' "$HDR" && pass "Runtime: WAF prod chặn request XSS mẫu (403, X-Blocked-By: waf)" \
    || fail "Runtime: WAF prod không chặn request XSS mẫu (HTTP $s)" "Xem: sh scripts/waf-mode.sh và docker exec nginx-waf nginx -t"
s=$(http --cacert "$CA" -o /dev/null -w '%{http_code}' -X POST "$BASE/api/v1/auth/login" -H 'Content-Type: application/json' -d '{"username":"user_a","password":"UserA@Nhom9-2026"}')
case "$s" in
    200) pass "Đăng nhập user_a thành công" ;;
    429) warn "Đăng nhập prod đang bị rate limit (429)" "Chờ khoảng 1 phút (5 lần/phút mỗi IP) rồi chạy lại preflight" ;;
    401)
        # Chỉ đọc: user seed còn trong DB prod không? Không đề xuất xóa volume.
        case "$(db_prod "select count(*) from users where username='user_a' and enabled")" in
            1) fail "Đăng nhập user_a trên prod bị 401: user còn nhưng mật khẩu không khớp seed" "Kiểm tra mật khẩu trong database/init/03-seed-data.sql; không xóa volume DB prod" ;;
            0) fail "Đăng nhập user_a trên prod bị 401: DB prod không có user seed user_a (hoặc bị khóa)" "Kiểm tra bảng users trong DB prod (chỉ đọc); không xóa volume DB prod" ;;
            *) fail "Đăng nhập user_a trên prod bị 401, không đọc được DB prod" "Xem: docker compose ps database" ;;
        esac ;;
    5*|000) fail "Đăng nhập user_a trên prod lỗi HTTP $s (backend/Nginx không phản hồi)" "Xem: docker compose ps và docker compose logs --tail 50 backend-node-1 backend-node-2 nginx-waf" ;;
    *) fail "Đăng nhập user_a trên prod lỗi HTTP $s" "Xem: docker compose logs --tail 50 backend-node-1 backend-node-2" ;;
esac

echo; echo "Kết quả: $P PASS, $W WARN, $F FAIL"
[ "$F" -eq 0 ]
