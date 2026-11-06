# Tóm tắt kỹ thuật cho AI và người phát triển — BTL ATTT Nhóm 9

Baseline: commit `2981c24ba3fd81886ccac5bb588e4fc8b57b156c` (branch gốc `codex/main-2-audit`). Tài liệu này được viết ngày 2026-11-07 bằng cách đọc source tại commit đó.

Nhãn dùng trong tài liệu:
- **[FACT]**: đọc trực tiếp từ source/cấu hình hoặc từ lệnh đã chạy trên đúng commit này.
- **[INFERENCE]**: suy luận từ source, chưa chạy runtime để chứng minh.
- **[UNVERIFIED]**: tuyên bố trong báo cáo cũ hoặc hành vi runtime chưa được chạy lại trên commit này.

Đọc kèm [BASELINE.md](../../BASELINE.md) để biết nguồn gốc và tình trạng kiểm thử.

---

## 1. Cấu trúc thư mục

| Thư mục / file | Trách nhiệm |
|---|---|
| `docker-compose.yml` | Stack chính: 4 container (`nginx-waf`, `backend-node-1`, `backend-node-2`, `database`), 2 network |
| `nginx/nginx.conf` | Reverse proxy TLS, load balancing, rate limit, Request-ID, trang lỗi WAF/503 |
| `nginx/modsecurity/` | ModSecurity v3: `modsecurity.conf` (engine, body processor, audit log), `main.conf` (thứ tự include), `mode/On.conf` / `mode/DetectionOnly.conf`, `crs-tuning.conf` (ngoại lệ CRS), `custom-rules/nhom9-custom.conf` (virtual patch 100100, username rule 100200) |
| `nginx/certs/generate-cert.sh` | Sinh chứng chỉ tự ký cục bộ (khóa/chứng chỉ không được commit) |
| `backend/` | Spring Boot (Java), `Dockerfile`, `pom.xml`, test JUnit; `backend/docker-compose.sqli-lab*.yml` và `backend/scripts/*.ps1` là công cụ kiểm thử lịch sử của TV3 |
| `database/init/` | `01-schema.sql`, `02-least-privilege.sql` (role ứng dụng), `03-seed-data.sql` (dữ liệu giả), `04-sqli-demo.sh` (database `sqli_lab` + role chỉ đọc) |
| `scripts/` | `init-env.sh` (sinh `.env` ngẫu nhiên, `--lab` bật API lỗi), `preflight.sh`, `waf-mode.sh`, `waf-audit.sh`, `reset-demo.sh` (**xóa volume DB và log**) |
| `tests/demo/` | 5 script demo, `run-all.sh`, `common.sh`, `test-evidence-guards.sh` (offline) |
| `tests/burp/`, `tests/postman/` | Request mẫu cho Burp/Postman (chứa mật khẩu tài khoản demo công khai) |
| `docs/` | Hợp đồng API/DB/cổng, quyết định thiết kế, checklist demo |

## 2. Docker Compose  [FACT, đã chạy `docker compose config` với giá trị giả]

- `nginx-waf`: image `owasp/modsecurity-crs:4.30.0-nginx-alpine-…@sha256:873ce68a…` (ghim digest). Port publish **duy nhất**: `127.0.0.1:${HTTPS_PORT:-443} → 8443`. Thuộc `dmz_net` và `internal_net` (IP cố định `10.209.10.10`). `cap_drop: ALL`, `no-new-privileges`.
- `backend-node-1/2`: cùng image `nhom9/blog-api:local` (build từ `./backend`), chỉ thuộc `internal_net`, không publish port. Log ghi ra `./logs/backend-node-N`.
- `database`: `postgres:16-alpine`, chỉ thuộc `internal_net`, không publish port. Healthcheck `pg_isready`.
- `internal_net`: `internal: true` (không đi ra Internet), subnet `10.209.10.0/24`.
- Biến bắt buộc trong `.env`: `DB_ADMIN_PASSWORD`, `APP_DB_USERNAME`, `APP_DB_PASSWORD`, `JWT_SECRET` (Base64 ≥ 32 byte), `SQLI_LAB_READER_PASSWORD`. Tùy chọn: `WAF_MODE` (On), `SQLI_DEMO_ENABLED` (false), `HTTPS_PORT` (443).
- Healthcheck: backend dùng `curl -f /actuator/health` (có kiểm tra DB). Nginx dùng `curl -so /dev/null http://127.0.0.1:8080/` (không có `-f`, chỉ đo tiến trình còn sống). **[INFERENCE]** Trạng thái healthy của nginx-waf không chứng minh đường HTTPS → backend hoạt động.

