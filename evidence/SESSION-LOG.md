# Nhật ký phiên: xác minh baseline và tách lab (T-001 / T-002)

Bắt đầu: 2026-11-07. Không chứa secret.

## Giai đoạn A: xác định workspace (xong)

- **Repo Git trong workspace** (độ sâu ≤ 2):
  - `ATTT-Security-Project`: `origin` = `meomaydoraemon/ATTT-Security-Project`, là **repo riêng của người dùng**. `team-readonly` = repo nhóm, chỉ fetch; push URL đã bị vô hiệu (`no-push://`). Nhánh `main`, HEAD `281e748` (2026-11-07, "chore: allow pushes only to the personal repository"). `develop` = `main` = `origin/main` = `281e748`. Tag `baseline/2981c24-audited`. Không có stash; working tree sạch.
  - `audit-main-2`: `origin` = **repo nhóm** (fetch); push URL đã bị vô hiệu. Nhánh `codex/main-2-audit`, HEAD `2981c24`; `main-2` ở `0a22829`. Working tree sạch.
  - `private-repo-staging`: không có Git, chỉ để tham khảo.
- **Fetch chỉ đọc (2026-11-07):** `team-readonly/main` = `team-readonly/main-2` = `0a22829`. Nhánh `main-2` của nhóm **không có commit nào mới hơn `0a22829`**. `origin/main` và `origin/develop` = `281e748`.
- **Lựa chọn (A3):** dùng `ATTT-Security-Project`.
  - Repo này chứa `docker-compose.yml`, `backend/`, `nginx/`.
  - HEAD `281e748` kế thừa trực tiếp `2981c24`. Phần khác so với `2981c24` chỉ gồm 20 file tài liệu, hook và quy tắc AI (`git diff --stat 2981c24 HEAD`: 20 files, +1198), không đổi source.
  - Đây là repo người dùng vừa push lên GitHub, và theo quy tắc của repo (AGENTS.md) là nơi phát triển duy nhất.
  - Không có mâu thuẫn, nên không cần hỏi.
- **A4:** `git diff --stat` rỗng; `git diff --ignore-cr-at-eol --stat` rỗng; không có file untracked. Có 4 file tài liệu audit ở trạng thái `w/mixed` EOL: nội dung không đổi, đó là định dạng gốc của báo cáo Codex.
- **A5:** tạo nhánh `work/local-lab-split` từ `281e748`. Không cần commit snapshot. Hook `pre-push` đã có sẵn: `core.hooksPath=.githooks`, chỉ cho push tới repo riêng, chặn repo nhóm. Không đổi git config toàn cục trong phiên này.
- **A6:** tag cục bộ `checkpoint/session-start` → `281e748`.

## Giai đoạn B: T-001 (đang làm)

### B1 Môi trường
- Windows 10.0.26300.9818; Docker client/server 29.9.2; Compose v5.6.1.
- Git Bash: bash 5.3.9 (`sh` = bash); có `/usr/bin/dash`. OpenSSL 3.5.6; curl 8.19.0.
- **Không có** Java hoặc Maven trên máy; có sẵn image `maven:3.9.6-eclipse-temurin-21`. Không có `pwsh` 7.
- RAM: tổng 14.8 GB, **trống 2.7 GB** (rủi ro khi chạy 6 container cùng Maven). Đĩa trống: C 29.2 GB, D 79.5 GB.

