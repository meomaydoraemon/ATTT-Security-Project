# Cổng, service và biến môi trường

Nguồn sự thật cho `docker-compose.yml` ở thư mục gốc.

Chế độ Local (D11):
- Publish đúng 2 cổng, đều loopback: `127.0.0.1:${HTTPS_PORT:-443}:8443` (prod) và `127.0.0.1:${LAB_HTTPS_PORT:-9443}:9443` (lab).
- API cố ý lỗi chỉ chạy ở `lab-backend` (profile `lab`).
- Gateway healthcheck chỉ đo process/HTTP redirect; preflight mới kiểm tra HTTPS/WAF/backend end-to-end.

## Service và mạng (prod 4 container; bật profile `lab` thì thêm 2 container)

| Service (container_name) | Image | Mạng (IP cố định) | Cổng ra host | Ghi chú |
|---|---|---|---|---|
| `nginx-waf` | `owasp/modsecurity-crs:4.30.0-nginx-alpine-202610180210@sha256:873ce68a…` (CRS 4.30.0, ModSecurity 3.0.17, Nginx 1.30.6, Alpine 3.24.2) | `dmz_net`; `internal_net` (10.209.10.10); `lab_net` (10.209.20.10) | `127.0.0.1:443`→8443 (prod), `127.0.0.1:9443`→9443 (lab); cổng 8080 chỉ dùng nội bộ cho healthcheck | Điểm vào duy nhất; container duy nhất gắn nhiều mạng; nginx chạy uid 101, `cap_drop: ALL` |
| `backend-node-1`, `backend-node-2` | `nhom9/blog-api:local` (build `./backend`) | `internal_net` | không | Cổng nội bộ `8080`; chỉ có `/secure` và API nghiệp vụ (`/vuln` trả 404); `mem_limit` 768m |
| `database` | `postgres:16-alpine` | `internal_net` | không | Volume `postgres_data`; chứa `blogdb` (và `sqli_lab` tồn dư, R-RES-01) |
| `lab-db` (profile `lab`) | `postgres:16-alpine` | `lab_net` | không | tmpfs; chạy nguyên văn `database/init/01–04`; có `blogdb` và `sqli_lab` của lab |
| `lab-backend` (profile `lab`) | `nhom9/blog-api:local` | `lab_net` | không | Profile `integration,sqli-lab`; có `/secure` và `/vuln`; JWT secret riêng; log ở `logs/lab-backend/`; `mem_limit` 768m |

`internal_net` (10.209.10.0/24) và `lab_net` (10.209.20.0/24) đều `internal: true`: không ra Internet, không publish cổng. Chỉ `nginx-waf` gắn nhiều mạng (`dmz_net`, `internal_net`, `lab_net`). Lab không thấy DB prod và ngược lại (kiểm chứng ở Demo 6).

Lệnh demo dùng đúng tên service/container: `docker compose stop backend-node-1`. Bật/tắt lab bằng `sh scripts/lab.sh up|down|reset|status`, không dùng `docker compose --profile lab down` (lệnh này dừng cả prod).

## Biến trong `.env` (sinh bằng `sh scripts/init-env.sh`, mẫu `.env.example`)

`init-env.sh` chỉ bổ sung khóa còn thiếu, không đổi giá trị đã có và không in giá trị nào.

| Biến | Dùng bởi | Yêu cầu |
|---|---|---|
| `DB_ADMIN_PASSWORD` | `database` (`postgres_admin`) | Ngẫu nhiên; chỉ dùng cho khởi tạo |
| `APP_DB_USERNAME` | `database` (script 02), 2 node (`DB_USERNAME`) | Mặc định `app_user` |
| `APP_DB_PASSWORD` | `database` (script 02), 2 node (`DB_PASSWORD`) | Ngẫu nhiên, tối thiểu 24 ký tự |
| `JWT_SECRET` | 2 node prod | Base64 của >= 32 byte; backend từ chối khởi động nếu sai |
| `WAF_MODE` | `nginx-waf` | `On` (mặc định) hoặc `DetectionOnly` |
| `HTTPS_PORT` | `nginx-waf` | Mặc định 443; chỉ đổi cổng, luôn bind 127.0.0.1 |
| `SQLI_LAB_READER_PASSWORD` | `database` (script 04) | Tồn dư R-RES-01; node prod không còn dùng |
| `LAB_JWT_SECRET` | `lab-backend` | Base64 >= 32 byte, **khác `JWT_SECRET`** |
| `LAB_DB_ADMIN_PASSWORD` | `lab-db` | Ngẫu nhiên |
| `LAB_APP_DB_PASSWORD` | `lab-db` (script 02), `lab-backend` | Ngẫu nhiên, tối thiểu 24 ký tự |
| `LAB_SQLI_READER_PASSWORD` | `lab-db` (script 04), `lab-backend` | Ngẫu nhiên |
| `LAB_HTTPS_PORT` | `nginx-waf` | Mặc định 9443; luôn bind 127.0.0.1 |
| `SQLI_DEMO_ENABLED` | không service nào | **Ngừng dùng**; preflight in INFO nếu biến còn trong `.env` |

