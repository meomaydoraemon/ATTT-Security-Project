# Chốt bàn giao vòng sửa lỗi main-2

Ngày 27/10/2026, Asia/Saigon. **Sẵn sàng cho kiểm toán chéo. CONDITIONAL GO cho nghiệm thu/trình bày.** Không còn P0/P1 đã xác nhận trong phạm vi vòng này mà chưa sửa. Điều kiện vận hành: Docker Engine phải hoạt động khi chạy lại; diễn tập trên máy trình bày khác vẫn là UNVERIFIED. Phiên bàn giao không chạy lại toàn bộ runtime, không sửa thêm source.

## Định danh bản bàn giao

- Nhánh `codex/main-2-audit`; HEAD và `main-2` cùng SHA gốc `0a2282931500c8dbddd35495ad3b29aca19777cc`.
- Working tree chưa commit có **27 file**:25file tracked sửa và2file test mới. Con số26 trong nhật ký tóm tắt trước gián đoạn không phải số cuối; kiểm kê Git hiện tại khớp danh sách27file.
- Fingerprint **162file** của working tree và bản sao lab vẫn khớp bản đã kiểm thử, không có source thay đổi sau snapshot.
- SHA256 của `evidence/source-snapshot.json`: `3525EAB50B1BCCD19F2FD7FB9323168820BB9395E4141F2CCA16C39DF395F203`.
- Không stage/commit/push/merge/reset/hoàn tác. Không có audit artifacts, `.env` thật hoặc private key được Git theo dõi; `.env*.example` là mẫu cấu hình.

## Đóng các phát hiện từ kiểm toán gốc

Đường dẫn evidence dưới đây tính từ `evidence/`. Chi tiết nguyên nhân và sửa đổi trong01_FIX_SUMMARY.md.

| ID / ưu tiên gốc | Trạng thái và thay đổi | Bằng chứng |
|---|---|---|
| R01 / P0: API cố ý lỗi ngoài loopback | **FIXED trong lab**. Bind127.0.0.1, flag mặc định false, bật tường minh bằng --lab | docker/default-safety-runtime.json, local-safety.json: vuln404, secure201,5địa chỉ non-loopback từ chối TCP; HTTP độc lập vẫn xác minh vuln khi bật |
| R02 / P1: custom rules bỏ qua query | **FIXED**. 100100/100200 dùng REQUEST_FILENAME; username policy đồng bộ backend | http/supplement-auth-query.json; waf-matrix-On.json và waf-matrix-DetectionOnly.json: plain/query/encoded path; waf/correlation.json: đúng rule và backend trace |
| R03 / P1: comment trả500 với input sai | **FIXED**. Validate page/size; parent khác Post và depth trả domain400; không chèn comment sai | http/independent-Core.json; build/targeted-java-regressions.json: lỗi400 và reply hợp lệ201 |
| R04 / P1: slug vượt varchar200 | **FIXED**. Truncate có chỗ suffix, xử lý trùng/rỗng, giữ URL khi title không đổi | http/postgres-edges.json; build/full-maven-postgres.json: title200/201/220/255, duplicate/create/update và flush database |
| R05 / P1: absence assertion PASS khi thiếu log | **FIXED**. Require log/RID, positive control, rule/nguồn403, IP cùng RID | demos/final-evidence-guards.json10controls; final-all-demos.json56assertion; waf/correlation.json34đối chiếu |
| R06 / P2: waf-mode suy ra On khi lỗi | **FIXED**. Lỗi Engine/config/directive trả exit khác0 | demos/final-evidence-guards.json; On/DetectionOnly thực trong full demo |
| R07 / P2: diễn giải DetectionOnly/HA/ACL quá rộng | **Đã sửa tài liệu/script hiện hành**. Chủ động không chặn; chỉ chịu lỗi một backend; không suy ACL từ400 | README, docs/decisions.md, demo3; đối chứng HTTP/demo vẫn đạt |
| R08 / P2: preflight hardcode port/image | **FIXED ở cấu hình đã thử**. Đọc BASE/HTTPS_PORT và image project; timeout/chẩn đoán transport | demos/preflight-auto-port.json:19443,19PASS/0WARN/0FAIL trước demo. Default443 chỉ render config |
| R09 / P2: mô tả CONNECT quá rộng | **Đã sửa tuyên bố**, không đổi ACL; PUBLIC vẫn CONNECT postgres/templates; reader không CONNECT blogdb | Comment database/init/04-sqli-demo.sh, docs/decisions.md; giới hạn được công bố |
| R10 / P2: health và hướng dẫn | **Đã sửa hướng dẫn hiện hành; giữ giới hạn thiết kế**. Gateway health là liveness; preflight HTTPS; kiểm branch/SHA, tránh xóa project khác | README, docs/demo-checklist.md; preflight19PASS. Không đồng bộ lại toàn bộ tài liệu lịch sử hoặc đổi health thiết kế |

Phát hiện bổ sung cùng nguyên nhân R02: ngoại lệ CRS password/refreshToken cũng dùng REQUEST_URI. Đã sửa crs-tuning.conf; register hợp lệ có query đổi403→201, URL trần vẫn201. `http/auth-password-query-before.json` và `auth-password-query.json` giữ trước/sau; không thêm whitelist riêng cho payload mẫu.

## Kết quả được tái sử dụng