### B2 Cô lập Docker: **CÓ XUNG ĐỘT, DỪNG VÀ HỎI**
- Repo chưa có `.env`; chưa có `logs/`; chưa có khóa hay chứng chỉ.
- Không có container nào trùng tên `nginx-waf`, `backend-node-1`, `backend-node-2`, `database`, `lab-backend`, `lab-db`.
- Cổng 443 và 9443: không có tiến trình nào nghe.
- Subnet 10.209.20.0/24: trống.
- **Xung đột:** network `audit-m2-0a2282_internal_net` (project Compose `audit-m2-0a2282`, lab kiểm toán cũ của Codex) đang chiếm **10.209.10.0/24**. Network này đã `internal`, có 0 endpoint; 4 container của project đó đã dừng 10 ngày (`audit-m2-0a2282-{nginx,node1,node2,db}`), volume `audit-m2-0a2282_postgres_data` vẫn còn. Không xử lý thì Compose sẽ báo `Pool overlaps` khi tạo `internal_net`.
- **Ghi nhận thêm:**
  - Tag image `nhom9/blog-api:local` đã tồn tại (tạo 2026-10-28, không có container nào dùng), có thể thuộc project `csattt-btl--nhom9-main-2` (còn volume và `dmz_net`). Lệnh build của phiên sẽ gắn lại tag này; image cũ thành dangling chứ không bị xóa.
  - Image NGINX đã có sẵn, digest `sha256:873ce68a…3365`, khớp D3.
- **Quyết định của người dùng:** "Gỡ network project cũ". Đã chạy `docker compose -p audit-m2-0a2282 down` (không `-v`): xóa 4 container đã dừng và 2 network; volume `audit-m2-0a2282_postgres_data` **vẫn còn**. Sau đó 10.209.10.0/24 và 10.209.20.0/24 đều trống.
- **Cấu hình đã resolve** (chỉ trích các trường cần, không lưu toàn bộ output):
  - Project `nhom9-local`.
  - Container `nginx-waf`, `backend-node-1`, `backend-node-2`, `database`.
  - Cổng duy nhất: `127.0.0.1:443→8443`.
  - Mạng `nhom9-local_dmz_net`, `nhom9-local_internal_net` (internal, 10.209.10.0/24, nginx 10.209.10.10).
  - Volume `nhom9-local_postgres_data` (mới, rỗng).
  - **B2 = PASS** sau khi người dùng cho phép xử lý xung đột.

### B3 Env và chứng chỉ: PASS
- Đã chạy `sh scripts/init-env.sh --lab`: `.env` mới, secret ngẫu nhiên, `SQLI_DEMO_ENABLED=true`. Thêm `COMPOSE_PROJECT_NAME=nhom9-local`.
- Đã chạy `generate-cert.sh`: SAN `localhost`/`127.0.0.1`, hết hạn 2027-11-06.
- `git check-ignore`: `.env` (.gitignore:21) và `server.key` (.gitignore:25) đều bị ignore.

### B4 Script: PASS (trong Git Bash)
- `sh` = bash 5.3.9. `sh -n` cho 16 script: 0 lỗi.
- Guard test chạy bằng `sh` (bash): 10/10 PASS, exit 0.
- Chạy bằng `dash`: exit 1 ("Không xác định được SecRuleEngine"). Khớp lỗi khả chuyển F10; sẽ sửa tùy chọn ở Giai đoạn C.
- Bằng chứng: `raw/B4-*.txt`.

### B5 Maven: PASS
- Chạy `mvn -B -ntp test` trong container `maven:3.9.6-eclipse-temurin-21` (`--memory 2g`), trên bản sao source; cache ở volume `nhom9-local-m2`.
- Kết quả: **170 run, 0 fail, 0 error, 5 skip** (cả 5 thuộc `SqliLabPostgresTest`, ghi **UNVERIFIED**). BUILD SUCCESS. Bằng chứng: `raw/B5-mvn-test.txt`.

### Commit
- `77c968c` chore(evidence): ignore `evidence/**/raw/` và `evidence/**/rollback/`.

### B6: đang chạy `docker compose up -d --build --wait`
- B6 PASS: 4 container healthy, digest nginx khớp D3.
- B7 PASS: preflight 19/0/0.
- B8 PASS: 56 assertion, "TẤT CẢ DEMO ĐẠT", WAF On.
- B9: đã ghi module nginx và RAM.
- B11 PASS: scan 0 kết quả, đối chứng dương 4/4.
- B12 PASS: đã lưu 3 image ra `evidence/T-001/rollback/`.
- **Kết luận A ĐẠT, Kết luận B ĐẠT** (xem `T-001/REPORT.md`). Bỏ qua Giai đoạn C; F10 ghi nhận.

