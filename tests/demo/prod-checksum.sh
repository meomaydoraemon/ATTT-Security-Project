#!/bin/sh
# In checksum dữ liệu bảng posts và comments của DB prod (container database). Chỉ in giá trị hash.
# Dùng cho INV-12: chạy trước và sau các demo lab, hai giá trị phải bằng nhau.
#   sh tests/demo/prod-checksum.sh
set -eu
cd "$(dirname "$0")/../.."
q="select md5(coalesce((select string_agg(md5(p::text), ',' order by p.id) from public.posts p), '')
           || '|' ||
           coalesce((select string_agg(md5(c::text), ',' order by c.id) from public.comments c), ''))"
sum=$(MSYS_NO_PATHCONV=1 docker compose exec -T database psql -U postgres_admin -d blogdb -tAc "$q" | tr -d '\r')
printf '%s\n' "$sum" | grep -Eq '^[0-9a-f]{32}$' || { echo "Không tính được checksum DB prod." >&2; exit 1; }
printf '%s\n' "$sum"
