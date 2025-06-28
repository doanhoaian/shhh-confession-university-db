-- ============================================
-- COMMENT SYSTEM FUNCTIONS
-- ============================================

-- ============================================
-- CREATE COMMENT ON A POST
-- ============================================
/**
 * @name create_comment_on_post
 * @description Tạo một bình luận mới cấp cao nhất cho một bài viết.
 *
 * @param {varchar} p_user_id - ID của người dùng tạo bình luận.
 * @param {varchar} p_post_id - ID của bài viết được bình luận.
 * @param {text} p_content - Nội dung của bình luận.
 *
 * @returns {table} - Trả về một bảng chứa một hàng duy nhất với thông tin của bình luận vừa được tạo.
 *
 * @throws {exception} - Ném ra lỗi trong các trường hợp sau:
 * - Nội dung rỗng ('Content cannot be empty.').
 * - Nội dung quá dài, vượt quá 1000 ký tự ('Comment too long.').
 * - Người dùng không tồn tại, không hoạt động, hoặc đã bị xóa ('User is not valid, not active, or does not exist.').
 * - Bài viết không tồn tại hoặc không hoạt động ('Post does not exist or is not active.').
 * - Bài viết đã tắt tính năng bình luận ('Comments are disabled for this post.').
 * - Người dùng không thuộc trường của bài viết nếu bài viết giới hạn bình luận trong trường ('This post is restricted to users from the same school.').
 */
create or replace function create_comment_on_post(
    p_user_id varchar,
    p_post_id varchar,
    p_content text
)
    returns table
            (
                comment_id bigint,
                post_id    varchar,
                user_id    varchar,
                content    text,
                created_at timestamp
            )
as
$$
declare
    v_user_record record;
    v_post_record record;
    v_permission  permission_type;
begin
    -- Validate content
    if btrim(p_content) = '' then
        raise exception 'Content cannot be empty.';
    end if;

    if length(p_content) > 1000 then
        raise exception 'Comment too long.';
    end if;

    -- Validate user
    select *
    into v_user_record
    from users
    where id = p_user_id
      and deleted_at is null
      and status = 'active';
    if not found then
        raise exception 'User is not valid, not active, or does not exist.';
    end if;

    -- Validate post
    select *
    into v_post_record
    from posts
    where id = p_post_id
      and status = 'active'
      and deleted_at is null;
    if not found then
        raise exception 'Post does not exist or is not active.';
    end if;

    -- Check permission
    select comment_permission
    into v_permission
    from post_permissions
    where post_id = p_post_id;

    if v_permission = 'none' then
        raise exception 'Comments are disabled for this post.';
    elsif v_permission = 'school_only' and
          v_user_record.school_id is distinct from v_post_record.school_id then
        raise exception 'This post is restricted to users from the same school.';
    end if;

    -- Insert comment
    return query
        insert into comments (post_id, user_id, content)
            values (p_post_id, p_user_id, p_content)
            returning id, post_id, user_id, content, created_at;
end;
$$ language plpgsql;


-- ============================================
-- CREATE REPLY TO COMMENT
-- ============================================
/**
 * @name create_reply_to_comment
 * @description Tạo một phản hồi (reply) cho một bình luận đã có (chỉ trả lời được bình luận cấp cao nhất).
 *
 * @param {varchar} p_user_id - ID của người dùng tạo phản hồi.
 * @param {bigint} p_parent_comment_id - ID của bình luận cha đang được phản hồi.
 * @param {text} p_content - Nội dung của phản hồi.
 *
 * @returns {table} - Trả về một bảng chứa một hàng duy nhất với thông tin của phản hồi vừa được tạo.
 *
 * @throws {exception} - Ném ra lỗi trong các trường hợp sau:
 * - Nội dung rỗng ('Content cannot be empty.').
 * - Nội dung quá dài ('Comment too long.').
 * - Người dùng không hợp lệ ('User is not valid, not active, or does not exist.').
 * - Bình luận cha không tồn tại hoặc đã bị xóa ('Parent comment does not exist or has been deleted.').
 * - Cố gắng trả lời một bình luận không phải là bình luận cấp cao nhất ('Only top-level comments can be replied to.').
 * - Bài viết gốc không tồn tại hoặc không hoạt động ('The original post does not exist or is not active.').
 * - Quyền bình luận trên bài viết gốc không cho phép (tắt bình luận hoặc giới hạn trường).
 */
create or replace function create_reply_to_comment(
    p_user_id varchar,
    p_parent_comment_id bigint,
    p_content text
)
    returns table
            (
                comment_id        bigint,
                post_id           varchar,
                user_id           varchar,
                parent_comment_id bigint,
                content           text,
                created_at        timestamp
            )