## Giai đoạn D: T-002 (bước tiếp theo)
- **D1 (xong):** `init-env.sh` bổ sung 5 khóa `LAB_*` vào `.env` hiện có; các dòng cũ giữ nguyên (đã đối chiếu hash); không in giá trị. Commit `51ba096`.
- **D2 (xong):** compose tách prod và lab. Đã áp lên prod bằng `up -d --wait`: node được tạo lại, volume DB giữ nguyên. Bật lab: 6 container healthy. Commit `a4d8ab0`.
- **D3 (xong):** listener lab 9443; prod chặn `/api/v1/vuln/` trả 404; file include dùng chung; `nginx -t` OK. Commit `435cdae`.
- **D4 (chưa commit):** `common.sh` có `LAB_BASE`, `DEMO_TARGET`, log theo tham số; Demo 2/3/4 chạy trên lab; Demo 4 có kiểm tra dương với bài 4 của user_b; thêm `demo6-isolation.sh` (chạy lần đầu 54/0) và `prod-checksum.sh`; `run-all.sh` FAIL khi lab tắt.
- **D5 (chưa commit):** preflight 25 PASS / 0 WARN / 0 FAIL, kèm 1 INFO.
- **D6 (chưa commit):** đã thử `lab.sh` down/up/reset/status. Reset mất 24 giây và khôi phục bài 3; checksum prod không đổi; ID container prod không đổi.
- **Tiếp theo:** chạy `run-all` lần 1 (đang chạy), commit test và script, viết tài liệu D7, rồi nghiệm thu D8 (gồm chế độ không bật lab).
- **D4–D7 (xong):** đã commit `f68954f` (test), `fcecd6f` (scripts), `8acf646` (docs).
- **D8 (xong):** mọi cổng PASS (xem `T-002/REPORT.md`). `run-all` chạy 2 lần, mỗi lần 111/0. Chế độ không bật lab: Demo 1 và 5 PASS, listener lab trả 503 JSON. Reset 20–29 giây. `mvn` 170/0/5. Scan 0.
- **Trạng thái cuối:** 6 container healthy; dữ liệu lab đã reset về seed; WAF On; preflight 25/0/0 kèm 1 INFO.
- **Ghi nhận:** bài 3 của DB prod đã bị Demo 4 của T-001 sửa (khi baseline còn để /vuln trên prod). Không tự khôi phục.

## T-003 (bắt đầu 2026-11-07, nhánh `work/t003-local-ready`, tag `checkpoint/t003-start` = `8f55b6d`)
- Trạng thái đầu: working tree sạch, 6 container healthy, RAM trống 1.63 GB, nginx-waf 77.8 MiB.
- **2.1 (xong, đã commit `a213509` `4d7aaf5` `e8c618f`):**
  - Bỏ mount WAF_MODE toàn cục. Lab có override trên tmpfs `/etc/nginx/waf-lab/`, nạp TRƯỚC rules file; `waf-mode.sh lab On|DetectionOnly` dùng `nginx -t` + reload.
  - Lần đầu đặt override SAU rules file thì không có tác dụng; proof bắt được (FAIL 4). Đã sửa thứ tự.
  - Proof `tests/demo/waf-listener-proof.sh`: 30/0, prod không gián đoạn (46 request lành tính đều 200).
  - Demo 3: 12/0, có assertion prod vẫn chặn.
  - Ngắt bằng TERM: lab tự về On. Kill -9: preflight FAIL, run-all FAIL, in lệnh khôi phục `sh scripts/waf-mode.sh lab On`.
  - Preflight 26/0/0. Guard 10/10 trên bash và dash (đã sửa F10). RAM nginx 74.7 → 87.6 MiB.
