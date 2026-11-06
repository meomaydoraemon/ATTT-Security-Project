# Hoàn thiện sau kiểm toán — vòng 1

Ngày 27/10/2026, Asia/Saigon. Nhánh sửa: **codex/main-2-audit**. Base/HEAD: **0a2282931500c8dbddd35495ad3b29aca19777cc**. Bản được kiểm thử là working tree đã sửa, **không phải nội dung nguyên commit base**; fingerprint nằm trong evidence/source-snapshot.json. Không commit, push hay merge.

## Kết luận: CONDITIONAL GO

Các P0/P1 đã được xác nhận trong kiểm toán đã sửa và có kiểm chứng thực tế trên máy hiện tại. Không còn trường hợp HTTP500 đã nêu; custom rules xử lý đúng các URL đã thử; script từ chối kết luận khi thiếu log; các đối chứng SQLi/IDOR/DetectionOnly/failover được giữ.

Điều kiện còn lại là diễn tập trên **đúng máy dự kiến trình bày** nếu chuyển sang máy khác. Máy/OS khác chưa có sẵn để thực thi, vì vậy không tuyên bố đã VERIFIED PASS ở đó. Đây không phải yêu cầu viết thêm chức năng hay còn lỗi P0/P1 đã biết chưa sửa.

## Thay đổi và nguyên nhân

| Nhóm | Nguyên nhân trước sửa | Sửa cụ thể | Kết quả |
|---|---|---|---|
| P0 lab | Gateway không ràng buộc loopback; flag vuln luôn true | Bind 127.0.0.1, chỉ cho đổi HTTPS_PORT; flag mặc định false, init-env --lab bật tường minh | Engine/host listener loopback; TCP qua 5 địa chỉ non-loopback của host bị từ chối; không bật flag thì vuln404, secure vẫn201 |
| P1 WAF | REQUEST_URI chứa query, regex kết thúc bằng $ | Dùng REQUEST_FILENAME ở100100/100200 | URL thường/query/encoded path kích hoạt đúng rule; normal request đi qua |
| P1 Comment | PageRequest nhận số âm/zero; parent/depth ném exception chung | Validate page/size; dùng InvalidRequestException cho parent/depth | Các input lỗi400, reply hợp lệ201, không thêm dòng khi bị từ chối |
| P1 slug | DTO title255 nhưng slug varchar200; suffix không được tính vào giới hạn | Bound slug theo Post.MAX_SLUG_LENGTH, dành chỗ suffix; bỏ chính Post hiện tại khi tìm trùng; giữ URL khi title không đổi; fallback cho slug rỗng | Title200/201/220/255 và duplicate không500; flush database đạt; same-title update không đổi URL |
| P1 evidence | Cat/grep che lỗi file thiếu, absence được coi là proof | Require hai log readable/nonempty, RID32hex; positive backend control; assert rule ID/nguồn403; curl có timeout; failover có restore trap và check recovery | Offline negative controls10/10, full demo vẫn đạt |
| WAF mode | Exec/grep lỗi bị suy ra On | Đọc cả engine/mode file và kiểm tra exit; chỉ công bố On/DetectionOnly hợp lệ | Docker lỗi/missing directive phải exit khác0 |
| P2 vận hành | Preflight hardcode443/tag; chỉ dẫn reset/xóa container dễ sai phạm vi | Đọc BASE/HTTPS_PORT, image của project đang dùng, mode đã xác minh; hướng dẫn giữ project khác, lab fake data; giải thích đúng DetectionOnly/HA/ACL | Preflight19443 đạt19PASS/0WARN/0FAIL trước khi seed bị demo sửa |

## Bổ sung có bằng chứng, cùng nguyên nhân query matching

Kiểm tra request xác thực hợp lệ phát hiện ngoại lệ CRS cho password/refreshToken cũng dùng REQUEST_URI. Trước sửa, password có ký tự giống SQL đăng ký được ở URL trần201 nhưng query bị403; đó là false positive, không phải SQLi ở AuthService.

Đã đổi vị trí matching duy nhất trong nginx/modsecurity/crs-tuning.conf sang REQUEST_FILENAME. Hai request sau sửa đều201. Username policy vẫn được kiểm tra ở backend khi DetectionOnly; SQLi/CRS trên secure Record vẫn bị chặn ở On. Không thêm whitelist chỉ dành cho một payload mẫu.

Theo [tài liệu chính thức ModSecurity v3](https://modsecurity.org/docs/3-reference-manual/3-3-variables/), REQUEST_FILENAME biểu diễn path không có query. Runtime còn kiểm tra path mã hóa để đối chiếu với endpoint backend thực sự chấp nhận.

## Giữ nguyên giá trị thực nghiệm

- Vẫn bốn container, hai network; không thêm frontend, cache, Kubernetes hay đổi framework/database.
- Vuln SQLi vẫn nối chuỗi và lộ ba fixture khi DetectionOnly; secure bind tham số và lọc owner vẫn trả rỗng với payload.
- Vuln Post vẫn đọc/sửa/xóa cùng bảng blogdb khi bật lab; đây là đối chứng có chủ ý, không được coi thành bảo vệ dữ liệu production.
- Secure ownership vẫn401/403 đúng nguồn; B không sửa được tài nguyên A qua đường secure.
- JWT được chấp nhận ở cả hai node, node còn lại phục vụ khi một node dừng; load balancing trở lại sau recovery.
- Logging/tracing kiểm tra bằng request ID và positive control, không chỉ số dòng PASS.

## Source đã thay đổi

Danh sách chính xác27 file tại SOURCE_FILES_CHANGED.txt; có25 file tracked sửa và2 regression file mới. Không sửa hay xóa báo cáo/evidence của vòng kiểm toán trước. audit-results được thêm vào .gitignore để không vô tình stage bản sao có secrets.

Các thay đổi backend chỉ gồm CommentController, CommentServiceImpl, PostServiceImpl, Post entity, RegisterRequest policy và comment mô tả phạm vi VulnerablePostController. Không thay toàn bộ Spring Security hoặc xóa vulnerable API. Regression Java mới là AuditFixRegressionTest; regression shell mới là test-evidence-guards.sh. Không sửa/xóa các test cũ để tăng tỷ lệ PASS.

## Trạng thái Git và tài nguyên

main-2 giữ nguyên base SHA. codex/main-2-audit chứa thay đổi chưa commit; trạng thái và fingerprint cuối được lưu riêng. Không git add -A, reset, clean, push hay merge.

Lab fix-r1-0a2282 dùng localhost19443, network/volume/tên container riêng. Subnet10.209.11.0/24 và trust IP10.209.11.10 được override vì lab kiểm toán cũ vẫn giữ subnet10.209.10.0/24. Không thay Java/SQL semantics để làm test PASS. Các container/volume/network cũ được giữ nguyên; lab vòng này được dừng sau thu bằng chứng.

Khi tiếp tục bàn giao, Docker Engine không truy cập được cho lần đọc bổ sung; kết luận về Docker cũ dựa trên evidence thành công cuối, không phải kiểm tra lại thời gian thực. Xem 04_FINAL_STATUS.md và evidence/docker/handover-environment-check.json. Source162file vẫn khớp snapshot đã kiểm thử, vì vậy giữ nguyên các kết quả runtime hợp lệ.
