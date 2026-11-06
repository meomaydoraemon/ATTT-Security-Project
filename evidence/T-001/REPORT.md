# T-001: Xác minh baseline (2026-11-07)

- Source: `ATTT-Security-Project`, nhánh `work/local-lab-split`, tách từ `281e748`. Phần source khác `2981c24` chỉ ở tài liệu và hook.
- Project Compose: `nhom9-local`.
- Bằng chứng thô ở `evidence/T-001/raw/` (bị Git ignore).
- Không in secret nào ra báo cáo. Mật khẩu tài khoản seed được che.

| # | Kiểm tra | Trạng thái | Kết quả / bằng chứng |
|---|---|---|---|
| B1 | Môi trường | PASS (đã ghi) | Windows 10.0.26300; Docker 29.9.2; Compose v5.6.1; Git Bash: `sh` = bash 5.3.9, có dash; OpenSSL 3.5.6; curl 8.19.0. **Không có** Java, Maven, pwsh 7. RAM tổng 14.8 GB / trống 2.7 GB; VM Docker 7.1 GiB. Đĩa trống: C 29.2 GB, D 79.5 GB |
| B2 | Cô lập Docker | PASS (sau khi người dùng quyết định) | Phát hiện network `audit-m2-0a2282_internal_net` chiếm 10.209.10.0/24. Người dùng chọn "Gỡ network project cũ", nên đã chạy `docker compose -p audit-m2-0a2282 down` (không `-v`, volume giữ nguyên). Không có container trùng tên; cổng 443/9443 trống; 10.209.20.0/24 trống. Đã resolve: project `nhom9-local`, publish duy nhất `127.0.0.1:443→8443`, volume mới `nhom9-local_postgres_data` |
| B3 | Env và chứng chỉ | PASS | `init-env.sh --lab` sinh secret mới; chứng chỉ có SAN localhost/127.0.0.1, hết hạn 2027-11-06. `git check-ignore`: `.env` và `server.key` đều bị ignore |
| B4 | Cú pháp, guard | PASS | 16 script `sh -n` OK. Guard chạy bằng `sh` (bash): 10/10 PASS. Chạy bằng dash: exit 1. Đó là lỗi khả chuyển F10 của test, không ảnh hưởng tiêu chí (README bắt buộc Git Bash). `raw/B4-*` |
| B5 | `mvn test` (container `maven:3.9.6-eclipse-temurin-21`) | PASS | 170 run, 0 fail, 0 error, 5 skip. `SqliLabPostgresTest` (5 test) ghi **UNVERIFIED** vì cần `SQLI_LAB_TEST_ENABLED`. Không chạy được bộ PowerShell (không có pwsh 7). `raw/B5-mvn-test.txt` |
| B6 | `compose up --build --wait` | PASS | 4 container healthy. Image backend `sha256:31e97ca2…c715`, postgres `sha256:f4610795…ac36`, nginx `sha256:873ce68a…3365`. RepoDigest khớp D3. `raw/B6-*` |
| B7 | preflight | PASS | 19 PASS, 0 WARN, 0 FAIL. `raw/B7-preflight.txt` |
| B8 | `run-all.sh`, `waf-mode.sh` | PASS | Guard 10/10. Demo 1: 15, Demo 2: 9, Demo 3: 8, Demo 4: 13, Demo 5: 11 PASS, tổng 56, 0 FAIL. In ra "TẤT CẢ DEMO ĐẠT". Sau đó `waf-mode.sh` báo On. `raw/B8-*` |
| B9 | Ghi nhận | PASS (đã ghi) | nginx 1.30.6. Module có sẵn gồm `http_realip`, `http_ssl`, `stream_*`, `headers_more`, `njs`, `modsecurity` (dynamic). RAM: nginx 41 MiB, node1 554 MiB, node2 535 MiB, db 70 MiB. `raw/B9-*` |
| B10 | Báo cáo | PASS | File này. Luật ignore `evidence/**/raw/` có ở commit `77c968c` |
| B11 | Quét secret `evidence/` | PASS | 0 kết quả (4 khóa secret có trong `.env`, cùng mẫu JWT/refreshToken/Bearer). Đối chứng dương: cài thử 4 mẫu, bắt đủ 4. Công cụ: `evidence/scan-secrets.py` |
| B12 | Rollback image | PASS | Đã lưu `evidence/T-001/rollback/` (bị ignore): `backend-blog-api-local.tar` 155 MB `ba0b010d…fd71`; `nginx-modsecurity-crs.tar` 40 MB `9329559b…7384`; `postgres-16-alpine.tar` 117 MB `3ca74d85…7fac` (SHA256 đầy đủ ở `SHA256SUMS`). Tag `checkpoint/t001-verified` |

## Kết luận A: đã hoàn tất kiểm tra. **ĐẠT**
Mọi mục B1–B12 đều có trạng thái và bằng chứng.

## Kết luận B: baseline đủ điều kiện triển khai tiếp. **ĐẠT**
- Source đã xác định.
- B2 hết xung đột, sau khi người dùng cho phép gỡ network cũ.
- B3: secret mới.
- B4: guard PASS.
- B5: 0 FAIL.
- B6: 4 container healthy.
- B7: 0 FAIL.
- B8: mọi demo PASS.
- B11: 0 kết quả.

Vì Kết luận B đạt nên **không cần Giai đoạn C** (T-001b). Lỗi F10 (dash) được ghi lại, chưa sửa.

## UNVERIFIED
- `SqliLabPostgresTest`.
- Các bộ PowerShell trong `backend/scripts`.
- Guard chạy bằng dash: đã chạy, **FAIL** do F10. Đây là lỗi của test, ngoài tiêu chí.
