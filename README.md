# Cơ sở An toàn Thông tin – BTL Nhóm 9

Kiến trúc phòng thủ đa lớp (Defense in Depth) tích hợp WAF trên Load Balancer cho ứng dụng Spring Boot phân lớp.

```text
                 Máy kiểm thử local
                          │ HTTPS 127.0.0.1:443 (prod)   127.0.0.1:9443 (lab)
              ┌───────────▼─────────────┐  dmz_net
 Lớp 1        │ nginx-waf               │  SSL Termination, Rate Limiting, Round-Robin + Failover,
 (biên)       │ ModSecurity + OWASP CRS │  JSON Body Inspection, vá ảo, X-Request-ID
              └─────┬─────────────┬─────┘
   internal_net     │             │  lab_net (10.209.20.0/24, internal, chỉ khi bật profile lab)
   (10.209.10.0/24) │             └──────────────┬──────────────────────┐
          ┌─────────┼─────────────┐       ┌──────▼──────┐        ┌──────▼──────┐
   ┌──────▼──────┐ ┌▼────────────┐ ┌▼──────────────┐ │ lab-backend │        │ lab-db      │
   │backend-node-1│ │backend-node-2│ │ database      │ │ /secure +   │        │ tmpfs, seed │
   │  /secure (vá)│ │  /secure (vá)│ │ blogdb        │ │ /vuln (lỗi) │        │ blogdb +    │
   └─────────────┘ └─────────────┘ └───────────────┘ └─────────────┘        │ sqli_lab    │
   2 node prod dùng chung image, JWT secret và CSDL    secret và dữ liệu riêng  └─────────────┘
```

