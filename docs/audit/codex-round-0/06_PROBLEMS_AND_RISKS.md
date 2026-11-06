# Vấn đề, mức ưu tiên và cách tái hiện

Ngày 27/10/2026, Asia/Saigon. main-2, SHA **0a2282931500c8dbddd35495ad3b29aca19777cc**. Không thực hiện bất kỳ phương án sửa source nào trong báo cáo.

Đường dẫn source dưới đây tính từ D:\BTL ATTT\audit-main-2. Evidence tính từ audit-results/evidence. P0/P1 là mức ưu tiên cho nghiệm thu BTL, không phải điểm CVSS.

## R01 — P0: Cấu hình mặc định mở API cố ý lỗi ngoài ranh giới loopback

- **Trạng thái:** STATICALLY SUPPORTED về binding gốc; VERIFIED về khả năng IDOR sửa/xóa cùng bảng nghiệp vụ trong lab.
- **Vị trí:** docker-compose.yml:32,33,61,63; backend/src/main/java/com/blogapi/demo/VulnerablePostController.java:31,34,41,54.
- **Bằng chứng:** docker/original-effective-config-sanitized.json không có host_ip ở port443; http/independent-Core.json xác nhận B sửa/xóa Post A, A thấy thay đổi/404 ở đường secure; waf/correlation.json có backend event, không phải WAF block.
- **Tác động:** binding gốc không tự giới hạn lab ở localhost. Anonymous đọc nháp/email; người tự đăng ký có thể sửa/xóa Post khác qua đường vuln. Đây là lỗ hổng có chủ ý, nhưng public gateway và cùng bảng blogdb làm nó nguy hiểm nếu dùng ngoài môi trường fake data. Không kiểm tra/khẳng định đã truy cập được từ Internet hay qua firewall LAN của máy hiện tại.
- **Tái hiện an toàn:** chỉ render config gốc; chạy bản sao override loopback; A register/create DRAFT và lấy ID; B PUT/DELETE /vuln/posts/ID; A GET /secure/posts/ID. Không cần chạy binding mọi interface để chứng minh khả năng phá ownership.
- **Sửa tối thiểu:** mặc định bind gateway loopback; ghi rõ toàn bộ stack là lab dữ liệu dùng một lần; profile/flag bật vuln phải tường minh. Nếu cần triển khai có dữ liệu thật thì tắt vulnerable Post hoặc cho nó dùng tập dữ liệu riêng. Không bắt buộc thêm container hay áp lại kiến trúc cũ chỉ để phục vụ BTL.
- **Test lại:** inspect active IPv4/IPv6 bindings; xác nhận backend/DB không publish; hai user/ID động; vuln chỉ tồn tại trong profile lab; request từ ngoài ranh giới bị từ chối theo cấu hình đã chọn.

## R02 — P1: Cả hai custom WAF rule bỏ qua URL có query string

- **Trạng thái:** VERIFIED FAIL.
- **Vị trí:** nginx/modsecurity/custom-rules/nhom9-custom.conf:10 và24; backend/src/main/java/com/blogapi/dto/request/AuthRequests.java:11.
- **Bằng chứng:** http/supplement-auth-query.json: keyword Unicode ở path trần403 nhưng ?audit=1 trả200; O'Reilly403→400 từ backend; username có space403→201 khi register có query. Correlation xác nhận các request query đến backend và không có custom audit event.
- **Nguyên nhân:** regex REQUEST_URI kết thúc bằng $, trong khi REQUEST_URI có query string. Backend vẫn xử lý cùng endpoint.
- **Tác động:** lớp vá ảo/input policy không áp dụng nhất quán. CRS vẫn chặn SQLi phổ biến với query bằng942100/949110; **chưa chứng minh bypass toàn WAF hoặc SQLi thành công khi On**.
- **Tái hiện:** so sánh POST /api/v1/vuln/records/search và cùng path?audit=1 với keyword trên; so sánh register username chứa space, mỗi lần dùng email/tên mới.
- **Sửa tối thiểu:** so khớp path đã chuẩn hóa tách query, kiểm soát các biến thể URL được backend chấp nhận; áp cùng chính sách username ở backend nếu đó là hợp đồng dữ liệu.
- **Test lại:** cả hai rule với không query/có query/encoded path và parser JSON; assert403 + đúng rule ID + không có upstream/backend; normal request vẫn qua; lặp CRS riêng để không nhầm nguồn chặn.

