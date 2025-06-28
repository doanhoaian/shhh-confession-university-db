-- ============================================
-- USER MANAGEMENT SYSTEM
-- ============================================

-- ============================================
-- CREATE & AUTHENTICATION
-- ============================================

/**
 * @name create_user_and_return
 * @description Tạo một người dùng mới và trả về thông tin chi tiết.
 * @param {varchar} p_id - ID người dùng.
 * @param {varchar} p_email - Email người dùng.
 * @param {varchar} p_password_hash - Mật khẩu đã hash.
 * @param {login_method} p_login_method - Phương thức đăng nhập.
 * @param {user_status} [p_status] - Trạng thái người dùng, mặc định là 'pending'.
 * @returns {table} Thông tin chi tiết người dùng.
 */
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
                school_id         integer,
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
as
$$
declare
    v_user_row users;
begin
    insert into users (id, email, password_hash, login_method, status, created_at, updated_at)
    values (p_id, p_email, p_password_hash, p_login_method, p_status, now(), now())
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
$$ language plpgsql;


/**
 * @name find_or_create_user_and_return
 * @description Tìm hoặc tạo người dùng dựa trên email.
 * @param {varchar} p_id
 * @param {varchar} p_email
 * @param {varchar} p_password_hash
 * @param {login_method} p_login_method
 * @param {user_status} [p_status]
 * @returns {table} Thông tin người dùng chi tiết.
 */
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
                alias_index       integer,
                display_name      varchar,
                avatar_url        text,
                school_id         integer,
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
as
$$
declare
    v_user_id varchar(128);
begin
    select id into v_user_id from users where users.email = p_email;

    if v_user_id is null then
        insert into users (id, email, password_hash, login_method, status, created_at, updated_at)
        values (p_id, p_email, p_password_hash, p_login_method, p_status, now(), now())
        returning id into v_user_id;
    end if;

    return query select u.id                                       as user_id,
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
$$ language plpgsql;


/**
 * @name get_user_auth
 * @description Trả về thông tin xác thực từ user_id.
 * @param {varchar} p_id
 * @returns {table} Chi tiết xác thực người dùng.
 */
