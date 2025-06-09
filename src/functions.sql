-- ====== TRIGGER ====== --

-- Cập nhật updated_at
create or replace function update_updated_at_column()
    returns trigger as
$$
begin
    NEW.updated_at = now(); -- Cập nhật updated_at khi có thay đổi
    return NEW;
end;
$$ language plpgsql;

create or replace function combined_user_trigger()
    returns trigger as
$$
declare
    next_index integer;
begin
    -- cập nhật thời gian
    new.updated_at := now();
    if new.alias_id is distinct from old.alias_id then
        new.updated_alias_at := now();
    end if;

    -- gán alias_index
    if (tg_op = 'insert') or (new.alias_id is distinct from old.alias_id) then
        if new.alias_id is not null then
            select next_user_index
            into next_index
            from aliases
            where id = new.alias_id
                for update;

            new.alias_index := next_index;

            update aliases
            set next_user_index = next_user_index + 1
            where id = new.alias_id;
        else
            new.alias_index := null;
        end if;
    end if;

    -- kích hoạt user
    if new.alias_id is not null
        and new.school_id is not null
        and new.status = 'pending'::user_status then
        new.status := 'active'::user_status;
    end if;

    return new;
end;
$$ language plpgsql;

create trigger combined_user_trigger
    before insert or update
    on users
    for each row
execute function combined_user_trigger();

-- Ẩn confession bị report nhiều cho bảng confessions
create or replace function check_confession_report()
    returns trigger as
$$
declare
    report_count     int;
    report_threshold int;
begin
    select count(*) into report_count from confession_reports where confession_id = NEW.confession_id;

    select value::int
    into report_threshold
    from system_settings
    where key = 'max_reports_to_hide_confession';

    if report_count >= report_threshold then
        update confessions
        set status        = 'hidden',
            hidden_reason = 'report'
        where id = NEW.confession_id
          and status = 'active';
    end if;

    return null;
end;
$$ language plpgsql;

-- Xóa comment bị report nhiều cho bảng comments
create or replace function check_comment_report()
    returns trigger as
$$
declare
    report_count     int;
    report_threshold int; -- ngưỡng report
begin
    select count(*) into report_count from comment_reports where comment_id = NEW.comment_id;

    select value::int
    into report_threshold
    from system_settings
    where key = 'max_reports_to_delete_comment';

    if report_count >= report_threshold then
        delete from comments where id = NEW.comment_id;
    end if;

    return null;
end;
$$ language plpgsql;


-- ====== Xác thực đăng nhập/đăng ký ====== --

create or replace function get_user_auth(p_id varchar)
    returns table
            (
                user_id           varchar,
                email             varchar,
                login_method      login_method,
                alias_id          uuid,
                display_name      varchar,
                avatar_url        text,
                school_id         int,
                school_name       varchar,
                school_short_name varchar,
                status            user_status,
                banned_reason     banned_reason,
                deleted_reason    deleted_reason,
                updated_alias_at  timestamp,
                created_at        timestamp,
                updated_at        timestamp,
                deleted_at        timestamp
            )
    language sql
as
$$
select u.id                                    as user_id,
       u.email,
       u.login_method,
       u.alias_id,
       a.display_name,
       concat(i.base_url, i.id, '.', i.format) as avatar_url,
       u.school_id,
       s.name                                  as school_name,
       s.short_name                            as school_short_name,
       u.status,
       u.banned_reason,
       u.deleted_reason,
       u.updated_alias_at,
       u.created_at,
       u.updated_at,
       u.deleted_at
from users u
         left join aliases a on u.alias_id = a.id
         left join images i on a.icon_image_id = i.id
         left join schools s on u.school_id = s.id
where u.id = p_id;
$$;

-------------------------
create or replace function create_user_and_return(
    p_id varchar,
    p_email varchar,
    p_password_hash varchar,
    p_login_method login_method,
    p_status user_status default 'pending'
)
    returns table
            (
                user_id           varchar,
                email             varchar,
                login_method      login_method,
                alias_id          uuid,
                display_name      varchar,
                avatar_url        text,
                school_id         int,
                school_name       varchar,
                school_short_name varchar,
                status            user_status,
                banned_reason     banned_reason,
                deleted_reason    deleted_reason,
                updated_alias_at  timestamp,
                created_at        timestamp,
                updated_at        timestamp,
                deleted_at        timestamp
            )
    language plpgsql
as
$$
declare
    v_user_row users;
