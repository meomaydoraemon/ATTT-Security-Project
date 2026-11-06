# Báo cáo phiên: xác minh baseline và tách lab ở chế độ Local (2026-11-07)

## 1. Source đã dùng

| Mục | Giá trị |
|---|---|
| Repo | `D:\BTL ALL MAJOR\BTL ATTT Claude\ATTT-Security-Project` |
| Remote | `origin` = `meomaydoraemon/ATTT-Security-Project` (repo riêng của người dùng, đích push duy nhất); `team-readonly` = `Lemonimjuice/CSATTT-BTL--Nhom9` (repo nhóm, chỉ fetch, push URL `no-push://`) |
| Repo khác | `audit-main-2` (clone repo nhóm, push bị vô hiệu): không dùng, không sửa. `private-repo-staging`: bản archive tham khảo |
| Nhánh làm việc | `work/local-lab-split`, tách từ HEAD `281e748` |
| HEAD lúc bắt đầu | `281e748` (kế thừa trực tiếp `2981c24`; khác biệt chỉ ở tài liệu và hook) |
| HEAD lúc kết thúc | tag `checkpoint/t002-local-lab-split` |
| Commit snapshot | Không cần: working tree sạch, `diff` và `diff --ignore-cr-at-eol` đều rỗng |
| Repo nhóm | Không thay đổi: ref trên GitHub y nguyên (`main`, `main-2` = `0a22829`); `main-2` không có commit mới |
| Push | Không push |

## 2. Các thay đổi (commit trên `work/local-lab-split`)

| Commit | Mô tả |
|---|---|
| `77c968c` chore(evidence) | Ignore `evidence/**/raw/` và `evidence/**/rollback/` |
| `74c9b24` docs(evidence) | Báo cáo T-001 và công cụ quét secret chỉ in số lượng (`evidence/scan-secrets.py`) |
| `51ba096` chore(env) | `init-env.sh` sinh secret lab riêng, chỉ bổ sung khóa thiếu, ngừng `SQLI_DEMO_ENABLED`; cập nhật `.env.example` |
| `a4d8ab0` feat(compose) | Node prod bỏ `sqli-lab`, flag false ghi cứng, tắt springdoc, `mem_limit` 768m; thêm `lab-db`, `lab-backend`, `lab_net` |
| `435cdae` feat(nginx) | Listener lab 9443; prod chặn `/api/v1/vuln/` (404); file include dùng chung; zone rate limit riêng cho lab; `srv=` trong log |
| `f68954f` test | Demo 2/3/4 chạy trên lab; Demo 4 có kiểm tra dương; thêm Demo 6 và `prod-checksum.sh`; `run-all` FAIL khi lab tắt |
| `fcecd6f` feat(scripts) | Thêm `lab.sh` up/down/reset/status; preflight theo mục 5.5 |
| `8acf646` docs | README (Chế độ Local), `decisions.md` D11, `ports-and-env.md` |
| (cuối) docs(evidence) | Báo cáo T-002, nhật ký phiên, báo cáo này |

Tag cục bộ: `checkpoint/session-start`, `checkpoint/t001-verified`, `checkpoint/t002-local-lab-split`. Không có `checkpoint/t001b-fixed` vì không cần Giai đoạn C.

## 3. Kết quả

### T-001: xác minh baseline ([T-001/REPORT.md](T-001/REPORT.md))

| # | Trạng thái | Tóm tắt |
|---|---|---|
| B1 | PASS (đã ghi) | Không có Java, Maven, pwsh; RAM trống 2.7/14.8 GB |
| B2 | PASS | Xung đột subnet 10.209.10.0/24 do project cũ `audit-m2-0a2282`; người dùng chọn gỡ (`down`, không `-v`) |
| B3 | PASS | Secret mới; `.env` và `server.key` bị ignore |
| B4 | PASS | 16 script OK; guard 10/10 (bash). Chạy bằng dash FAIL do F10, ngoài tiêu chí |
| B5 | PASS | `mvn test` 170/0/0, 5 skip (`SqliLabPostgresTest` UNVERIFIED) |
| B6 | PASS | 4 container healthy, digest nginx khớp D3 |
| B7 | PASS | preflight 19/0/0 |
| B8 | PASS | 56 assertion, "TẤT CẢ DEMO ĐẠT", WAF On |
| B9 | PASS (đã ghi) | Module nginx (có `realip`), RAM |
| B10–B12 | PASS | Báo cáo; scan 0; đã lưu 3 image (`evidence/T-001/rollback/`, SHA256SUMS) |

