# Kiểm chứng trước/sau và hồi quy

Ngày27/10/2026, Asia/Saigon. Base **0a2282931500c8dbddd35495ad3b29aca19777cc**; working tree codex/main-2-audit được định danh bằng evidence/source-snapshot.json. Evidence ghi command/exit code/UTC; secrets không đưa vào response artifacts.

## Trước/sau các lỗi xác nhận

| Trường hợp | Kiểm toán trước | Sau sửa |
|---|---|---|
| Comment page=-1 | 500 | 400 |
| Reply parent thuộc Post khác | 500 | 400, không tạo Comment |
| Title220 có slug vượt DB | 500, SQLState22001 | 201, slug<=200 |
| Title dài/trùng/same-title update | Chưa có regression đầy đủ | H2 và PostgreSQL thực xác minh giới hạn, uniqueness, URL ổn định |
| Unicode/apostrophe ở vuln search?audit=1 | Custom100100 bị bỏ qua,200/400 từ backend |403 từ WAF, đúng100100, không backend event |
| Username space ở register?audit=1 |201 |403 từ WAF100200; DetectionOnly thì backend400 |
| Backend log thiếu | Assertion absence vẫn PASS | Exit khác0; không có kết luận no-request giả |
| Docker/mode không đọc được | On/exit0 | Error/exit khác0 |
| Preflight trên19443 |3FAIL do hardcode443 |19PASS/0WARN/0FAIL, tự đọc HTTPS_PORT |
| Mật khẩu hợp lệ giống SQL tại register có query |403 ở phép thử bổ sung trước sửa tuning |201 sau sửa; URL trần cũng201 |
| Không bật flag vuln | Gốc luôn bật | GET vuln404, SQLi route404, secure Record201 |

Baseline lấy từ audit-results/evidence của kiểm toán, không chạy lại source cũ trên dữ liệu thật. Repro bổ sung auth-password-query-before được giữ riêng trong evidence/http của vòng này.

## Những bộ đã thực thi

| Bộ | Kết quả | Evidence |
|---|---|---|
| Regression Java mới |11/11PASS | build/targeted-java-regressions.json |
| Toàn bộ Maven + PostgreSQL opt-in |170PASS,0failure/error/skip trong cùng lần chạy | build/full-maven-postgres.json |
| Docker build/start/init volume mới |exit0,4healthy, hai backend cùng image | build/build-startup.json; docker/topology-final.json |
| Bộ HTTP độc lập gốc |126/126PASS, giữ expected results gốc | http/independent-Core.json, independent-Detection.json, independent-Failover.json, supplement-auth-query.json |
| WAF matrix On/DetectionOnly |14+14case đạt về status; rule/backend correlation kiểm tra riêng | http/waf-matrix-On.json, waf-matrix-DetectionOnly.json; waf/correlation.json |
| PostgreSQL HTTP edge |19case/assertionPASS | http/postgres-edges.json |
| Auth query false-positive |2/2PASS sau sửa, so với201/403 trước | http/auth-password-query.json; auth-password-query-before.json |
| Negative controls offline |10/10PASS | demos/final-evidence-guards.json |
| Full demo cuối |56assertionPASS,4demo chính và1bổ sung | demos/final-all-demos.json |
| Preflight tự đọc port |19PASS,0WARN,0FAIL trước demo | demos/preflight-auto-port.json |
| Mặc định không bật vuln và loopback |Flagfalse; routes404; secure201;5non-loopback TCP denied | docker/default-safety-runtime.json; local-safety.json |
| Snapshot/tracing |Đủ hai log backend; positive control; blocked không backend; DetectionOnly ba lớp | waf/correlation.json; docker/log-snapshot.json |

Không cộng170Maven,126HTTP và56demo thành một phần trăm bảo mật. 126HTTP là phạm vi giống bộ120/126 trước; WAF/PG edge và auth-query là kiểm tra bổ sung riêng. Không tính các lần chạy lại hoặc bản log lệnh thành case mới.

## Chứng minh cơ chế

**WAF On:** custom bad keyword/username nhận403 với đúng100100/100200, is_interrupted=true; không có backend access event. Payload SQLi tại secure route nhận CRS942100/949110. Normal request có backend event và response dữ liệu thật của lab.

**DetectionOnly:** custom/CRS vẫn có audit event nhưng is_interrupted=false, backend nhận request. Vuln SQLi trả3fixture, secure SQLi trả[]. Các thử users/catalog/stacked/timeout bị từ chối theo lab containment. Username sai bị backend validation400, không được hiểu là WAF đang chặn.

**Ownership/IDOR:** hai account mới và Post ID động; secure owner200/nonowner403/anonymous401. Vuln vẫn cho B sửa/xóa cùng tài nguyên lab. Không đánh đồng bảo vệ một route với bảo vệ toàn bộ tài nguyên nếu bật route cố ý lỗi.

**Failover:** hai node nhận cùng JWT,12request sau stop đều200, sau restart cả hai trở lại phục vụ. Log upstream có lần thử node lỗi rồi chuyển node sống. Không suy ra full HA hoặc mọi POST/in-flight không gián đoạn.

**IP/tracing:** backend có dòng log cùng RID, IP trùng peer được Nginx quan sát; không dựa vào việc không thấy một IP proxy hardcode. Có transaction DetectionOnly cùng RID ở đủ ba lớp.

## Phạm vi lab và sai khác cấu hình

Nguồn đã sửa tự bind loopback; override vòng này không thay ports để che lỗi. HTTPS_PORT chỉ đổi443→19443. Override chỉ đổi project/container/tag và subnet/trust IP để không đụng network của vòng trước. Dữ liệu được tạo trong volume mới, chỉ fake seed và account random. Không nối DB nghiệp vụ cũ.

Secrets/cert mới ở lab/root; cấu hình gốc .env không bị ghi đè. Root default flag không bật được render và chạy thực bằng env file không chứa SQLI_DEMO_ENABLED; khôi phục lab true sau phép thử.

## Chất lượng evidence và giới hạn

162file source của bản sao khớp byte SHA256 với working tree lúc chốt snapshot. Java image được build từ source đã sửa; WAF config mount của phiên cuối chứa auth tuning đã sửa. Git HEAD vẫn là base vì không commit.

Log WAF dùng AHKZ bỏ header/body, nhưng matched data có thể chứa trường nhạy cảm nếu một rule khớp password. Artifact chia sẻ đã che matched data của password/refreshToken; các rule ID, RID và trạng thái ngắt vẫn giữ để đối chiếu. Log gốc cục bộ và secrets nằm trong khu vực lab, không đưa vào Git.

Trong QA có một lỗi đặt tên capture: independent-core và independent-Core trùng trên Windows. Log lệnh ban đầu được giữ riêng, Core đã chạy lại với tên capture khác; file kết quả Core mới chứa đủ case và response. Không tái tạo PASS từ suy đoán hoặc dùng wrapper log thay JSON kết quả. Helper capture sau đó tránh ghi đè file đã tồn tại.

Host hiện tại Windows Docker Desktop đã đạt. Chưa thực thi trên máy/OS khác, chưa chạy GUI Postman/Newman, không kiểm tra mọi payload/cipher/concurrency hoặc HA database. Những mục đó là UNVERIFIED hoặc ngoài phạm vi, không được quảng bá thành PASS.