as
$$
declare
    v_user_record    record;
    v_parent_comment record;
    v_post_record    record;
    v_permission     permission_type;
begin
    if btrim(p_content) = '' then
        raise exception 'Content cannot be empty.';
    end if;

    if length(p_content) > 1000 then
        raise exception 'Comment too long.';
    end if;


    select *
    into v_user_record
    from users
    where id = p_user_id
      and deleted_at is null
      and status = 'active';
    if not found then
        raise exception 'User is not valid, not active, or does not exist.';
    end if;

    select *
    into v_parent_comment
    from comments
    where id = p_parent_comment_id
      and deleted_at is null;
    if not found then
        raise exception 'Parent comment does not exist or has been deleted.';
    end if;

    if v_parent_comment.parent_comment_id is not null then
        raise exception 'Only top-level comments can be replied to.';
    end if;

    select *
    into v_post_record
    from posts
    where id = v_parent_comment.post_id;
    if not found or v_post_record.status <> 'active' or v_post_record.deleted_at is not null then
        raise exception 'The original post does not exist or is not active.';
    end if;

    select comment_permission
    into v_permission
    from post_permissions
    where post_id = v_post_record.id;

    if v_permission = 'none' then
        raise exception 'Comments are disabled for the post this comment belongs to.';
    elsif v_permission = 'school_only' and
          v_user_record.school_id is distinct from v_post_record.school_id then
        raise exception 'This post is restricted to users from the same school.';
    end if;

    return query
        insert into comments (post_id, user_id, parent_comment_id, content)
            values (v_post_record.id, p_user_id, p_parent_comment_id, p_content)
            returning id, post_id, user_id, parent_comment_id, content, created_at;
end;
$$ language plpgsql;


-- ============================================
-- UPDATE COMMENT CONTENT
-- ============================================
/**
 * @name update_comment
 * @description Cập nhật nội dung của một bình luận đã tồn tại. Chỉ chủ sở hữu mới có quyền chỉnh sửa.
 *
 * @param {varchar} p_user_id - ID của người dùng yêu cầu chỉnh sửa.
 * @param {bigint} p_comment_id - ID của bình luận cần chỉnh sửa.
 * @param {text} p_new_content - Nội dung mới của bình luận.
 *
 * @returns {table} - Trả về bảng chứa ID, nội dung đã cập nhật và thời gian cập nhật của bình luận.
 *
 * @throws {exception} - Ném ra lỗi trong các trường hợp sau:
 * - Nội dung mới rỗng ('Content cannot be empty.').
 * - Bình luận không tồn tại ('Comment does not exist.').
 * - Bình luận đã bị xóa ('Cannot edit a deleted comment.').
 * - Người dùng không có quyền chỉnh sửa (không phải chủ sở hữu) ('You do not have permission to edit this comment.').
 */
create or replace function update_comment(
    p_user_id varchar,
    p_comment_id bigint,
    p_new_content text
)
    returns table
            (
                id         bigint,
                content    text,
                updated_at timestamp
            )
as
$$
declare
    v_comment record;
begin
    if btrim(p_new_content) = '' then
        raise exception 'Content cannot be empty.';
    end if;

    select *
    into v_comment
    from comments
    where id = p_comment_id;

    if not found then
        raise exception 'Comment does not exist.';
    elsif v_comment.deleted_at is not null then
        raise exception 'Cannot edit a deleted comment.';
    elsif v_comment.user_id <> p_user_id then
        raise exception 'You do not have permission to edit this comment.';
    end if;

    return query
        update comments
            set content = p_new_content,
                updated_at = now()
            where id = p_comment_id
            returning id, content, updated_at;
end;
$$ language plpgsql;


-- ============================================
-- DELETE COMMENT UNIVERSALLY (by system/moderator/owner/post_owner)
-- ============================================
/**
 * @name delete_comment_universal
 * @description Xóa một bình luận (xóa mềm).
 * Hành động này có thể được thực hiện bởi:
 * - 'system': Hệ thống tự động xóa (ví dụ: do bị báo cáo nhiều lần).
 * - Chủ sở hữu bình luận.
 * - Chủ sở hữu bài viết chứa bình luận đó.
 * - Người dùng có vai trò 'moderator' hoặc 'admin'.
 *
 * @param {varchar} p_requesting_user_id - ID của người dùng hoặc hệ thống yêu cầu xóa.
 * @param {bigint} p_comment_id - ID của bình luận cần xóa.
 * @param {text} p_reason - (Tùy chọn) Lý do xóa, chủ yếu dành cho quản trị viên ghi log.
 *
 * @returns {boolean} - Trả về `true` nếu xóa thành công hoặc nếu bình luận đã được xóa trước đó.
 *
 * @throws {exception} - Ném ra lỗi nếu người yêu cầu không có quyền xóa ('You do not have permission to delete this comment.').
 *
 * @note
 * - Đây là cơ chế xóa mềm (soft delete), chỉ cập nhật trường `deleted_at` và thay đổi nội dung.
 * - Nội dung của bình luận bị xóa sẽ được thay thế bằng một chuỗi định danh hệ thống, ví dụ: '@@SYS::...::DELETED_BY_OWNER'.
 * - Nếu người xóa không phải là chủ sở hữu, một bản ghi sẽ được thêm vào bảng `moderation_logs`.
 */
