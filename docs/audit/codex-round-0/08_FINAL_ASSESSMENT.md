# Kết luận nghiệm thu độc lập

Ngày **27/10/2026**, múi giờ Asia/Saigon. Repository Lemonimjuice/CSATTT-BTL--Nhom9, nhánh **main-2**. Commit được khóa: **0a2282931500c8dbddd35495ad3b29aca19777cc**, khớp remote tại lúc bắt đầu và lần xác minh sau đó.

## Kết luận: NO-GO cho việc chốt bản hiện tại là “sẵn sàng nộp”

**Dự án có triển khai thật, build được và vận hành được; bốn demo chính cùng demo bổ sung đã chạy thành công trong lab cô lập.** Không có căn cứ để nói dự án chỉ gồm script/README hoặc phải viết lại.

Tuy nhiên, nguyên cấu hình mặc định chưa phù hợp ranh giới lab an toàn, cả hai custom WAF rule bỏ qua URL có query, ba đầu vào gây HTTP500 và một số assertion có thể PASS khi thiếu bằng chứng. Vì thế chưa đủ cơ sở chốt bản hiện tại là hoàn thiện toàn diện và sẵn sàng nộp. NO-GO ở đây là quyết định nghiệm thu bản hiện tại, **không phải kết luận build hay mọi demo thất bại**.

Sau khi đóng R01 và sửa/kiểm chứng lại R02–R05, có thể nghiệm thu lại để chuyển sang GO mà không mở rộng kiến trúc. Các vấn đề P2 nên xử lý trước buổi trình bày để tránh kết luận sai cơ chế.

## A. Có build và chạy được trên máy hiện tại không?

**Có, với phạm vi được xác định rõ:** source của SHA trên đã compile/package và build image mới thành công, exit0; fresh volume chạy đủ SQL/init01–04; bốn container healthy; HTTPS có kiểm tra cert trả200UP; backend–DB và gateway–backend/WAF có bằng chứng request/log thật.

Runtime dùng bản sao nguyên source và Compose override: project/tên container/image riêng, publish duy nhất127.0.0.1:18443, file log/cert/secrets/volume riêng. Không đổi Java, SQL, Nginx hay rules để làm test đạt. **Nguyên Compose gốc publish443 trên mọi địa chỉ chưa được chạy**, vì trái yêu cầu không mở vulnerable API ra LAN. Không dùng PASS của override để chứng nhận cấu hình gốc PASS.

Evidence: build/source-build.json, docker/startup.json, database/database-init.json, http/certificate-health.json, docker/original-effective-config-sanitized.json.

## B. Có bao nhiêu chức năng PASS/FAIL/UNVERIFIED?

Danh mục nghiệm thu có **37 hạng mục** với phạm vi và điều kiện cụ thể:

| Trạng thái | Số lượng |
|---|---:|
| VERIFIED PASS | **28** |
| VERIFIED FAIL | **4** |
| UNVERIFIED | **3** |
| STATICALLY SUPPORTED | **2** |
| NOT IMPLEMENTED / NOT APPLICABLE trong danh mục này | **0** |

Bốn FAIL: custom100100 với query, custom100200 với query, validation biên/HTTP500 và độ tin cậy assertion chứng cứ. Ba UNVERIFIED: nguyên Compose gốc mọi interface, chạy nguyên Postman collection, tái hiện trên host Linux/macOS khác. Hai STATICALLY SUPPORTED: đánh giá rủi ro loopback của config gốc và source reset-demo; **không tính chúng là PASS**.

Đơn vị đếm là hạng mục nghiệm thu, không phải số endpoint. PASS CRUD cơ bản không che FAIL riêng của input biên. Xem 02_FEATURE_VERIFICATION.md và evidence/feature-catalog.json; không quy đổi ra tỷ lệ phần trăm “hoàn thiện” giả tạo.

## C. Có bao nhiêu demo thật sự PASS?

**4/4 demo chính đạt kịch bản đối chứng đã thực thi, cộng1 demo bổ sung.** Bộ gốc có39 assertion PASS,0FAIL,exit0. Demo2 đạt payload chuẩn nhưng chưa đạt thuộc tính custom virtual patch nhất quán khi có query; giới hạn này được ghi riêng, không bỏ qua để chốt GO.

