"""Quét bằng chứng tìm secret/token theo mục 5.7; chỉ in SỐ LƯỢNG, không bao giờ in giá trị.

Dùng: python -I evidence/scan-secrets.py [--env FILE] [--tokens-only] [đích ...]
  đích: thư mục hoặc file (mặc định: evidence). --env: file .env chứa secret (mặc định: .env ở gốc repo).
  --tokens-only: chủ ý chỉ quét mẫu token, không cần .env (output ghi rõ chế độ này).
Exit 0 chỉ khi: mọi đích tồn tại và đọc được, quét được ít nhất 1 file, đủ 8 khóa secret bắt buộc
(trừ --tokens-only) và 0 kết quả. Exit 1 khi có kết quả; exit 2 khi không đủ điều kiện để kết luận.
"""
import argparse
import os
import re
import sys

SECRET_KEYS = ["DB_ADMIN_PASSWORD", "APP_DB_PASSWORD", "JWT_SECRET", "SQLI_LAB_READER_PASSWORD",
               "LAB_JWT_SECRET", "LAB_DB_ADMIN_PASSWORD", "LAB_APP_DB_PASSWORD", "LAB_SQLI_READER_PASSWORD"]
TOKEN_PATTERNS = {
    "jwt": re.compile(rb"eyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}"),
    "refreshToken": re.compile(rb'"refreshToken"\s*:\s*"[^"]+"'),
    "bearer": re.compile(rb"Authorization:\s*Bearer\s+\S+", re.I),
}
SEED_PASSWORD = re.compile(rb"[A-Za-z]+@Nhom9-20\d\d")  # mật khẩu seed công khai: chỉ đếm để che trong báo cáo
# Console Windows (cp1252) không in được tiếng Việt: lỗi in không được làm sai exit code.
sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def unusable(msg):
    print(f"LỖI ĐO: {msg}. Không kết luận được (exit 2).")
    sys.exit(2)


root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ap = argparse.ArgumentParser(add_help=True)
ap.add_argument("--env", default=os.path.join(root, ".env"))
ap.add_argument("--tokens-only", action="store_true")
ap.add_argument("targets", nargs="*")
args = ap.parse_args()

secrets = {}
if not args.tokens_only:
    try:
        with open(args.env, encoding="utf-8") as env:
            for line in env:
                key, sep, value = line.strip().partition("=")
                if sep and key in SECRET_KEYS and value:
                    secrets[key] = value.encode()
    except OSError:
        unusable("không đọc được file env")
    missing = [k for k in SECRET_KEYS if k not in secrets]
    if missing:
        unusable("env thiếu khóa secret bắt buộc: " + " ".join(missing))

files = []
for target in args.targets or [os.path.join(root, "evidence")]:
    if os.path.isfile(target):
        files.append(target)
    elif os.path.isdir(target):
        for dirpath, _, names in os.walk(target):
            files += [os.path.join(dirpath, n) for n in names if not n.endswith(".tar")]
    else:
        unusable(f"đích không tồn tại: {os.path.basename(target) or target}")

counts = {k: 0 for k in list(secrets) + list(TOKEN_PATTERNS)}
seed_hits = 0
for path in files:
    try:
        data = open(path, "rb").read()
    except OSError:
        unusable(f"không đọc được file: {os.path.basename(path)}")
    for key, value in secrets.items():
        counts[key] += data.count(value)
    for key, pattern in TOKEN_PATTERNS.items():
        counts[key] += len(pattern.findall(data))
    if "raw" not in path.replace("\\", "/").split("/"):
        seed_hits += len(SEED_PASSWORD.findall(data))
if not files:
    unusable("không có file nào để quét")

total = sum(counts.values())
mode = "tokens-only (chủ ý KHÔNG kiểm giá trị secret)" if args.tokens_only else "secrets+tokens"
print(f"mode={mode} files={len(files)} secret_keys_checked={len(secrets)} findings={total}")
for key, n in counts.items():
    print(f"  {key}: {n}")
print(f"  seed_passwords_in_reports (public lab fixtures, mask in reports; not counted): {seed_hits}")
sys.exit(1 if total else 0)
