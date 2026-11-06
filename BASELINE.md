# Baseline đã kiểm toán: ATTT-Security-Project (BTL ATTT Nhóm 9)

Repository này (`meomaydoraemon/ATTT-Security-Project`, PRIVATE) là **nơi phát triển chính**, độc lập với repository của nhóm. Nó không thay thế và **không đồng bộ ngược** về repository nhóm. Repository nhóm chỉ dùng để tham khảo; quy tắc bắt buộc nằm trong [AGENTS.md](AGENTS.md).

## Nguồn gốc

| Mục | Giá trị |
|---|---|
| Repository gốc | `github.com/Lemonimjuice/CSATTT-BTL--Nhom9` (nhánh `main-2`) |
| Baseline nhóm | `0a2282931500c8dbddd35495ad3b29aca19777cc` (`main-2`, 2026-10-27) |
| **Baseline của repo này** | **`2981c24ba3fd81886ccac5bb588e4fc8b57b156c`**: "fix: harden lab and resolve audit findings" (nhánh local `codex/main-2-audit`, cha duy nhất là `0a22829`) |
| Tag | `baseline/2981c24-audited` trỏ đúng commit trên |
| Thay đổi so với nhóm | 27 file (25 sửa, 2 test mới), +421/−83 dòng |
| Gói đã xác minh | `main-2-fixed-for-audit.verified.zip`, SHA256 `38ff3ba4ea0832088f07e6ce428546b66e0abafbe348729df42df8a82503f4ff`, giữ ngoài repo |
| Lịch sử | Giữ nguyên toàn bộ 30 commit tới baseline và thông tin tác giả gốc (Lemonimjuice/Tú, meomaydoraemon, mka123390) |

## Tình trạng kiểm thử (xác minh ngày 2026-11-07)

**Đã chạy trên đúng commit này:**
- Source 162/162 file khớp snapshot mà Codex đã kiểm thử.
- `tests/demo/test-evidence-guards.sh`: 10/10 PASS.
- `sh -n` cho 16 script: 0 lỗi cú pháp.
- `docker compose config` hợp lệ.
- Quét secret trong Git history: sạch.

**UNVERIFIED (chỉ là tuyên bố của Codex, chưa chạy lại):** Maven 170 test, HTTP integration 126/126, demo 56 assertion, WAF/PostgreSQL/failover runtime. Lý do: máy kiểm toán không có Java/Maven và Docker Engine không chạy.

**Kết luận cũ của Codex:** CONDITIONAL GO cho nghiệm thu. Kiểm toán độc lập lượt 1 xác nhận nguồn gốc và nội dung bản vá. Các mục còn PENDING nằm trong `docs/audit/INDEPENDENT_REVIEW_ROUND1.md`.

## Giới hạn đã biết

- Chỉ là lab một máy: gateway bind `127.0.0.1`, dữ liệu giả, chứng chỉ tự ký.
- Có API cố ý lỗi (`/api/v1/vuln/**`). Mặc định tắt, chỉ bật bằng `SQLI_DEMO_ENABLED=true`. Khi bật, `/vuln/posts` sửa/xóa được bảng `posts` thật của lab.
- Tài khoản và mật khẩu demo công khai nằm trong seed, README, Postman, Burp.
- **Chưa sẵn sàng** cho hai máy hay public Internet. Xem `docs/ai-context/TECHNICAL_SUMMARY.md` mục 11.

## Chạy nhanh (Git Bash, Docker Desktop)

```bash
sh scripts/init-env.sh --lab      # sinh .env ngẫu nhiên; --lab bật API cố ý lỗi cho demo
sh nginx/certs/generate-cert.sh   # chứng chỉ tự ký cục bộ
docker compose up -d --build --wait
sh scripts/preflight.sh
sh tests/demo/run-all.sh
```

Không chạy `scripts/reset-demo.sh --yes` nếu chưa chắc: lệnh này xóa volume DB và log.

## Remote và chống push nhầm

| Remote | Fetch | Push |
|---|---|---|
| `origin` | `meomaydoraemon/ATTT-Security-Project` | Được phép (đích duy nhất) |
| `team-readonly` | `Lemonimjuice/CSATTT-BTL--Nhom9` (chỉ tham khảo, `--no-tags`) | **Vô hiệu** (`no-push://…`) |

- Hook `.githooks/pre-push` chỉ cho push tới `origin` của repo này, chặn mọi đích khác. Sau mỗi lần clone phải bật: `git config core.hooksPath .githooks`.
- Không dùng `git push --no-verify`.

## Nhánh và rollback

- `main`: baseline ổn định. Chỉ nhận merge từ `develop` sau khi đã kiểm thử.
- `develop`: phát triển tiếp.
- Rollback toàn bộ về baseline: `git checkout baseline/2981c24-audited` (để xem), hoặc `git revert` các commit sau tag trên `main`.
- Không đưa `.env`, khóa TLS, `logs/`, `audit-results/` vào repo (đã có trong `.gitignore`).

## Cho AI (Claude Code, Codex, tư vấn kiến trúc)

1. Đọc file này, rồi `docs/ai-context/TECHNICAL_SUMMARY.md`.
2. Coi các tuyên bố trong `docs/audit/codex-*` là lịch sử, không phải sự thật. Kiểm chứng lại bằng source hoặc runtime.
3. Phân biệt FACT / INFERENCE / UNVERIFIED trong mọi báo cáo.