Độc lập đã bổ sung ID động, dữ liệu mới, nguồn403, correlation ba lớp, nhận JWT trên cả hai node và load balancing sau phục hồi.

- Maven gốc:159 test,154PASS,0failure/error,5SKIPPED.
- PostgreSQL opt-in chạy riêng:5/5PASS,0failure/error/skip.
- Bốn bộ HTTP độc lập chuẩn:126case/assertion,120PASS/6FAIL, trong đó6FAIL gồm ba500 và ba trường hợp custom-rule URL. Không cộng lần supplement khám phá trước vào số này.

Không mô tả số liệu trên thành một lần chạy159/159 no-skip hoặc thành tỷ lệ bảo mật tổng thể.

## D. Demo có chứng minh đúng nguyên lý bảo mật không?

**Có, nếu diễn giải đúng phạm vi:**

- Cùng JWT được hai node chấp nhận; dừng một node,12/12GET vẫn200; node khôi phục và cả hai tiếp tục nhận request. Đây là chịu lỗi một backend.
- Payload chuẩn bị WAF chặn với rule100100 hoặc CRS942100/949110, upstream=- và không có backend event, trong khi positive control chứng minh logging đang sống.
- DetectionOnly có cùng RID ở Nginx/WAF/backend; vulnerable SQL thay đổi kết quả thành3fixture, secure bind literal và lọc owner trả[].
- Hai user độc lập cho thấy securePost owner200/nonowner403/anonymous401; đường vuln cố ý cho đọc/sửa/xóa cùng Post.

DetectionOnly là chủ động không chặn để đo lớp sau, **không phải bypass WAF**. HTTP400 khi FROMpublic.users không tự chứng minh cross-database security; datasource và ACL/PostgreSQL tests mới hỗ trợ kết luận đó. Hai backend không phải HA database/gateway/host.

## E. Có lỗ hổng bảo mật nghiêm trọng không?

**Có rủi ro nghiêm trọng cần kiểm soát trước khi dùng config gốc:** vulnerablePost đọc nháp/email và sửa/xóa Post của người khác trên cùng bảng blogdb; root Compose bật nó và không giới hạn published443 vào loopback. Khả năng IDOR đã được xác minh trong lab; nguy cơ ngoài lab được hỗ trợ bởi cấu hình. Không khẳng định đã mở được qua Internet hoặc firewall LAN thực tế.

SQLi vulnerable có chủ ý được giới hạn tốt hơn: reader/datasource riêng, khôngCONNECTblogdb, SELECT fixture, write/catalog/stacked bị từ chối. Không tìm thấy bypass ownership của đường secure trong các trường hợp đã thử. Chưa chạy SCA/CVE hay kiểm thử mọi payload nên không kết luận “không còn lỗ hổng”.

## F. Có chức năng được tuyên bố hoàn thành nhưng chưa hoạt động đúng không?

Có: custom whitelist/virtual patch chỉ đúng với URL trần, không nhất quán khi có query. Validation chưa đầy đủ: page bình luận âm, parent khác Post và title220 hợp lệ theo DTO đều dẫn500. Chỉ dẫn preflight không theo BASE khiến lab cổng khác bị chẩn đoán sai; đây là giới hạn vận hành, không phải app18443 hỏng.

Các chức năng chính có evidence hoạt động, gồm WAF, CRS, JWT, least privilege, LB/failover và IDOR pair. Không có căn cứ gán toàn bộ tuyên bố của người triển khai là sai; báo cáo đánh giá source và kết quả thực, không đánh giá năng lực cá nhân.

## G. Các bài test hiện tại có đáng tin không?

**Hữu ích trong phạm vi, chưa đủ làm căn cứ nghiệm thu duy nhất.** Run-all gom lỗi; demo2 với URL không có service trảexit1/HTTP000; Maven thật sự thực thi assertion và báo rõ năm testPGskip. Không thấy whole suite luônPASS.

Nhưng negative control xác nhận assertion “backend không nhận” vẫnPASS khi cả hai file log không tồn tại. Mode viewer báoOn/exit0 khi Docker trảlỗi. Demo5 kiểm tra IP bằng absence mà không yêu cầu dòng log có thật; demo1 không xác nhận round-robin sau recovery; CRS step có nơi chỉ assert403. Cần positive control, kiểm tra lỗi thu evidence và đối chiếu nguồn response. Bộ audit độc lập đã bù những khoảng trống này cho lần chạy hiện tại.

