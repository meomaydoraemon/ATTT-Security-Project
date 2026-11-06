#!/bin/sh
# Quản lý lab tách biệt (profile lab: lab-db + lab-backend). Chạy từ Git Bash ở thư mục gốc repo:
#   sh scripts/lab.sh up       # bật lab (chỉ lab-db, lab-backend), chờ healthy
#   sh scripts/lab.sh down     # dừng và xóa ĐÚNG 2 container lab (dữ liệu lab trên tmpfs mất theo)
#   sh scripts/lab.sh reset    # tạo lại lab-db (nạp lại seed gốc) rồi lab-backend, chờ healthy
#   sh scripts/lab.sh status   # trạng thái lab, listener lab và các container prod
# Không bao giờ dùng `docker compose --profile lab down`: lệnh đó dừng cả các service prod.
# Sau mỗi lệnh, script xác nhận container prod không bị tạo lại hay đổi trạng thái.
set -eu
cd "$(dirname "$0")/.."
PROD="nginx-waf backend-node-1 backend-node-2 database"
LAB_SERVICES="lab-db lab-backend"
lab() { docker compose --profile lab "$@"; }

state_of() {
    _s=$(docker inspect -f '{{.Id}} {{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' "$1" 2>/dev/null) \
        || { echo absent; return 0; }
    printf '%s\n' "$_s" | awk '{print substr($1, 1, 12) "/" $2 "/" $3}'
}
prod_snapshot() { for c in $PROD; do printf '%s=%s ' "$c" "$(state_of "$c")"; done; }
verify_prod() {
    after=$(prod_snapshot)
    if [ "$before" = "$after" ]; then echo "Prod không bị ảnh hưởng: $after"
    else echo "FAIL: trạng thái container prod đã thay đổi." >&2; echo "  trước: $before" >&2; echo "  sau:   $after" >&2; exit 1; fi
}
lab_status() {
    for c in $LAB_SERVICES; do printf '  %-12s %s\n' "$c" "$(state_of "$c")"; done
    port=$(sed -n 's/^LAB_HTTPS_PORT=//p' .env 2>/dev/null | head -1 | tr -d '\r')
    code=$(curl -s -o /dev/null --cacert nginx/certs/server.crt --connect-timeout 3 --max-time 10 \
        -w '%{http_code}' "https://localhost:${port:-9443}/actuator/health" || true)
    echo "  listener lab https://localhost:${port:-9443}/actuator/health -> HTTP $code"
}

before=$(prod_snapshot)
case "${1:-}" in
    up)
        lab up -d --wait --wait-timeout 300 $LAB_SERVICES
        lab_status ;;
    down)
        lab stop lab-backend lab-db
        lab rm -f lab-backend lab-db
        lab_status ;;
    reset)
        start=$(date +%s)
        # lab-db trên tmpfs: tạo lại container là xóa dữ liệu lab và chạy lại database/init (01-04)
        lab up -d --force-recreate --wait --wait-timeout 300 lab-db
        lab up -d --force-recreate --no-deps --wait --wait-timeout 300 lab-backend
        echo "Đã reset lab trong $(( $(date +%s) - start )) giây."
        lab_status ;;
    status)
        lab_status ;;
    *)
        echo "Dùng: sh scripts/lab.sh up|down|reset|status" >&2; exit 2 ;;
esac
verify_prod
