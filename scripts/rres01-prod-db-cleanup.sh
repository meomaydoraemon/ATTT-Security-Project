#!/bin/sh
# R-RES-01: gỡ phần lab tồn dư khỏi cluster DB prod (database sqli_lab, role sqli_demo_reader) và khôi phục
# bài 3 về đúng giá trị seed (database/init/03-seed-data.sql). KHÔNG khởi tạo lại volume.
#   sh scripts/rres01-prod-db-cleanup.sh            # dry-run: CHỈ ĐỌC, liệt kê những gì sẽ đổi
#   R_RES_01=ĐỒNG_Ý sh scripts/rres01-prod-db-cleanup.sh --apply
#       chỉ chạy khi người dùng đã đồng ý; sao lưu trước, kiểm từng bước, dừng khi có bất thường.
# Sau --apply còn phải sửa docker-compose.yml để DB prod không chạy 04 và không cần SQLI_LAB_READER_PASSWORD.
# Không in secret: chỉ dùng psql qua socket của container với postgres_admin.
set -eu
cd "$(dirname "$0")/.."
q() { MSYS_NO_PATHCONV=1 docker exec database psql -U postgres_admin -d blogdb -v ON_ERROR_STOP=1 -tAc "$1" | tr -d '\r'; }
SEED_TITLE='Bản nháp bí mật của User A'
SEED_SLUG='ban-nhap-bi-mat-cua-user-a'
SEED_CONTENT='Nội dung nháp chưa công bố, chỉ User A và ADMIN được đọc.'
SEED_SUMMARY='Bản nháp'
# Điều kiện hẹp: đúng bài id=3 của user_a
POST3_WHERE="p.id = 3 AND p.author_id = (SELECT id FROM public.users WHERE username = 'user_a')"

[ "$(docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' database 2>/dev/null)" = "$(docker compose ps -a --format '{{.Project}}' | sort -u)" ] \
    || { echo "LỖI: container database không thuộc project Compose hiện tại." >&2; exit 2; }

echo "== Hiện trạng cluster DB prod (chỉ đọc)"
has_db=$(q "select count(*) from pg_database where datname = 'sqli_lab'")
has_role=$(q "select count(*) from pg_roles where rolname = 'sqli_demo_reader'")
conns=$(q "select count(*) from pg_stat_activity where datname = 'sqli_lab'")
owned=$(q "select count(*) from pg_class c join pg_roles r on r.oid = c.relowner where r.rolname = 'sqli_demo_reader'")
rows=$(q "select count(*) from public.posts p where $POST3_WHERE")
same=$(q "select count(*) from public.posts p where $POST3_WHERE and p.title = '$SEED_TITLE' and p.slug = '$SEED_SLUG' and p.content = '$SEED_CONTENT' and p.summary = '$SEED_SUMMARY' and p.status = 'DRAFT'")
echo "  database sqli_lab tồn tại: $has_db"
echo "  role sqli_demo_reader tồn tại: $has_role (sở hữu $owned đối tượng trong blogdb)"
echo "  kết nối đang mở tới sqli_lab: $conns"
echo "  bài 3 của user_a: $rows dòng khớp; đã đúng seed: $same"
q "select '  bài 3 hiện tại: status=' || p.status || ', title=' || p.title from public.posts p where $POST3_WHERE"

echo "== Kế hoạch"
[ "$has_db" = 1 ] && echo "  1. DROP DATABASE sqli_lab (sau khi sao lưu blogdb + globals, kiểm 0 kết nối)"
[ "$has_role" = 1 ] && echo "  2. DROP ROLE sqli_demo_reader"
[ "$same" = 0 ] && [ "$rows" = 1 ] && echo "  3. UPDATE đúng 1 dòng bài 3 về giá trị seed (title, slug, content, summary, status=DRAFT)"
echo "  4. (thủ công, commit riêng) docker-compose.yml: DB prod không mount 04-sqli-demo.sh, bỏ SQLI_LAB_READER_PASSWORD"

if [ "${1:-}" != --apply ]; then
    echo "DRY-RUN: không thay đổi gì. Chạy --apply chỉ khi người dùng đồng ý R-RES-01."
    exit 0
fi
[ "${R_RES_01:-}" = ĐỒNG_Ý ] || { echo "LỖI: cần R_RES_01=ĐỒNG_Ý (người dùng đồng ý) để --apply." >&2; exit 2; }
[ "$rows" = 1 ] || { echo "LỖI: điều kiện bài 3 khớp $rows dòng (phải đúng 1)." >&2; exit 1; }
[ "$conns" = 0 ] || { echo "LỖI: còn $conns kết nối tới sqli_lab." >&2; exit 1; }
[ "$owned" = 0 ] || { echo "LỖI: role reader còn sở hữu đối tượng trong blogdb." >&2; exit 1; }

backup=evidence/T-003/rollback
mkdir -p "$backup"
git check-ignore -q "$backup/x" || { echo "LỖI: $backup không bị Git ignore." >&2; exit 1; }
stamp=$(date +%Y%m%d-%H%M%S)
MSYS_NO_PATHCONV=1 docker exec database pg_dump -U postgres_admin -Fc blogdb > "$backup/blogdb-$stamp.dump"
MSYS_NO_PATHCONV=1 docker exec database pg_dumpall -U postgres_admin --globals-only > "$backup/globals-$stamp.sql"
MSYS_NO_PATHCONV=1 docker exec -i database pg_restore --list < "$backup/blogdb-$stamp.dump" > /dev/null \
    || { echo "LỖI: bản sao lưu blogdb không đọc lại được." >&2; exit 1; }
[ -s "$backup/globals-$stamp.sql" ] || { echo "LỖI: bản sao lưu globals rỗng." >&2; exit 1; }
echo "Đã sao lưu: $backup/blogdb-$stamp.dump, $backup/globals-$stamp.sql"

[ "$has_db" = 1 ] && MSYS_NO_PATHCONV=1 docker exec database psql -U postgres_admin -d blogdb -v ON_ERROR_STOP=1 -c "DROP DATABASE sqli_lab"
[ "$has_role" = 1 ] && MSYS_NO_PATHCONV=1 docker exec database psql -U postgres_admin -d blogdb -v ON_ERROR_STOP=1 -c "DROP ROLE sqli_demo_reader"
if [ "$same" = 0 ]; then
    n=$(q "WITH u AS (UPDATE public.posts p SET title = '$SEED_TITLE', slug = '$SEED_SLUG', content = '$SEED_CONTENT', summary = '$SEED_SUMMARY', status = 'DRAFT', updated_at = now() WHERE $POST3_WHERE RETURNING 1) SELECT count(*) FROM u")
    [ "$n" = 1 ] || { echo "LỖI: UPDATE bài 3 đổi $n dòng (phải 1)." >&2; exit 1; }
fi
echo "Xong. Tiếp: sửa docker-compose.yml (bước 4), chạy preflight, Demo 1, Demo 5, ghi checksum INV-12 mới."