**Kết luận A: ĐẠT. Kết luận B: ĐẠT.** T-001b không cần.

### T-002: tách lab ([T-002/REPORT.md](T-002/REPORT.md))

| Cổng | Trạng thái |
|---|---|
| Functional (6 container healthy; Demo 1–6 PASS hai lần, mỗi lần 111/0) | PASS |
| Security (INV-01 đến INV-14) | PASS |
| Regression (`mvn` 170/0/5; guard 10/10; `nginx -t`) | PASS |
| Hoạt động độc lập (lab tắt: 4 container healthy, Demo 1 và 5 PASS, lab trả 503 JSON) | PASS |
| Operational (`reset` 20–29 giây, khôi phục bài 3, checksum prod không đổi; `down` sạch; `up` hai lần OK) | PASS |
| Bằng chứng (scan 0) | PASS |

UNVERIFIED: `SqliLabPostgresTest`, các bộ PowerShell trong `backend/scripts`, guard chạy bằng dash (FAIL do F10).

## 4. Cách chạy và demo (cmd của Windows)

Các lệnh `docker` chạy trực tiếp trong cmd. Script `.sh` chạy qua Git Bash: `"C:\Program Files\Git\bin\bash.exe" <script>` (hoặc mở Git Bash tại thư mục repo rồi gõ `sh <script>`).

```bat
cd /d "D:\BTL ALL MAJOR\BTL ATTT Claude\ATTT-Security-Project"
```
Vào thư mục repo; mọi lệnh sau chạy từ đây.

```bat
"C:\Program Files\Git\bin\bash.exe" scripts/init-env.sh
```
Lần đầu, hoặc sau khi cập nhật: tạo `logs/`, bổ sung khóa còn thiếu vào `.env` mà không đổi giá trị cũ. Kết quả: "đã có đủ khóa" hoặc danh sách khóa vừa thêm.

```bat
docker compose up -d --build --wait
```
Khởi động phần prod: 4 container `nginx-waf`, `backend-node-1`, `backend-node-2`, `database`. Kết quả: 4 dòng "Healthy". Prod chạy ở `https://localhost`.

```bat
"C:\Program Files\Git\bin\bash.exe" scripts/lab.sh up
```
Bật lab (`lab-db`, `lab-backend`). Kết quả: cả hai `running/healthy`, `listener lab ... -> HTTP 200` và dòng "Prod không bị ảnh hưởng".

```bat
"C:\Program Files\Git\bin\bash.exe" scripts/preflight.sh
```
Kiểm tra toàn hệ thống trước buổi trình bày. Kết quả mong đợi: `25 PASS, 0 WARN, 0 FAIL`; có thể kèm 1 dòng INFO về `SQLI_DEMO_ENABLED` đã ngừng dùng.

```bat
"C:\Program Files\Git\bin\bash.exe" tests/demo/run-all.sh
```
Chạy guard và Demo 1–6 (khoảng 3–4 phút). Kết quả: dòng cuối "TẤT CẢ DEMO ĐẠT". Nếu lab chưa bật, runner FAIL ngay và hướng dẫn chạy `lab.sh up`.

```bat
"C:\Program Files\Git\bin\bash.exe" tests/demo/demo1-failover.sh
```
Demo 1 (prod): Round-Robin, tắt node 1, token cũ vẫn dùng được, node 1 tự tham gia lại. Kết quả: `15 PASS, 0 FAIL`.

