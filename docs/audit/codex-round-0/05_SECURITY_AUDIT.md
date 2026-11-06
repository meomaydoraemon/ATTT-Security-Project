# Kiểm toán bảo mật và chất lượng

Ngày 27/10/2026, Asia/Saigon. main-2, SHA **0a2282931500c8dbddd35495ad3b29aca19777cc**. Runtime trong lab loopback; không sửa source.

## Authentication và Authorization

**VERIFIED PASS:** BCrypt register/login; sai mật khẩu trả 401. JWT malformed, sai chữ ký và hết hạn bị từ chối 401. Expired token được ký bằng key lab đúng để kiểm tra expiration thực, không chỉ sửa payload. Maven kiểm tra startup với key thiếu/sai/ngắn; không có raw-key fallback. JWT filter đọc lại user/enabled/role từ database, không tin role do client gán.

Refresh và logout đạt; refresh sau logout trả 401. Access token cũ vẫn dùng được đến hết hạn: đây là semantics hiện tại, không tự coi là bug nếu ứng dụng chưa hứa thu hồi access token ngay. Refresh token lưu bản rõ và một token/user; không yêu cầu thiết kế lại thành hệ thống authentication production cho BTL.

Ownership của secure Post và secure Record đạt với hai user mới và ID động. USER bị từ chối quản lý Category; ADMIN CRUD đạt. Anonymous protected write trả 401; private Post trả 401 cho anonymous và 403 cho nonowner. Không xác nhận được bypass SecurityFilterChain ở các đường secure đã thử. ERROR dispatch permitAll giữ mã lỗi gốc; direct request tới /error vẫn được Maven kiểm tra 401.

**VERIFIED:** vulnerable Post cho anonymous đọc nháp/email và nonowner sửa/xóa cùng Post trong blogdb. Đây là lỗi có chủ ý được kiến trúc khai báo, nhưng trở thành đường thay thế vô hiệu hóa ownership khi mở ngoài lab. Không được mô tả toàn ứng dụng đã chống IDOR chỉ vì /secure đạt. Toàn bộ dữ liệu runtime audit nằm trên volume mới; không truy cập dữ liệu project cũ.

Visibility bình luận có 46 case H2/MockMvc đạt. HTTP độc lập xác minh CRUD/ownership của bình luận public, chưa lặp đủ 46 tổ hợp qua gateway/PostgreSQL. Không biến coverage H2 thành chứng nhận toàn bộ database thật.

## Database security

**VERIFIED PASS:** secure Record dùng JPA bind :username/:keyword với LOCATE. Payload tautology đến Java trong DetectionOnly vẫn trả []; normal owner có dữ liệu và người khác không lấy được dữ liệu đó.

Vulnerable SQLi cố ý dùng Statement/nối chuỗi và thật sự trả ba fixture thay vì một. Datasource URL cố định sqli_lab, reader riêng. Startup và mỗi request kiểm tra role, membership, privileges, schema/extensions/functions/sequences và fixture. Có cấm dấu chấm phẩy, query timeout 2 giây, row cap 50 và socket/connect timeout. Những biện pháp đó là containment cho lab, không phải cách vá SQLi của secure API.

Role app không có superuser/create database/create role/bypass RLS hay CREATE schema; chỉ có DML cần thiết theo bảng. Reader không CONNECT blogdb và không ghi được fixture. Test PostgreSQL xác minh write bị từ chối ngay cả khi đổi default read-only về off, nên bằng chứng không dựa riêng vào read-only setting.

**Hạn chế đã xác minh:** app và reader vẫn có CONNECT tới postgres/template qua PUBLIC. Vì vậy câu “chỉ CONNECT sqli_lab” trong comment script 04 rộng hơn quyền thực tế. Không quan sát quyền đọc blogdb của reader và không kết luận đã phá containment. Có thể sửa cách diễn giải hoặc siết grant tối thiểu.

FROM public.users trong sqli_lab không phải phép thử truy vấn ba phần sang database khác. HTTP 400 có thể chỉ do relation không tồn tại. Kết luận isolation phải dựa thêm vào datasource, ACL và thử nghiệm PostgreSQL thực.

## Infrastructure security

