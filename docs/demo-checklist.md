# Checklist trình bày và xử lý sự cố (chế độ Local)

Lệnh dưới đây chạy trong **cmd** của Windows, từ thư mục repo:

```bat
cd /d "D:\BTL ALL MAJOR\BTL ATTT Claude\ATTT-Security-Project"
```

Lệnh `docker` chạy trực tiếp. Script `.sh` chạy qua Git Bash, viết tắt `BASH` trong tài liệu này:
`"C:\Program Files\Git\bin\bash.exe" <script>`. Có thể mở Git Bash rồi gõ `sh <script>` thay thế.

**Không bao giờ dùng** `docker compose down -v`, `scripts/reset-demo.sh --yes` hay `docker system prune` để chữa lỗi
demo: các lệnh này xóa volume DB prod hoặc image đã tải. Lab có lệnh reset riêng, không đụng prod.

## Hai môi trường

| | Prod | Lab |
|---|---|---|
| Địa chỉ | `https://localhost` (cổng `HTTPS_PORT`, mặc định 443) | `https://localhost:9443` (`LAB_HTTPS_PORT`) |
| Demo | 1 (failover), 5 (rate limit, audit) | 2, 3, 4; Demo 6 kiểm tra cô lập |
| WAF | Luôn **On**, không đổi được | On; chỉ Demo 3 tạm đổi sang DetectionOnly |
| Đăng nhập | Token chỉ dùng trên prod | Token chỉ dùng trên lab (JWT secret khác, dùng chéo sẽ trả `401`) |

Tài khoản giống nhau ở hai bên (xem README), nhưng **mỗi môi trường phải đăng nhập riêng** ở `/api/v1/auth/login` của
chính listener đó. Trong Burp/Postman, tạo hai environment riêng (base URL và token).

## Trước buổi trình bày (ở nhà, có Internet)

- [ ] `git status` sạch, `git rev-parse HEAD` đúng commit cần trình bày; không pull/đổi nhánh giữa buổi.
- [ ] `BASH scripts/init-env.sh`: tạo `logs/` và bổ sung khóa còn thiếu vào `.env` (không đổi giá trị cũ).
- [ ] `BASH nginx/certs/generate-cert.sh` nếu chưa có chứng chỉ.
- [ ] `docker compose up -d --build --wait`: kết quả là 4 container prod `Healthy`. Lần đầu cần Internet; đừng để tới
      lúc dùng mạng trường mới tải.
- [ ] `BASH scripts/lab.sh up`: `lab-db`, `lab-backend` `running/healthy`, listener lab `HTTP 200`.
- [ ] `BASH tests/demo/run-all.sh`: dòng cuối là `TẤT CẢ DEMO ĐẠT`.
- [ ] Nếu 443 bận, đặt `HTTPS_PORT` khác trong `.env`; không dừng project khác.

## Ngay trước khi trình bày (10 phút)

- [ ] `BASH scripts/lab.sh reset`: đưa dữ liệu lab về seed gốc (khoảng 20–30 giây), prod không bị đụng.
- [ ] `BASH scripts/preflight.sh`: không còn dòng `[FAIL]`. Dòng `[WARN]`/`[INFO]` thì đọc gợi ý ngay bên dưới.
- [ ] `BASH scripts/waf-mode.sh`: phải in `WAF prod: On` và `WAF lab: On`.
- [ ] Burp/Postman: thêm `nginx/certs/server.crt` làm chứng chỉ tin cậy, hoặc tắt kiểm tra SSL.

## Thứ tự demo và khôi phục sau từng demo

| # | Lệnh | Môi trường | Khôi phục sau demo |
|---|---|---|---|
| 1 | `BASH tests/demo/demo1-failover.sh` | prod | Script tự bật lại `backend-node-1`. Làm tay thì: `docker compose start backend-node-1` |
| 2 | `BASH tests/demo/demo2-waf-virtual-patch.sh` | lab | Không cần |
| 3 | `BASH tests/demo/demo3-defense-in-depth.sh` | lab | Script tự trả **lab** về On, kể cả khi bấm Ctrl+C. Prod luôn On. Nếu cửa sổ bị đóng hoặc tiến trình bị kill: `BASH scripts/waf-mode.sh lab On` |
| 4 | `BASH tests/demo/demo4-idor.sh` | lab | Demo sửa bài 3 của lab: `BASH scripts/lab.sh reset` trước khi chạy lại |
| 6 | `BASH tests/demo/demo6-isolation.sh` | cả hai | Không cần |
| 5 | `BASH tests/demo/demo5-ratelimit-audit.sh` | prod | Chờ khoảng **1 phút** trước khi đăng nhập prod lại |

