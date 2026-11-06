#!/bin/sh
# Chạy lần lượt mọi demo. Yêu cầu prod và lab đang chạy:
#   docker compose up -d --build --wait
#   sh scripts/lab.sh up
set -eu
# Dùng: sh tests/demo/run-all.sh
cd "$(dirname "$0")"
# Demo 2, 3, 4, 6 cần lab: không chạy được thì báo lỗi rõ ràng, không âm thầm bỏ qua.
for c in lab-db lab-backend; do
    if [ "$(docker inspect -f '{{.State.Health.Status}}' "$c" 2>/dev/null)" != healthy ]; then
        echo "FAIL: $c chưa chạy hoặc chưa healthy. Bật lab: sh scripts/lab.sh up (hoặc reset: sh scripts/lab.sh reset)" >&2
        exit 1
    fi
done
# WAF phải ở trạng thái chuẩn trước khi chạy: prod On (cố định), lab On (chỉ Demo 3 tạm đổi).
if [ "$(sh ../../scripts/waf-mode.sh 2>/dev/null | tr '\n' ' ')" != "WAF prod: On WAF lab: On " ]; then
    echo "FAIL: WAF lab không ở On ngoài Demo 3 (hoặc không đọc được chế độ WAF). Khôi phục: sh scripts/waf-mode.sh lab On" >&2
    exit 1
fi
FAILED=""
sh ./test-evidence-guards.sh
# INV-12: checksum dữ liệu prod trước các demo, Demo 6 so lại ở cuối
PROD_CHECKSUM_BEFORE=$(sh ./prod-checksum.sh)
export PROD_CHECKSUM_BEFORE
for d in demo1-failover demo2-waf-virtual-patch demo3-defense-in-depth demo4-idor demo5-ratelimit-audit demo6-isolation; do
    sh "./$d.sh" || FAILED="$FAILED $d"
done
echo
if [ -z "$FAILED" ]; then echo "TẤT CẢ DEMO ĐẠT"; else echo "DEMO CÓ LỖI:$FAILED"; exit 1; fi