## 3. NGINX  [FACT]

- Upstream `backend_cluster`: `backend-node-1:8080` và `backend-node-2:8080`, round-robin, `resolve` qua Docker DNS `127.0.0.11`, `max_fails=1 fail_timeout=15s`, keepalive 16.
- Failover thụ động: `proxy_next_upstream error timeout http_502 http_503 http_504`, `proxy_next_upstream_tries 2`, `proxy_connect_timeout 1s`. **[INFERENCE]** Theo mặc định của Nginx, request không idempotent (POST) không được thử lại sang node khác nếu đã gửi đi.
- Cổng 8080 trong container redirect 301 sang HTTPS (cổng này không được publish ra host).
- TLS 1.2/1.3, chứng chỉ tự ký.
- Rate limit theo `$binary_remote_addr`: zone chung 5 r/s burst 10; `/api/v1/auth/login` 5 r/phút burst 5; trả 429.
- Header gửi xuống backend: `X-Real-IP` và `X-Forwarded-For` **ghi đè** bằng `$remote_addr` (không nối chuỗi XFF của client), `X-Request-ID $request_id`.
- Header trả về client: `X-Request-ID`, `X-Upstream`, `X-Content-Type-Options`, `X-Frame-Options`. `X-Upstream` làm lộ IP nội bộ của backend; được giữ có chủ đích để demo.
- Chặn tại gateway: `/actuator/*` trả 404 (trừ `/actuator/health`), Swagger/OpenAPI trả 404.
- Lỗi: 403 → JSON `Request blocked by WAF` kèm `X-Blocked-By: waf`. 502/503/504 → JSON 503.

## 4. ModSecurity / OWASP CRS  [FACT]

- Thứ tự include (`main.conf`): `modsecurity.conf` (SecRuleEngine On) → file mode (rỗng hoặc `SecRuleEngine DetectionOnly`) → `crs-setup.conf` → `crs-tuning.conf` → custom rules → CRS rules. File mode được mount từ `mode/${WAF_MODE}.conf`, nên directive sau cùng quyết định chế độ.
- Body processor JSON cho `^application/json` và `^application/<x>+json` (đã lowercase). **[INFERENCE]** Hai rule này phủ cả các Content-Type JSON mà Spring chấp nhận.
- Audit log JSON tại `/var/log/modsecurity/audit/modsec_audit.log` (mount ra `./logs/waf`). `SecAuditEngine RelevantOnly`. `unique_id` = `$request_id` của Nginx.
- `crs-tuning.conf` id 900500: bỏ `ARGS:json.password` và `ARGS:json.refreshToken` khỏi phạm vi quét CRS trên 4 endpoint auth (so khớp `REQUEST_FILENAME`).
- Custom rule 100100: whitelist ký tự `keyword` tại `/api/v1/vuln/records/search` (virtual patch). Rule 100200: ràng buộc ký tự username tại `/api/v1/auth/(login|register)`. Cả hai so khớp `REQUEST_FILENAME` (path, không gồm query string).
- **[UNVERIFIED]** Hành vi với các biến thể path có mã hóa, so với cách Spring/StrictHttpFirewall chuẩn hóa: Codex báo đã thử, chưa chạy lại.

## 5. Backend Spring Boot  [FACT]