Để Demo 5 (brute-force) **cuối cùng**: Burp, Postman, trình duyệt trên cùng máy dùng chung hạn mức đăng nhập
5 lần/phút mỗi IP, sau brute-force phải chờ khoảng 1 phút. Hạn mức của lab tách riêng (`lab_login`), nên brute-force
trên prod không chặn đăng nhập lab và ngược lại.

## Trong lúc trình bày

| Lưu ý | Vì sao |
|---|---|
| Đăng nhập lại ngay trước mỗi demo, trên đúng listener | Access token hết hạn sau **15 phút**; token lab dùng trên prod (hoặc ngược lại) trả `401` |
| `/api/v1/vuln/*` trên prod trả `404` | Đúng thiết kế: API cố ý lỗi chỉ có ở lab (`https://localhost:9443`) |
| Tìm kiếm có dấu ở `/api/v1/vuln/records/search` bị WAF chặn `403` | Cố ý: luật vá ảo 100100 chỉ cho chữ không dấu, số và `. , _ -` |
| Gõ tiếng Việt qua Postman/Burp/trình duyệt, không gõ thẳng trong `curl` trên terminal Windows | Terminal có thể gửi sai mã hóa; WAF trả `400 Failed to parse request body` |
| Log ghi giờ UTC | Giờ Việt Nam = giờ trong log + 7 |
| Chỉ thực nghiệm từ máy local | Mọi cổng chỉ bind `127.0.0.1`. Docker Desktop không giữ IP nguồn: log và rate limit gộp chung một IP |

## Sau khi trình bày: lấy minh chứng

Log nằm trong `logs/`: `nginx/access.log` (có `srv=8443` prod / `srv=9443` lab), `waf/modsec_audit.log`,
`backend-node-1/`, `backend-node-2/`, `lab-backend/`. Tra một request trên WAF: `BASH scripts/waf-audit.sh <X-Request-ID>`.

Dừng hệ thống mà **giữ dữ liệu**: `BASH scripts/lab.sh down` rồi `docker compose stop`.

## Xử lý sự cố (mọi bước chẩn đoán chỉ đọc)

| Triệu chứng | Nguyên nhân thường gặp | Cách xử lý |
|---|---|---|
| preflight: `WAF lab đang DetectionOnly ngoài Demo 3` | Demo 3 bị ngắt cứng (đóng cửa sổ, kill) | `BASH scripts/waf-mode.sh lab On` |
| `run-all` báo `lab-db/lab-backend chưa chạy` | Lab đang tắt | `BASH scripts/lab.sh up` (hoặc `BASH scripts/lab.sh reset`) |
| Listener lab trả `503` JSON | Lab đang tắt | `BASH scripts/lab.sh up` |
| preflight: bài 3 của lab đã bị sửa | Vừa chạy Demo 4 | `BASH scripts/lab.sh reset` |
| Đăng nhập trả `429` | Rate limit (5 lần/phút mỗi IP) | Chờ khoảng 1 phút rồi thử lại |
| Đăng nhập prod trả `401` | Sai mật khẩu, hoặc dùng token/tài khoản của môi trường khác | Xem dòng chẩn đoán của preflight (kiểm user seed trong DB prod, chỉ đọc); **không** xóa volume prod |
| Đăng nhập lab trả `401` | Dữ liệu lab bị sửa | `BASH scripts/lab.sh reset` |
| Mã `5xx` / `000` | Backend hoặc Nginx không phản hồi | `docker compose ps`, rồi `docker compose logs --tail 50 backend-node-1 backend-node-2 nginx-waf` |
| `docker compose up` báo `Đặt ... trong .env` | `.env` thiếu khóa | `BASH scripts/init-env.sh` (chỉ bổ sung khóa thiếu, giữ giá trị cũ) |
| `port is already allocated` (443 hoặc 9443) | Ứng dụng khác chiếm cổng | Đặt `HTTPS_PORT` / `LAB_HTTPS_PORT` khác trong `.env`; không dừng project khác |
| `Pool overlaps with other one on this address space` | Network khác trùng `10.209.10.0/24` hoặc `10.209.20.0/24` | `docker network ls` để xác định project đang chiếm; không tự xóa network của project khác |
| `Conflict. The container name ... is already in use` | Project khác dùng trùng tên container | Xác định project bằng `docker ps -a`; không xóa container của project khác |
| `http://localhost` không vào được | Cổng 80 không mở | Dùng `https://localhost` |
| `failed to connect to the docker API` | Docker Desktop chưa chạy | Mở Docker Desktop, chờ biểu tượng chuyển xanh |
