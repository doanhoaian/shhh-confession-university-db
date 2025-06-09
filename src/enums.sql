-- Schools
create type school_types as enum (
    'university', -- đại học
    'academy', -- học viện
    'college' -- cao đẳng
    );

-- Users
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

-- Confessions
create type confession_status as enum (
    'active', -- đang hoạt động
    'hidden', -- bị ẩn
    'deleted' -- bị xóa
    );

CREATE TYPE hidden_reason AS ENUM (
    'report', -- ẩn do quá nhiều report
    'sensitive', -- ẩn do nội dung nhạy cảm (ML hoặc mod flag)
    'spam', -- ẩn do spam
    'other' -- lý do khác
    );

CREATE TYPE deleted_reason AS ENUM (
    'user', -- xóa bởi người dùng
    'system', -- xóa tự động bởi hệ thống
    'mod', -- xóa bởi mod/admin
    'violation', -- xóa do vi phạm chính sách
    'other' -- lý do khác
    );
