# Bàn giao và điều kiện trình bày

Ngày27/10/2026, Asia/Saigon. Branch codex/main-2-audit; base **0a2282931500c8dbddd35495ad3b29aca19777cc**. Trạng thái: **CONDITIONAL GO** cho chuyển sang nghiệm thu/trình bày trên máy khác; các P0/P1 xác nhận đã được xử lý và kiểm chứng trên host hiện tại.

## Còn tồn tại và phạm vi được chấp nhận

Không còn lỗi P0/P1 đã được tái hiện mà chưa sửa trong phạm vi vòng này. Các giới hạn sau được giữ có chủ đích:

- Vulnerable API vẫn là lỗ hổng khi bật lab; chỉ dữ liệu giả, chỉ loopback. Không kết nối dữ liệu nghiệp vụ thật.
- Rule100100 vẫn whitelist ASCII hạn chế cho fixture lab; Unicode/apostrophe ở route vuln bị chặn là chính sách đã khai báo. Secure search chấp nhận chuỗi bình thường có Unicode/apostrophe.
- Hai backend không là HA database/gateway/host. Gateway health là process liveness, preflight mới kiểm đường HTTPS/WAF/backend.
- Reader không CONNECT blogdb, nhưng còn grantPUBLIC trên postgres/template. Đã sửa lời giải thích; không đổi ACL nghiệp vụ để thỏa một tuyên bố quá rộng.
- Demo4 gốc vẫn dùng seed Post3 và sửa title. Các phép thử độc lập dùng ID động. Preflight sau demo có thể WARN seed đã thay đổi; đây là tác động được biết, không tự reset/xóa dữ liệu.
- Root Compose có tên container/subnet cố định; máy có project trùng phải dùng override riêng. Không xóa container/network của người khác.
- Chưa thực thi trên máy trình bày khác/OS khác; chưa chạy nguyên Postman GUI/Newman, mọi cipher hay exhaustive concurrency.

## Nguy cơ regression cần chú ý

| Thay đổi | Nguy cơ | Evidence đã giảm rủi ro |
|---|---|---|
| Flag vuln mặc định false | Quên bật lab khiến demo route404 | Init --lab và preflight chỉ rõ trạng thái; default-off/explicit-on đều đã chạy |
| Slug bounded | URL thay ngoài ý muốn hoặc trùng sau truncate | Test short slug, same-title update, duplicate200–255 và flush DB; URL cũ giữ khi title không đổi |
| Username pattern backend | Chặn username ngoài policy | Policy đồng bộ WAF hiện tại; không đổi DTO login để phá các account/negative audit tests cũ |
| Fail-fast shell | Script dừng sớm khi thiếu evidence |10negative controls và full demo56PASS; trap phục hồi node/WAF khi lỗi |
| REQUEST_FILENAME | Scope encoded path khác backend | Ma trận URL thường/query/encoded path; rule ID và backend correlation cả hai mode |
| BASE/port tự đọc | Gọi nhầm project/port | Preflight19443 không cần BASE; timeout; chỉ chấp nhận URL loopback |

## Chạy lại trên host hiện tại

Lab đã được dừng và giữ dữ liệu/evidence. Nếu muốn dùng lại đúng bản sao đã kiểm thử, mở Git Bash tại:

    D:\BTL ATTT\audit-main-2\audit-results\fix-round-1\lab\root

Chạy:

    . ./audit-env.sh
    docker compose up -d --no-build --wait
    sh scripts/preflight.sh
    sh tests/demo/run-all.sh

HTTPS tại localhost19443. .env/cert của lab không đưa vào Git hoặc chia sẻ công khai. Không cần xóa volume cũ. Chạy demo có thể sửa dữ liệu fake và làm preflight cảnh báo seed.

## Tái hiện từ source trên máy sạch

Nhận đúng working tree/nhánh đã sửa sau khi người dùng review; remote main-2 chưa có các sửa đổi này vì không push/merge. Không clone base rồi tuyên bố đang chạy bản sửa.

Trong Git Bash, từ repository riêng, với Docker Desktop/Engine và Internet/cache cần thiết:

    git status --short
    git branch --show-current
    git rev-parse HEAD
    sh scripts/init-env.sh --lab
    sh nginx/certs/generate-cert.sh
    docker compose up -d --build --wait
    sh scripts/preflight.sh
    sh tests/demo/run-all.sh

Không dùng .env/database thật cũ. Nếu443 bận, đặt HTTPS_PORT riêng trong .env. Nếu subnet/container name trùng project khác, dùng Compose override đồng bộ subnet, IP gateway và TRUSTED_PROXY_REGEX như lab vòng này; không dọn Docker chung. README và docs/demo-checklist đã cập nhật các giới hạn này.

Chạy regression Java cơ bản bằng builder Docker rồi script hiện có:

    docker build --target builder -t nhom9-backend-tests ./backend
    pwsh -NoProfile -File backend/scripts/Test-BackendTests.ps1 -Image nhom9-backend-tests

Lệnh Maven cơ bản có thể skip năm test PostgreSQL nếu không opt-in; phải ghi đúng số skip. Phiên nghiệm thu này đã truyền reader credentials theo tên env và chạy170test cùng PostgreSQL thật,0skip. Evidence lệnh ở build/full-maven-postgres.json. Không in .env, JWT hoặc resolved Compose environment khi tái hiện.

## Những yêu cầu chưa nghiệm thu trên môi trường khác

Một lần diễn tập trên đúng máy trình bày vẫn cần thực hiện nếu thay host. Kiểm tra Docker build, port, bind permission, cert trust, preflight, cả năm demo và log correlation. Chỉ sau lần đó mới đổi trạng thái của host ấy từ UNVERIFIED thành VERIFIED PASS. Không cần thêm frontend, container hoặc tính năng production để đáp ứng điều kiện này.

## Dữ liệu bàn giao

- SOURCE_FILES_CHANGED.txt: chính xác các file source/docs/test đã sửa hoặc thêm.
- evidence/source-snapshot.json: SHA256 toàn bộ162source file và đối chiếu bản sao lab.
- evidence/: command, exit code, HTTP case/response đã loại token, Docker state và log đã rà soát.
- evidence/final-git-status.json và evidence/docker/final-environment-check.json: trạng thái Git và lần đối chiếu Docker thành công cuối; evidence/docker/handover-environment-check.json ghi lần đọc bổ sung khi Engine không khả dụng.
- FILE_MANIFEST.tsv: toàn bộ file mới của riêng fix-round-1; phân biệt báo cáo/evidence/helper/source copy và cấu hình riêng tư.

Không ghi đè hoặc xóa tám báo cáo/evidence cũ của vòng kiểm toán. Không reset/clean/prune hay xóa volume. Người dùng có thể review diff trước khi quyết định commit hoặc đưa thay đổi lên remote.

Đọc 04_FINAL_STATUS.md trước khi bàn giao: chỉ chia sẻ báo cáo, danh sách, manifest và evidence đã rà soát. Toàn bộ lab/ chứa secrets/private key/log gốc và các helper *.ps1 là nội bộ. Không phát hành nguyên thư mục fix-round-1. Docker Engine hiện không truy cập được cho lần đọc bổ sung; các kiểm thử runtime được tái sử dụng từ artifacts hợp lệ, không chạy lại toàn bộ.