create or replace function delete_comment_universal(
    p_requesting_user_id varchar,
    p_comment_id bigint,
    p_reason text default null
)
    returns boolean
as
$$
declare
    v_comment_context        record;
    v_requester_role         user_roles;
    v_rows_affected          integer;
    v_reason_code            text;
    v_deleted_placeholder    text;
    v_delete_protocol_prefix text := '@@SYS::vn.dihaver.tech.campus.comments.v1.deleted::';
begin
    select c.id, c.user_id as owner_id, c.deleted_at, p.user_id as post_owner_id
    into v_comment_context
    from comments c
             join posts p on c.post_id = p.id
    where c.id = p_comment_id;

    if not found or v_comment_context.deleted_at is not null then
        return true;
    end if;

    if p_requesting_user_id <> 'system' then
        select role into v_requester_role from users where id = p_requesting_user_id;
    end if;

    if p_requesting_user_id <> 'system' and
       v_comment_context.owner_id <> p_requesting_user_id and
       v_comment_context.post_owner_id <> p_requesting_user_id and
       v_requester_role not in ('moderator', 'admin') then
        raise exception 'You do not have permission to delete this comment.';
    end if;

    -- Reason code
    if p_requesting_user_id = 'system' then
        v_reason_code := 'DELETED_BY_SYSTEM';
    elsif v_comment_context.owner_id = p_requesting_user_id then
        v_reason_code := 'DELETED_BY_OWNER';
    elsif v_requester_role in ('moderator', 'admin') then
        v_reason_code := 'DELETED_BY_MODERATOR';
    else
        v_reason_code := 'DELETED_BY_POST_OWNER';
    end if;

    v_deleted_placeholder := v_delete_protocol_prefix || v_reason_code;

    update comments
    set deleted_at = now(),
        content    = v_deleted_placeholder
    where id = p_comment_id;

    if v_comment_context.owner_id <> p_requesting_user_id then
        insert into moderation_logs(moderator_id, action, target_id, target_type, reason)
        values (p_requesting_user_id, 'DELETE_COMMENT', p_comment_id::varchar, 'comment', p_reason);
    end if;

    get diagnostics v_rows_affected = row_count;
    return v_rows_affected > 0;
end;
$$ language plpgsql;


-- ============================================
-- PAGINATED COMMENT FETCH
-- ============================================
/**
 * @name get_comment_ids_for_post
 * @description Lấy danh sách ID của các bình luận cho một bài viết theo cơ chế phân trang cursor-based.
 *
 * @param {varchar} p_post_id - ID của bài viết cần lấy bình luận.
 * @param {bigint} p_parent_comment_id - (Tùy chọn) ID của bình luận cha.
 * - Nếu `NULL` (mặc định), hàm sẽ lấy các bình luận cấp cao nhất.
 * - Nếu có giá trị, hàm sẽ lấy các phản hồi của bình luận cha đó.
 * @param {integer} p_limit - (Tùy chọn) Số lượng ID tối đa trả về mỗi lần gọi (mặc định là 20).
 * @param {bigint} p_cursor_id - (Tùy chọn) ID của bình luận cuối cùng trong trang trước đó. Hàm sẽ lấy các bình luận có ID lớn hơn cursor này.
 *
 * @returns {table} - Trả về một bảng chứa một cột `id` của các bình luận thỏa mãn điều kiện.
 */
create or replace function get_comment_ids_for_post(
    p_post_id varchar,
    p_parent_comment_id bigint default null,
    p_limit integer default 20,
    p_cursor_id bigint default null
)
    returns table
            (
                id bigint
            )
as
$$
begin
    return query
        select c.id
        from comments c
        where c.post_id = p_post_id
          and c.parent_comment_id is not distinct from p_parent_comment_id
          and (p_cursor_id is null or c.id > p_cursor_id)
        order by c.id
        limit p_limit;
