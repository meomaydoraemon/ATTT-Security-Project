"""Quét thư mục bằng chứng tìm secret/token theo mục 5.7; chỉ in SỐ LƯỢNG, không in giá trị.

Dùng: python -I evidence/scan-secrets.py [thư_mục ...]   (mặc định: evidence)
Đọc giá trị secret từ .env ở thư mục gốc repo (chỉ trong bộ nhớ). Exit 1 nếu có kết quả.
"""
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

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
secrets = {}
with open(os.path.join(root, ".env"), encoding="utf-8") as env:
    for line in env:
        key, sep, value = line.strip().partition("=")
        if sep and key in SECRET_KEYS and value:
            secrets[key] = value.encode()

targets = sys.argv[1:] or [os.path.join(root, "evidence")]
counts = {k: 0 for k in list(secrets) + list(TOKEN_PATTERNS)}
seed_hits = files = 0
for target in targets:
    for dirpath, _, names in os.walk(target):
        for name in names:
            if name.endswith(".tar"):
                continue
            files += 1
            data = open(os.path.join(dirpath, name), "rb").read()
            for key, value in secrets.items():
                counts[key] += data.count(value)
            for key, pattern in TOKEN_PATTERNS.items():
                counts[key] += len(pattern.findall(data))
            if "raw" not in dirpath.replace("\\", "/").split("/"):
                seed_hits += len(SEED_PASSWORD.findall(data))

total = sum(counts.values())
print(f"files={files} secret_keys_checked={len(secrets)} findings={total}")
for key, n in counts.items():
    print(f"  {key}: {n}")
print(f"  seed_passwords_in_reports (public lab fixtures, mask in reports; not counted): {seed_hits}")
sys.exit(1 if total else 0)