**VERIFIED PASS trong lab:** backend/DB không publish port, chỉ tham gia core internal; egress backend thất bại; gateway nối hai network. Dockerfile chạy backend nonroot; gateway cap-drop/no-new-privileges. HTTPS được kiểm tra với certificate SAN thực. Swagger/OpenAPI/actuator phụ trả 404. Gateway overwrite XFF và request ID; backend chỉ trust đúng IP gateway. Header giả không được dùng làm bằng chứng IP.

**P0, STATICALLY SUPPORTED từ config gốc:** port 443:8443 không giới hạn host IP; vulnerable API luôn bật trên cả hai node. IDOR động đã xác minh đường vuln tác động cùng bảng nghiệp vụ. Người dùng có thể tự đăng ký tài khoản. Không kiểm tra hoặc khẳng định reachable Internet/LAN qua firewall thực tế; vấn đề là binding mặc định không cung cấp ranh giới loopback mà lab cần.

**VERIFIED FAIL:** custom rule 100100/100200 match REQUEST_URI có dấu kết thúc $, nên có query string thì không match. Đã thấy Unicode trả 200, username chứa space đăng ký 201, apostrophe đi tới backend và trả 400. CRS vẫn chặn payload SQLi chuẩn với query bằng 942100/949110. Chưa có evidence bypass toàn bộ WAF hoặc SQLi thành công khi engine On.

Unicode bị chặn ở endpoint vuln là hạn chế whitelist ASCII đã được khai báo; secure Unicode và O'Reilly trả 200. TLS1.2/1.3 được cấu hình nhưng chưa đo riêng mọi version/cipher. Certificate/key và .env của lab nằm trong lab/root; không đưa giá trị bí mật vào báo cáo hoặc evidence.

## Audit, tracing và độ tin cậy kiểm thử

Log Nginx/WAF/backend có request ID đối chiếu. WAF block có rule/is_interrupted và upstream=-; backend absence được xác nhận kèm positive control. DetectionOnly có đủ ba lớp cùng RID. Backend 403 có user/status và không có X-Blocked-By.

**VERIFIED FAIL qua negative control:** khi cả hai file log backend không tồn tại, assertion “backend không nhận request” vẫn PASS vì helper che lỗi cat rồi pipeline trả rỗng. Waf-mode viewer không đọc được Docker vẫn in On và exit0. Những assertion này không đáng tin khi thiếu positive control hoặc kiểm tra lỗi thu evidence.

Ngược lại, demo2 với URL không có service trả exit1/HTTP000. Run-all gom lỗi và trả exit1. Không có bằng chứng whole suite luôn PASS. Maven assertions có ý nghĩa trong phạm vi; mock SqliLabRepository ở Post-pair test được khai báo rõ và không được tính làm SQLi runtime. Năm PostgreSQL test skip mặc định đã được chạy opt-in riêng, 5/5 đạt.

Postman đã được đọc về status/content tests, token variables và fixed seed IDs nhưng chưa chạy Newman/GUI. Vài assertion 403 chưa kiểm tra nguồn lỗi ở mọi case. Test-V2Contract chỉ kiểm tra Compose backend lab độc lập, không nghiệm thu WAF nhóm. Test-V2Host dùng topology lịch sử khác; audit không dùng kết quả lịch sử đó để chứng nhận root stack hiện tại.

## Logic và độ tin cậy tích hợp

Ba lỗi 500 đã tái hiện: page bình luận âm, parent thuộc Post khác và title 220 ký tự được DTO cho phép nhưng slug vượt varchar200. Đây là lỗi source/contract, không phải lỗi mạng, build hay dependency. Response không lộ exception detail nhưng status/validation không đúng. Regression gốc chưa phủ các case này.

Fresh schema/init/seed/startup đạt trên volume audit mới. Hai node cùng image/key/DB; failover và recovery đạt. Khi database dừng, HTTPS health trả 503 DOWN nhưng Nginx vẫn healthy vì probe chỉ đo HTTP redirect nội bộ. Start database lại khôi phục 200 UP. Đây là bằng chứng về điểm lỗi đơn và giới hạn health, không phải yêu cầu biến BTL thành full HA.

Source không có migration volume cũ. Không lấy fresh-volume PASS làm bằng chứng nâng cấp dữ liệu hiện hữu. Không chạy SCA/CVE scan, mọi payload, DoS quy mô lớn, exhaustive concurrency, mọi API error variant hay host Linux khác. Không suy luận một version cũ tự động có CVE khai thác được. Đây là nghiệm thu BTL có phạm vi/evidence, không phải chứng chỉ an toàn sản phẩm thương mại.
