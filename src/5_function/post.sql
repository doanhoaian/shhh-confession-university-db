-- =============================================
-- POST MANAGEMENT SYSTEM
-- =============================================

-- ============================================
-- CREATE POST
-- ============================================
/**
 * @name create_confession
 * @description Tạo một bài viết confession mới.
 *
 * @param {varchar} p_user_id - ID của người dùng tạo bài viết.
 * @param {integer} p_school_id - ID của trường học nơi bài viết được đăng.
 * @param {text} p_content - Nội dung bài viết.
 * @param {bigint[]} p_topic_ids - (Tùy chọn) Mảng các ID chủ đề.
 * @param {numeric[]} p_topic_scores - (Tùy chọn) Mảng điểm tương ứng với các chủ đề.
 * @param {varchar[]} p_image_ids - (Tùy chọn) Mảng ID các hình ảnh đính kèm.
 * @param {permission_type} p_comment_permission - (Tùy chọn) Quyền bình luận ('all', 'school_only', 'none'). Mặc định là 'all'.
 * @param {permission_type} p_view_permission - (Tùy chọn) Quyền xem ('all', 'school_only'). Mặc định là 'all'.
 *
 * @returns {table} - Trả về thông tin cơ bản của bài viết vừa tạo.
 *
 * @throws {exception} - Ném lỗi nếu:
 * - Nội dung rỗng hoặc quá dài.
 * - Đính kèm quá 10 ảnh.
 * - Người dùng hoặc trường học không hợp lệ.
 * - Không có chủ đề nào được cung cấp.
 * - Số lượng topic_ids và topic_scores không khớp nhau.
 *
 * @note Cải tiến: Thêm kiểm tra số lượng phần tử của p_topic_ids và p_topic_scores phải bằng nhau.
 */
create or replace function create_confession(
    p_user_id varchar,
    p_school_id integer,
    p_content text,
    --
    p_topic_ids bigint[] default '{}',
    p_topic_scores numeric[] default '{}',
    p_image_ids varchar[] default '{}',
    p_status post_status default 'active',
    p_hidden_reason hidden_reason default null,
    p_comment_permission permission_type default 'all',
    p_view_permission permission_type default 'all'
)
    returns table
            (
                post_id       varchar,
                status        post_status,
                hidden_reason hidden_reason,
                created_at    timestamp
            )
as
$$
declare
    v_post_id     varchar(12);
    v_topic_count integer;
    v_image_count integer;
begin
    -- Validate content
    if btrim(p_content) = '' then
        raise exception 'Post content cannot be empty.';
    end if;

    if length(p_content) > 3000 then
        raise exception 'Post content is too long (max 3000 characters).';
    end if;

    -- Validate images
    v_image_count := array_length(p_image_ids, 1);
    if v_image_count > 10 then
        raise exception 'Too many images. Maximum allowed is 10.';
    end if;

    -- Validate user and school
    if not exists (select 1 from users where id = p_user_id and deleted_at is null and users.status = 'active') then
        raise exception 'User is not valid or not active.';
    end if;

    if not exists (select 1 from schools where id = p_school_id and is_active = true) then
        raise exception 'School does not exist or is not active.';
    end if;

    -- Validate topics
    v_topic_count := array_length(p_topic_ids, 1);
    if v_topic_count is null or v_topic_count = 0 then
        raise exception 'At least one topic must be provided.';
    end if;

    -- *** BỔ SUNG QUAN TRỌNG ***
    -- Validate that topic and score arrays have the same length
    if v_topic_count <> array_length(p_topic_scores, 1) then
        raise exception 'The number of topic IDs and topic scores must match.';
    end if;

    -- Generate post ID and insert
    v_post_id := substring(gen_random_uuid()::text from 1 for 12);

    insert into posts (id, post_type, user_id, school_id, status, hidden_reason, content, created_at, updated_at)
    values (v_post_id, 'confession', p_user_id, p_school_id, p_status, p_hidden_reason, p_content, now(), now());

    insert into post_permissions (post_id, comment_permission, view_permission)
    values (v_post_id, p_comment_permission, p_view_permission);

    -- Insert associated
    if v_topic_count > 0 then
        insert into post_topics (post_id, topic_id, score, created_at)
        select v_post_id, topic_id, score, now()
        from unnest(p_topic_ids, p_topic_scores) as t(topic_id, score);
    end if;

    if v_image_count > 0 then
        insert into post_images (post_id, image_id, created_at)
        select v_post_id, unnest(p_image_ids), now();
    end if;

    return query select p.id, p.status::post_status, p.hidden_reason::hidden_reason, p.created_at
                 from posts p
                 where p.id = v_post_id;