end;
$$ language plpgsql;


-- ============================================
-- GET COMMENT DETAILS BY IDS
-- ============================================
/**
 * @name get_comments_by_ids
 * @description Lấy thông tin chi tiết của nhiều bình luận dựa trên một mảng các ID.
 * Hàm này được thiết kế để hoạt động cùng với `get_comment_ids_for_post`.
 *
 * @param {bigint[]} p_comment_ids - Mảng chứa các ID của bình luận cần lấy thông tin.
 *
 * @returns {table} - Trả về một bảng chứa thông tin chi tiết của các bình luận, bao gồm thông tin người dùng (tên hiển thị, avatar, trường) và nội dung bình luận.
 */
create or replace function get_comments_by_ids(
    p_comment_ids bigint[]
)
    returns table
            (
                id                bigint,
                post_id           varchar,
                parent_comment_id bigint,
                user_id           varchar,
                display_name      varchar,
                avatar_url        text,
                school_short_name varchar,
                content           text,
                created_at        timestamp,
                updated_at        timestamp,
                deleted_at        timestamp
            )
as
$$
begin
    return query
        select c.id,
               c.post_id,
               c.parent_comment_id,
               c.user_id,
               coalesce(a.display_name, 'anonymous')                 as display_name,
               coalesce(concat(i.base_url, i.id, '.', i.format), '') as avatar_url,
               s.short_name                                          as school_short_name,
               c.content,
               c.created_at,
               c.updated_at,
               c.deleted_at
        from comments c
                 left join users u on c.user_id = u.id
                 left join aliases a on u.alias_id = a.id
                 left join images i on a.icon_image_id = i.id
                 left join schools s on u.school_id = s.id
        where c.id = any (p_comment_ids);
end;
$$ language plpgsql;


-- ============================================
-- GET COMMENT COUNTERS (e.g. replies)
-- ============================================
/**
 * @name get_comment_counters_by_ids
 * @description Đếm số liệu liên quan cho một danh sách bình luận, cụ thể là đếm tổng số phản hồi.
 *
 * @param {bigint[]} p_comment_ids - Mảng chứa các ID của bình luận cần đếm.
 *
 * @returns {table} - Trả về một bảng với hai cột: `comment_id` và `total_replies` (tổng số phản hồi của bình luận đó).
 */
create or replace function get_comment_counters_by_ids(
    p_comment_ids bigint[]
)
    returns table
            (
                comment_id    bigint,
                total_replies bigint
            )
as
$$
begin
    return query
        select ids.id                     as comment_id,
               count(distinct replies.id) as total_replies
        from unnest(p_comment_ids) as ids(id)
                 left join comments replies on ids.id = replies.parent_comment_id
        group by ids.id;
end;
$$ language plpgsql;


-- ============================================
-- TRIGGER: AUTO DELETE ON TOO MANY REPORTS
-- ============================================
/**
 * @name trg_auto_delete_comment_on_report
 * @description Hàm TRIGGER, được kích hoạt SAU KHI (AFTER) một bản ghi mới được chèn vào bảng `comment_reports`.
 * Chức năng của trigger là kiểm tra xem một bình luận có đạt đến ngưỡng báo cáo để bị tự động xóa hay không.
 *
 * @logic
 * 1. Đếm tổng số báo cáo hiện tại cho bình luận vừa bị báo cáo.
 * 2. Lấy giá trị ngưỡng xóa tự động từ bảng `system_settings` (với key là 'max_reports_to_delete_comment').
 * 3. Nếu tổng số báo cáo lớn hơn hoặc bằng ngưỡng, trigger sẽ gọi hàm `delete_comment_universal`
 * với `p_requesting_user_id` là 'system' để xóa bình luận đó.
 *
 * @returns {null} - Vì là trigger `AFTER`, giá trị trả về sẽ được bỏ qua.
 */
create or replace function trg_auto_delete_comment_on_report()
    returns trigger
as
$$
declare
    report_count     integer;
    report_threshold integer;
begin
    select count(*)
    into report_count
    from comment_reports
    where comment_id = new.comment_id;

    select value::integer
    into report_threshold
    from system_settings
    where key = 'max_reports_to_delete_comment'
    limit 1;

    report_threshold := coalesce(report_threshold, 9999);

    if report_count >= report_threshold then
        perform 1 from comments where id = new.comment_id for update;

        perform delete_comment_universal(
                p_requesting_user_id := 'system',
                p_comment_id := new.comment_id,
                p_reason := 'Comment automatically deleted due to reaching report threshold.'
                );
    end if;

    return null;
end;
$$ language plpgsql;