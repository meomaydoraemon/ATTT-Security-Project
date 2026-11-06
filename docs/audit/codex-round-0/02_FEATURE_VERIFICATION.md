# Ma trận nghiệm thu chức năng

Ngày27/10/2026, Asia/Saigon. SHA **0a2282931500c8dbddd35495ad3b29aca19777cc**, main-2. Runtime trên lab override; không sửa source.

Đơn vị đếm:37 hạng mục có phạm vi xác định; không phải endpoint/assertion. PASS CRUD cơ bản không phủ nhận FAIL validation biên. STATICALLY SUPPORTED chỉ là căn cứ source; F33 hỗ trợ kết luận có rủi ro, không phải đạt an toàn.

- **STATICALLY SUPPORTED: 2**
- **UNVERIFIED: 3**
- **VERIFIED FAIL: 4**
- **VERIFIED PASS: 28**

| ID | Chức năng/mục đích | Trạng thái | Thành phần/vị trí | Phụ thuộc/điều kiện | Phép thử/evidence dưới evidence/ | Rủi ro/giới hạn |
|---|---|---|---|---|---|---|
| F01 | Build từ source | VERIFIED PASS | backend/Dockerfile:1; backend/pom.xml:10 | Docker, Maven/Java21 trong builder | build/source-build.json | DskipTests chỉ build; test chạy riêng |
| F02 | Fresh startup và tích hợp4 service | VERIFIED PASS | docker-compose.yml:19; database/init/01-schema.sql:1 | Volume mới; secrets/cert; schema01–04 | docker/startup.json; database/database-init.json | Áp dụng lab override, không chứng nhận gốc mọi interface |
| F03 | Register, validation và duplicate | VERIFIED PASS | backend/src/main/java/com/blogapi/service/impl/AuthServiceImpl.java | DB INSERT users, BCrypt, username phù hợp WAF | http/independent-Core.json | Không phủ mọi race và giới hạn email/password |
| F04 | Login hợp lệ/sai mật khẩu | VERIFIED PASS | backend/src/main/java/com/blogapi/service/impl/AuthServiceImpl.java | User enabled; DB; rate budget còn | http/independent-Core.json | Rate limit có thể che authentication |
| F05 | JWT signature/malformed/expiry | VERIFIED PASS | backend/src/main/java/com/blogapi/security/JwtService.java; JwtAuthenticationFilter.java | Key chung >=32byte; DB user lookup | http/independent-Core.json; build/repository-maven-suite.json | Expired JWT được ký đúng key lab, không chỉ sửa payload; JWT vẫn phụ thuộc DB |
| F06 | Refresh/logout và thu hồi refresh | VERIFIED PASS | backend/src/main/java/com/blogapi/service/impl/AuthServiceImpl.java | refresh_tokens và token hợp lệ | http/independent-Core.json | Access còn hạn vẫn dùng được sau logout, semantics đã kiểm chứng |
| F07 | RBAC USER/ADMIN category | VERIFIED PASS | backend/src/main/java/com/blogapi/config/SecurityConfig.java; controller/CategoryController.java | Role từ DB; method security | http/independent-Core.json | MODERATOR chưa có actor riêng qua gateway, có Maven coverage |
| F08 | Post ownership GET/PUT/DELETE secure | VERIFIED PASS | backend/src/main/java/com/blogapi/service/impl/PostServiceImpl.java; security/PostReadAccessPolicy.java | JWT; owner/admin; Post ID động | http/independent-Core.json | Đường vuln vẫn truy cập cùng Post blogdb |
| F09 | Post CRUD cơ bản và public/private read | VERIFIED PASS | backend/src/main/java/com/blogapi/controller/PostController.java | JPA/schema/blogdb; pagination hợp lệ | http/independent-Core.json; build/repository-maven-suite.json | Validation biên được tách rõ F31 |
| F10 | Comment CRUD cơ bản/soft delete | VERIFIED PASS | backend/src/main/java/com/blogapi/service/impl/CommentServiceImpl.java | Post read policy; owner/mod/admin | http/independent-Core.json | Parent khác Post và pagination biên lỗi tại F31 |
| F11 | Visibility Comment của Post riêng tư | VERIFIED PASS | backend/src/main/java/com/blogapi/security/PostReadAccessPolicy.java | Spring Security thực thi với H2/MockMvc | build/repository-maven-suite.json | PASS ở H2, chưa lặp đủ46 tổ hợp qua gateway/PostgreSQL |
| F12 | Record create/read và ownership server-side | VERIFIED PASS | backend/src/main/java/com/blogapi/service/impl/RecordServiceImpl.java | JWT; secure_records; owner lấy từ principal | http/independent-Core.json | Không có Record update/delete trong phạm vi hứa |
| F13 | Secure search bind tham số/lọc owner | VERIFIED PASS | backend/src/main/java/com/blogapi/repository/RecordRepository.java:14 | JPA LOCATE :keyword/:username; payload tới backend | http/independent-Core.json; http/independent-Detection.json | Literal SQLi trả rỗng; không phải chứng nhận mọi truy vấn ứng dụng |
| F14 | SQLi vulnerable đối chứng thực | VERIFIED PASS | backend/src/main/java/com/blogapi/demo/SqliLabRepository.java:48 | sqli-lab profile; flag true; fixtures chuẩn | http/independent-Detection.json; database/postgres-optin-tests.json | Cố ý nối chuỗi, chỉ lab; normal1/injected3 |
| F15 | DB least privilege bảng/schema | VERIFIED PASS | database/init/02-least-privilege.sql; 04-sqli-demo.sh | Role riêng; admin-owned schema; reader SELECT | database/privilege-query.json; database/postgres-optin-tests.json | Reader/app vẫn CONNECT postgres/template qua PUBLIC |
| F16 | SQLi datasource isolation và cấm ghi fixture | VERIFIED PASS | backend/src/main/java/com/blogapi/demo/SqliLabRepository.java:139 | URL cố định sqli_lab; checks startup/per-request | database/postgres-optin-tests.json; http/independent-Detection.json | Áp dụng Record SQLi, không áp dụng vulnerable Post |
| F17 | Round-robin/JWT trên2 node | VERIFIED PASS | nginx/nginx.conf:35 | Cùng image/key/DB; resolver Docker | http/independent-Failover.json; demos/repository-demo-suite.json | Đối chiếu X-Upstream với log backend |
| F18 | Failover1 backend với JWT cũ | VERIFIED PASS | nginx/nginx.conf:69 | Passive failure/retry; node kia còn sống | http/independent-Failover.json; demos/repository-demo-suite.json | GET được kiểm thử; không khẳng định mọi write/in-flight đều không gián đoạn |
| F19 | Phục hồi phân phối tải sau restart node | VERIFIED PASS | nginx/nginx.conf:23 | Healthy và hết fail_timeout/DNS cache | http/independent-Failover.json | Độc lập bổ sung việc nhận request sau phục hồi, demo gốc chỉ check healthy |
| F20 | ModSecurity và phân biệt nguồn403 | VERIFIED PASS | nginx/modsecurity/modsec-nginx.conf:2; nginx/nginx.conf:121 | Module/engineOn; audit writable | waf/correlation.json; waf/nginx-config-runtime.json | Header + rule + upstream + log, không chỉ status |
| F21 | OWASP CRS SQLi/XSS | VERIFIED PASS | nginx/modsecurity/main.conf; crs-tuning.conf | Image theo digest; PL1/ngưỡng5 | waf/correlation.json; demos/repository-demo-suite.json | Chỉ payload đã thử, không cam kết chặn mọi tấn công |
| F22 | Custom100100 nhất quán khi URL có query | VERIFIED FAIL | nginx/modsecurity/custom-rules/nhom9-custom.conf:10 | Regex REQUEST_URI hiện match cả query | http/supplement-auth-query.json; waf/correlation.json | Path trần chặn; query bỏ qua custom rule; CRS vẫn chặn SQLi phổ biến |
| F23 | Custom100200 nhất quán khi URL có query | VERIFIED FAIL | nginx/modsecurity/custom-rules/nhom9-custom.conf:24 | Username policy ở WAF; DTO không có Pattern | http/supplement-auth-query.json | Username có space: path trần403, query đăng ký201 |
| F24 | Login rate limiting chống brute-force | VERIFIED PASS | nginx/nginx.conf:31; nginx/nginx.conf:94 | Theo IP peer; rate5r/m burst5 | demos/repository-demo-suite.json | 5x401 rồi3x429; không phải hard cap5 request tổng mỗi phút |
| F25 | Audit backend và WAF hoạt động | VERIFIED PASS | backend/src/main/resources/logback-spring.xml; nginx/modsecurity/modsecurity.conf | Mount writable; log nonempty; positive control | waf/correlation.json; docker/log-snapshot.json | Quét secrets lab thực không chứng nhận mọi đầu vào bất kỳ |
| F26 | Request ID xuyên3 lớp | VERIFIED PASS | nginx/nginx.conf:84; backend/src/main/java/com/blogapi/config/MdcLoggingFilter.java | ID Nginx32hex = WAF transaction ID | waf/correlation.json | Blocked không vào backend; DetectionOnly có cả3 lớp cùng ID |
| F27 | Gateway chống giả XFF/request ID | VERIFIED PASS | nginx/nginx.conf:79; backend/src/main/resources/application-integration.yml | Trust đúng10.209.10.10; overwrite header | http/independent-Core.json; waf/correlation.json | IP thấy là gateway Docker; không suy ra IP từng máyLAN |
| F28 | Network isolation/DB-backend không publish | VERIFIED PASS | docker-compose.yml:9 | Core internal; chỉ gateway ở edge; lab loopback | docker/internal-network.json; runtime-topology.json; core-egress-denied.json | Host/Docker admin ngoài trust boundary này |
| F29 | HTTPS cert self-signed/SAN | VERIFIED PASS | nginx/certs/generate-cert.sh:19; nginx/nginx.conf:59 | Cert mới; curl --cacert; listener8443 | http/certificate-health.json | Chưa đo riêng từng TLS version/cipher; không phải CA công cộng |
| F30 | Ẩn Swagger/OpenAPI/actuator phụ | VERIFIED PASS | nginx/nginx.conf:104 | Gateway trả404; health public | http/independent-Core.json; demos/repository-demo-suite.json | Không suy rộng thành phủ mọi variant URL nội bộ |
| F31 | Validation biên và HTTP error đúng | VERIFIED FAIL | backend/src/main/java/com/blogapi/controller/CommentController.java:36; dto/request/PostRequests.java:12 | Validation nhất quán schema; lỗi input map400 | http/independent-Core.json | 3x500: page âm, parent khácPost, title220/slug>200 |
| F32 | Assertion bằng chứng và fail-closed | VERIFIED FAIL | tests/demo/demo2-waf-virtual-patch.sh:36; scripts/waf-mode.sh:10 | Log có thật/readable/nonempty; kiểm tra exitDocker | demos/absent-log-false-pass.json; inaccessible-engine-mode-false-pass.json | No-request PASS khi thiếu log; WAFmode báoOn khi Docker lỗi; whole suite không luônPASS |
| F33 | Cấu hình gốc giới hạn lab loopback | STATICALLY SUPPORTED | docker-compose.yml:63; backend/src/main/java/com/blogapi/demo/VulnerablePostController.java:31 | Cần bind loopback hoặc kiểm soát tương đương | docker/original-effective-config-sanitized.json; http/independent-Core.json | Source hỗ trợ kết luận default KHÔNG giới hạn loopback; đây là rủi ro, không phảiPASS |
| F34 | Runtime nguyên Compose gốc443 mọi interface | UNVERIFIED | docker-compose.yml:63 | Không chạy do yêu cầu không công khai vuln raLAN | docker/original-effective-config-sanitized.json | Không lấy override để khẳng định gốcPASS |
| F35 | Postman collection chạy nguyên bộ | UNVERIFIED | tests/postman/Nhom9-DefenseInDepth.postman_collection.json | Postman/Newman; delay/rate/mode phù hợp | Đã đọc collection; chưa chạyGUI/Newman | HTTP chính có kiểm tra độc lập; không nâng collection thànhPASS |
| F36 | Tái hiện trên host Linux/macOS khác | UNVERIFIED | README.md; docs/decisions.md | Docker/bind permissions/cache theoOS | Chỉ hostWindows DockerDesktop được thực thi | Không suy rộng một host thành mọi nền tảng |
| F37 | Script reset-demo theo project riêng | STATICALLY SUPPORTED | scripts/reset-demo.sh:18 | Xóa volume/log có chủ ý; xác minh ownership | Đọc source; không chạy reset phá evidence | Fresh startup đạt; reset script còn hardcode preflight443 |

## Định nghĩa trạng thái

- VERIFIED PASS: đã thực thi có evidence, trong phạm vi và môi trường ghi rõ.
- VERIFIED FAIL: đã tái hiện sai lệch.
- STATICALLY SUPPORTED: căn cứ source/config, không tự tính là runtime PASS.
- UNVERIFIED: chưa đủ evidence runtime.
- NOT IMPLEMENTED và NOT APPLICABLE: không có mục nào trong37 dòng trên. FullHA, frontend, Kubernetes, Record update/delete và CA công cộng không thuộc lời hứa hiện tại; không coi thiếu chúng là lỗi.

Maven:159 test,154PASS/5SKIPPED; sau đó5/5 PostgreSQL opt-in PASS riêng. Không mô tả thành một lần159/159 no-skip. Demo gốc:39 assertionPASS. Không cộng các test khác bản chất thành tỷ lệ phần trăm hoàn thiện.