- Hai node chạy cùng image và cùng biến môi trường. Profile: `integration,sqli-lab` **luôn bật** trong compose.
- `server.forward-headers-strategy=native` (profile integration). Tomcat RemoteIp chỉ tin `TRUSTED_PROXY_REGEX='10\.209\.10\.10'`, tức IP của nginx-waf.
- Datasource chính: `blogdb` với user ứng dụng (không phải admin), `ddl-auto: validate`, Hikari pool 5.
- Security (`SecurityConfig`): stateless, CSRF tắt (API Bearer token, không dùng cookie), BCrypt, `@EnableMethodSecurity`.
  - Công khai: `/api/v1/auth/**`, `GET /api/v1/posts/**` (trừ `/posts/me`), `GET /categories/**`, `GET /comments/**`, `/actuator/health`, Swagger (bị Nginx chặn).
  - Quản lý category: `ROLE_ADMIN`. `/api/v1/secure/**`: cần xác thực. `GET /api/v1/vuln/posts/**`: công khai (cố ý). `/api/v1/vuln/**` còn lại: cần xác thực. Mọi đường khác: cần xác thực.
  - 401 qua `HttpStatusEntryPoint` cho `/secure/**`, `/vuln/**`, `/posts/me`.
- JWT: access token 15 phút, refresh token 7 ngày, lưu trong bảng `refresh_tokens` (dùng chung giữa 2 node qua DB). Logout xóa refresh token. Refresh hết hạn thì xóa và báo lỗi. **[INFERENCE]** Mỗi lần cấp refresh token mới sẽ xóa các refresh token cũ của user (`deleteByUser`). Access token không thể thu hồi trước khi hết hạn (stateless).
- Exception: `GlobalExceptionHandler` map các exception domain sang 400/401/403/404/409, phần còn lại rơi vào `Exception` → 500. **[INFERENCE]** Lỗi sai kiểu tham số (ví dụ `?page=abc`) và vi phạm ràng buộc DB do request đồng thời có thể trả 500. Chưa chạy để xác nhận.

### API chính (secure)
| Base | Endpoint |
|---|---|
| `/api/v1/auth` | POST `register`, `login`, `refresh`, `logout` |
| `/api/v1/posts` | GET list, `/{id}`, `/slug/{slug}`, `/category/{id}`, `/author/{id}`, `/search`, `/me`; POST; PUT/DELETE `/{id}` (owner hoặc admin) |
| `/api/v1` comments | GET `/posts/{postId}/comments`, `/comments/{id}`; POST `/posts/{postId}/comments`; PUT/DELETE `/comments/{id}` |
| `/api/v1/categories` | GET list, `/{id}`, `/slug/{slug}`; POST/PUT/DELETE (admin) |
| `/api/v1/secure/posts` | GET/PUT/DELETE `/{id}`: bản vá IDOR, kiểm tra quyền sở hữu |
| `/api/v1/secure/records` | POST tạo, GET `/{id}`, POST `/search`: truy vấn tham số hóa, lọc theo owner |

### API cố ý có lỗ hổng (chỉ dùng trong lab)
| Endpoint | Lỗ hổng | Dữ liệu |
|---|---|---|
| POST `/api/v1/vuln/records/search` | SQL Injection (nối chuỗi) | Database riêng `sqli_lab`, role `sqli_demo_reader` chỉ đọc |
| GET/PUT/DELETE `/api/v1/vuln/posts/{id}` | IDOR/BOLA (không kiểm tra owner; GET công khai) | **Dùng chung bảng `posts` của `blogdb`** |

## 6. Profile và flag điều khiển lab  [FACT]

- `SqliLabConfiguration`, `VulnerableRecordController`, `VulnerablePostController` đều cần cả `@Profile("sqli-lab")` **và** `app.demo.sqli.enabled=true`.
- `app.demo.sqli.enabled` lấy từ `SQLI_DEMO_ENABLED`. Mặc định `false` ở cả `application.yml` và `docker-compose.yml`.
- `sh scripts/init-env.sh --lab` ghi `SQLI_DEMO_ENABLED=true` khi tạo `.env` mới. Nếu `.env` đã tồn tại, script không sửa mà báo lỗi.
- **[INFERENCE]** Vì compose luôn bật profile `sqli-lab`, trên thực tế chỉ còn flag là lớp chặn duy nhất.
- **[INFERENCE]** Khi flag tắt, các controller `/vuln/**` không tồn tại, request sẽ nhận 401/404 tùy trạng thái xác thực. Chưa chạy runtime để xác nhận.

