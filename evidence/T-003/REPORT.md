# T-003: Local đủ tin cậy để chuyển sang hai máy (2026-11-07)

## 1. Phiên bản
- **SHA đã nghiệm thu:** `c31ede912f98bb776e454319550b116cad3a27a4` (working tree sạch).
- **Nhánh:** `work/t003-local-ready`, tách từ `8f55b6d` (tag `checkpoint/t003-start`). Commit tài liệu cuối mang tag `checkpoint/t003-local-ready`. Chưa push.
- **Bằng chứng thô:** `evidence/T-003/raw/` (bị Git ignore, đã kiểm bằng `git check-ignore`).
- **Nghiệm thu lần 1** (SHA `0e5cdb0`): FAIL, giữ ở `raw/run1-failed/`. Demo 6 nạp `netprobe.sh` bằng đường dẫn tương đối, nên hỏng khi được gọi từ `run-all`. Đã sửa ở `c31ede9` rồi chạy lại toàn bộ.

## 2. Thay đổi và lý do

| Mục | Thay đổi | Commit |
|---|---|---|
| 2.1 WAF | Bỏ mount `WAF_MODE` toàn cục. Lab nạp `/etc/nginx/waf-lab/*.conf` (tmpfs trong `nginx-waf`) **trước** file luật dùng chung. `waf-mode.sh lab On\|DetectionOnly` dùng `nginx -t` + reload, không tạo lại container. Prod không còn đường nào đổi chế độ. Thiết kế đầu (override đặt **sau** file luật) bị proof runtime bác bỏ (`raw/21-*`: lab vẫn chặn), đã sửa thứ tự. Đóng R-RES-02 (D12) | `a213509`, `4d7aaf5`, `e8c618f`, `4f2f1b2` |
| 2.1 test | `waf-listener-proof.sh`. Demo 3 chỉ đổi lab, trap INT/TERM, có assertion prod vẫn chặn. Guard theo giao diện mới. `run-all` và preflight FAIL khi lab không On | `4d7aaf5`, `e8c618f` |
| 2.2 Demo 6 | Thêm `netprobe.sh` 3 trạng thái, hiệu chuẩn trên image thật. Kiểm tra dương và âm trong cùng container. Kiểm từng IP theo đúng network. Network lấy theo label của project; tập network so bằng đúng (equal) | `1d3a168`, `c31ede9` |
| 2.2 scanner | Exit 2 khi đích thiếu, 0 file, hoặc thiếu khóa; quét được file lẻ; `--tokens-only` ghi rõ chế độ; self-test dùng `.env` giả | `3d3da56` |
| F10 | Stub của guard không dùng `printf` với `\"` nữa | `4d7aaf5` |
| 2.3 | Không đổi code: chạy `SqliLabPostgresTest` trên `lab-db` | — |
| 2.4 | Preflight chẩn đoán đăng nhập theo mã lỗi, chỉ đọc (bỏ gợi ý `reset-demo.sh`). Viết lại `demo-checklist.md` dạng cmd. README không còn hướng dẫn xóa volume prod | `e8c618f`, `4f2f1b2` |
| 2.5 | `scripts/rres01-prod-db-cleanup.sh`, mặc định dry-run. **Không áp dụng** vì R-RES-01 = CHƯA ĐỒNG Ý | `6562b4b` |

`backend/` không đổi so với `8f55b6d`, nên không chạy lại đủ bộ Maven; dùng lại kết quả T-002 (170/0/5), cộng mục 2.3.

## 3. Lệnh và kết quả