end;
$$ language plpgsql;

-- ============================================
-- UPDATE POST
-- ============================================
/**
 * @name update_post
 * @description Cập nhật một bài viết đã tồn tại. Chỉ chủ sở hữu hoặc Quản trị viên có thể thực hiện.
 *
 * @param {varchar} p_requesting_user_id - ID của người dùng yêu cầu cập nhật.
 * @param {varchar} p_post_id - ID của bài viết cần cập nhật.
 * @param {text} p_new_content - (Tùy chọn) Nội dung mới cho bài viết.
 * @param {permission_type} p_new_comment_permission - (Tùy chọn) Quyền bình luận mới.
 * @param {permission_type} p_new_view_permission - (Tùy chọn) Quyền xem mới.
 * @param {text} p_moderation_reason - (Tùy chọn) Lý do nếu hành động được thực hiện bởi Quản trị viên.
 *
 * @returns {boolean} - Trả về `true` nếu cập nhật thành công.
 *
 * @throws {exception} - Ném lỗi nếu:
 * - Bài viết không tồn tại, đã bị xóa hoặc ẩn.
 * - Người yêu cầu không có quyền cập nhật.
 * - Không có tham số nào được cung cấp để cập nhật.
 */
create or replace function update_post(
    p_requesting_user_id varchar,
    p_post_id varchar,
    p_new_content text default null,
    p_new_comment_permission permission_type default null,
    p_new_view_permission permission_type default null,
    p_moderation_reason text default null
)
    returns boolean
as
$$
declare
    v_post           record;
    v_requester_role user_roles;
begin
    -- Check if there is anything to update
    if p_new_content is null and p_new_comment_permission is null and p_new_view_permission is null then
        raise exception 'No update parameters provided.';
    end if;

    -- Fetch post and validate its state
    select * into v_post from posts where id = p_post_id;
    if not found then
        raise exception 'Post not found.';
    end if;
    if v_post.deleted_at is not null then
        raise exception 'Cannot update a deleted post.';
    end if;
    if v_post.status = 'hidden' then
        raise exception 'Cannot update a hidden post.';
    end if;

    -- Check permissions
    select role into v_requester_role from users where id = p_requesting_user_id;

    if v_post.user_id <> p_requesting_user_id and v_requester_role not in ('moderator', 'admin') then
        raise exception 'You do not have permission to update this post.';
    end if;

    -- Update post content if provided
    if p_new_content is not null then
        update posts
        set content    = p_new_content,
            updated_at = now()
        where id = p_post_id;
    end if;

    -- Update permissions if provided
    if p_new_comment_permission is not null or p_new_view_permission is not null then
        update post_permissions
        set comment_permission = coalesce(p_new_comment_permission, comment_permission),
            view_permission    = coalesce(p_new_view_permission, view_permission)
        where post_id = p_post_id;
    end if;

    -- Log if a moderator performed the action
    if v_post.user_id <> p_requesting_user_id and v_requester_role in ('moderator', 'admin') then
        insert into moderation_logs(moderator_id, action, target_id, target_type, reason)
        values (p_requesting_user_id, 'UPDATE_POST', p_post_id, 'post', p_moderation_reason);
    end if;

    return true;
end;
$$ language plpgsql;