## 7. PostgreSQL  [FACT]

- `02-least-privilege.sql`: role ứng dụng có CONNECT `blogdb`; schema public bị REVOKE khỏi PUBLIC. Quyền: `users` và `secure_records` chỉ SELECT/INSERT; `refresh_tokens` SELECT/INSERT/DELETE; `posts`/`comments`/`categories` CRUD.
- `04-sqli-demo.sh`: tạo DB `sqli_lab`, role `sqli_demo_reader` (CONNECT `sqli_lab`, SELECT `demo.records`, read-only). Role này vẫn có CONNECT mặc định của PUBLIC trên `postgres` và template DB, nhưng không có CONNECT trên `blogdb`.
- Seed (`03-seed-data.sql`): dữ liệu giả, 3 user có hash BCrypt. Mật khẩu plaintext của tài khoản demo nằm trong README, `preflight.sh`, `tests/demo/common.sh`, `tests/burp/*.http`, `tests/postman/*environment.json`. Đây là credential công khai có chủ đích, **phải đổi hoặc vô hiệu trước khi public**.
- Schema được tạo bởi init script. Không có công cụ migration (Flyway/Liquibase), Hibernate chỉ `validate`.

## 8. Log và Request-ID  [FACT]

- Nginx sinh `$request_id` (32 hex). Giá trị này được dùng làm `unique_id` của ModSecurity, gửi xuống backend qua `X-Request-ID` và trả cho client.
- Access log Nginx: `$remote_addr … rid=… upstream=… rt=… urt=…` tại `./logs/nginx/access.log`.
- Backend `MdcLoggingFilter`: nhận `X-Request-ID` nếu khớp `[A-Za-z0-9][A-Za-z0-9._-]{0,63}`, nếu không thì tự sinh UUID. Đưa vào MDC cùng method, URI, clientIp, userId. Profile khác `prod` ghi `logs/audit.log` (rolling, gzip).
- **[INFERENCE]** Backend tin `X-Request-ID` từ bất kỳ ai gửi tới. Hiện an toàn vì chỉ Nginx kết nối được tới backend. Nếu port backend lộ ra LAN, client có thể giả Request-ID.

## 9. Script demo và test

| Script | Mục đích |
|---|---|
| `demo1-failover.sh` | 2 node luân phiên → stop node 1 → 6 request vẫn 200 với token cũ → start lại → kiểm tra 2 node nhận lại request (có trap khôi phục) |
| `demo2-waf-virtual-patch.sh` | Request hợp lệ tới backend; SQLi bị 403 bởi rule 100100; backend không nhận; CRS 942100 chặn ở route secure |
| `demo3-defense-in-depth.sh` | Chuyển WAF sang DetectionOnly; vuln lộ fixture, secure không lộ; UNION sang `public.users` lỗi 400; WAF ghi log nhưng không ngắt; trả WAF về On |
| `demo4-idor.sh` | User B truy cập bài nháp của A (post 3): secure 403, vuln thành công |
| `demo5-ratelimit-audit.sh` | Brute-force login bị 429; XFF giả không lọt vào log; một Request-ID xuyên suốt 3 lớp |
| `run-all.sh` | Chạy guard test, rồi 5 demo |
| `test-evidence-guards.sh` | 10 case offline: thiếu log, log rỗng, RID rỗng, Docker lỗi phải FAIL |
| `scripts/preflight.sh` | Kiểm tra trước buổi demo (Docker, .env, health, WAF mode, flag lab, XSS bị chặn, login) |
| JUnit (`backend/src/test`) | 13 class, 78 annotation `@Test`/`@ParameterizedTest`; H2 cho phần lớn, `SqliLabPostgresTest` cần PostgreSQL (opt-in) |