| Bộ đã thực thi | Kết quả xác nhận từ artifacts |
|---|---|
| Maven, gồm5PostgreSQL test thật trong cùng lần chạy |170PASS,0failure/error/skip; BUILD SUCCESS |
| HTTP độc lập, cùng phạm vi bộ120/126 gốc |126/126PASS:70Core+11Detection+36Failover+9AuthQuery |
| Năm demo |56assertionPASS,0FAIL:15+9+8+13+11 |
| Offline evidence/mode guards |10/10PASS |
| WAF matrix bổ sung |28/28PASS:14On+14DetectionOnly |
| PostgreSQL HTTP edge bổ sung |19/19PASS |
| Auth password/query sau sửa |2/2PASS |
| Đối chiếu log RID |34/34PASS:positive control, rule/interruption và trace ba lớp |

Docker build/init volume mới, hai backend cùng image/JWT, load balancing, failover/recovery, CRS, SQLi, IDOR, rate limiting và default-off/loopback đã có evidence trong02_VALIDATION.md. `evidence/handover-validation.json` xác nhận JSON đọc được, kết quả canonical không có case fail và source không đổi. Không cộng các bộ chồng lặp thành tỷ lệ bảo mật. Artifacts before/earlier/correlation-harness-incomplete là lịch sử chẩn đoán, không thay kết quả cuối.

## Docker cũ và trạng thái hiện tại

Lần đối chiếu thành công cuối: **14:00:33 ngày27/10/2026, Asia/Saigon**, `docker/final-environment-check.json`: cả8container cũ giữ nguyên ID/image/trạng thái exited; tên volume/network cũ còn tồn tại;4container fix-r1-0a2282 đã dừng, giữ image/volume. Không prune/xóa hay nối vào DB cũ.

Khi tiếp tục bàn giao, Docker Desktop Linux Engine không truy cập được vì named pipe không tồn tại. Lần đọc bổ sung ghi **UNVERIFIED_CURRENT_DOCKER_STATE** tại `docker/handover-environment-check.json`; không khởi động Engine hoặc suy diễn tài nguyên bị mất. Kết luận dựa trên lần đối chiếu thành công cuối và phạm vi thao tác đã ghi. Không checksum nội dung volume cũ, vì vậy không khẳng định đã chứng minh dữ liệu giống từng byte.

## Dữ liệu nhạy cảm và phạm vi chia sẻ

`evidence/sensitive-data-review.json` rà27file thay đổi và toàn bộ evidence/report bàn giao, so4secret sinh trong lab, JWT và private-key markers: **0phát hiện secret thực trong phạm vi chia sẻ**. Mật khẩu fake seed công khai có sẵn vẫn xuất hiện trong README/preflight/common; không dùng với dữ liệu thật. Matched data password/refreshToken đã được che trong WAF evidence.

**Chỉ bàn giao báo cáo, danh sách file, manifest và evidence/. Không phát hành nguyên thư mục fix-round-1.** Toàn bộ lab/ là riêng tư, chứa .env, khóa TLS và log gốc; helper *.ps1 dành cho tái hiện nội bộ. Không commit hoặc công bố các khu vực này. Evidence kiểm toán cũ giữ nguyên, chưa được xác nhận an toàn để công bố.

## Còn tồn tại / chưa kiểm chứng

- Không còn P0/P1 đã xác nhận chưa sửa. Vulnerable API vẫn cố ý lỗi khi bật lab và dùng chung blogdb; chỉ dữ liệu giả.
- Chưa diễn tập máy/OS khác; chưa chạy Postman GUI/Newman, mọi cipher/payload hoặc concurrency toàn diện.
- Docker Engine hiện không khả dụng cho lần đọc bổ sung; trạng thái runtime hiện tại chưa xác minh lại.
- DB/gateway/host không có HA; gateway healthy không chứng minh toàn chuỗi. Image tags có thể thay đổi; evidence lưu image ID đã chạy.
- Demo4 đổi title seed Post3 có thể khiến preflight sau demo WARN; không reset để che cảnh báo.
- Compose root còn tên/subnet cố định, cần override khi xung đột; custom100100 còn policy ASCII; reader còn PUBLIC CONNECT như R09.

## Hồ sơ bàn giao

1. 01_FIX_SUMMARY.md: nguyên nhân và thay đổi.
2. 02_VALIDATION.md: trước/sau, cơ chế, giới hạn.
3. 03_HANDOVER.md: tái hiện, vận hành và rủi ro hồi quy.
4. 04_FINAL_STATUS.md: đóng R01–R10, đánh giá cuối.
5. SOURCE_FILES_CHANGED.txt: chính xác27file; evidence/final-git-status.json: Git cuối.
6. evidence/source-snapshot.json: SHA256162file; FILE_MANIFEST.tsv: phân loại toàn bộ file riêng vòng sửa, nhận diện khu vực riêng tư.

Manifest có một dòng cho chính nó, SHA256 để dấu “-” nhằm tránh tự tham chiếu; các dòng file khác có checksum SHA256. SHARE_SCOPE là hướng dẫn phạm vi bàn giao, không cấp quyền công bố dữ liệu kiểm toán cũ.

Đủ hồ sơ để kiểm toán chéo working tree hiện tại. Chỉ nâng đánh giá vận hành trên host khác thành GO sau diễn tập thực tế ở host đó; không cần mở thêm vòng phát triển để bàn giao bản sửa này.
