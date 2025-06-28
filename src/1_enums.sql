-- Schools
create type school_types as enum (
    'university', -- đại học
    'academy', -- học viện
    'college' -- cao đẳng
    );

-- Users
create type user_roles as enum (
    'admin',
    'moderator',
    'school_admin',
    'teacher',
    'student',
    'npc'
    );

create type user_status as enum (
    'active', -- đang hoạt động
    'pending', -- đang chờ duyệt
    'banned', -- bị khóa
    'deleted' -- bị xóa
    );

create type login_method as enum (
    'email',
    'google'
    );

create type banned_reason as enum (
    'system', -- khóa bởi hệ thống
    'mod', -- khóa bởi mod/admin
    'violation', -- khóa do vi phạm chính sách
    'other' -- lý do khác
    );

-- Posts
create type post_status as enum (
    'active', -- đang hoạt động
    'hidden', -- bị ẩn
    'deleted' -- bị xóa
    );

create type post_types as enum (
    'confession',
    'class_announcement',
    'class_document',
    'advertisement',
    'poll'
    );


create type permission_type as enum (
    'school_only',
    'all',
    'none'
    );

create type hidden_reason as enum (
    'report', -- ẩn do quá nhiều report
    'sensitive', -- ẩn do nội dung nhạy cảm (ml hoặc mod flag)
    'spam', -- ẩn do spam
    'ml_error', -- ẩn do lỗi học máy
    'other' -- lý do khác
    );

create type deleted_reason as enum (
    'user', -- xóa bởi người dùng
    'system', -- xóa tự động bởi hệ thống
    'mod', -- xóa bởi mod/admin
    'violation', -- xóa do vi phạm chính sách
    'other' -- lý do khác
    );

-- Topics
create type topic_category as enum (
    'social', -- Giao lưu, giải trí, tâm sự
    'academic', -- Học thuật, phát triển bản thân
    'utility', -- Tiện ích, đời sống hàng ngày
    'event' -- Sự kiện, thông báo
    );