Phần prod gồm **4 container** và **2 phân vùng mạng** như đề cương; hai node chỉ chạy cụm vá `/api/v1/secure`
và các API nghiệp vụ. Cụm API cố ý lỗi `/api/v1/vuln` (SQLi, IDOR) chỉ chạy trong **lab tách biệt** (xem
[Chế độ Local](#chế-độ-local-production-và-lab-tách-biệt)): container, database, mạng và JWT secret riêng, đi qua
cùng WAF ở listener `https://localhost:9443`.

**Phạm vi an toàn:** đây là môi trường dữ liệu giả, không phải cấu hình production. Mọi cổng chỉ bind `127.0.0.1`; backend/DB không publish cổng. Listener prod trả `404` cho `/api/v1/vuln/` và node prod không đăng ký route này. Hai backend chịu lỗi một node, không phải HA toàn hệ thống.

## Chế độ Local: production và lab tách biệt

| | Prod | Lab (profile `lab`) |
|---|---|---|
| Listener | `https://localhost` (cổng `HTTPS_PORT`, mặc định 443) | `https://localhost:9443` (`LAB_HTTPS_PORT`) |
| Container | `nginx-waf`, `backend-node-1`, `backend-node-2`, `database` | `lab-backend`, `lab-db` (dùng chung `nginx-waf`) |
| Mạng | `internal_net` 10.209.10.0/24 | `lab_net` 10.209.20.0/24 (không thấy DB prod) |
| API | `/api/v1/secure`, API nghiệp vụ; `/api/v1/vuln` → `404` | như prod **và** `/api/v1/vuln` (cố ý lỗi) |
| Dữ liệu | volume `postgres_data` (lâu dài) | tmpfs: mỗi lần reset nạp lại seed gốc |
| JWT secret | `JWT_SECRET` | `LAB_JWT_SECRET` (khác prod, nên token lab bị prod từ chối) |
| Demo | 1 (failover), 5 (rate limit, audit) | 2, 3, 4; Demo 6 kiểm tra cô lập giữa hai bên |

```bash
sh scripts/lab.sh up       # bật lab (chỉ lab-db, lab-backend), chờ healthy
sh scripts/lab.sh status   # trạng thái lab, listener lab và container prod
sh scripts/lab.sh reset    # đưa dữ liệu lab về seed gốc (vd. sau Demo 4), khoảng 25 giây
sh scripts/lab.sh down     # tắt và xóa 2 container lab; prod vẫn chạy
```

Tài khoản lab giống bảng [Tài khoản thử nghiệm](#tài-khoản-thử-nghiệm), nhưng nằm trong `lab-db` riêng. Lab tắt thì listener 9443 trả `503` JSON, prod vẫn chạy bình thường.
Không dùng `docker compose --profile lab down`: lệnh đó dừng cả prod. `lab.sh` kiểm tra lại sau mỗi lệnh rằng container prod không bị đổi.
WAF của listener prod luôn `On` (không có lệnh, biến hay file nào đổi được). Chỉ listener lab đổi tạm sang DetectionOnly cho Demo 3 (`sh scripts/waf-mode.sh lab DetectionOnly|On`, reload Nginx, không tạo lại container). Container khởi động lại thì lab tự về On.

## Chạy hệ thống

Yêu cầu: Docker Desktop (Compose v2) và **Git Bash** (cài cùng Git for Windows, có sẵn `openssl` và `sh`).
Mọi lệnh dưới đây chạy **trong Git Bash** (chuột phải thư mục repo > *Open Git Bash here*), từ thư mục gốc
repo; không chạy trong PowerShell hay CMD. macOS/Linux dùng terminal bình thường.

**1. Chuẩn bị môi trường**: tạo thư mục `logs/` và sinh file `.env` với mọi mật khẩu, khóa ngẫu nhiên
(chạy lại nhiều lần cũng an toàn, không ghi đè `.env` đã có):

```bash
sh scripts/init-env.sh
```

`.env` đã tồn tại được giữ nguyên giá trị; script chỉ bổ sung khóa còn thiếu, vd. các secret riêng của lab (`LAB_*`). Cờ `--lab` cũ đã ngừng dùng. Không xóa secrets/volume hiện có để chữa lỗi cấu hình.

**2. Sinh chứng chỉ tự ký** (có SAN cho `localhost` và `127.0.0.1`; khóa không được commit):

```bash
sh nginx/certs/generate-cert.sh
```

**3. Build và chạy** (lần đầu mất vài phút và cần Internet; sau mỗi lần `git pull` luôn kèm `--build`):

```bash
docker compose up -d --build --wait
```

Truy cập qua `https://localhost`. Nếu 443 bận, đặt `HTTPS_PORT=19443` trong `.env`, dùng `https://localhost:19443`. Các script tự đọc cổng này hoặc nhận `BASE=https://localhost:19443` tường minh.

**4. Kiểm tra nhanh** toàn hệ thống (Docker, `.env`, chứng chỉ, 4 container, WAF, dữ liệu mẫu), in PASS/WARN/FAIL
kèm cách sửa:

```bash
sh scripts/preflight.sh
```

**5. Bật lab và chạy toàn bộ demo** (các kiểm tra tự động, in kết quả PASS/FAIL; runner báo FAIL nếu lab chưa chạy):

```bash
sh scripts/lab.sh up
sh tests/demo/run-all.sh
```

Runner có regression offline kiểm tra log thiếu/rỗng, RID thiếu và Docker/WAF mode lỗi; thiếu evidence phải FAIL. Regression Java nằm tại `AuditFixRegressionTest.java`.

**Đưa dữ liệu demo về ban đầu:** dùng `sh scripts/lab.sh reset` (chỉ lab, không đụng prod). Không dùng `scripts/reset-demo.sh` hay `docker compose down -v` để chữa lỗi demo: cả hai **xóa volume DB prod**.

Trước buổi trình bày đọc [docs/demo-checklist.md](docs/demo-checklist.md): việc cần làm, lưu ý khi demo và bảng
xử lý sự cố.

## Tài khoản thử nghiệm

Nạp từ `database/init/03-seed-data.sql`. Chỉ dùng trên máy lab.

| Username | Mật khẩu | Vai trò | Dữ liệu |
|---|---|---|---|
| `admin` | `Admin@Nhom9-2026` | ADMIN | bài 1 |
| `user_a` | `UserA@Nhom9-2026` | USER | bài 2 (công khai), **bài 3 (NHÁP)**, Record 1–2 |
| `user_b` | `UserB@Nhom9-2026` | USER | bài 4, Record 3–4 |

Các tài khoản này có ở cả DB prod và `lab-db`. Token lấy ở `/api/v1/auth/login` của listener nào chỉ dùng được trên listener đó.

## Các demo

Demo 1 và 5 chạy trên listener prod. Demo 2, 3, 4 chạy trên listener lab (`https://localhost:9443`) và đọc log `logs/lab-backend/audit.log`.

| Demo | Script | Nội dung kiểm chứng |
|---|---|---|
| 1. HA & Failover | `tests/demo/demo1-failover.sh` | `docker compose stop backend-node-1`, token cũ vẫn dùng được, Nginx chuyển sang node 2 |
| 2. Vá ảo tại WAF | `tests/demo/demo2-waf-virtual-patch.sh` | SQLi vào `/api/v1/vuln/records/search` bị WAF chặn `403`, audit có rule `100100`, backend không nhận request |
| 3. Defense in Depth | `tests/demo/demo3-defense-in-depth.sh` | WAF chuyển DetectionOnly: bản lỗi lộ 3 dòng, bản vá (Parameterized Query) trả `[]`; bảng nghiệp vụ không có trong datasource SQLi; kiểm tra ACL riêng để chứng minh isolation |
| 4. Chống IDOR | `tests/demo/demo4-idor.sh` | User B thao tác trên nháp của A tại `/api/v1/secure/posts/{id}`: `403` từ backend (không có `X-Blocked-By`), chưa đăng nhập `401`; bản lỗi `/api/v1/vuln/posts/{id}` cho người chưa đăng nhập đọc nháp (lộ email) và cho B sửa bài |
| Bổ sung | `tests/demo/demo5-ratelimit-audit.sh` | Brute-force đăng nhập bị `429`; IP giả trong `X-Forwarded-For` không vào audit log; 1 request ID xuyên suốt Nginx, WAF, backend; Swagger, actuator và cổng 80 không mở ra ngoài |
| 6. Cô lập lab | `tests/demo/demo6-isolation.sh` | Token lab bị prod từ chối (`401`) và ngược lại; 4 route `/vuln` trả `404` trên prod, cả qua gateway lẫn khi gọi thẳng node; lab-backend không phân giải và không kết nối được DB prod; chỉ nginx-waf gắn nhiều mạng; secret khác nhau; mật khẩu/token không vào log; checksum dữ liệu prod không đổi |

Demo 3 đổi chế độ WAF của riêng listener lab bằng `sh scripts/waf-mode.sh lab DetectionOnly`, trả lại bằng `sh scripts/waf-mode.sh lab On`
(script demo tự làm việc này, kể cả khi bị Ctrl+C; prod vẫn chặn trong suốt demo). DetectionOnly là cấu hình thí nghiệm chủ động không chặn để đo lớp sau, không phải kỹ thuật bypass WAF.

Kiểm thử thủ công: Postman trong `tests/postman/` (phủ toàn bộ API), mẫu request Burp trong `tests/burp/`
(hướng dẫn trong [tests/burp/README.md](tests/burp/README.md)).
Thu thập minh chứng: [docs/test-evidence/README.md](docs/test-evidence/README.md).

## Audit log tập trung

Khi chạy, mọi log ghi ra thư mục `logs/` trên máy (đã có trong `.gitignore`):

```
logs/
├── nginx/access.log              # log truy cập Nginx (có rid, upstream)
├── waf/modsec_audit.log          # audit log ModSecurity (JSON; bỏ header/body, rà soát matched data trước khi chia sẻ)
├── backend-node-1/audit.log      # log ứng dụng node 1 (reqId, user, ip)
└── backend-node-2/audit.log      # log ứng dụng node 2
```

Một request có thể đối chiếu qua 3 lớp bằng `X-Request-ID` (= `unique_id` trong audit WAF, `reqId=` trong log backend).
Log backend bỏ các dòng healthcheck nội bộ của Docker (mỗi 10 giây) để chỉ còn sự kiện thật. Giờ trong log là UTC
(giờ Việt Nam = UTC+7).

## Cấu trúc thư mục và người phụ trách

```
CSATTT-BTL--Nhom9/
├── README.md                          # TV1 (dựng khung, hướng dẫn chạy, tài khoản thử, nguồn mã DevFinesse)
├── .gitignore                         # TV1 (.env, logs/, target/, *.key, *.crt)
├── .gitattributes                     # TV1 (ép LF cho *.sh, *.sql, *.conf, *.yml; *.http giữ CRLF)
├── .env.example                       # TV1 (mẫu biến môi trường, không chứa mật khẩu thật)
├── docker-compose.yml                 # TV1 (4 container, 2 mạng; TV2/TV3 gửi thay đổi qua ports-and-env.md)
├── scripts/
│   ├── init-env.sh                    # TV1 (tạo thư mục logs/, sinh .env với mật khẩu, khóa ngẫu nhiên)
│   ├── preflight.sh                   # TV1 (kiểm tra nhanh toàn hệ thống trước khi trình bày)
│   ├── reset-demo.sh                  # TV1 (CẢNH BÁO: xóa volume DB prod và log; không dùng để chữa lỗi demo)
│   ├── waf-mode.sh                    # TV2 (xem chế độ WAF prod/lab; chỉ đổi được lab On / DetectionOnly)
│   └── waf-audit.sh                   # TV2 (xem modsec_audit.log theo request ID)
├── docs/
│   ├── decisions.md                   # Cả nhóm đề xuất, TV1 chốt (quy ước kỹ thuật chung)
│   ├── demo-checklist.md              # TV4 (checklist trình bày, bảng xử lý sự cố; cả nhóm đọc)
│   ├── test-evidence/                 # TV4 (hướng dẫn chụp minh chứng; bản gốc để trên Drive)
│   └── contract/                      # TV3 chủ trì, cả nhóm đọc
│       ├── api-endpoints.md           # TV3 (danh sách endpoint, cặp /vuln – /secure)
│       ├── db-schema.md               # TV3 (bảng, cột, kiểu dữ liệu), TV4 đối chiếu
│       ├── tv3-v2-handover.md         # TV3 (biên bản bàn giao backend)
│       └── ports-and-env.md           # TV1 (cổng, tên service, biến môi trường)
├── nginx/
│   ├── nginx.conf                     # TV1 (upstream, SSL, Rate Limiting, header; include modsecurity/modsec-nginx.conf)
│   ├── certs/generate-cert.sh         # TV1 (script openssl tự sinh chứng chỉ có SAN; khóa không commit)
│   └── modsecurity/                   # TV2
│       ├── modsec-nginx.conf          # TV2 (modsecurity on; transaction ID = X-Request-ID)
│       ├── main.conf                  # TV2 (thứ tự nạp luật)
│       ├── modsecurity.conf           # TV2 (SecRuleEngine On, JSON body processor, modsec_audit.log)
│       ├── crs-tuning.conf            # TV2 (paranoia level, ngưỡng, method, content type, ngoại lệ)
│       └── custom-rules/              # TV2 (đúng 2 luật tùy chỉnh: 100100, 100200)
├── backend/                           # TV3 (Spring Boot 3.2.5 / Java 21; cụm /secure và /vuln trong src/.../controller, demo)
│   ├── Dockerfile, pom.xml, src/      # TV3 (test cặp /secure – /vuln: src/test/.../PostSecureVulnPairIntegrationTest.java)
│   └── (docker-compose.sqli-lab*.yml, scripts/, docs/ của bộ kiểm thử E2E riêng — TV3)
├── database/
│   └── init/                          # Mount vào /docker-entrypoint-initdb.d/ của PostgreSQL
│       ├── 01-schema.sql              # TV3 (tạo bảng, ddl-auto=validate), TV4 đối chiếu
│       ├── 02-least-privilege.sql     # TV3 (tài khoản app_user, quyền tối thiểu)
│       ├── 03-seed-data.sql           # TV4 (dữ liệu mẫu: Admin, User A, User B; mật khẩu băm BCrypt)
│       └── 04-sqli-demo.sh            # TV1 (database sqli_lab + tài khoản chỉ-đọc cho cụm /vuln)
└── tests/                             # TV4
    ├── demo/                          # TV4 tổng hợp (run-all.sh, common.sh); mỗi demo do người phụ trách lớp đó kiểm
    ├── postman/                       # TV4 (Postman Collection phủ toàn bộ API + environment)
    └── burp/                          # TV4 (mẫu request tấn công cho Repeater/Intruder)
```

Quy tắc: mỗi file chỉ một người sửa. Muốn sửa file của người khác, báo người đó trước.
Quy ước kỹ thuật: [docs/decisions.md](docs/decisions.md). Cổng, service, biến: [docs/contract/ports-and-env.md](docs/contract/ports-and-env.md). API: [docs/contract/api-endpoints.md](docs/contract/api-endpoints.md).

## Nguồn mã

Backend dựa trên [Spring-Boot-Blog-API](https://github.com/DevFinesse/Spring-Boot-Blog-API) của tác giả DevFinesse. Kho gốc không kèm giấy phép; nhóm chỉ dùng cho mục đích học tập và ghi rõ nguồn.