-- ============================================
-- DELETE POST (UNIVERSAL)
-- ============================================
/**
 * @name delete_post_universal
 * @description Xóa mềm một bài viết.
 *
 * @param {varchar} p_requesting_user_id - ID của người dùng hoặc hệ thống yêu cầu xóa.
 * @param {varchar} p_post_id - ID của bài viết cần xóa.
 * @param {deleted_reason} p_reason_category - Lý do xóa theo danh mục (enum).
 * @param {text} p_detailed_reason - (Tùy chọn) Lý do chi tiết để ghi log.
 *
 * @returns {boolean} - Trả về `true` nếu thành công.
 */
create or replace function delete_post_universal(
    p_requesting_user_id varchar,
    p_post_id varchar,
    p_reason_category deleted_reason,
    p_detailed_reason text default null
)
    returns boolean
as
$$
declare
    v_post                  record;
    v_requester_role        user_roles;
    v_final_reason_category deleted_reason;
begin
    select * into v_post from posts where id = p_post_id;
    if not found or v_post.deleted_at is not null then
        return true;
    end if;

    if p_requesting_user_id <> 'system' then
        select role into v_requester_role from users where id = p_requesting_user_id;
    end if;

    -- Kiểm tra quyền
    if v_post.user_id <> p_requesting_user_id
        and p_requesting_user_id <> 'system'
        and v_requester_role not in ('moderator', 'admin') then
        raise exception 'You do not have permission to delete this post.';
    end if;

    if v_post.user_id = p_requesting_user_id then
        v_final_reason_category := 'user';
    elsif p_requesting_user_id = 'system' then
        v_final_reason_category := 'system';
    elsif v_requester_role in ('moderator', 'admin') then
        v_final_reason_category := 'mod';
    else
        v_final_reason_category := p_reason_category;
    end if;

    -- Cập nhật deleted_at và deleted_reason
    update posts
    set deleted_at     = now(),
        status         = 'deleted',
        deleted_reason = v_final_reason_category
    where id = p_post_id;

    -- Ghi log nếu hành động không phải do chính chủ bài viết thực hiện
    if v_post.user_id <> p_requesting_user_id then
        insert into moderation_logs(moderator_id, action, target_id, target_type, reason)
        values (p_requesting_user_id, 'DELETE_POST', p_post_id, 'post', p_detailed_reason);
    end if;

    return true;
end;
$$ language plpgsql;


-- ============================================
-- HIDE POST UNIVERSAL
-- ============================================
/**
 * @name hide_post_universal
 * @description Ẩn một bài viết. Có thể được gọi bởi Moderator/Admin hoặc hệ thống.
 *
 * @param {varchar} p_requesting_user_id - ID của người dùng ('moderator', 'admin') hoặc 'system'.
 * @param {varchar} p_post_id - ID của bài viết cần ẩn.
 * @param {hidden_reason} p_reason_category - Lý do ẩn theo danh mục (enum).
 * @param {text} p_detailed_reason - (Tùy chọn) Mô tả chi tiết lý do để ghi log.
 *
 * @returns {boolean} - Trả về `true` nếu thành công.
 */
create or replace function hide_post_universal(
    p_requesting_user_id varchar,
    p_post_id varchar,
    p_reason_category hidden_reason,
    p_detailed_reason text default null
)
    returns boolean
as
$$
declare
    v_requester_role user_roles;
    v_post_status    post_status;
begin
    -- Kiểm tra quyền
    if p_requesting_user_id <> 'system' then
        select role into v_requester_role from users where id = p_requesting_user_id;
        if v_requester_role not in ('moderator', 'admin') then
            raise exception 'You do not have permission to hide this post.';
        end if;
    end if;

    -- Lấy trạng thái hiện tại của bài viết
    select status into v_post_status from posts where id = p_post_id for update;
    if not found then
        raise exception 'Post not found.';
    end if;
    if v_post_status <> 'active' then
        raise exception 'Post is not active and cannot be hidden.';
    end if;

    -- Cập nhật status và hidden_reason với kiểu ENUM
    update posts
    set status        = 'hidden',
        hidden_reason = p_reason_category
    where id = p_post_id;

    -- Ghi log với lý do chi tiết
    insert into moderation_logs(moderator_id, action, target_id, target_type, reason)
    values (p_requesting_user_id, 'HIDE_POST', p_post_id, 'post', p_detailed_reason);

    return true;