| Lệnh | Exit | Trạng thái | Bằng chứng |
|---|---|---|---|
| `sh -n` / `dash -n` cho mọi `.sh` tracked | 0 / 0 | PASS | `raw/30-shn-*.txt` |
| Guard (bash / dash) | 0 / 0 | PASS 10/10 | `raw/30-test-evidence-guards-*.txt` |
| `test-netprobe.sh` (bash / dash) | 0 / 0 | PASS 19/19 | `raw/30-test-netprobe-*.txt` |
| `test-scan-secrets.sh` (bash / dash) | 0 / 0 | PASS 10/10 | `raw/30-test-scan-secrets-*.txt` |
| `nginx -t` | 0 | PASS | `raw/30-nginx-t.txt` |
| `preflight.sh` | 0 | PASS 26/0/0 (2 INFO về biến đã ngừng dùng) | `raw/30-preflight.txt` |
| `run-all.sh` | 0 | PASS: 120 assertion, 0 FAIL (T-002: 111; thêm 4 ở Demo 3 và 5 ở Demo 6) | `raw/30-run-all.txt` |
| `waf-listener-proof.sh` | 0 | PASS 30/0 | `raw/21-waf-proof.txt` |
| Demo 3 bị TERM / bị kill -9 | 143 / 137 | PASS: TERM thì lab về On; kill thì preflight (2 FAIL) và `run-all` (exit 1) phát hiện, in `sh scripts/waf-mode.sh lab On` | `raw/23-interrupt-*.txt` |
| `lab.sh down`: 4 container prod healthy | 0 | PASS | `raw/30-prod-health.txt` |
| Demo 1 / Demo 5 khi lab tắt | 0 / 0 | PASS 15/0, 11/0 | `raw/30-demo1-laboff.txt`, `raw/30-demo5-laboff.txt` |
| Listener lab khi lab tắt | 0 | PASS: `503` JSON | `raw/30-lab-503.txt` |
| Prod chặn request đối chứng khi lab tắt | 0 | PASS: `403` + `X-Blocked-By: waf` | `raw/30-prod-block-laboff.txt` |
| `lab.sh up` + `lab.sh reset` (24 giây); checksum prod | 0 | PASS: `0904d672…0e8e` không đổi | `raw/30-lab-reset.txt`, `raw/30-checksum.txt` |
| Demo 2 / Demo 4 sau reset | 0 / 0 | PASS 9/0, 14/0 | `raw/30-demo2-rerun.txt`, `raw/30-demo4-rerun.txt` |
| `SqliLabPostgresTest` trên `lab-db` | 0 | PASS 5/5, 0 skip | `raw/28-sqlilab-postgres-test.txt` |
| Quét output của 2.3 | 0 | PASS: 0 kết quả | `raw/28-scan.txt` |
| R-RES-01 dry-run | 0 | PASS: chỉ đọc, checksum không đổi; `--apply` khi chưa đồng ý bị từ chối | `raw/29-rres01-dryrun.txt` |
| Quét file đã commit trong `evidence/` | 0 | PASS: 0 kết quả (6 file, 8 khóa) | `raw/30-scan-committed.txt` |
| Quét toàn bộ `evidence/`, gồm raw | 0 | PASS: 0 kết quả (122 file) | `raw/30-scan-all.txt` |
| Đo trong lúc Docker Engine tắt | — | LỖI ĐO, không dùng | `raw/27-sqlitest-target-LOI-DO-docker-down.txt` |

RAM của `nginx-waf`: 77.8 MiB lúc bắt đầu, 87.6 MiB sau proof, 105.8 MiB cuối phiên (sau khoảng chục lần reload, mỗi lần nạp lại CRS).

## 4. Phạm vi đã chứng minh
- **INV-07 (WAF):**
  - Request đối chứng là payload SQLi của Demo 3 vào `POST /api/v1/secure/records/search`, route được proxy, có token của đúng môi trường.
  - Mỗi kết luận đối chiếu theo `X-Request-ID`: status và `X-Blocked-By`; audit WAF `is_interrupted`; số dòng có rid trong log backend của đúng môi trường (log thiếu hoặc rỗng là lỗi đo).
  - Có request lành tính làm kiểm tra dương cho từng listener.
  - Trong lúc đổi chế độ lab: 46 request lành tính tới `GET /api/v1/posts` của prod (khoảng 4 req/s), 0 mã khác 200.
  - Ctrl+C: dùng chung trap với TERM, nhưng không tái hiện được trong shell không tương tác (tiến trình nền bỏ qua SIGINT), nên **UNVERIFIED riêng cho Ctrl+C**. TERM đã PASS.
- **INV-06 (cô lập):**
  - Đo bằng curl (`time_connect` + `exitcode`) và getent, hiệu chuẩn trên `nhom9/blog-api:local` (`raw/24-calibration.txt`).
  - `lab-backend` → `lab-db` 10.209.20.2:5432: được (kiểm tra dương). `lab-backend` → `database` 10.209.10.2:5432: không. Tên `database`: không phân giải.
  - `backend-node-1` → `database` 10.209.10.2:5432: được (kiểm tra dương). `backend-node-1` → `lab-db` 10.209.20.2:5432: không. Tên `lab-db`: không phân giải.
  - Tập network của `lab-backend` và `lab-db` bằng đúng `{nhom9-local_lab_net}`; chỉ `nginx-waf` gắn nhiều mạng.
  - **Chưa đo** cổng khác ngoài 5432, và chưa đo từ `backend-node-2` hay `lab-db`.
- **2.3:** container test chỉ gắn `nhom9-local_lab_net`, Maven offline với cache `nhom9-local-m2`. Container phân giải được `lab-db`, không phân giải được `database`. Mật khẩu truyền bằng `-e SQLI_DEMO_DB_PASSWORD`, không nằm trên dòng lệnh.