begin
    insert into users (id,
                       email,
                       password_hash,
                       login_method,
                       status,
                       created_at,
                       updated_at)
    values (p_id,
            p_email,
            p_password_hash,
            p_login_method,
            p_status,
            now(),
            now())
    returning * into v_user_row;

    return query select v_user_row.id,
                        v_user_row.email,
                        v_user_row.login_method,
                        v_user_row.alias_id,
                        null::varchar as display_name,
                        null::text    as avatar_url,
                        v_user_row.school_id,
                        null::varchar as school_name,
                        null::varchar as school_short_name,
                        v_user_row.status,
                        v_user_row.banned_reason,
                        v_user_row.deleted_reason,
                        v_user_row.updated_alias_at,
                        v_user_row.created_at,
                        v_user_row.updated_at,
                        v_user_row.deleted_at;

end;
$$;

-------------------------
create or replace function find_or_create_user_and_return(
    p_id varchar,
    p_email varchar,
    p_password_hash varchar,
    p_login_method login_method,
    p_status user_status default 'pending'
)
    returns table
            (
                user_id           varchar,
                email             varchar,
                login_method      login_method,
                alias_id          uuid,
                alias_index       int,
                display_name      varchar,
                avatar_url        text,
                school_id         int,
                school_name       varchar,
                school_short_name varchar,
                school_logo_url   text,
                status            user_status,
                banned_reason     banned_reason,
                deleted_reason    deleted_reason,
                updated_alias_at  timestamp,
                created_at        timestamp,
                updated_at        timestamp,
                deleted_at        timestamp
            )
    language plpgsql
as
$$
declare
    v_user_id varchar(128);
begin
    select id
    into v_user_id
    from users
    where users.email = p_email;

    if v_user_id is not null then
        null;
    else
        insert into users (id,
                           email,
                           password_hash,
                           login_method,
                           status,
                           created_at,
                           updated_at)
        values (p_id,
                p_email,
                p_password_hash,
                p_login_method,
                p_status,
                now(),
                now())
        returning id into v_user_id;
    end if;

    return query
        select u.id                                       as user_id,
               u.email,
               u.login_method,
               u.alias_id,
               u.alias_index,
               a.display_name,
               concat(i1.base_url, i1.id, '.', i1.format) as avatar_url,
               u.school_id,
               s.name                                     as school_name,
               s.short_name                               as school_short_name,
               concat(i2.base_url, i2.id, '.', i2.format) as school_logo_url,
               u.status,
               u.banned_reason,
               u.deleted_reason,
               u.updated_alias_at,
               u.created_at,
               u.updated_at,
               u.deleted_at
        from users u
                 left join aliases a on u.alias_id = a.id
                 left join images i1 on a.icon_image_id = i1.id
                 left join schools s on u.school_id = s.id
                 left join images i2 on s.logo_image_id = i2.id
        where u.id = v_user_id;
end;
$$;


create or replace function update_user_password(
    p_email varchar,
    p_password_hash varchar
)
    returns boolean
    language plpgsql
as
$$
declare
    v_user_exists boolean;
begin
    select exists(select 1
                  from users
                  where email = p_email
                    and deleted_at is null
                    and status != 'banned')
    into v_user_exists;

    if not v_user_exists then
        return false;
    end if;

    update users
    set password_hash = p_password_hash
    where email = p_email;

    return true;
end;
$$;

select *
from user_logins;


create or replace function update_user_alias(
    p_user_id varchar,
    p_alias_id uuid
)
    returns integer
    language plpgsql
as
$$
declare
    v_user_exists boolean;
    v_alias_index integer;
begin
    -- kiểm tra xem user có tồn tại và hợp lệ không
    select exists (select 1
                   from users
                   where id = p_user_id
                     and deleted_at is null
                     and status != 'banned')
    into v_user_exists;

    if not v_user_exists then
        return null; -- trả về null nếu user không hợp lệ
    end if;

    -- kiểm tra xem alias_id có tồn tại không
    if not exists (select 1
                   from aliases
                   where id = p_alias_id) then
        return null; -- trả về null nếu alias_id không tồn tại
    end if;

    -- cập nhật alias_id cho user
    update users
    set alias_id = p_alias_id
    where id = p_user_id;

    -- lấy alias_index sau khi cập nhật
    select alias_index
    into v_alias_index
    from users
    where id = p_user_id;

    return v_alias_index; -- trả về alias_index
end;
$$;

-- Function to update a user's school_id
create or replace function update_user_school(
    p_user_id varchar,
    p_school_id int
)
    returns boolean
    language plpgsql
as
$$
declare
    v_user_exists boolean;