## H. Chạy lại từ môi trường sạch được không?

**Đã xác minh một lần trên volume/database mới trong project riêng của host hiện tại.** Database init đủ01–04, backend schema validate và demo seed hoạt động. Database stop làm health503, start lại khôi phục200; node restart cũng phục hồi load balancing.

Build có dùng cache dependency/image hiện có. Chưa kiểm tra host hoàn toàn mới, mọi OS, air-gapped build hay migration volume cũ. Reset-demo gốc không chạy để giữ evidence; static review chỉ ra tác động xóa volume/log và preflight hardcode443. Vì vậy không nâng fresh-volume PASS thành bảo đảm mọi môi trường sạch.

## I. Bắt buộc xử lý trước khi chốt nộp

1. **R01/P0:** default lab ở loopback và giới hạn việc bật/tiếp cận vulnerable Post; tuyệt đối chỉ dữ liệu lab. Xác minh active bindings thực tế.
2. **R02/P1:** sửa phạm vi cả hai custom rule cho các URL backend chấp nhận, gồm query; kiểm chứng rule ID/no backend và normal requests.
3. **R03–R04/P1:** sửa ba500 và thống nhất contract DTO/schema; thêm regression đầu vào biên.
4. **R05/P1:** assertion phải fail khi thiếu log/evidence; thêm positive control, exit checks và nguồn403. Chạy lại demo và negative controls.
5. Chốt SHA sửa lỗi mới, dựng lab mới và nghiệm thu lại; giữ evidence hiện tại để so trước/sau.

Danh sách file/dòng, tác động, cách tái hiện, sửa tối thiểu và test lại ở 06_PROBLEMS_AND_RISKS.md. Không có sửa source nào được thực hiện trong phiên này.

## J. Nên bổ sung gì để nâng chất lượng BTL?

Sửa mode unknown/failure; làm preflight dùng BASE và timeout; phân biệt liveness/process với health end-to-end; chuẩn hóa câu chữ DetectionOnly/cross-DB/HA/IP. Dùng ID động và fake data mới, evidence có SHA/RID/thời gian, một transaction DetectionOnly có ba lớp log. Làm rõ quyềnCONNECT còn lại quaPUBLIC hoặc siết nếu vẫn tuyên bố độc quyền một database. Gộp chỉ dẫn vận hành hiện hành, đánh dấu tài liệu lịch sử.

## K. Không cần làm gì nữa?

Không cần viết lại backend, áp lại kế hoạch phân công cũ, tăng container cho đủ mô hình cũ, thêm frontend/Kubernetes/SIEM/distributed cache hoặc HA database. Không cần biến lab thành production, thay self-signed bằng CA công cộng hay tối ưu/refactor lớn trước nghiệm thu. Các demo có giá trị; giữ chúng trong phạm vi an toàn và cải thiện tính chính xác.

## L. Đủ điều kiện chuyển sang báo cáo, slide và trình diễn chưa?

**Đủ evidence để soạn nháp báo cáo/slide; chưa đủ điều kiện chốt bản nộp và tuyên bố nghiệm thu toàn diện.** Các kết quả tích cực có thể sử dụng với SHA và giới hạn đã nêu. Sau R01–R05 được đóng và test lại, dự án có cơ sở chuyển sang giai đoạn hoàn thiện trình bày mà không xây thêm hệ thống lớn.

## Tính toàn vẹn và đầu ra

Đã tạo đủ tám báo cáo và evidence build/docker/http/waf/database/demos. Source gốc và branch không thay đổi; không commit/push/merge. Chỉ tạo file trong audit-results; source copy, cấu hình/secrets lab, helper và log đều ở đó. Manifest liệt kê chính xác các file mới tại FILE_MANIFEST.tsv; dấu vết kiểm tra nằm ở evidence/source-integrity.json và final-git-status.json.

Bốn container audit được dừng, volume/image giữ lại để tái hiện. Bốn container cũ còn nguyên ID/image/trạng thái exited, volume và network cũ còn tồn tại. Xem docker/final-environment-check.json. Khi chia sẻ báo cáo chỉ lấy tám file Markdown và evidence đã rà soát; .env và server.key trong lab/root là cấu hình bí mật cục bộ, không phải tài liệu báo cáo.
