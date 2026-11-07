#!/bin/sh
# Hồi quy offline cho tests/demo/netprobe.sh: docker giả trong PATH tạm, không đụng Docker thật, không HTTP.
# Chạy được bằng bash và dash: sh tests/demo/test-netprobe.sh ; dash tests/demo/test-netprobe.sh
set -eu
repo=$(cd "$(dirname "$0")/../.." && pwd)
suite=$(mktemp -d)
trap 'rm -rf "$suite"' EXIT
mkdir -p "$suite/bin"
cat > "$suite/bin/docker" <<'EOF'
#!/bin/sh
d=$(dirname "$0")
case "$1" in
    compose) cat "$d/projects" ;;
    network) case "$*" in *"project=nhom9-local --filter"*) echo nhom9-local_lab_net ;; esac ;;
    exec) cat "$d/out"; exit "$(cat "$d/rc")" ;;
esac
EOF
chmod +x "$suite/bin/docker"
PATH="$suite/bin:$PATH"
. "$repo/tests/demo/netprobe.sh"
n=0
# stub OUTPUT RC
stub() { printf '%s' "$1" > "$suite/bin/out"; printf '%s\n' "$2" > "$suite/bin/rc"; }
expect() {
    n=$((n+1))
    [ "$2" = "$3" ] || { echo "FAIL: $1: mong đợi '$2', nhận '$3'" >&2; exit 1; }
}

stub '0.000272|28' 28; expect "timeout sau khi TCP đã kết nối là ĐÃ KẾT NỐI" được "$(np_tcp c 10.0.0.2 5432)"
stub '0.000236|52' 52; expect "server trả dữ liệu không phải HTTP" được "$(np_tcp c 10.0.0.2 5432)"
stub '0.000000|7' 7;   expect "refused/unreachable" không "$(np_tcp c 10.0.0.2 5432)"
stub '0.000000|28' 28; expect "connect timeout" không "$(np_tcp c 10.0.0.2 5432)"
stub '' 127;           expect "thiếu công cụ curl" "LỖI ĐO" "$(np_tcp c 10.0.0.2 5432)"
stub 'Error response from daemon' 1; expect "lỗi docker exec" "LỖI ĐO" "$(np_tcp c 10.0.0.2 5432)"
stub '0.000000|6' 6;   expect "exit code chưa hiệu chuẩn" "LỖI ĐO" "$(np_tcp c 10.0.0.2 5432)"
expect "IP rỗng" "LỖI ĐO" "$(np_tcp c '' 5432)"
expect "IP không hợp lệ" "LỖI ĐO" "$(np_tcp c 10.0.0 5432)"
expect "hai IP dính nhau" "LỖI ĐO" "$(np_tcp c 10.0.0.210.0.0.3 5432)"
stub '' 0;   expect "getent phân giải được" được "$(np_resolves c lab-db)"
stub '' 2;   expect "getent không có tên" không "$(np_resolves c database)"
stub '' 127; expect "getent thiếu công cụ" "LỖI ĐO" "$(np_resolves c database)"
stub '' 1;   expect "getent lỗi docker exec" "LỖI ĐO" "$(np_resolves c database)"
expect "tên rỗng" "LỖI ĐO" "$(np_resolves c '')"
printf 'nhom9-local\n' > "$suite/bin/projects"
expect "project hiện tại" nhom9-local "$(np_project)"
expect "network lab theo label project" nhom9-local_lab_net "$(np_network nhom9-local lab_net)"
printf 'other-project\n' > "$suite/bin/projects"
expect "project mang tên khác: không có network lab" "" "$(np_network "$(np_project)" lab_net)"
printf 'nhom9-local\nother-project\n' > "$suite/bin/projects"
expect "nhiều project: không xác định" "" "$(np_project)"
echo "PASS: $n netprobe cases; measurement errors never become 'không'."
