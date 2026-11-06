# Build và runtime Docker

Ngày 27/10/2026, Asia/Saigon. SHA **0a2282931500c8dbddd35495ad3b29aca19777cc**, main-2. Source gốc không sửa.

## Môi trường và bảo vệ tài nguyên cũ

Docker Desktop Linux Engine29.9.2, Desktop4.96.3, Compose5.6.1, Windows; Docker báo16CPU và khoảng7.15GiB RAM. Lần gọi đầu bị sandbox từ chối named pipe. Gọi lại với quyền cần thiết truy cập thành công: giới hạn quyền công cụ, không phải lỗi Engine/source.

Baseline có bốn container dự án spring-boot-blog-api-main ở trạng thái exited, hai network và hai volume liên quan. Không start/stop/remove container đó; không prune, reset Docker/WSL hoặc xóa volume cũ. Evidence: docker/baseline.json, environment-version.json và final-environment-check.json.

## Lab riêng

Project audit-m2-0a2282. Bản sao tại audit-results/lab/root. Override compose.audit.yml. Container audit-m2-0a2282-nginx/node1/node2/db. Network/volume có prefix project riêng; volume mới audit-m2-0a2282_postgres_data.

| Khác biệt | Gốc | Lab |
|---|---|---|
| HTTPS publish | 443:8443, không giới hạn host IP | 127.0.0.1:18443:8443 qua !override |
| Container names | Global nginx-waf/backend-node-1/backend-node-2/database | Tên riêng audit |
| Backend image tag | nhom9/blog-api:local | nhom9-audit-0a2282:local |
| File/config/log | Trong repo gốc | Bản sao source; secrets/cert/log trong lab/root |
| Invocation | Compose mặc định | Project và hai Compose file tường minh |

Không đổi Java, Dockerfile, SQL, nginx.conf, WAF rules, healthcheck, profile, subnet core hoặc IP trust. Core giữ10.209.10.0/24 sau kiểm tra tài nguyên Docker không xung đột.

Git Bash với Docker native Windows cần COMPOSE_FILE dùng dấu chấm phẩy. Lần thử dùng dấu hai chấm thất bại đã giữ trong compose-validation.json; chỉnh harness rồi validation đạt, không sửa source.

## Lệnh và kết quả

Từ bản sao, nạp audit-env.sh:

    sh scripts/init-env.sh
    sh nginx/certs/generate-cert.sh
    docker compose config -q
    docker compose build backend-node-1
    docker compose up -d --no-build --wait --wait-timeout 240
    sh tests/demo/run-all.sh

| Hạng mục | Kết quả | Evidence tương đối dưới evidence/ |
|---|---|---|
| Sinh secrets/cert riêng | exit0; SAN localhost/127.0.0.1 | docker/preparation.json |
| Compose lab | exit0, đúng4 service | docker/compose-validation-safe.json |
| Build hiện tại | exit0, compile/package thành công | build/source-build.json |
| Fresh startup | exit0,4 healthy, đủ init01–04 | docker/startup.json; database/database-init.json |
| Hai backend | Cùng digest image | docker/runtime-topology.json |
| Nginx syntax | nginx -t exit0 | waf/nginx-config-runtime.json |
| HTTPS có xác minh cert | 200 UP, upstream thật | http/certificate-health.json |
| WAF runtime | 100100/100200/942100/949110, audit tương ứng | waf/correlation.json |
| Core network | internal=true, backend/DB không publish | docker/internal-network.json |
| Backend egress | curl tới1.1.1.1 exit7 | docker/core-egress-denied.json |
| Failover/recovery | JWT cũ, cả hai node trở lại phục vụ | http/independent-Failover.json |
| DB dependency | Health trước/dừng/sau restart; gateway probe vẫn healthy khi DB mất | docker/dependency-recovery-decoded.json |

Build dùng lại cache Maven dependency layer và image PostgreSQL đã có, nhưng đã compile source hiện tại. Không dùng jar/image ứng dụng cũ thay kết quả. Image WAF được pull đúng digest. Chưa chứng nhận host mới không cache, build offline hoặc tái lập bit-for-bit do tag Maven/Temurin/Postgres mutable.

## Preflight và healthcheck

Preflight gốc trên lab trả12PASS,3WARN,3FAIL, exit1. Ba HTTP FAIL do hardcode https://localhost:443, bỏ qua BASE18443. Đây là sai khác harness công bố, không phải lỗi app18443. WARN tag nhom9/blog-api:local không có do tag riêng; WARN bài3 bị sửa là tác động thật của demo4.

Gateway healthcheck chỉ curl HTTP8080 lấy301, không dùng -f, không kiểm tra HTTPS8443/cert/WAF/upstream. Backend depends_on DB healthy; gateway depends_on backend nhưng không đặt condition healthy. Cần end-to-end health để chứng nhận startup. Không dùng gateway healthy làm bằng chứng toàn hệ thống khỏe.

## Kết thúc và giới hạn

Sau thu evidence, dừng các container lab, giữ volume/image để tái hiện. Xem docker/lab-stop.json và final-environment-check.json. Không chạy nguyên cấu hình gốc publish mọi interface vì yêu cầu không công khai vulnerable API ra LAN.

Kết luận: **source build và tích hợp chạy được trong lab override đã mô tả; nguyên cấu hình gốc chưa được runtime nghiệm thu**. Fresh volume trên host hiện tại đạt, không chứng nhận mọi máy/OS khác.

Snapshot runtime-topology.json được lấy trong demo1 lúc node1 đang dừng. Snapshot runtime-topology-final.json xác nhận cả bốn healthy ngay trước khi dừng lab. Lỗi tên hàm PowerShell trong lần đầu của dependency harness được giữ riêng; lần corrected mới là phép thử runtime hợp lệ.

