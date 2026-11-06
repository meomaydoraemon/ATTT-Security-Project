# Kiểm toán độc lập — lượt 1 (Phase A + Phase C sơ bộ)

> Ghi chú làm việc, 2026-11-07. Các mục PENDING chưa được kết luận. Cập nhật 2026-11-07: giả thuyết Content-Type JSON không chuẩn (R02) đã bị bác bỏ ở mức tĩnh — modsecurity.conf rule 200006 bật JSON processor cho `application/<x>+json`.


## Phase A — Repository (ĐÃ XÁC MINH)
- Repo chính: `D:\BTL ALL MAJOR\BTL ATTT Claude\audit-main-2` (repo git duy nhất, không có .git lồng nhau).
- HEAD = 2981c24ba3fd81886ccac5bb588e4fc8b57b156c, branch `codex/main-2-audit` (local, chưa push; không có upstream).
- Baseline 0a22829… = `main-2` = `origin/main-2`. 2981c24 có parent duy nhất là 0a22829 (1 commit, không merge).
- Commit: tác giả meomaydoraemon, 2026-10-27 14:45 +0700, "fix: harden lab and resolve audit findings".
- Diff baseline→HEAD: 27 file (25 M + 2 A: AuditFixRegressionTest.java, tests/demo/test-evidence-guards.sh), +421/-83. Khớp SOURCE_FILES_CHANGED.txt và commit-receipt.json.
- Working tree sạch (status porcelain rỗng). 162 file được track.
- 1566 file trên đĩa = 162 file track + 1404 file trong `audit-results/` (bị ignore, .gitignore thêm trong commit này). Không có file untracked khác (không có .env, target/, khóa TLS ở source chính).
- EOL: core.autocrlf=true. 113 file i/lf w/crlf; 36 i/lf w/lf; 13 file .http i/crlf (cố ý, -text). Worktree so với blob HEAD: 49 giống hệt, 113 chỉ khác EOL, 0 khác nội dung. Các file *.sh/*.sql/*.conf/*.yml đều LF trong worktree (tốt cho container).
- Snapshot Codex (fix-round-1/evidence/source-snapshot.json): 162/162 SHA256 khớp worktree hiện tại → bản Codex đã kiểm thử = nội dung commit 2981c24 (chỉ khác EOL so với blob).
- Freeze: `main-2-fixed-for-audit.verified.zip` SHA256 38FF3BA4…F4FF khớp receipt; 162 file source trong ZIP giống blob HEAD byte-for-byte; ZIP không chứa .env/.key/lab. `source-from-commit-v2.zip` và `package-v2/` = blob chính xác. `source-from-commit.zip` và `package/` (v1) = bản checkout CRLF, nội dung giống, đã bị thay thế bởi v2. → KHÔNG dùng freeze làm source chính; source chính = worktree tại HEAD.
- Bất thường:
  1. Các báo cáo fix-round-1 01–04 ghi "Base/HEAD: 0a22829, không commit" vì viết trước commit (14:40 < 14:45). 05_FREEZE_RECEIPT nói rõ điều này. Không phải mâu thuẫn nội dung, nhưng 01–04 KHÔNG định danh đúng commit.
  2. Đường dẫn trong báo cáo là `D:\BTL ATTT\audit-main-2`; thư mục hiện tại là `D:\BTL ALL MAJOR\BTL ATTT Claude\audit-main-2` → đã copy/di chuyển. Không ảnh hưởng nội dung.
  3. `audit-results/lab/root/` và `audit-results/fix-round-1/lab/root/` chứa `.env`, `default*.env`, `nginx/certs/server.key` của lab cũ (không track, không có trong ZIP). Có trong thư mục được bàn giao → rủi ro lộ nếu chia sẻ nguyên folder. Đánh giá ở B5 (KHÔNG in giá trị).
  4. Ghi chú: các "PASS cũ" (Maven 170, HTTP 126, demo 56) là evidence chạy trên worktree trước commit, được Codex tái sử dụng — CHƯA chạy lại; trạng thái = UNVERIFIED cho tới lượt 3.

## Phase C sơ bộ — Bản vá (static, chưa runtime)
| ID | Lỗi gốc | Thay đổi | Trạng thái sơ bộ | Cần kiểm tra thêm |
|---|---|---|---|---|
| R01 P0 | Gateway bind mọi interface; SQLI_DEMO_ENABLED luôn true | compose: `127.0.0.1:${HTTPS_PORT:-443}:8443`; flag `${SQLI_DEMO_ENABLED:-false}`; application.yml mặc định false; 3 controller demo có @Profile("sqli-lab") + @ConditionalOnProperty(app.demo.sqli.enabled=true); init-env --lab | PENDING (tĩnh nhất quán) | B2: SecurityConfig permitAll /vuln/**? 404 khi tắt; SPRING_PROFILES_ACTIVE luôn chứa sqli-lab → thực tế chỉ còn 1 cổng (flag), javadoc "profile AND flag" đúng chữ nhưng profile luôn bật; Docker Desktop Windows loopback; vuln Post vẫn dùng blogdb khi bật |
| R02 P1 | Custom rule REQUEST_URI + `$` bị query bypass | 100100, 100200 → REQUEST_FILENAME | PENDING (đúng nguyên nhân gốc về query) | B4: biến thể path (encode %xx, //, ;, trailing /, hoa/thường) so với Spring/StrictHttpFirewall; GIẢ THUYẾT: Content-Type JSON không chuẩn (vd `application/*+json` mà Spring chấp nhận) → ModSecurity không parse ARGS:json.* → 100100 có thể không kích hoạt; xem body processor rule + CRS allowed_request_content_type. Chưa chứng minh. |
| 900500 | CRS exclusion password/refreshToken dùng REQUEST_URI | → REQUEST_FILENAME | PENDING | Exclusion giờ áp cả khi có query (đúng ý); kiểm tra không mở rộng ngoài 4 endpoint |
| R03 P1 | page âm / parent khác post / depth → 500 | Controller check page<0||size<1 → InvalidRequestException (map 400 tại GlobalExceptionHandler:25); service đổi IllegalArgumentException → InvalidRequestException | VERIFIED FIXED (tĩnh, cho 3 case nêu) — test chưa chạy lại | GlobalExceptionHandler KHÔNG có handler cho MethodArgumentTypeMismatchException / MissingServletRequestParameter / HttpRequestMethodNotSupported / DataIntegrityViolation → rơi vào Exception.class:107 (có thể 500). Giả thuyết `?page=abc` → 500 → nếu đúng thì R03 PARTIALLY FIXED. Runtime lượt 3. |
| R04 P1 | slug > varchar(200) → 500 | Post.MAX_SLUG_LENGTH=200; ensureUniqueSlug cắt stem chừa chỗ suffix, bỏ qua chính post; giữ slug khi title không đổi; fallback "post" | VERIFIED FIXED (tĩnh, về độ dài) | Race 2 request cùng title đồng thời → unique violation → không có handler → 500 (có từ trước, không phải regression). Test chạy trên H2 ddl create-drop, không dùng 01-schema.sql. |
| Username | (bổ sung) | RegisterRequest @Pattern `[A-Za-z0-9_.@-]+` | PENDING | So với regex WAF 100200 và seed users; login không validate (đúng) |
| R05 P1 | Assertion vắng mặt PASS sai | common.sh: set -eu, require_rid/require_log/backend_count/require_backend_received, timeout curl; demo2 positive control + assert 942100 + nguồn 403; demo5 so IP với log Nginx; demo3 assert is_interrupted=false; test-evidence-guards.sh 10 case offline | PARTIALLY VERIFIED (tĩnh) | D: tác dụng phụ `set -eu` khi source vào demo (gán `X=$(... grep -c ...)` trả 1 → thoát âm thầm?); fatal trong `$(...)` chỉ thoát subshell; chưa test log không đọc được (quyền), backend 403, service unreachable; run-all có `set -e` |
| R06 P2 | waf-mode báo On khi lỗi | Đọc modsecurity.conf + modsecurity-mode.conf, lấy SecRuleEngine cuối, lỗi → exit≠0 | PENDING | B4: thứ tự include thực tế; còn file nào khác set SecRuleEngine trong image (CRS image)? |
| R07 P2 | Diễn giải quá mức | Sửa câu chữ demo3/README/waf-mode | VERIFIED (tài liệu) | E: đánh giá thuyết trình |
| R08 P2 | Preflight hardcode 443/image | BASE từ HTTPS_PORT, chỉ cho loopback; images từ `docker compose images`; timeout; dùng waf-mode.sh | PENDING | F: ràng buộc BASE loopback sẽ cản preflight trong mô hình 2 máy/Internet |
| R09 P2 | Mô tả ACL reader sai | Chỉ sửa comment 04-sqli-demo.sh | VERIFIED FIXED (dạng sửa tài liệu; ACL không đổi) | B3: ma trận quyền thực |
| R10 P2 | Health gateway không đại diện | KHÔNG đổi healthcheck (`curl -so /dev/null http://127.0.0.1:8080/` không -f); chỉ ghi chú docs | PARTIALLY FIXED (chỉ tài liệu, có chủ đích) | B5/F |
| Demo1 | (bổ sung) | trap khôi phục node1, check exited, sleep 16 rồi kiểm 2 node nhận lại | PENDING | B4: max_fails/fail_timeout của upstream so với sleep 16 |

## Khác ghi nhận
- Chỉ 1 cổng publish (nginx). Network lõi internal: true, subnet cố định 10.209.10.0/24 (trust XFF theo IP Nginx 10.209.10.10, TRUSTED_PROXY_REGEX).
- reset-demo.sh không đổi: `docker compose down -v` + rm logs (phá dữ liệu — KHÔNG chạy). Nếu .env thiếu → init-env không --lab → flag false → demo 2/3/4 sẽ fail (preflight chỉ WARN).

## Lượt 2 (Phase B) — việc cần làm
B1 SecurityConfig, JWT (gen/validate/refresh/revoke), BCrypt, RBAC, ownership Post/Comment/Record, IDOR, user enumeration, exception mapping (giả thuyết type mismatch → 500), CORS/CSRF, race.
B2 gating demo + đường bypass (SecurityConfig, filter), profile/flag.
B3 01-schema.sql, 02/03 seed, 04-sqli-demo.sh, grants, 2 backend chung DB.
B4 nginx.conf (upstream, max_fails/fail_timeout, proxy_next_upstream, real_ip, limit_req key, headers), modsecurity.conf, mode include, body processor/Content-Type, custom rules đầy đủ.
B5 compose (env, healthcheck, user, cap), Dockerfile, secrets trong git history (`git log -p` grep tên biến, không in giá trị), file lab trong audit-results.
