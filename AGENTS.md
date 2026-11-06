# Quy tắc bắt buộc cho mọi AI (Claude Code, Codex, …) và người phát triển

## 1. Repository: ràng buộc không có ngoại lệ

- Đích phát triển **duy nhất** là `meomaydoraemon/ATTT-Security-Project` (PRIVATE), remote `origin`. Mọi commit và push, kể cả khi xong một mốc, chỉ vào đây.
- Repository nhóm `Lemonimjuice/CSATTT-BTL--Nhom9` **chỉ để tham khảo/đối chiếu** (remote `team-readonly`, push đã bị vô hiệu).
- **Cấm** trên repository nhóm: push, force-push, merge, rebase, tạo/xóa/đổi branch hoặc tag, mở PR/issue/comment/release, sửa settings, `gh repo sync`, hay bất kỳ lệnh `gh`/API nào có ghi. Chỉ được đọc (fetch, `git ls-remote`, `gh api` GET).
- Không tự động đồng bộ từ repo này sang repo nhóm. Chỉ **đề xuất** đưa bản cuối lên repo nhóm khi dự án đã hoàn chỉnh, kiểm thử ổn định **và** chủ repo cho phép rõ ràng bằng lời trong phiên làm việc.
- Không dùng `git push --no-verify`. Không sửa/xóa `.githooks/pre-push`, không đổi `core.hooksPath`, không thêm remote hay đổi URL push khi chưa được chủ repo cho phép.

Sau mỗi lần clone: `git config core.hooksPath .githooks`

## 2. Nhánh

- `main`: baseline ổn định. Tag `baseline/2981c24-audited` đánh dấu đúng commit baseline đã kiểm toán. Không force-push `main`.
- `develop`: phát triển hằng ngày. Merge vào `main` chỉ sau khi đã kiểm thử.

## 3. Dữ liệu nhạy cảm

Không commit `.env`, khóa/chứng chỉ TLS, `logs/`, `audit-results/`, dump database, token hay mật khẩu thật. Mật khẩu tài khoản demo trong seed/README/Postman/Burp là dữ liệu giả công khai; phải đổi trước khi public Internet.

## 4. An toàn khi chạy

- Không chạy `scripts/reset-demo.sh --yes` hay `docker compose down -v` khi chưa xác nhận đúng project/volume: các lệnh này xóa DB và log.
- API cố ý lỗi `/api/v1/vuln/**` chỉ bật trong lab dữ liệu giả (`SQLI_DEMO_ENABLED=true`).

## 5. Trước khi làm và khi báo cáo

- Đọc [BASELINE.md](BASELINE.md) và [docs/ai-context/TECHNICAL_SUMMARY.md](docs/ai-context/TECHNICAL_SUMMARY.md).
- Báo cáo trong `docs/audit/` là lịch sử, không phải sự thật mặc định: kiểm chứng lại bằng source/runtime.
- Phân biệt FACT / INFERENCE / UNVERIFIED. Không biến UNVERIFIED thành PASS.