end;
$$ language plpgsql;


-- ============================================
-- PAGINATED POST FETCH
-- ============================================
create or replace function get_post_ids_for_feed(
    p_school_id integer,
    p_topic_value varchar default null,
    p_limit integer default 15,
    p_offset integer default 0,
    p_like_weight numeric default 0.6,
    p_comment_weight numeric default 0.4,
    p_dislike_weight numeric default 1.5,
    p_new_post_boost_score numeric default 5.0,
    p_new_post_duration_hours integer default 1,
    p_hot_topic_boost numeric default 1.2,
    p_time_decay_period_hours integer default 48,
    p_user_post_limit integer default 3
)
    returns table
            (
                id varchar
            )
as
$$
begin
    return query
        with interaction_score as (select c.id as post_id,
                                          (
                                              count(distinct cl.id) * p_like_weight
                                                  - count(distinct cd.id) * p_dislike_weight
                                                  + count(distinct cm.id) * p_comment_weight
                                              )
                                              * (1.0 / (1.0 + extract(epoch from (now() - c.created_at)) /
                                                              (p_time_decay_period_hours * 3600)))
                                               as base_score
                                   from posts c
                                            left join post_likes cl on c.id = cl.post_id
                                            left join post_dislikes cd on c.id = cd.post_id
                                            left join comments cm on c.id = cm.post_id
                                   where c.status = 'active'
                                     and c.deleted_at is null
                                   group by c.id, c.created_at),

             hot_posts as (select distinct ct.post_id
                           from post_topics ct
                                    join topics t on ct.topic_id = t.id
                           where t.is_hot = true),

             ranked_posts as (select c.id,
                                     (
                                         is_.base_score
                                             + case
                                                   when c.created_at > now() - (p_new_post_duration_hours * interval '1 hour')
                                                       then p_new_post_boost_score
                                                   else 0
                                             end
                                         ) *
                                     (case when hc.post_id is not null then p_hot_topic_boost else 1.0 end)
                                           as final_score,

                                     row_number() over (
                                         partition by c.user_id
                                         order by
                                             (is_.base_score + case
                                                                   when c.created_at > now() - (p_new_post_duration_hours * interval '1 hour')
                                                                       then p_new_post_boost_score
                                                                   else 0 end) *
                                             (case when hc.post_id is not null then p_hot_topic_boost else 1.0 end) desc
                                         ) as user_rank
                              from posts c
                                       join interaction_score is_ on c.id = is_.post_id
                                       left join hot_posts hc on c.id = hc.post_id
                                       left join post_permissions cp on c.id = cp.post_id
                                       left join post_topics ct on c.id = ct.post_id
                                       left join topics t on ct.topic_id = t.id
                              where c.status = 'active'
                                and c.deleted_at is null
                                and c.school_id = p_school_id
                                and (cp.view_permission = 'all' or cp.view_permission = 'school_only')
                                and (p_topic_value is null or t.value = p_topic_value)
                              group by c.id, c.user_id, is_.base_score, hc.post_id, c.created_at)

        select rc.id
        from ranked_posts rc
        where rc.user_rank <= p_user_post_limit
        order by rc.final_score desc, rc.id desc
        limit p_limit offset p_offset;

end;
$$ language plpgsql;


