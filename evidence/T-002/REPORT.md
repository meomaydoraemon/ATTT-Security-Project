# T-002: Tách lab khỏi production ở chế độ Local (2026-11-07)

- Nhánh `work/local-lab-split`; project Compose `nhom9-local`.
- Bằng chứng thô ở `evidence/T-002/raw/` (bị Git ignore).
- Không in secret hay token ra báo cáo. Hash chỉ dùng để so sánh.

## Cổng nghiệm thu D8

| Cổng | Trạng thái | Bằng chứng |
|---|---|---|
| Functional | **PASS** | Bật profile lab: 6 container healthy (`raw/D8-ps.txt`). `run-all.sh` Demo 1–6 chạy **hai lần**, cả hai đều in "TẤT CẢ DEMO ĐẠT". Mỗi lần 111 assertion, 0 FAIL: D1 15, D2 9, D3 8, D4 14 (+1 kiểm tra dương), D5 11, D6 54. `raw/D8-run-all-1.txt`, `raw/D8-run-all-2.txt` |
| Security | **PASS** | INV-01 đến INV-14 đều PASS, xem bảng dưới |
| Regression | **PASS** | `mvn test`: 170 run, 0 fail, 0 error, 5 skip, giống T-001 (`raw/D8-mvn-test.txt`). Guard 10/10. `nginx -t` OK (`raw/D8-nginx-t.txt`, `raw/D3-nginx-t.txt`) |
| Hoạt động độc lập | **PASS** | Sau `lab.sh down`: 4 container prod healthy, restarts = 0; listener lab trả `503` JSON; Demo 1 PASS 15/0; Demo 5 PASS 11/0; `run-all.sh` FAIL kèm hướng dẫn `lab.sh up` (exit 1, không âm thầm bỏ qua). `raw/D8-independent.txt` |
| Operational | **PASS** | `lab.sh reset` khôi phục bài 3 của lab (`DRAFT\|Bản nháp bí mật của User A`) trong 20–29 giây (3 lần: 24, 20, 29 giây); checksum prod không đổi. `lab.sh down` không còn container lab nào, prod vẫn healthy, ID container prod không đổi. `docker compose up -d --wait` hai lần và `--profile lab up -d --wait` hai lần đều exit 0. `raw/D6-*`, `raw/D8-operational.txt` |
| Bằng chứng | **PASS** | Quét `evidence/`: 40 file, 8 khóa secret và các mẫu token, **0 kết quả** (`raw/D8-scan.txt`). Scanner có đối chứng dương ở T-001 |

## Bất biến