```bat
"C:\Program Files\Git\bin\bash.exe" tests/demo/demo2-waf-virtual-patch.sh
```
Demo 2 (lab): SQLi bị WAF chặn 403 bởi rule 100100, backend lab không nhận request. Kết quả: `9 PASS, 0 FAIL`.

```bat
"C:\Program Files\Git\bin\bash.exe" tests/demo/demo3-defense-in-depth.sh
```
Demo 3 (lab): tạm bật DetectionOnly (cho toàn bộ Nginx, chỉ chấp nhận ở Local); bản lỗi lộ 3 dòng, bản vá trả `[]`; tự trả WAF về On. Kết quả: `8 PASS, 0 FAIL`.

```bat
"C:\Program Files\Git\bin\bash.exe" tests/demo/demo4-idor.sh
```
Demo 4 (lab): user_b đọc được bài của chính mình (200), bị 403 với bài nháp của user_a; chưa đăng nhập nhận 401; bản lỗi `/vuln` để lộ và cho sửa. Kết quả: `14 PASS, 0 FAIL`. Demo này sửa bài 3 của lab, nên chạy lại cần `lab.sh reset` trước.

```bat
"C:\Program Files\Git\bin\bash.exe" tests/demo/demo5-ratelimit-audit.sh
```
Demo 5 (prod): brute-force bị 429, XFF giả không vào log, một rid xuyên 3 lớp, Swagger/actuator/cổng 80 đóng. Kết quả: `11 PASS, 0 FAIL`.

```bat
"C:\Program Files\Git\bin\bash.exe" tests/demo/demo6-isolation.sh
```
Demo 6: cô lập lab và prod (token chéo 401, `/vuln` 404 trên prod, mạng tách, secret khác, log sạch, checksum prod không đổi). Kết quả: `54 PASS, 0 FAIL`.

```bat
"C:\Program Files\Git\bin\bash.exe" scripts/lab.sh reset
```
Reset lab: tạo lại `lab-db` trên tmpfs (nạp lại seed) và `lab-backend`, mất khoảng 20–30 giây. Kết quả: "Đã reset lab trong N giây" và dòng "Prod không bị ảnh hưởng".

```bat
"C:\Program Files\Git\bin\bash.exe" scripts/lab.sh down
```
Tắt lab: dừng và xóa đúng 2 container lab. Kết quả: cả hai `absent`, listener lab trả `HTTP 503`, prod vẫn healthy.

```bat
docker compose stop
```
Dừng toàn bộ phần prod mà **giữ dữ liệu** (volume `postgres_data` còn nguyên). Bật lại bằng `docker compose up -d --wait`. Không dùng `down -v` hay `scripts/reset-demo.sh`, vì cả hai đều xóa DB prod.

## 5. Việc còn lại
- **R-RES-01:** DB prod vẫn có `sqli_lab`, `sqli_demo_reader` và cần `SQLI_LAB_READER_PASSWORD`. Phải khởi tạo lại DB prod mà không chạy `04` trước khi triển khai phân tán; cần người dùng đồng ý. Có thể làm cùng lúc khôi phục bài 3 của prod, vốn đã bị Demo 4 của T-001 sửa khi baseline còn để `/vuln` trên prod.
- **R-RES-02:** `waf-mode.sh` đổi chế độ WAF cho toàn bộ Nginx. Cần thí nghiệm chế độ WAF riêng cho từng listener.
- Thí nghiệm mạng hai máy; triển khai phân tán; đưa lên Internet (`realip`, seed riêng cho production, tắt đăng ký); frontend; console; wrapper `.cmd`.
- Cập nhật `docs/demo-checklist.md` theo chế độ Local (`lab.sh reset` thay cho `reset-demo.sh` khi chuẩn bị Demo 4).
- F10: guard test chưa chạy được bằng dash.
- UNVERIFIED: `SqliLabPostgresTest`; các bộ PowerShell trong `backend/scripts` (máy không có pwsh 7).
- Nhánh `work/local-lab-split` chưa merge vào `develop` và chưa push: chờ người dùng quyết định.
