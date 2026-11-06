#!/bin/sh
# Chế độ WAF theo listener. Chạy từ thư mục gốc repo (Git Bash):
#   sh scripts/waf-mode.sh                    # xem chế độ của prod và lab
#   sh scripts/waf-mode.sh lab DetectionOnly  # chỉ listener lab không chặn (Demo 3)
#   sh scripts/waf-mode.sh lab On             # lab chặn lại (mặc định)
# Listener prod luôn On: không có lệnh, biến hay file nào đổi được chế độ prod.
# Đổi chế độ lab bằng file override trên tmpfs trong nginx-waf rồi `nginx -t` + reload (không tạo lại
# container, prod không gián đoạn). Thiếu file hoặc container khởi động lại thì lab về On.
set -eu
cd "$(dirname "$0")/.."

OVERRIDE=/etc/nginx/waf-lab/lab-mode.conf
nx() { MSYS_NO_PATHCONV=1 docker compose exec -T nginx-waf "$@"; }

# In "PROD LAB": prod = SecRuleEngine cuối trong modsecurity.conf (chuỗi luật duy nhất của prod),
# lab = chuỗi của prod cộng override của lab. Lỗi đọc không bao giờ được suy ra On.
modes() {
    config=$(nx sh -c 'cat /etc/nginx/modsecurity/modsecurity.conf && echo "#--LAB--" && { cat /etc/nginx/waf-lab/*.conf 2>/dev/null || true; }') \
        || { echo "Không đọc được cấu hình WAF thực tế." >&2; return 1; }
    printf '%s\n' "$config" | awk '
        /^#--LAB--$/ { lab_part = 1; next }
        { line = $0; sub(/#.*/, "", line) }
        match(line, /SecRuleEngine[ \t]+[A-Za-z]+/) {
            v = substr(line, RSTART, RLENGTH); sub(/SecRuleEngine[ \t]+/, "", v)
            if (lab_part) lab = v; else { prod = v; lab = v }
        }
        END { print (prod == "" ? "?" : prod), (lab == "" ? "?" : lab) }'
}
valid() { case "$1" in On|DetectionOnly) return 0 ;; *) return 1 ;; esac; }

show() {
    m=$(modes) || return 1
    set -- $m
    valid "$1" && valid "$2" || { echo "Không xác định được SecRuleEngine (prod=$1, lab=$2)." >&2; return 1; }
    echo "WAF prod: $1"
    echo "WAF lab: $2"
    [ "$1" = On ] || { echo "LỖI: prod phải luôn On." >&2; return 1; }
}

case "${1:-}" in
    "")
        show ;;
    lab)
        case "${2:-}" in
            DetectionOnly)
                nx sh -c "printf '%s\n' \"modsecurity_rules 'SecRuleEngine DetectionOnly';\" > $OVERRIDE" ;;
            On)
                nx rm -f "$OVERRIDE" ;;
            *) echo "Giá trị không hợp lệ: ${2:-} (chỉ nhận On hoặc DetectionOnly)" >&2; exit 2 ;;
        esac
        # Cấu hình mới phải hợp lệ mới reload; sai thì gỡ override (lab về On) và giữ cấu hình đang chạy.
        if ! nx nginx -t >/dev/null 2>&1; then
            nx rm -f "$OVERRIDE" || true
            echo "LỖI: nginx -t từ chối cấu hình mới; đã gỡ override, cấu hình đang chạy giữ nguyên." >&2
            exit 1
        fi
        nx nginx -s reload >/dev/null
        sleep 2   # worker mới nạp lại CRS; đo xác nhận ở tests/demo/waf-listener-proof.sh
        show
        [ "$(modes | cut -d' ' -f2)" = "$2" ] || { echo "LỖI: chưa đổi được lab sang $2" >&2; exit 1; }
        [ "$2" = On ] || echo "CẢNH BÁO: listener lab chỉ ghi log, KHÔNG chặn. Xong Demo 3 chạy: sh scripts/waf-mode.sh lab On" ;;
    *)
        echo "Dùng: sh scripts/waf-mode.sh [lab On|DetectionOnly]  (prod luôn On, không đổi được)" >&2
        exit 2 ;;
esac