-- ============================================
-- PAGINATED CURSOR POST FETCH
-- ============================================
create or replace function get_post_ids_for_feed_cursor(
    p_school_id integer,
    p_topic_value varchar default null,
    p_limit integer default 15,
    --
    p_cursor_score numeric default null,
    p_cursor_id varchar default null,
    --
    p_like_weight numeric default 0.6,
    p_comment_weight numeric default 0.4,
    p_dislike_weight numeric default 1.5,
    p_new_post_boost_score numeric default 5.0,
    p_new_post_duration_hours integer default 1,
    p_hot_topic_boost numeric default 1.2,
    p_time_decay_period_hours integer default 48,
    p_user_post_limit integer default 3
)
    returns table
            (
                id          varchar,
                final_score numeric
            )
as
$$
begin
    return query
        with fully_ranked_feed as (with interaction_score as (select c.id as post_id,
                                                                     (
                                                                         count(distinct cl.id) * p_like_weight
                                                                             - count(distinct cd.id) * p_dislike_weight
                                                                             + count(distinct cm.id) * p_comment_weight
                                                                         )
                                                                         * (1.0 / (1.0 +
                                                                                   extract(epoch from (now() - c.created_at)) /
                                                                                   (p_time_decay_period_hours * 3600)))
                                                                          as base_score
                                                              from posts c
                                                                       left join post_likes cl on c.id = cl.post_id
                                                                       left join post_dislikes cd on c.id = cd.post_id
                                                                       left join comments cm on c.id = cm.post_id
                                                              where c.status = 'active'
                                                                and c.deleted_at is null
                                                              group by c.id, c.created_at),
                                        hot_posts as (select distinct ct.post_id
                                                      from post_topics ct
                                                               join topics t on ct.topic_id = t.id
                                                      where t.is_hot = true),
                                        ranked_posts as (select c.id,
                                                                (
                                                                    is_.base_score
                                                                        + case
                                                                              when c.created_at > now() - (p_new_post_duration_hours * interval '1 hour')
                                                                                  then p_new_post_boost_score
                                                                              else 0
                                                                        end
                                                                    ) *
                                                                (case when hc.post_id is not null then p_hot_topic_boost else 1.0 end)
                                                                      as final_score,
                                                                row_number() over (
                                                                    partition by c.user_id
                                                                    order by
                                                                        (is_.base_score + case
                                                                                              when c.created_at > now() - (p_new_post_duration_hours * interval '1 hour')
                                                                                                  then p_new_post_boost_score
                                                                                              else 0
                                                                            end) *
                                                                        (case when hc.post_id is not null then p_hot_topic_boost else 1.0 end) desc
                                                                    ) as user_rank
                                                         from posts c
                                                                  join interaction_score is_ on c.id = is_.post_id
                                                                  left join hot_posts hc on c.id = hc.post_id
                                                                  left join post_permissions cp on c.id = cp.post_id
                                                                  left join post_topics ct on c.id = ct.post_id
                                                                  left join topics t on ct.topic_id = t.id
                                                         where c.status = 'active'
                                                           and c.deleted_at is null
                                                           and c.school_id = p_school_id
                                                           and (cp.view_permission = 'all' or cp.view_permission = 'school_only')
                                                           and (p_topic_value is null or t.value = p_topic_value)
                                                         group by c.id, c.user_id, is_.base_score, hc.post_id, c.created_at)
                                   select rc.id,
                                          rc.final_score
                                   from ranked_posts rc
                                   where rc.user_rank <= p_user_post_limit)
        select frf.id,
               frf.final_score
        from fully_ranked_feed frf
        where p_cursor_score is null
           or (frf.final_score, frf.id) < (p_cursor_score, p_cursor_id)
        order by frf.final_score desc, frf.id desc
        limit p_limit;
end;
$$ language plpgsql;


-- ============================================
-- GET POST CONTENT
-- ============================================
create or replace function get_posts_by_ids(
    p_post_ids varchar[]
)
    returns table
            (
                id                 varchar,
                user_id            varchar,
                school_id          integer,
                avatar_url         text,
                display_name       varchar,
                school_name        varchar,
                school_short_name  varchar,
                content            text,
                images             json,
                status             post_status,
                comment_permission permission_type,
                view_permission    permission_type,
                created_at         timestamp,
                updated_at         timestamp
            )