## R03 — P1: Đầu vào bình luận sai trả HTTP500

- **Trạng thái:** VERIFIED FAIL, hai trường hợp.
- **Vị trí:** backend/src/main/java/com/blogapi/controller/CommentController.java:36; service/impl/CommentServiceImpl.java:54,59; exception/GlobalExceptionHandler.java:107.
- **Bằng chứng:** GET /api/v1/posts/2/comments?page=-1 trả500, RID454b4cf73ad0081dcb7c47810bceeba9. Tạo reply có parent thuộc Post khác trả500, RIDc8736a11e2eb47b10679f5be63caade0. Backend ghi IllegalArgumentException, không phải WAF.
- **Tác động:** lỗi do client bị trình bày thành lỗi server; bộ test gốc vẫn xanh, khiến tuyên bố validation đầy đủ thiếu cơ sở. Giới hạn depth có cùng cách ném exception nhưng chưa tái hiện runtime riêng, chỉ căn cứ tĩnh.
- **Tái hiện:** GET page=-1; A tạo hai Post và Comment ở Post thứ nhất, gửi parentId Comment đó khi POST comment vào Post thứ hai.
- **Sửa tối thiểu:** kiểm tra page>=0/size>0 trước PageRequest; chuyển các lỗi parent/depth thành domain invalid-request được map400. Tránh map mọi IllegalArgumentException hệ thống thành400 một cách mù quáng.
- **Test lại:** page=-1,size=0; parent khác Post, parent không tồn tại, depth6; normal replies và private-Post authorization vẫn đúng.

## R04 — P1: Hợp đồng title/slug không nhất quán gây500 cho input hợp lệ

- **Trạng thái:** VERIFIED FAIL.
- **Vị trí:** backend/src/main/java/com/blogapi/dto/request/PostRequests.java:12,27; entity/Post.java:28; service/impl/PostServiceImpl.java:41; database/init/01-schema.sql:24.
- **Bằng chứng:** title gồm220 ký tự a được DTO max255 chấp nhận nhưng slug dài220 vượt varchar200; HTTP500, RIDfeeb03c8fbf1bf24cf3fb7738d07ac8a. Backend SQLState22001, value too long for type character varying(200).
- **Tác động:** API reject input hợp lệ theo contract; có thể phá demo nhập title dài. Không phải lỗi image, mạng hay dependency.
- **Tái hiện:** user đăng nhập, POST /api/v1/posts với title220 ký tự a, content hợp lệ.
- **Sửa tối thiểu:** giới hạn/truncate slug an toàn và dành chỗ cho hậu tố uniqueness, hoặc đồng bộ contract/schema có chủ đích. Không cần thiết kế lại toàn bộ bài viết.
- **Test lại:** create/update title200,201,220,255; nhiều title trùng cần hậu tố; tiếng Việt/chuỗi không tạo slug; giữ uniqueness và response lỗi hợp lý.

## R05 — P1: Một số assertion chứng minh bằng sự vắng mặt có thể PASS sai