Lưu ý:
- Demo 2/3/4 cần `SQLI_DEMO_ENABLED=true`.
- Demo 4 sửa dữ liệu post 3 trong `blogdb`.
- `reset-demo.sh --yes` chạy `docker compose down -v`, **xóa DB và log**.

## 10. Kết quả kiểm thử trên đúng commit này (2026-11-07)

| Hạng mục | Kết quả | Nhãn |
|---|---|---|
| `git archive 2981c24`: 162 file | Khớp 162/162 với snapshot Codex đã kiểm thử và ZIP verified | FACT |
| `sh tests/demo/test-evidence-guards.sh` | `PASS: 10 evidence/mode guard cases`, exit 0 | FACT |
| `sh -n` cho 16 script `.sh` | 0 lỗi cú pháp | FACT |
| `docker compose config` (giá trị giả) | exit 0; publish duy nhất `127.0.0.1:443→8443`; `SQLI_DEMO_ENABLED=false` | FACT |
| Quét secret trong Git history (318 blob, mọi branch) | Không có khóa riêng, token hay mật khẩu thật; chỉ có placeholder và mật khẩu demo | FACT |
| Maven 170 test | Chưa chạy lại: máy không có Java/Maven | UNVERIFIED |
| HTTP integration 126/126, demo 56 assertion, WAF, failover, PostgreSQL | Chưa chạy lại: Docker Engine không chạy | UNVERIFIED |

## 11. Còn thiếu cho mô hình hai máy và public Internet  [INFERENCE, chưa thiết kế hay thử]

1. **Upstream qua Docker DNS:** Nginx dùng tên container. Node 2 trên máy B cần IP/hostname LAN, `resolve` với Docker DNS không còn áp dụng.
2. **Kết nối PostgreSQL giữa hai host:** DB hiện chỉ ở `internal_net` (internal, không publish). Máy B cần đường kết nối riêng tới DB (publish có giới hạn IP, TLS, `pg_hba`), làm thay đổi ranh giới "DB không lộ".
3. **Lộ port backend trên máy B:** node 2 phải nghe trên LAN, nên bỏ qua WAF được nếu không firewall. Request-ID và XFF cũng bị giả được nếu không giới hạn nguồn.
4. **Trusted proxy:** `TRUSTED_PROXY_REGEX` cố định `10.209.10.10`, phải đổi theo IP Nginx thật nhìn từ máy B.
5. **IP client và rate limit:** đi qua Cloudflare Tunnel thì `$remote_addr` là IP của connector, rate limit sẽ gộp chung mọi người. Cần `real_ip` từ `CF-Connecting-IP` với `set_real_ip_from` tin cậy.
6. **Bind loopback:** gateway, `preflight.sh` và `common.sh` chỉ chấp nhận `https://localhost|127.0.0.1`. Cloudflare Tunnel chạy trên máy A có thể dùng loopback được, nhưng script kiểm tra cần chỉnh cho mô hình mới.
7. **API cố ý lỗi:** phải bảo đảm `SQLI_DEMO_ENABLED=false` trên cả hai node khi public. Nên bỏ profile `sqli-lab` khỏi cấu hình public. `/vuln/posts` dùng chung `blogdb`.
8. **Tài khoản và mật khẩu demo công khai** trong seed, README, Postman, Burp phải đổi hoặc vô hiệu hóa.
9. **Chứng chỉ:** đang tự ký. Với Cloudflare cần chứng chỉ origin hoặc cấu hình TLS phù hợp.
10. **Health/failover:** healthcheck Nginx không đo đường tới backend. Failover chỉ thụ động và không retry POST.
11. **Migration:** không có công cụ migration, schema dựa vào init script chạy lần đầu.
12. **Windows/Docker Desktop:** không giữ IP nguồn LAN; network host và firewall khác Linux.
13. **Endpoint lộ thông tin:** header `X-Upstream`, cùng `actuator/health` công khai (`show-details: when_authorized`).
