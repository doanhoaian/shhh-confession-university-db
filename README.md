# Shhh - Cơ sở dữ liệu cho nền tảng C.A.M.P.U.S

Dự án này chứa toàn bộ lược đồ (schema), các hàm (functions), và dữ liệu khởi tạo (seed data) cho cơ sở dữ liệu PostgreSQL của nền tảng **C.A.M.P.U.S**

## Tính năng chính

Hệ thống cơ sở dữ liệu được thiết kế để hỗ trợ các tính năng sau:

* **Quản lý Người dùng**:
    * Đăng ký và xác thực người dùng qua Email và Google.
    * Hệ thống định danh ẩn (alias) cho phép người dùng đăng bài mà không tiết lộ danh tính thật. Mỗi alias có một tên và avatar riêng.
    * Người dùng được liên kết với trường đại học của họ.

* **Hệ thống Bài đăng**:
    * Tạo, xem, sửa và xóa bài đăng.
    * Phân loại bài đăng theo các chủ đề (topics) như "Tâm sự", "Góc học tập", "Tình yêu", v.v..
    * Tùy chọn đính kèm hình ảnh vào bài đăng.
    * Kiểm soát quyền riêng tư: giới hạn quyền xem và bình luận cho từng bài viết (công khai, chỉ trong trường).

* **Tương tác & Cộng đồng**:
    * Hệ thống bình luận hai cấp (bình luận gốc và phản hồi).
    * Chức năng Thích/Không thích cho cả bài đăng và bình luận.
    * Hệ thống báo cáo (report) dành cho các nội dung không phù hợp. Nội dung sẽ tự động bị ẩn hoặc xóa khi đạt đến một ngưỡng báo cáo nhất định.

* **Quản trị & Kiểm duyệt**:
    * Các công cụ cho quản trị viên (moderator) để ẩn hoặc xóa bài đăng/bình luận vi phạm.
    * Ghi lại các hành động kiểm duyệt.
    * Hệ thống có các thiết lập toàn cục có thể được quản lý, ví dụ như bật/tắt tính năng hoặc chế độ bảo trì.

* **Bảng tin (Feed) thông minh**:
    * Một thuật toán phức tạp để sắp xếp bảng tin, ưu tiên các bài đăng mới, bài đăng từ các chủ đề "hot", và các bài đăng có nhiều tương tác (like, comment).

## Cấu trúc Thư mục

Dự án được tổ chức một cách rõ ràng để dễ dàng quản lý và triển khai:

* **`src/`**: Chứa toàn bộ mã nguồn SQL của cơ sở dữ liệu.
    * `1_enums.sql`: Định nghĩa các kiểu dữ liệu enum tùy chỉnh.
    * `2_tables.sql`: Lược đồ của tất cả các bảng trong cơ sở dữ liệu.
    * `3_constraints.sql`: Các ràng buộc (constraints) cho bảng.
    * `5_function/`: Chứa các hàm PostgreSQL cho logic nghiệp vụ (ví dụ: tạo người dùng, đăng bài, bình luận).
    * `6_triggers.sql`: Các trigger tự động thực thi các hành động dựa trên sự kiện của cơ sở dữ liệu.
    * `7_views.sql`: Các view để đơn giản hóa việc truy vấn và tạo báo cáo.
    * `8_data/`: Các tệp SQL để chèn dữ liệu ban đầu (dữ liệu mẫu) vào hệ thống, bao gồm danh sách trường học, chủ đề, alias, v.v..
* **`scripts/`**: Chứa các kịch bản (scripts) để tự động hóa.
    * `migrate.sh`: Kịch bản shell để chạy tất cả các tệp SQL theo đúng thứ tự và thiết lập một cơ sở dữ liệu hoàn chỉnh từ đầu.

## Cài đặt

Để thiết lập cơ sở dữ liệu trên máy cục bộ của bạn, hãy làm theo các bước sau:

1.  **Chuẩn bị**:
    * Cài đặt PostgreSQL.
    * Tạo một cơ sở dữ liệu mới (ví dụ: `shhh`).

2.  **Cấu hình**:
    * Mở tệp `scripts/migrate.sh` và chỉnh sửa các biến `DB_NAME`, `DB_USER`, `DB_HOST`, `DB_PORT` cho phù hợp với môi trường của bạn.

3.  **Chạy Migration**:
    * Cấp quyền thực thi cho kịch bản:
        ```bash
        chmod +x scripts/migrate.sh
        ```
    * Chạy kịch bản:
        ```bash
        ./scripts/migrate.sh
        ```
    * Kịch bản sẽ tự động thực thi các tệp SQL trong thư mục `src` theo đúng thứ tự để thiết lập cấu trúc và dữ liệu ban đầu.

4.  **Hoàn tất**:
    * Sau khi kịch bản chạy xong, bạn sẽ có một cơ sở dữ liệu "Shhh" đầy đủ và sẵn sàng để sử dụng.
