# Nghiệm thu demo

Ngày27/10/2026, Asia/Saigon. SHA **0a2282931500c8dbddd35495ad3b29aca19777cc**, main-2. Bản sao nguyên source + override loopback18443. Evidence có command, UTC và exit code; không lưu JWT/password của HTTP response.

## Kết quả tổng hợp

| Demo | Script gốc | Đối chứng độc lập | Kết luận |
|---|---|---|---|
| 1 LB/failover | 3PASS/0FAIL | JWT trên2node,12request sau stop,12sau phục hồi và log | VERIFIED PASS trong phạm vi một backend |
| 2 WAF/virtual patch | 6PASS/0FAIL | Custom100100/CRS, no upstream/backend và positive log control | VERIFIED PASS với payload chuẩn; custom rule không phủ URL có query |
| 3 Defense in Depth | 7PASS/0FAIL | Normal1/injected3, secure rỗng, đủ3log ở DetectionOnly | VERIFIED PASS đối chứng, cần diễn giải đúng chế độ |
| 4 IDOR | 13PASS/0FAIL | Hai account mới, Post ID động, secure403/401, vuln đọc/sửa/xóa | VERIFIED PASS đối chứng; vulnerable Post chạm blogdb |
| 5 bổ sung | 10PASS/0FAIL | Correlation/IP/hidden routes và HTTPS độc lập | VERIFIED PASS các hành vi đã đo |

Gốc:39assertionPASS, exit0, tại evidence/demos/repository-demo-suite.json. **4/4demo chính đạt kịch bản kiểm thử, cộng1demo bổ sung.** Điều này không có nghĩa mọi chức năng của WAF hay mọi biến thể request đều đạt.

Bộ kiểm tra độc lập chuẩn lấy Core, Detection, Failover và supplement-auth-query:126case/assertion,120đạt/6không đạt. Ba lỗi500 và ba lệch custom-rule URL; các phép bổ sung có cả status assertion lẫn content assertion. supplement.json là lần khám phá trước7case, giữ làm lịch sử và không cộng lặp vào126.

## Demo1 — LB và failover

**Đầu vào:** hai node healthy, cùng image/key/DB; gateway On; account mới A. **Các bước:** đăng ký/lấy token;8GET /posts/me; stop riêng backend-node-1;12GET token cũ; start node; chờ healthy và16giây;12GET.

**Expected:** cả2upstream nhận request và nhận JWT; node2 sống sau stop; node1 trở lại phân phối. **Actual:**8/8 trước stop200;12/12 sau stop200;12/12 sau phục hồi200. Hai IP10.209.10.3 và10.209.10.4 xuất hiện trước/sau; sau stop chỉ node2 thực sự xử lý. Các request có upstream chain chứng minh đã thử node1 lỗi rồi retry node2.

Ví dụ RID sau stop có retry: ed7e57d9294f6dd6c73460eea4eafc8d, upstream10.209.10.4:8080,10.209.10.3:8080. Trong12request đo không có HTTP lỗi. Có kết nối upstream thất bại được che bằng retry; không được gọi là không có lỗi ở mọi lớp.

**Evidence:** http/independent-Failover.json; waf/correlation.json; nginx/access snapshot; gốc demo1. Demo gốc chỉ check node healthy sau start, kiểm tra độc lập đã bổ sung phân phối trở lại. Không phải HA toàn hệ thống, không kiểm thử mọi POST/in-flight. Tái hiện được trên host hiện tại, cần giữ URL/project/cert và chờ DNS/fail_timeout trên máy khác.

## Demo2 — WAF và vá ảo

**Đầu vào:** engineOn, audit writable, tokenA. **Các bước:** normal keyword alpha; SQLi vào vuln; cùng SQLi vào secure; đối chiếu header/RID/audit/Nginx/backend. Kiểm tra log bằng request hợp lệ trước khi tin sự vắng mặt của log.

**Expected:** normal200, SQLi403 do WAF;100100 trên vuln,942100/949110 trên secure; backend không nhận blocked request. **Actual:** đúng đối với payload chuẩn. RID độc lập dd3016d1db2b1adeeb7ae555c1b05c68:403,100100,is_interrupted=true,upstream=-,không có backend access event. Secure RID2f9d62e0affe736bf3201886c0f870b7:403,942100/949110. Normal có backend event và content fixture.

**False-positive:** Unicode trong keyword vuln bị100100 chặn; đây là hạn chế whitelist ASCII đã được tài liệu khai báo, cần giới thiệu rõ. Secure Unicode và O'Reilly đều200 khi engineOn.

**Lỗi bổ sung:** thêm ?audit=1 làm100100 không áp dụng. Unicode chuyển403→200; O'Reilly chuyển403→400 từ backend. SQLi chuẩn với query vẫn403 bởi CRS. **Không có evidence bypass toàn bộ WAF hoặc SQLi thành công khi engineOn**; có evidence custom virtual patch thiếu phạm vi URL. Rule100200 bị lỗi tương tự, username space đăng ký được201 khi có query.

