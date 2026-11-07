#!/bin/sh
# Self-test cho evidence/scan-secrets.py: dùng .env GIẢ trong thư mục tạm, không đọc .env thật.
# Chạy được bằng bash và dash: sh evidence/test-scan-secrets.sh ; dash evidence/test-scan-secrets.sh
set -eu
repo=$(cd "$(dirname "$0")/.." && pwd)
scan="$repo/evidence/scan-secrets.py"
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
fake=fake-secret-value-0123456789
for k in DB_ADMIN_PASSWORD APP_DB_PASSWORD JWT_SECRET SQLI_LAB_READER_PASSWORD \
         LAB_JWT_SECRET LAB_DB_ADMIN_PASSWORD LAB_APP_DB_PASSWORD LAB_SQLI_READER_PASSWORD; do
    printf '%s=%s-%s\n' "$k" "$fake" "$k" >> "$t/fake.env"
done
mkdir -p "$t/clean" "$t/dirty" "$t/empty"
printf 'nothing sensitive here\n' > "$t/clean/report.md"
printf 'leak %s-JWT_SECRET\n' "$fake" > "$t/dirty/a.txt"
# JWT giả ghép lúc chạy, để chính file này không chứa mẫu JWT (thư mục evidence/ cũng bị quét)
printf 'x %s.%s.%s y\n' eyJhbGciOi eyJzdWIiOi c2lnbmF0dXJl > "$t/dirty/b.txt"
head -3 "$t/fake.env" > "$t/partial.env"
n=0
# expect MÔ_TẢ EXIT_MONG_ĐỢI lệnh...
expect() {
    _d=$1; _e=$2; shift 2; n=$((n+1)); _rc=0
    "$@" > "$t/out" 2>&1 || _rc=$?
    [ "$_rc" = "$_e" ] || { echo "FAIL: $_d: exit $_rc, mong đợi $_e" >&2; cat "$t/out" >&2; exit 1; }
    if grep -q "$fake" "$t/out"; then echo "FAIL: $_d: output lộ giá trị secret" >&2; exit 1; fi
}
py() { python -I "$scan" "$@"; }
expect "thư mục sạch"                 0 py --env "$t/fake.env" "$t/clean"
expect "file lẻ sạch"                 0 py --env "$t/fake.env" "$t/clean/report.md"
expect "thư mục có secret và JWT"     1 py --env "$t/fake.env" "$t/dirty"
expect "file lẻ có secret"            1 py --env "$t/fake.env" "$t/dirty/a.txt"
expect "đích không tồn tại"           2 py --env "$t/fake.env" "$t/missing"
expect "thư mục rỗng: 0 file"         2 py --env "$t/fake.env" "$t/empty"
expect "env không tồn tại"            2 py --env "$t/no.env" "$t/clean"
expect "env thiếu khóa bắt buộc"      2 py --env "$t/partial.env" "$t/clean"
expect "tokens-only: bắt được JWT"    1 py --tokens-only "$t/dirty/b.txt"
expect "tokens-only: sạch"            0 py --tokens-only "$t/clean"
grep -q 'mode=tokens-only' "$t/out" || { echo "FAIL: tokens-only phải ghi rõ chế độ" >&2; exit 1; }
echo "PASS: $n scanner cases; scanner never exits 0 without a real, complete scan."