begin
    select exists(select 1
                  from users
                  where id = p_user_id
                    and deleted_at is null
                    and status != 'banned')
    into v_user_exists;

    if not v_user_exists then
        return false;
    end if;

    -- Check if school_id exists
    if not exists(select 1 from schools where id = p_school_id) then
        return false;
    end if;

    update users
    set school_id = p_school_id
    where id = p_user_id;

    return true;
end;
$$;


-- ====== USER ====== --


-- Ghi lại lịch sử đăng nhập của người dùng
create or replace function record_user_login(
    p_user_id varchar,
    p_ip_address inet,
    p_user_agent text,
    p_device_info jsonb,
    p_platform varchar
)
    returns void
    language plpgsql
as
$$
begin
    insert into user_logins (user_id, ip_address, user_agent, device_info, platform, logged_in_at)
    values (p_user_id, p_ip_address, p_user_agent, p_device_info, p_platform, now());
end;
$$;

-- Đăng ký FCM token cho người dùng (không ghi đè, cho phép nhiều thiết bị)
-- Hàm này sẽ cập nhật last_used_at nếu token đã tồn tại cho user, ngược lại sẽ thêm mới.
CREATE OR REPLACE FUNCTION register_fcm_token(
    p_user_id VARCHAR(128),
    p_fcm_token TEXT,
    p_device_id VARCHAR(255),
    p_platform VARCHAR(50)
)
    RETURNS VOID
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_existing_fcm_id BIGINT;
BEGIN
    -- Kiểm tra xem user_id và fcm_token này đã tồn tại chưa
    SELECT id
    INTO v_existing_fcm_id
    FROM user_fcms
    WHERE user_id = p_user_id
      AND fcm_token = p_fcm_token
    LIMIT 1;

    IF v_existing_fcm_id IS NOT NULL THEN
        -- Nếu đã tồn tại, cập nhật last_used_at và có thể cả device_id, platform nếu chúng thay đổi cho token đó
        UPDATE user_fcms
        SET last_used_at = NOW(),
            device_id    = COALESCE(p_device_id, user_fcms.device_id), -- Cập nhật nếu device_id mới được cung cấp
            platform     = COALESCE(p_platform, user_fcms.platform)    -- Cập nhật nếu platform mới được cung cấp
        WHERE id = v_existing_fcm_id;
    ELSE
        -- Nếu chưa tồn tại, thêm bản ghi mới
        INSERT INTO user_fcms (user_id, fcm_token, device_id, platform, created_at, last_used_at)
        VALUES (p_user_id, p_fcm_token, p_device_id, p_platform, NOW(), NOW());
    END IF;
END;
$$;
-- Lưu ý: Để tối ưu và tránh race condition cho hàm register_fcm_token,
-- bạn nên cân nhắc thêm một UNIQUE constraint vào bảng user_fcms:
-- ALTER TABLE user_fcms ADD CONSTRAINT unique_user_fcm_token UNIQUE (user_id, fcm_token);
-- Khi đó, bạn có thể dùng INSERT ... ON CONFLICT ... DO UPDATE mạnh mẽ hơn.

-- Cấm (ban) và bỏ cấm (unban) người dùng
CREATE OR REPLACE FUNCTION ban_user(
    p_user_id VARCHAR(128),
    p_reason banned_reason
)
    RETURNS BOOLEAN
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_user_exists BOOLEAN;
BEGIN
    SELECT EXISTS (SELECT 1 FROM users WHERE id = p_user_id AND deleted_at IS NULL) INTO v_user_exists;

    IF NOT v_user_exists THEN
        RETURN FALSE; -- Người dùng không tồn tại hoặc đã bị xóa mềm
    END IF;

    UPDATE users
    SET status        = 'banned',
        banned_reason = p_reason
    WHERE id = p_user_id;
    RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION unban_user(
    p_user_id VARCHAR(128)
)
    RETURNS BOOLEAN
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_user_exists BOOLEAN;
BEGIN
    SELECT EXISTS (SELECT 1 FROM users WHERE id = p_user_id AND deleted_at IS NULL) INTO v_user_exists;

    IF NOT v_user_exists THEN
        RETURN FALSE;
    END IF;

    UPDATE users
    SET status        = 'active',
        banned_reason = NULL
    WHERE id = p_user_id
      AND status = 'banned';
    RETURN FOUND;
END;
$$;