- **Còn lại:** 2.2 (demo6 tcp/resolves/network, scanner, hồi quy), 2.3 SqliLabPostgresTest, 2.4 demo-checklist, 2.5 script R-RES-01 dry-run, docs R-RES-02, nghiệm thu, báo cáo.
- WAF hiện ở trạng thái an toàn: prod On, lab On.
- **2.2 (xong, commit `1d3a168` `3d3da56`):**
  - Hiệu chuẩn trên `nhom9/blog-api:local` (`raw/24-calibration.txt`): exit 28 có `time_connect` > 0 là ĐÃ KẾT NỐI (server im lặng). Công cụ cũ coi là "bị chặn".
  - Thêm `netprobe.sh` (3 trạng thái); `test-netprobe.sh` 19/19 trên bash và dash.
  - Đo lại Demo 6: 59/0, **không có vi phạm cô lập**.
  - Scanner fail-closed (exit 2); self-test 10/10 trên bash và dash; quét thật `evidence/` 0/56 file.
  - Ghi chú: self-test ban đầu chứa sẵn JWT giả nên chính nó bị quét ra; đã sửa bằng cách ghép chuỗi lúc chạy.
- **Tiếp theo:** 2.3 SqliLabPostgresTest, 2.4 checklist, 2.5 dry-run, tài liệu, nghiệm thu.
- **2.4 (xong, commit `4f2f1b2`):**
  - Preflight chẩn đoán đăng nhập theo mã lỗi, chỉ đọc (đã có từ `e8c618f`).
  - Viết lại `demo-checklist.md` cho chế độ Local, lệnh dạng cmd.
  - README không còn hướng dẫn chạy `reset-demo.sh`.
  - Thêm D12, đóng R-RES-02.
- **2.5 (script xong, commit `6562b4b`):** `scripts/rres01-prod-db-cleanup.sh` mặc định dry-run. R-RES-01 = CHƯA ĐỒNG Ý nên không --apply. **Dry-run CHƯA chạy (UNVERIFIED)** vì Docker tắt.
- **SỰ CỐ:** từ lúc chuẩn bị 2.3, Docker Engine không phản hồi (`dockerDesktopLinuxEngine` không tồn tại). Lần đo mục tiêu 2.3 là LỖI ĐO (`raw/27-sqlitest-target-LOI-DO-docker-down.txt`); không chạy gì trên DB.
- **Trạng thái an toàn:** WAF prod On cố định. Override lab nằm trên tmpfs, nên khi Docker chạy lại thì lab On. Không có thay đổi nào chưa commit.
- **NỐI LẠI (khi Docker chạy):**
  1. `docker compose up -d --wait` rồi `sh scripts/lab.sh up`.
  2. `sh scripts/waf-mode.sh`: phải là prod On, lab On.
  3. **2.3:** xác minh đích `lab-db` (label project, tmpfs, chỉ lab_net, có `sqli_lab` và role reader, chỉ phân giải được `lab-db`). Chạy `docker run --rm --network nhom9-local_lab_net -v nhom9-local-m2:/root/.m2`, Maven offline `-o -Dtest=SqliLabPostgresTest`, env `SQLI_LAB_TEST_ENABLED=true`, `SQLI_DEMO_DB_URL=jdbc:postgresql://lab-db:5432/sqli_lab`, `SQLI_DEMO_DB_USERNAME=sqli_demo_reader`, `-e SQLI_DEMO_DB_PASSWORD` lấy từ `LAB_SQLI_READER_PASSWORD`. Quét secret output, rồi `lab.sh reset` và kiểm checksum prod.
  4. **2.5:** `sh scripts/rres01-prod-db-cleanup.sh` (dry-run) và lưu raw.
  5. **Nghiệm thu mục 3:** sh -n; guard, netprobe, scanner dưới bash và dash; `nginx -t`; preflight; run-all (so 111); lab down + Demo 1/5 + 503 + prod chặn; lab up + reset + checksum; quét evidence.
  6. Viết `evidence/T-003/REPORT.md`, tag `checkpoint/t003-local-ready`.
