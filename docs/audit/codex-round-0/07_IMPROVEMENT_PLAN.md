# Kế hoạch hoàn thiện tối thiểu và nghiệm thu lại

Ngày 27/10/2026, Asia/Saigon. SHA kiểm toán **0a2282931500c8dbddd35495ad3b29aca19777cc**, main-2. Tài liệu là đề xuất; chưa sửa source, commit hay triển khai bất kỳ thay đổi nào.

## Thứ tự thực hiện

| Đợt | Việc làm | Tiêu chí hoàn tất | Chạy lại |
|---|---|---|---|
| P0 | R01: default loopback, giới hạn profile vuln và dữ liệu lab | Bindings thực tế an toàn; không có đường vuln ngoài phạm vi được chọn | Config/inspect, hai user và ID động, published-port checks |
| P1a | R02: sửa phạm vi cả hai custom rule | Cùng policy khi có/không query; rule đúng thực sự chặn trước Java | Supplement URL matrix, audit ID, upstream/positive control |
| P1b | R03/R04: validation Comment/title-slug | Client input sai400; title hợp lệ không500; uniqueness giữ nguyên | Ba repro trong Core, thêm title200/201/220/255 và commentdepth |
| P1c | R05: assertion có evidence và fail closed | Mất log/không đọc được/RID rỗng không thể PASS | Negative controls và năm demo gốc |
| P2 | R06–R10: mode trạng thái, preflight, ACL wording, health và tài liệu | Người trình bày không dùng kết luận vượt evidence | Mode failure tests; BASE443/18443; dependency/recovery; đọc kịch bản |
| Nghiệm thu | Chốt SHA mới và lưu evidence mới riêng | Không ghi đè audit hiện tại; mọi P0 đóng và P1 có test đạt | Fresh project/volume, Maven+PG, demo1–5, độc lập, git status |

Không tự sửa trong phiên này. Người triển khai nên dùng nhánh/chỗ làm việc riêng và giữ bộ evidence của SHA hiện tại để so sánh trước/sau.

## Bộ kiểm tra tối thiểu sau sửa

1. Chốt commit mới; working tree và bản sao nguồn rõ ràng. Inventory Docker/cổng; project/network/volume/cert/secrets riêng.
2. Render effective config đã loại secrets. Build source; fresh init01–04; xác minh bốn container và HTTPS end-to-end, không chỉ health.
3. Chạy Maven gốc; báo số PASS/SKIPPED đúng thực tế. Bật riêng năm test PostgreSQL và lưu output. Không thay test thật bằng mock.
4. Chạy demo gốc sau đọc phạm vi tác động. Chạy độc lập hai account mới, ID động, owner/nonowner/anonymous, check nội dung sau write/delete.
5. LB: JWT trên hai node, stop đúng node có ownership, ghi mọi HTTP, start và chứng minh cả hai trở lại nhận request.
6. WAF: normal đi qua, custom/CRS block đúng rule, no-upstream/no-backend có positive control; URL có query và JSON parser được phủ.
7. DetectionOnly: cùng request có ba lớp log, vuln3/secure0 và owner data controls, ACL/write test; restore On phải được xác minh.
8. Rate/IP/RID: vượt rate nhận429, spoofed header không vào log, một transaction DetectionOnly đủ cả ba lớp, docs/actuator phụ không public.
9. Chạy negative controls có chủ đích: service unreachable, thiếu log, mode không đọc được, một component down. Thiếu bằng chứng phải FAIL/UNVERIFIED.
10. Dừng riêng tài nguyên test, giữ artifacts; so container/volume cũ trước/sau; source sạch ngoài khu vực được phép.

## Giá trị học thuật và chuẩn bị trình bày

Các đối chứng hiện tại đã có giá trị: cùng payload ở hai chế độ WAF; vulnerable/secure SQL; hai user IDOR; node failure có JWT cũ; cùng request ID đối chiếu lớp biên và ứng dụng. Nên dùng những bằng chứng này làm trục bài, không dùng số lượng file hoặc số PASS để chứng minh an toàn tổng thể.

Các điểm giảng viên có thể chất vấn và câu trả lời phải chuẩn bị:

- Vì sao DetectionOnly không phải bypass? Vì engine vẫn phát hiện nhưng được cấu hình không chặn; đây là thí nghiệm đo lớp sau.
- Vì sao SQLi vuln trả3 còn secure rỗng? Một bên đổi nghĩa SQL do nối chuỗi; bên kia bind literal và owner. Cần normal-data control để biết endpoint không phải luôn rỗng.
- Vì sao400 không tự chứng minh cross-database security? Có thể chỉ là relation không tồn tại; phải đưa DS/ACL và PostgreSQL privilege tests.
- Vì sao secure403 không thể do WAF? Request sạch tới backend, audit access event có user/status; không có marker WAF; WAF block có rule và upstream=-.
- Bài đã có ownership sao vẫn sửa được? Vì đường vuln dùng chung tài nguyên và cố ý bỏ check. Chỉ được mở trong lab, không tuyên bố toàn ứng dụng bảo vệ dữ liệu đó.
- Hai node có là full HA? Không; DB/gateway/host đơn. JWT không cần session affinity nhưng vẫn lookup DB.
- Rate5r/m có nghĩa chỉ nhận5request/phút không? Còn burst và hồi token; trình bày chuỗi đo, không diễn đạt thành hard quota.
- IP thực là IP nào? Peer quan sát ở Nginx/Docker; NAT có thể gộp máy. Không tin XFF do client tự gửi.

Ưu tiên ID động, dữ liệu mới dùng một lần, log snapshot có SHA/thời gian và một bảng Expected/Actual theo RID. Không cần thao tác sửa SQL thủ công trước mỗi demo.

## Những việc không cần làm thêm

Không cần viết lại toàn bộ backend, tăng số container để khớp kế hoạch cũ, thêm frontend, Kubernetes, distributed cache/rate limit, SIEM, certificate CA công cộng hay HA database. Không cần loại bỏ các demo có chủ ý lỗi nếu chúng được cô lập và giải thích đúng. Không cần tối ưu cấu trúc source trước khi chốt tính đúng của thực nghiệm.

Có thể soạn nháp báo cáo/slide song song dựa trên evidence hiện tại, nhưng chưa chốt trạng thái “sẵn sàng nộp” cho commit này. Chỉ cập nhật kết luận sau nghiệm thu lại commit sửa lỗi.