- **Trạng thái:** VERIFIED FAIL với negative control.
- **Vị trí:** tests/demo/common.sh:59; tests/demo/demo2-waf-virtual-patch.sh:36; tests/demo/demo5-ratelimit-audit.sh:22–25; demo2:42–45.
- **Bằng chứng:** demos/absent-log-false-pass.json: cả hai log backend không tồn tại nhưng assertion no-request vẫn PASS, exit0. Helper cat che stderr rồi pipeline trả rỗng. Hai assertion IP giả của demo5 cũng so count0 mà không đòi LINE nonempty. Bước CRS in rule IDs nhưng chỉ assert403.
- **Tác động:** không có log có thể bị hiểu nhầm là backend không nhận request hoặc IP chống giả đúng; backend403 có thể bị hiểu nhầm là CRS chặn ở bước kiểm tra thiếu nguồn.
- **Tái hiện:** dùng hàm common.sh nguyên bản, trỏ ROOT vào thư mục tạm không có log, grep một RID không rỗng và chạy check0 giống demo2. Không cần xóa log thật.
- **Sửa tối thiểu:** log file phải tồn tại/readable/nonempty; gửi positive control cùng endpoint và xác nhận backend log; chỉ sau đó kiểm tra blocked RID vắng mặt. Assert rule ID, interruption, upstream và nguồn403. Không bỏ qua lỗi Docker/grep khi thu chứng cứ.
- **Test lại:** mất file, thiếu quyền đọc, log rỗng, RID rỗng, backend logging hỏng, backend403, service unreachable; tất cả phép thiếu evidence phải FAIL/UNVERIFIED. HTTP happy path hiện tại vẫn đạt.

## R06 — P2: waf-mode báo On khi không đọc được trạng thái

- **Trạng thái:** VERIFIED FAIL với Docker stub trả lỗi.
- **Vị trí:** scripts/waf-mode.sh:10–15.
- **Bằng chứng:** demos/inaccessible-engine-mode-false-pass.json: Docker giả lập exit1, script vẫn “WAF đang ở chế độ: On”, exit0.
- **Tác động:** người trình bày có thể tin WAF đang chặn khi container/Engine/grep thất bại. Không suy ra script chuyển chế độ lúc runtime đã hỏng: các lần chuyển thật đã đạt.
- **Tái hiện:** PATH tạm đặt executable docker trả1 rồi gọi script ở chế độ xem hiện tại; không dừng Engine thật.
- **Sửa tối thiểu:** phân biệt đọc thành công và nội dung mode với lỗi truy cập; trả Unknown/error và exit khác0 khi không đủ evidence.
- **Test lại:** engine không truy cập được, container stopped, thiếu mode file, On và DetectionOnly thật; lỗi restore phải hiển thị rõ.

## R07 — P2: Diễn giải thực nghiệm dễ dẫn đến kết luận học thuật quá mức

- **Trạng thái:** STATICALLY SUPPORTED về câu chữ, runtime đối chứng đã được xác minh.
- **Vị trí:** tests/demo/demo3-defense-in-depth.sh:16,39; scripts/waf-mode.sh:3; README.md phần demo1–3; database/init/04-sqli-demo.sh:6.
- **Bằng chứng:** DetectionOnly cho payload qua theo cấu hình; FROM public.users gây400 vì bảng không tồn tại ở datasource lab; DB ACL mới là evidence isolation; topology có gateway/DB/host đơn.
- **Tác động:** nhầm “bypass WAF”, “đã chứng minh truy vấn chéo DB bị ACL chặn” chỉ từ400, hoặc “HA toàn hệ thống”.
- **Tái hiện/kiểm chứng:** đọc câu chữ và đối chiếu independent-Detection, privilege-query, topology và dependency-recovery-decoded.
- **Sửa tối thiểu:** gọi DetectionOnly là thí nghiệm chủ động không chặn; mô tả riêng parameter binding, ACL và datasource; gọi demo1 là chịu lỗi một backend.
- **Test lại:** người trình bày giải thích được vì sao từng request có kết quả và evidence nào loại trừ giải thích thay thế.

## R08 — P2: Preflight không tái sử dụng BASE/project image của lab

