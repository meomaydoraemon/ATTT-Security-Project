#!/bin/sh
# Hàm đo mạng cho Demo 6. Được `. tests/demo/netprobe.sh` nạp. Mọi phép đo trả đúng một trong ba giá trị:
#   được   : đã kết nối TCP / đã phân giải được tên
#   không  : bị chặn / không phân giải được
#   LỖI ĐO : docker exec lỗi, thiếu công cụ, thiếu đầu vào, output lạ. LỖI ĐO không bao giờ thành PASS.
# Ánh xạ hiệu chuẩn trên image nhom9/blog-api:local (curl 7.81, getent glibc), xem evidence/T-003:
#   curl -w '%{time_connect}|%{exitcode}': time_connect > 0 là đã kết nối, kể cả exit 28 (server im lặng)
#   hay 52 (server trả dữ liệu không phải HTTP). time_connect = 0 và exit 7 (refused/unreachable) hoặc
#   28 (connect timeout) là bị chặn. getent: 0 = phân giải được, 2 = không có tên, mã khác = LỖI ĐO.

np_exec() { MSYS_NO_PATHCONV=1 docker exec "$@"; }

# np_ipv4 VALUE -> 0 nếu là một địa chỉ IPv4 hợp lệ duy nhất
np_ipv4() { printf '%s\n' "$1" | grep -Eqx '([0-9]{1,3}\.){3}[0-9]{1,3}'; }

# np_tcp FROM_CONTAINER IP PORT
np_tcp() {
    np_ipv4 "${2:-}" || { echo "LỖI ĐO"; return 0; }
    case "${3:-}" in ''|*[!0-9]*) echo "LỖI ĐO"; return 0 ;; esac
    _o=$(np_exec "$1" curl -s -o /dev/null --connect-timeout 3 --max-time 5 \
        -w '%{time_connect}|%{exitcode}' "http://$2:$3/" 2>/dev/null) || true
    printf '%s\n' "$_o" | grep -Eqx '[0-9]+(\.[0-9]+)?\|[0-9]+' || { echo "LỖI ĐO"; return 0; }
    _t=${_o%|*}; _e=${_o#*|}
    if awk -v t="$_t" 'BEGIN { exit !(t > 0) }'; then echo được; return 0; fi
    case $_e in 7|28) echo không ;; *) echo "LỖI ĐO" ;; esac
}

# np_resolves FROM_CONTAINER NAME
np_resolves() {
    [ -n "${2:-}" ] || { echo "LỖI ĐO"; return 0; }
    _rc=0; np_exec "$1" getent hosts "$2" >/dev/null 2>&1 || _rc=$?
    case $_rc in 0) echo được ;; 2) echo không ;; *) echo "LỖI ĐO" ;; esac
}

# np_project -> tên project Compose hiện tại (đúng một), rỗng nếu không xác định được
np_project() {
    _p=$(docker compose ps -a --format '{{.Project}}' 2>/dev/null | sort -u) || true
    [ "$(printf '%s\n' "$_p" | grep -c .)" = 1 ] && printf '%s\n' "$_p"
}

# np_network PROJECT COMPOSE_NETWORK_KEY -> tên network Docker (đúng một), rỗng nếu không có/nhiều hơn một
np_network() {
    [ -n "${1:-}" ] || return 0
    _n=$(docker network ls --filter "label=com.docker.compose.project=$1" \
        --filter "label=com.docker.compose.network=$2" --format '{{.Name}}' 2>/dev/null) || true
    [ "$(printf '%s\n' "$_n" | grep -c .)" = 1 ] && printf '%s\n' "$_n"
}

# np_ip CONTAINER NETWORK -> IP của container trên đúng network đó (rỗng nếu không gắn)
np_ip() {
    [ -n "${2:-}" ] || return 0
    docker inspect -f "{{with index .NetworkSettings.Networks \"$2\"}}{{.IPAddress}}{{end}}" "$1" 2>/dev/null | tr -d ' \r'
}

# np_networks CONTAINER -> danh sách network đã sắp xếp, cách nhau bởi dấu cách
np_networks() {
    docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{"\n"}}{{end}}' "$1" 2>/dev/null \
        | tr -d '\r' | grep . | sort | tr '\n' ' ' | sed 's/ $//'
}
