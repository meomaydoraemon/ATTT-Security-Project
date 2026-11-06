# Phạm vi sản phẩm và kiến trúc thực tế

Kiểm toán ngày 27/10/2026, Asia/Saigon. Nhánh main-2, SHA **0a2282931500c8dbddd35495ad3b29aca19777cc**. Mọi kết quả runtime áp dụng cho bản sao nguyên source với Compose override cô lập. Không sửa source gốc.

## Phiên bản và nguồn sự thật

Workspace: D:\BTL ATTT\audit-main-2. Working tree ban đầu sạch. SHA khớp git ls-remote origin refs/heads/main-2 khi bắt đầu và lần xác minh tiếp theo. Không checkout, pull, commit, push hay merge. Source kiểm thử được lấy bằng git archive HEAD.

README, docs/decisions.md và contract tích hợp hiện hành xác định phạm vi. Không áp phân công hay kế hoạch cũ làm điều kiện nghiệm thu. Các kết quả lịch sử trong tài liệu backend không được tính thành PASS hiện tại.

## Thành phần và luồng dữ liệu

    Client lab -> HTTPS127.0.0.1:18443 -> Nginx + ModSecurity + CRS
                                      -> Spring node1 / node2
                                         -> PostgreSQL: blogdb (nghiệp vụ)
                                         -> PostgreSQL: sqli_lab (fixture SQLi)

Bốn container và hai network. Hai backend cùng image, key JWT và blogdb. Chỉ gateway nối cả edge và core internal. PostgreSQL chứa hai database trong cùng container. Gateway, database và host đều là điểm lỗi đơn.

| Lớp | Chức năng thực tế | Điều kiện |
|---|---|---|
| Gateway | TLS, round-robin, passive failover, retry, rate limit, overwrite XFF và request ID | Cert/log writable, resolver Docker, upstream |
| WAF | ModSecurity, CRS PL1/ngưỡng5, JSON inspection, custom100100/100200, audit JSON | Engine On, mount đúng; custom rule có lỗi với query string |
| Spring | Register/login/refresh/logout, BCrypt/JWT, RBAC, ownership và CRUD | DB hoạt động, key Base64 >=32 byte, schema validate |
| SQLi lab | Cố ý nối chuỗi SELECT trên fixture riêng, reader giới hạn, timeout/row cap, cấm stacked statements | Profile sqli-lab + flag true, isolation checks đạt |
| Database | Schema admin-owned, app_user DML theo bảng, SQLi reader chỉ SELECT fixture | Volume mới chạy đủ01–04; không có migration volume cũ |
| Demo/audit | Log gateway/WAF/hai backend; bốn demo chính, demo5 bổ sung; Postman/Burp | Log có dữ liệu và đọc được; assertion có điểm yếu đã tái hiện |

## Phạm vi API

- Auth: POST register/login/refresh/logout dưới /api/v1/auth. Access15 phút, refresh7 ngày. Logout thu hồi refresh; access còn hạn vẫn dùng được.
- Post: list/detail ID/slug/search/category/author/me và create/update/delete. Public read chỉ PUBLISHED; owner/admin đọc riêng tư. /secure/posts/{id} dùng chung PostService cho GET/PUT/DELETE.
- Comment: list theo Post, detail, create/reply, update, soft-delete. Read/create kiểm tra visibility Post; update/delete theo owner/MODERATOR/ADMIN. Độ sâu tối đa5.
- Category: public read, ADMIN create/update/delete.
- Secure Record: create, detail owner-only, search bind tham số/lọc owner/giới hạn50. Không có update/delete được hứa cho Record.
- Vulnerable Record: POST search cùng token nhưng datasource sqli_lab riêng. Đây là đối chứng SQLi trên dữ liệu giả.
- Vulnerable Post: anonymous GET đọc nháp và email, user bất kỳ PUT/DELETE. **Dùng PostRepository của blogdb**, không phải fixture SQLi. Đã xác minh bằng Post ID động: B sửa/xóa bài A, sau đó A thấy đổi/mất qua đường secure.
- Health public; Swagger/OpenAPI và actuator khác health bị gateway trả404. Không có frontend thuộc phạm vi README.

## Các quyết định kiến trúc và giới hạn

Dùng chung JWT/identity trên hai node và SQLi fixture ở database riêng cùng PostgreSQL phù hợp mục tiêu hiện tại; không coi khác kế hoạch cũ là lỗi. Tuy nhiên không thể nói mọi /vuln đã cách ly khỏi bảng nghiệp vụ. WAF không kiểm tra ownership, nên đường secure đúng không bảo vệ cùng tài nguyên khi đường vuln vẫn mở.

Hai backend chứng minh chịu lỗi một node ở tầng API, không chứng minh HA toàn hệ thống, chịu lỗi database/gateway/host hoặc mọi write request không mất. JWT stateless về session nhưng filter vẫn truy vấn DB lấy user/quyền trên mỗi request.

Danh mục chức năng, nguồn, điều kiện, phép thử và giới hạn ở 02_FEATURE_VERIFICATION.md. Tài liệu backend lịch sử đã có ghi chú chuyển kiến trúc nhưng còn nhiều đoạn nói identity/JWT riêng và WAF NOT RUN; cần làm rõ để người trình bày không sử dụng nhầm.