as
$$
begin
    return query
        select c.id,
               c.user_id,
               c.school_id,
               coalesce(concat(i.base_url, i.id, '.', i.format), '')        as avatar_url,
               coalesce(a.display_name, 'anonymous')                        as display_name,
               s.name                                                       as school_name,
               s.short_name                                                 as school_short_name,
               c.content,
               coalesce(json_agg(distinct concat(ci_i.base_url, ci_i.id, '.', ci_i.format))
                        filter (where ci.image_id is not null), '[]'::json) as images,
               c.status,
               coalesce(cp.comment_permission, 'all'::permission_type)      as comment_permission,
               coalesce(cp.view_permission, 'all'::permission_type)         as view_permission,
               c.created_at,
               c.updated_at
        from posts c
                 left join users u on c.user_id = u.id
                 left join aliases a on u.alias_id = a.id
                 left join images i on a.icon_image_id = i.id
                 left join schools s on c.school_id = s.id
                 left join post_permissions cp on c.id = cp.post_id
                 left join post_images ci on c.id = ci.post_id
                 left join images ci_i on ci.image_id = ci_i.id
        where c.id = any (p_post_ids)
          and c.status = 'active'
          and c.deleted_at is null
        group by c.id, u.id, a.id, i.id, s.id, cp.id;
end;
$$ language plpgsql;


-- ============================================
-- GET POST COUNTERS
-- ============================================
create or replace function get_post_counters_by_ids(
    p_post_ids varchar[]
)
    returns table
            (
                id            varchar,
                total_like    bigint,
                total_dislike bigint,
                total_comment bigint
            )
as
$$
begin
    return query
        select ids.id                as id,
               count(distinct cl.id) as total_like,
               count(distinct cd.id) as total_dislike,
               count(distinct cm.id) as total_comment
        from unnest(p_post_ids) as ids(id)
                 left join post_likes cl on ids.id = cl.post_id
                 left join post_dislikes cd on ids.id = cl.post_id
                 left join comments cm on ids.id = cm.post_id
        group by ids.id;
end;
$$ language plpgsql;


create or replace function get_user_interactions_for_posts(
    p_user_id varchar(128),
    p_post_ids varchar[]
)
    returns table
            (
                post_id     varchar,
                is_liked    boolean,
                is_disliked boolean
            )
as
$$
begin
    return query
        select ids.id              as post_id,
               (cl.id is not null) as is_liked,
               (cd.id is not null) as is_disliked
        from unnest(p_post_ids) as ids(id)
                 left join post_likes cl on ids.id = cl.post_id and cl.user_id = p_user_id
                 left join post_dislikes cd on ids.id = cd.post_id and cd.user_id = p_user_id;
end;
$$ language plpgsql;


-- ============================================
-- TRIGGER: AUTO HIDDEN ON TOO MANY REPORTS
-- ============================================
/**
 * @name check_post_report
 * @description Trigger được kích hoạt sau khi có report mới.
 * Nếu vượt ngưỡng, gọi hàm hide_post_universal để ẩn bài.
 */
create or replace function trg_auto_hidden_post_on_report()
    returns trigger as
$$
declare
    report_count     integer;
    report_threshold integer;
begin
    select count(*)
    into report_count
    from post_reports
    where post_id = new.post_id;

    select value::integer
    into report_threshold
    from system_settings
    where key = 'max_reports_to_hide_post';

    report_threshold := coalesce(report_threshold, 9999);

    if report_count >= report_threshold then
        perform 1 from posts where id = new.post_id for update;

        perform hide_post_universal(
                p_requesting_user_id := 'system',
                p_post_id := new.post_id,
                p_reason_category := 'report',
                p_detailed_reason :=
                    'Post automatically hidden due to reaching report threshold (' || report_count || '/' ||
                    report_threshold || ').' -- Lý do chi tiết
                );
    end if;

    return null;
end;
$$ language plpgsql;