| Mã | Trạng thái | Cách kiểm / bằng chứng |
|---|---|---|
| INV-01 | PASS | Demo 6: `nginx-waf` publish đúng 2 cổng, không cổng nào ngoài `127.0.0.1`. `raw/D8-ps.txt`: `127.0.0.1:443`, `127.0.0.1:9443` |
| INV-02 | PASS | Demo 6: `docker port` của database, 2 node, lab-backend, lab-db đều trả 0 dòng |
| INV-03 | PASS | Demo 6 và preflight: hai node có `SPRING_PROFILES_ACTIVE=integration`, `SQLI_DEMO_ENABLED=false` |
| INV-04 | PASS | X-02, dùng token prod hợp lệ: 4 route lab trả `404` qua gateway và khi gọi thẳng từng node; GET không token gọi thẳng node cũng `404`. Kiểm tra dương: gọi thẳng node `/api/v1/posts/1` trả `200` |
| INV-05 | PASS | Hash `JWT_SECRET` runtime: 2 node prod GIỐNG NHAU, prod và lab KHÁC NHAU; hash trong `.env` cũng KHÁC NHAU. X-01: token lab gọi prod `/posts/me` trả `401`, token prod gọi lab trả `401`; kiểm tra dương mỗi bên trả `200` |
| INV-06 | PASS | X-03: (a) lab-backend không phân giải được `database`; (b) không mở được TCP tới IP thật của database:5432; (c) lab-backend và lab-db chỉ gắn `nhom9-local_lab_net`, chỉ nginx-waf gắn nhiều mạng; (d) backend-node-1 không phân giải và không kết nối được lab-db. Kiểm tra dương: nginx-waf mở được TCP tới cả hai DB |
| INV-07 | PASS | Sau mỗi lần `run-all`, `waf-mode.sh` báo `On` (`raw/D8-waf-mode-1.txt`, `-2.txt`). DetectionOnly chỉ bật trong Demo 3, có trap trả về On |
| INV-08 | PASS | Demo 5 (prod): IP giả `6.6.6.6` không vào log; IP backend khớp IP peer ở Nginx; một rid xuyên suốt 3 lớp |
| INV-09 | PASS | Demo 6: `/swagger-ui/index.html`, `/v3/api-docs`, `/actuator/env` trả `404` trên cả hai listener; gọi thẳng 2 node `/v3/api-docs` trả `404` (springdoc tắt) |
| INV-10 | PASS | Đăng nhập lab với mật khẩu sai chứa chuỗi canary ngẫu nhiên: trả `401`, backend có nhận request; canary xuất hiện 0 lần trong log nginx, WAF và backend (lab + prod). Mẫu JWT trong cùng các log: 0. Response `/posts/me` và response lỗi 401 không chứa token |
| INV-11 | PASS | `test-evidence-guards.sh` 10/10 (mặc định target prod, không sửa test guard) |
| INV-12 | PASS | Checksum posts/comments prod trước và sau các demo lab: `0904d672…0e8e` = `0904d672…0e8e`, ở cả 2 lần `run-all` và qua các lần `lab.sh reset` |
| INV-13 | PASS | `raw/D8-git.txt`: chỉ `origin` = repo riêng có push; push URL của `team-readonly` = `no-push://…`; hook chặn URL nhóm (exit 1). Ref của repo nhóm trên GitHub vẫn y nguyên (main/main-2 `0a22829`, feat/tv3-backend `8768569`, tag v1.0-final) |
| INV-14 | PASS | Quét theo mục 5.7: 0 kết quả |

## Thay đổi chính
- **`init-env.sh`:** chỉ bổ sung khóa thiếu (`LAB_*`); ngừng `SQLI_DEMO_ENABLED`; tạo `logs/lab-backend`.
- **Compose:**
  - Node prod: profile `integration`, flag `"false"` ghi cứng, không có `SQLI_DEMO_DB_*`, springdoc tắt, `mem_limit` 768m (đo được khoảng 365–390 MiB).
  - Thêm `lab-db` (tmpfs) và `lab-backend` trên `lab_net` 10.209.20.0/24; nginx có địa chỉ 10.209.20.10.
- **Nginx:**
  - `includes/listener-common.conf` dùng chung cho hai listener.
  - Listener prod chặn `^~ /api/v1/vuln/` (404).
  - Listener lab 9443 dùng zone `lab_api`/`lab_login`, upstream `lab_cluster` với `resolve`, trả 503 JSON khi lab tắt.
  - Thêm `srv=$server_port` ở cuối log.
- **Demo:** Demo 2/3/4 chạy trên lab; Demo 4 có kiểm tra dương; thêm Demo 6 và `prod-checksum.sh`; `run-all` FAIL khi lab tắt.
- **Script:** thêm `lab.sh`; preflight kiểm tra theo mục 5.5.

## Ghi nhận
- **Dữ liệu prod đã đổi từ T-001:** bài 3 trong DB prod mang tiêu đề "B da sua bai cua A". Đây là do Demo 4 chạy **trong T-001**, khi baseline (D2) còn để `/vuln` trên node prod. Kể từ T-002, checksum prod không đổi. Đây là dữ liệu giả; muốn khôi phục phải khởi tạo lại volume prod, việc này cần người dùng đồng ý và có thể gộp với R-RES-01.
- **R-RES-01, R-RES-02:** ghi trong `docs/decisions.md` mục D11.
- **`docs/demo-checklist.md` chưa cập nhật** theo chế độ Local (ngoài phạm vi D7). Một số mục vẫn nhắc `reset-demo.sh` cho Demo 4; nên đổi thành `lab.sh reset`.