create or replace function get_user_auth(p_id varchar)
    returns table
            (
                user_id           varchar,
                email             varchar,
                login_method      login_method,
                alias_id          uuid,
                display_name      varchar,
                avatar_url        text,
                school_id         integer,
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
$$ language sql;


-- ============================================
-- UPDATES & PROFILE SETTINGS
-- ============================================

/**
 * @name update_user_password
 * @description Cập nhật mật khẩu người dùng nếu hợp lệ.
 * @param {varchar} p_email
 * @param {varchar} p_password_hash
 * @returns {boolean} Thành công hoặc thất bại.
 */
create or replace function update_user_password(
    p_email varchar,
    p_password_hash varchar
) returns boolean as
$$
declare
    v_current_password_hash varchar;
    v_user_exists           boolean;
begin
    select password_hash, true
    into v_current_password_hash, v_user_exists
    from users
    where email = p_email
      and deleted_at is null
      and status != 'banned';

    if not v_user_exists or (v_current_password_hash is not null and v_current_password_hash = p_password_hash) then
        return false;
    end if;

    update users set password_hash = p_password_hash where email = p_email;
    return true;
end;
$$ language plpgsql;


/**
 * @name update_user_alias
 * @description Gán alias cho user và cập nhật alias_index.
 * @param {varchar} p_user_id
 * @param {uuid} p_alias_id
 * @returns {integer} alias_index
 */
create or replace function update_user_alias(
    p_user_id varchar,
    p_alias_id uuid
) returns integer as
$$
declare
    v_user_exists boolean;
    v_alias_index integer;
begin
    select exists (select 1 from users where id = p_user_id and deleted_at is null and status != 'banned')
    into v_user_exists;

    if not v_user_exists or not exists (select 1 from aliases where id = p_alias_id) then
        return null;
    end if;

    update users set alias_id = p_alias_id where id = p_user_id;
    select alias_index into v_alias_index from users where id = p_user_id;
    return v_alias_index;
end;
$$ language plpgsql;


/**
 * @name update_user_school
 * @description Gán trường học cho user nếu hợp lệ.
 * @param {varchar} p_user_id
 * @param {integer} p_school_id
 * @returns {boolean} Thành công hay không.
 */
create or replace function update_user_school(
    p_user_id varchar,
    p_school_id integer
) returns boolean as
$$
declare
    v_user_exists boolean;
begin
    select exists (select 1 from users where id = p_user_id and deleted_at is null and status != 'banned')
    into v_user_exists;

    if not v_user_exists or not exists (select 1 from schools where id = p_school_id) then
        return false;
    end if;

    update users set school_id = p_school_id where id = p_user_id;
    return true;
end;
$$ language plpgsql;


-- ============================================
-- ACTIVITY TRACKING & NOTIFICATIONS
-- ============================================

/**
 * @name record_user_login
 * @description Ghi lại lịch sử đăng nhập.
 * @param {varchar} p_user_id
 * @param {inet} p_ip_address
 * @param {text} p_user_agent
 * @param {jsonb} p_device_info
 * @param {varchar} p_platform
 * @returns {void}
 */
create or replace function record_user_login(
    p_user_id varchar,
    p_ip_address inet,
    p_user_agent text,
    p_device_info jsonb,
    p_platform varchar
) returns void as
$$
begin
    insert into user_logins (user_id, ip_address, user_agent, device_info, platform, logged_in_at)
    values (p_user_id, p_ip_address, p_user_agent, p_device_info, p_platform, now());
end;
$$ language plpgsql;


/**
 * @name register_fcm_token
 * @description Đăng ký hoặc cập nhật FCM token.
 * @param {varchar} p_user_id
 * @param {text} p_fcm_token
 * @param {varchar} p_device_id
 * @param {varchar} p_platform
 * @returns {void}
 */
create or replace function register_fcm_token(
    p_user_id varchar,
    p_fcm_token text,
    p_device_id varchar,
    p_platform varchar
) returns void as
$$
declare
    v_existing_fcm_id bigint;
begin
    select id
    into v_existing_fcm_id
    from user_fcms
    where user_id = p_user_id
      and fcm_token = p_fcm_token
    limit 1;

    if v_existing_fcm_id is not null then
        update user_fcms
        set last_used_at = now(),
            device_id    = coalesce(p_device_id, device_id),
            platform     = coalesce(p_platform, platform)
        where id = v_existing_fcm_id;
    else
        insert into user_fcms (user_id, fcm_token, device_id, platform, created_at, last_used_at)
        values (p_user_id, p_fcm_token, p_device_id, p_platform, now(), now());
    end if;
end;
$$ language plpgsql;


-- ============================================
-- TRIGGERS
-- ============================================

/**
 * @name combined_user_trigger
 * @description Trigger xử lý update alias, alias_index, active nếu đủ điều kiện.
 * @returns {trigger} new record
 */
create or replace function combined_user_trigger()
    returns trigger as
$$
declare
    next_index integer;
begin
    new.updated_at = now();
    if new.alias_id is distinct from old.alias_id then
        new.updated_alias_at = now();
    end if;

    if tg_op = 'insert' or (new.alias_id is distinct from old.alias_id) then
        if new.alias_id is not null then
            select next_user_index
            into next_index
            from aliases
            where id = new.alias_id for update;
            new.alias_index = next_index;
            update aliases
            set next_user_index = next_user_index + 1
            where id = new.alias_id;
        else
            new.alias_index = null;
        end if;
    end if;

    if new.alias_id is not null and new.school_id is not null
        and new.status = 'pending'::user_status then
        new.status = 'active'::user_status;
    end if;

    return new;
end;
$$ language plpgsql;