## 5. Đính chính so với T-001 và T-002
- **Guard chạy bằng dash:** ở T-001 là **FAIL** (đã chạy, exit 1), không phải UNVERIFIED. Từ T-003: PASS.
- **INV-06 của T-002** được đo bằng công cụ cũ: exit 28 bị coi là "chặn", lỗi `docker exec` bị coi là "được", kiểm tra dương chỉ chạy từ `nginx-waf`. Kết quả đó không đủ tin cậy. Đo lại bằng `netprobe.sh`: PASS, **không có vi phạm cô lập**.
- **`SqliLabPostgresTest`:** T-001/T-002 ghi UNVERIFIED (skip). T-003: **PASS 5/5** trên `lab-db`.
- **R-RES-02:** đã đóng (D12).

## 6. Chưa xác minh, hoãn, giới hạn
- **R-RES-01 chưa xử lý** (người dùng CHƯA ĐỒNG Ý): DB prod vẫn có `sqli_lab` và `sqli_demo_reader`; bài 3 prod vẫn là "B da sua bai cua A". Đã có script, đã dry-run.
- Ctrl+C khi chạy Demo 3: UNVERIFIED (lý do ở mục 4).
- Các bộ PowerShell trong `backend/scripts`: UNVERIFIED (không có pwsh 7).
- RAM host trống thấp (0.8–1.6 GB). `nginx-waf` tăng dần sau nhiều lần reload.
- Ngoài phạm vi: máy B, Tailscale, Cloudflare, Internet, `realip`, frontend, console.

## 7. Sẵn sàng cho hai máy

| Điều kiện | Trạng thái |
|---|---|
| WAF prod luôn On, có bằng chứng runtime | **Đạt** (D12, proof 30/0, kill -9 bị phát hiện) |
| R-RES-01 đã xử lý | **Chưa**: chờ người dùng đồng ý; script và dry-run sẵn sàng |
| Bằng chứng tin cậy (fail-closed, 3 trạng thái, hồi quy bash/dash) | **Đạt** |
| `SqliLabPostgresTest` chạy trên lab | **Đạt** 5/5 |
| Checklist vận hành dùng được, không hướng tới xóa volume prod | **Đạt** |
| Cô lập lab/prod đo lại bằng công cụ đã hiệu chuẩn | **Đạt** (phạm vi ở mục 4) |
| Upstream/DB qua LAN, `realip`, bind ngoài loopback | **Chưa làm** (ngoài phạm vi T-003) |

## 8. Lệnh cmd
```bat
cd /d "D:\BTL ALL MAJOR\BTL ATTT Claude\ATTT-Security-Project"
```
Vào thư mục repo.
```bat
docker compose up -d --wait
```
Bật prod. Kết quả: 4 container `Healthy`.
```bat
"C:\Program Files\Git\bin\bash.exe" scripts/lab.sh up
```
Bật lab. Kết quả: `lab-db`, `lab-backend` `running/healthy`.
```bat
"C:\Program Files\Git\bin\bash.exe" scripts/preflight.sh
```
Kiểm tra trước buổi trình bày. Kết quả: `26 PASS, 0 WARN, 0 FAIL`.
```bat
"C:\Program Files\Git\bin\bash.exe" tests/demo/run-all.sh
```
Chạy hồi quy offline và Demo 1–6. Kết quả: dòng cuối `TẤT CẢ DEMO ĐẠT`.
```bat
"C:\Program Files\Git\bin\bash.exe" scripts/waf-mode.sh
```
Xem chế độ WAF. Kết quả: `WAF prod: On`, `WAF lab: On`.
```bat
"C:\Program Files\Git\bin\bash.exe" scripts/waf-mode.sh lab On
```
Khôi phục khi Demo 3 bị ngắt cứng. Kết quả: lab trở về On, prod không gián đoạn.
```bat
"C:\Program Files\Git\bin\bash.exe" scripts/lab.sh reset
```
Đưa dữ liệu lab về seed, ví dụ sau Demo 4. Kết quả: `Đã reset lab trong ~25 giây`, prod không bị đụng.
```bat
"C:\Program Files\Git\bin\bash.exe" scripts/rres01-prod-db-cleanup.sh
```
Xem trước R-RES-01 (chỉ đọc). Kết quả: danh sách những gì sẽ đổi, kèm dòng `DRY-RUN: không thay đổi gì`.
```bat
"C:\Program Files\Git\bin\bash.exe" scripts/lab.sh down && docker compose stop
```
Dừng toàn bộ mà vẫn giữ dữ liệu prod.
