#!/bin/sh
# Đổi chế độ WAF mà không phải sửa .env. Chạy từ thư mục gốc repo (Git Bash):
#   sh scripts/waf-mode.sh               # xem chế độ đang chạy
#   sh scripts/waf-mode.sh DetectionOnly # chủ động không chặn để đo lớp phòng thủ sau
#   sh scripts/waf-mode.sh On            # chặn (mặc định, Demo 2)
# Chỉ khởi động lại container nginx-waf (vài giây); backend và database không bị ảnh hưởng.
set -eu
cd "$(dirname "$0")/.."

current() {
    # Read both effective include files: a failed exec is not evidence of On.
    config=$(MSYS_NO_PATHCONV=1 docker compose exec -T nginx-waf cat \
        /etc/nginx/modsecurity/modsecurity.conf /etc/nginx/modsecurity-mode.conf) \
        || { echo "Không đọc được cấu hình WAF thực tế." >&2; return 1; }
    mode=$(printf '%s\n' "$config" | awk '$1 == "SecRuleEngine" {mode=$2} END {print mode}')
    case "$mode" in On|DetectionOnly) printf '%s\n' "$mode" ;;
        *) echo "Không xác định được SecRuleEngine." >&2; return 1 ;; esac
}

case "${1:-}" in
    "")
        mode=$(current) || exit 1
        echo "WAF đang ở chế độ: $mode" ;;
    On|DetectionOnly)
        WAF_MODE=$1 docker compose up -d --no-deps --force-recreate --wait nginx-waf >/dev/null
        mode=$(current)
        echo "WAF đang ở chế độ: $mode"
        [ "$mode" = "$1" ] || { echo "LỖI: chưa đổi được sang $1"; exit 1; }
        if [ "$mode" = DetectionOnly ]; then
            echo "CẢNH BÁO: WAF chỉ ghi log, KHÔNG chặn. Xong Demo 3 nhớ chạy: sh scripts/waf-mode.sh On"
        fi ;;
    *)
        echo "Giá trị không hợp lệ: $1 (chỉ nhận On hoặc DetectionOnly, phân biệt hoa thường)"
        exit 2 ;;
esac