-- Xóa mềm người dùng (soft delete)
CREATE OR REPLACE FUNCTION soft_delete_user(
    p_user_id VARCHAR(128),
    p_reason deleted_reason
)
    RETURNS BOOLEAN
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_user_exists BOOLEAN;
BEGIN
    SELECT EXISTS (SELECT 1 FROM users WHERE id = p_user_id AND deleted_at IS NULL) INTO v_user_exists;

    IF NOT v_user_exists THEN
        RETURN FALSE;
    END IF;

    UPDATE users
    SET status         = 'deleted',
        deleted_reason = p_reason,
        deleted_at     = NOW()
    -- Cân nhắc: Vô hiệu hóa email/username để cho phép đăng ký lại, ví dụ:
    -- email = email || '_deleted_' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISSMS'),
    -- user_name = user_name || '_deleted_' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISSMS')
    -- Điều này cần thiết nếu bạn có UNIQUE constraints trên email/user_name
    -- và muốn cho phép người dùng mới đăng ký lại với email/username đó.
    -- Tuy nhiên, việc này làm thay đổi dữ liệu gốc.
    -- Một cách khác là xử lý logic này ở tầng ứng dụng hoặc điều chỉnh UNIQUE constraint.
    -- Hiện tại, hàm này chỉ đánh dấu xóa.
    WHERE id = p_user_id;
    RETURN FOUND;
END;
$$;

-- Cập nhật mật khẩu người dùng
-- (trả về false nếu mật khẩu mới trùng mật khẩu cũ hoặc user không tồn tại)
CREATE OR REPLACE FUNCTION update_user_password(
    p_user_id VARCHAR(128),
    p_new_password_hash VARCHAR(255)
)
    RETURNS BOOLEAN
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_current_password_hash VARCHAR(255);
    v_user_exists           BOOLEAN;
BEGIN
    SELECT password_hash, TRUE
    INTO v_current_password_hash, v_user_exists
    FROM users
    WHERE id = p_user_id
      AND deleted_at IS NULL
      AND status != 'banned'; -- Chỉ cho phép user active đổi mật khẩu

    IF NOT v_user_exists THEN
        RETURN FALSE; -- Người dùng không tồn tại, đã bị xóa hoặc bị cấm
    END IF;

    IF v_current_password_hash IS NOT NULL AND v_current_password_hash = p_new_password_hash THEN
        RETURN FALSE; -- Mật khẩu mới trùng với mật khẩu cũ
    END IF;

    UPDATE users
    SET password_hash = p_new_password_hash
    WHERE id = p_user_id;
    RETURN TRUE;
END;
$$;


-- ================

create or replace function create_confession(
    p_user_id varchar(128),
    p_school_id int,
    p_content text,
    p_topic_ids bigint[] default '{}',
    p_topic_scores numeric[] default '{}',
    p_image_ids varchar(128)[] default '{}',
    p_status confession_status default 'active',
    p_hidden_reason hidden_reason default null
)
    returns table
            (
                confession_id varchar(12),
                status        confession_status,
                hidden_reason hidden_reason,
                created_at    timestamp
            )
    language plpgsql
as
$$
declare
    v_confession_id varchar(12);
    v_topic_count   int;
begin
    if not exists (select 1
                   from users u
                   where u.id = p_user_id
                     and u.deleted_at is null
                     and u.status = 'active') then
        raise exception 'user is not valid or active';
    end if;

    if not exists (select 1
                   from schools s
                   where s.id = p_school_id) then
        raise exception 'school does not exist';
    end if;

    v_topic_count := array_length(p_topic_ids, 1);

    if v_topic_count is null or v_topic_count = 0 then
        raise exception 'no topic ids provided';
    end if;

    if array_length(p_topic_scores, 1) is distinct from v_topic_count then
        raise exception 'topic ids and scores length mismatch';
    end if;

    v_confession_id := substring(gen_random_uuid()::text from 1 for 12);

    insert into confessions (id, user_id, school_id, status, content, hidden_reason, created_at, updated_at)
    values (v_confession_id, p_user_id, p_school_id, p_status, p_content, p_hidden_reason, now(), now());

    if array_length(p_topic_ids, 1) > 0 then
        insert into confession_topics (confession_id, topic_id, score, created_at)
        select v_confession_id, topic_id, score, now()
        from unnest(p_topic_ids, p_topic_scores) as t(topic_id, score);
    end if;

    if array_length(p_image_ids, 1) > 0 then
        insert into confession_images (confession_id, image_id, created_at)
        select v_confession_id, unnest(p_image_ids), now();
    end if;

    return query
        select c.id, c.status, c.hidden_reason, c.created_at
        from confessions c
        where c.id = v_confession_id;
end;
$$;


select *
from confessions;