- **Trạng thái:** VERIFIED FAIL khi chạy với override18443; không kết luận gốc443 hỏng.
- **Vị trí:** scripts/preflight.sh:24,79–88; tests/demo/common.sh:7 hỗ trợ BASE trong khi preflight không dùng.
- **Bằng chứng:** demos/preflight-original-port.json:12PASS,3WARN,3FAIL. End-to-end curl --cacert18443 cùng thời gian200; baFAIL là request hardcode443/HTTP000; tag gốc tạo WARN.
- **Tác động:** khó tái hiện ở máy có cổng443 bận hoặc nhiều project; gợi ý reset database có thể không đúng nguyên nhân.
- **Tái hiện:** chạy preflight với BASE=https://localhost:18443 trong lab riêng.
- **Sửa tối thiểu:** dùng BASE và image thực/effective config; thêm connect/request timeout và chẩn đoán đúng transport; tránh đề xuất reset dữ liệu khi chỉ sai URL.
- **Test lại:** default443, override18443, cổng không listen, cert không tin cậy, rate429; phân biệt từng lỗi.

## R09 — P2: Câu “reader chỉ CONNECT sqli_lab” rộng hơn ACL thực tế

- **Trạng thái:** VERIFIED về quyền; không có evidence đọc được blogdb.
- **Vị trí:** database/init/04-sqli-demo.sh:6,19–20.
- **Bằng chứng:** database/privilege-query.json: reader CONNECTblogdb=false, sqli_lab=true nhưng postgres/template0/template1=true quaPUBLIC.
- **Tác động:** mô tả least privilege thiếu chính xác; nếu quảng bá “chỉ một DB” thì kiểm chứng không đạt.
- **Tái hiện:** query has_database_privilege cho từng database dưới provisioning owner, không cần lộ password.
- **Sửa tối thiểu:** sửa lời giải thích theo quyền thực; nếu cần cam kết độc quyền CONNECT thì revoke các grantPUBLIC không cần trên cluster lab và grant tường minh phù hợp. Không cần bổ sung hệ thống quản lý quyền phức tạp.
- **Test lại:** ma trận CONNECT từng DB, SELECT/WRITE/CREATE/TEMP, đảm bảo backend startup và fixture checks vẫn đạt.

## R10 — P2: Health gateway không đại diện đường HTTPS/backend và tài liệu vận hành còn lệch

- **Trạng thái:** VERIFIED về health; STATICALLY SUPPORTED về tài liệu.
- **Vị trí:** docker-compose.yml:73–76; docs/demo-checklist.md:8 và phần xử lý sự cố; backend/docs/FEATURE_FREEZE.md và contract/tv3-v2-handover.md.
- **Bằng chứng:** dependency-recovery-decoded.json: DB dừng, HTTPShealth503DOWN nhưng Nginx vẫn healthy; DB start lại, HTTPS200UP. Tài liệu có ghi chú tích hợp mới song vẫn còn đoạn identity/JWT riêng, WAF NOT RUN hoặc pull origin main khi nhiệm vụ kiểm tra main-2.
- **Tác động:** healthy bị dùng làm proof toàn hệ thống; người vận hành nhầm tài liệu lịch sử/branch hoặc dọn container chung tên. Đây không phải yêu cầu biến BTL thành full HA.
- **Tái hiện:** dừng riêng database lab; so HTTPShealth với inspect gateway; đọc các chỉ dẫn mâu thuẫn.
- **Sửa tối thiểu:** probe phù hợp mục đích hoặc ghi rõ health chỉ là process liveness, thêm end-to-end preflight; đánh dấu tài liệu lịch sử và một lệnh chạy hiện hành; không đề xuất xóa container khác bằng tên chung.
- **Test lại:** cert thiếu, DB down, một node down, WAF config sai, clean start/restart; mỗi mức health có ý nghĩa rõ. Đối chiếu branch/SHA trước dựng demo.

## P3 — Không cấp thiết

Refactor cấu trúc, tối ưu N+1, đổi refresh-token design sang production, distributed rate limiting, Kubernetes, frontend, WAF dashboard và HA database không cần để đạt mục tiêu BTL hiện tại. Không tìm thấy căn cứ phải mở rộng các hạng mục đó trước khi sửa những lỗi trên.

