#!/bin/sh
# Chuẩn bị môi trường chạy. Chạy từ thư mục gốc repo (Git Bash), chạy lại nhiều lần cũng an toàn:
#   sh scripts/init-env.sh
# 1. Tạo các thư mục logs/ mà container ghi vào (audit log tập trung).
# 2. Sinh .env với mọi mật khẩu/khóa ngẫu nhiên nếu chưa có; .env đã có thì chỉ bổ sung khóa còn thiếu,
#    không đổi giá trị đang có. Không in giá trị bí mật.
set -eu
cd "$(dirname "$0")/.."
case "${1:-}" in
    "") ;;
    --lab) echo "Lưu ý: --lab đã ngừng dùng. Lab chạy ở service riêng (sh scripts/lab.sh up), không cần cờ trong .env." ;;
    *) echo "Dùng: sh scripts/init-env.sh" >&2; exit 2 ;;
esac

# Tạo sẵn và cho phép ghi: trên Linux, nếu để Docker tự tạo thì thư mục thuộc root và Nginx (uid 101),
# backend (user blogapi) không ghi được log, Nginx sẽ không khởi động. Windows/macOS không bị ảnh hưởng.
mkdir -p logs/nginx logs/waf logs/backend-node-1 logs/backend-node-2 logs/lab-backend
chmod 777 logs/nginx logs/waf logs/backend-node-1 logs/backend-node-2 logs/lab-backend
echo "Thư mục logs/ đã sẵn sàng."

hex() { openssl rand -hex 24; }
b64() { openssl rand -base64 32; }

umask 077
[ -f .env ] && existed=true || existed=false
touch .env
added=""
# add KEY VALUE: chỉ ghi khi .env chưa có KEY (giữ nguyên secrets tương ứng dữ liệu hiện có).
add() {
    grep -q "^$1=" .env && return 0
    # Bảo đảm dòng mới không dính vào dòng cuối thiếu ký tự xuống dòng.
    [ -s .env ] && [ "$(tail -c 1 .env | od -An -c | tr -d ' ')" != '\n' ] && echo >> .env
    printf '%s=%s\n' "$1" "$2" >> .env
    added="$added $1"
}
add DB_ADMIN_PASSWORD "$(hex)"
add APP_DB_USERNAME app_user
add APP_DB_PASSWORD "$(hex)"
add JWT_SECRET "$(b64)"
add WAF_MODE On
# Tồn dư: database prod vẫn chạy 04-sqli-demo.sh nên vẫn cần biến này (R-RES-01).
add SQLI_LAB_READER_PASSWORD "$(hex)"
# Lab tách biệt (profile lab): secret riêng, không dùng chung với prod.
add LAB_JWT_SECRET "$(b64)"
add LAB_DB_ADMIN_PASSWORD "$(hex)"
add LAB_APP_DB_PASSWORD "$(hex)"
add LAB_SQLI_READER_PASSWORD "$(hex)"
add LAB_HTTPS_PORT 9443

if [ "$existed" = false ]; then
    echo "Đã tạo .env với giá trị ngẫu nhiên. Chỉ dùng dữ liệu giả và cổng loopback."
elif [ -n "$added" ]; then
    echo ".env đã có: giữ nguyên giá trị cũ, bổ sung khóa còn thiếu:$added"
else
    echo ".env đã có đủ khóa, giữ nguyên."
fi
if grep -q '^SQLI_DEMO_ENABLED=' .env; then
    echo "Lưu ý: SQLI_DEMO_ENABLED trong .env đã ngừng dùng, không service nào đọc biến này."
fi