**Evidence:** http/independent-Core.json, supplement-auth-query.json, waf/correlation.json. Demo2 đạt phép đối chứng payload gốc nhưng chưa thể nghiệm thu tuyên bố virtual patch hoạt động nhất quán mọi URL hợp lệ. Tái hiện khác máy chỉ cần cùng image/config và request tương ứng.

## Demo3 — Defense in Depth

**Đầu vào:** lab loopback, chuyển DetectionOnly bằng script gốc; giữ core/DB không publish. **Bước:** normalalpha; SQLi cùngpayload trên vuln/secure; thử users/catalog/stacked/timeout; đối chiếu log; trảOn.

**Expected:** WAF phát hiện nhưng không chặn; Java nhận request; vuln lộ3fakefixture; secure coi payload literal và không trả dữ liệu; reader không đọc/ghi ngoài phép. **Actual:** normal200/1dòng; vulnSQLi200/3dòng; secureSQLi200/[]; users400,pg_authid400,stacked400,query pg_sleep bịtimeout400. Backend log có cùngRID với WAF DetectionOnly/is_interrupted=false và gateway upstream thật.

Ví dụ vuln RID9ebb1b6ac77dc69b454aa59fdbac5884; secure RIDaae179bd2a8a8fbecc2301d650d51925. Source RecordRepository bind cả username và keyword; runtime owner search xác nhận A không lấy RecordB. PostgreSQL opt-in5/5 xác minh quyền thực và write bị từ chối ngay cả khi đổi default read-only.

**Diễn giải học thuật:** DetectionOnly là chủ động tắt hành động chặn để đo lớp sau. Không phải kỹ thuật bypass WAF. UNION FROM public.users là truy vấn bảng không có trong sqli_lab; HTTP400 tự nó không chứng minh quyền/kiến trúc database. Bằng chứng mạnh là datasource cố định, DB ACL, reader không CONNECT blogdb và test PostgreSQL.

**Evidence:** http/independent-Detection.json; database/postgres-optin-tests.json,privilege-query.json; waf/correlation.json; demos/independent-detection-run.json. Script đã trảOn; không sửa rule để có kết quả. Repro trên host hiện tại đạt; dùng fake fixture và chờ mode-recreate trên máy khác.

## Demo4 — IDOR/Broken Access Control

**Đầu vào:** hai user đăng ký độc lập A/B; A tạo PostDRAFT và lấy ID từ response, không cố định3. **Bước:** A đọc; B GET/PUT/DELETE secure; anonymous GET secure/public; anonymousGETvuln; BPUTvuln; Ađọcsecure xác nhận đổi; BDELETEvuln; Ađọcsecure xác nhận404.

**Expected/Actual:** owner200; nonowner secure3x403; anonymous401;403không X-Blocked-By và có backend event; vuln anonymous200/lộemail; BPUT200 làm đổi title; BDELETE204; AGET404. Dynamic PostID5 trong lần audit.

RID secure PUT94c25677bfb67aa05644e9ffe82d170e có backend userB/403. RID vuln PUT2493cbd685101c2eba3b7c056e017e2b; verifyA517153f7627ebafa8002d7dc5931ce28; DELETEe90bbc909a483961fe42b01dc29c098e; GETgone423429bc618b632962ae000ab9d1da38.

**Evidence:** http/independent-Core.json, waf/correlation.json, log snapshot. **Giới hạn quan trọng:** vulnerable Post tác động cùng bảng blogdb, không được cách ly như SQLi Record. Kết luận chỉ là đường secure có ownership; toàn ứng dụng chưa chống IDOR khi đường vuln vẫn public. Gốc dùngID3 và sửa titleseed, độc lập dùng dữ liệu mới.

## Demo5 — Rate, audit, tracing và cổng

**Đầu vào:** chờ hạn mức login hồi; modeOn. **Bước:**8login sai liên tiếp; gửi XFF/X-Real-IP giả; payloadXSS và normal; đọcSwagger/OpenAPI/actuator; kiểm tra80.

**Actual:**401,401,401,401,401,429,429,429. Backend failed-login log và gateway429 phân biệt được. Header giả6.6.6.6 không vào backend log; peer quan sát172.20.0.1. Client-chosen request ID bị gateway thay bằng32hex. XSS có gateway/WAF cùngID và không backend; normal có backend. DetectionOnly của demo3 cung cấp **một request thực sự có cả3lớp**. Swagger/OpenAPI/actuator phụ404;80không listen trong lab. Curl --cacert nhậnHTTPS200UP.

**Giới hạn:** rate theo IPpeer Docker, có thể gộp nhiều máy; không chứng nhận nhận diện IP LAN thật. Cổng80 gốc test là ambient host check nên phải đối chiếu bindings lab. Self-signed không là certificate CA công cộng. Preflight gốc hardcode443 fail trên18443 đã phân loại harness mismatch.

## Điều kiện để đưa vào bài trình bày

Giữ payload/schema đơn giản, ID động, evidence theoRID, hiển thị đủ2chếđộ và nguồn403. Sửa custom URL scope, error500 và assertion thiếu positive control trước nghiệm thu lại. Chỉ trình bày môi trường cô lập/fake data. Không dùng con số39PASS thay cho bằng chứng toàn bộ security.