## Biến cố định trong compose

| Biến | Giá trị | Lý do |
|---|---|---|
| `DB_HOST` / `DB_PORT` / `DB_NAME` | prod: `database` / `5432` / `blogdb`; lab: `lab-db` / `5432` / `blogdb` | Service thật của compose |
| `SPRING_PROFILES_ACTIVE` | prod: `integration`; lab: `integration,sqli-lab` | Chỉ lab bật cụm `/vuln` |
| `SQLI_DEMO_ENABLED` | prod: `"false"` (ghi cứng); lab: `"true"` | Không đọc từ `.env` |
| `SPRINGDOC_API_DOCS_ENABLED`, `SPRINGDOC_SWAGGER_UI_ENABLED` | prod: `"false"` | Gọi thẳng node `/v3/api-docs` cũng trả 404 |
| `SQLI_DEMO_DB_URL` | lab: `jdbc:postgresql://lab-db:5432/sqli_lab` | Chỉ lab; database riêng, reader chỉ đọc |
| `SQLI_DEMO_DB_USERNAME` | lab: `sqli_demo_reader` | Tài khoản chỉ SELECT fixture |
| `TRUSTED_PROXY_REGEX` | prod: `10\.209\.10\.10`; lab: `10\.209\.20\.10` | Backend chỉ nhận IP client qua `X-Forwarded-For` khi kết nối đến từ IP của `nginx-waf` trên mạng tương ứng |

## Header Nginx gửi xuống backend (cả hai listener)

| Header | Giá trị | Ghi chú |
|---|---|---|
| `X-Forwarded-For`, `X-Real-IP` | `$remote_addr` | Ghi đè, không nối thêm giá trị client gửi |
| `X-Forwarded-Proto` | `https` | |
| `X-Request-ID` | `$request_id` (32 hex) | Cũng là `unique_id` trong `modsec_audit.log`; client không tự đặt được |

Header trả về client: `X-Request-ID`, `X-Upstream` (chỉ cho demo), `X-Content-Type-Options`, `X-Frame-Options`; khi WAF chặn có thêm `X-Blocked-By: waf`. Phần dùng chung của hai listener nằm ở `nginx/includes/listener-common.conf`.

## Đường dẫn Nginx

| Listener | Location | Rate limit | Đích |
|---|---|---|---|
| prod 8443 | `= /api/v1/auth/login` | 5 r/phút mỗi IP, burst 5 (`loginlimit`) | `backend_cluster` |
| prod 8443 | `= /actuator/health` | 5 r/giây, burst 10 (`mylimit`) | `backend_cluster` |
| prod 8443 | `^~ /api/v1/vuln/` | — | `404` JSON tại Nginx |
| prod 8443 | `/` (gồm `/api/v1/secure`) | 5 r/giây, burst 10 (`mylimit`) | `backend_cluster` |
| lab 9443 | `= /api/v1/auth/login` | 5 r/phút, burst 5 (`lab_login`) | `lab_cluster` (`lab-backend`) |
| lab 9443 | `= /actuator/health`, `/` (gồm `/api/v1/secure` và `/api/v1/vuln`) | 5 r/giây, burst 10 (`lab_api`) | `lab_cluster` |
| cả hai | `/actuator/` (còn lại), `/swagger-ui*`, `/v3/api-docs*` | — | `404` tại Nginx |

Không còn node nào phản hồi, hoặc lab đang tắt: Nginx trả `503` JSON.

## Thư mục log trên host (mount từ container)

| Đường dẫn | Nguồn |
|---|---|
| `logs/nginx/access.log` | Nginx access log, có `srv=<cổng listener>` ở cuối dòng (8443 prod, 9443 lab) |
| `logs/waf/modsec_audit.log` | ModSecurity audit (JSON), chung cho hai listener |
| `logs/backend-node-1/audit.log`, `logs/backend-node-2/audit.log` | Log ứng dụng mỗi node prod |
| `logs/lab-backend/audit.log` | Log ứng dụng của lab-backend |

`logs/` nằm trong `.gitignore`.
