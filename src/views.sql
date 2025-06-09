-- View: view_aliases
-- Mục đích: Cung cấp danh sách các bí danh (aliases) kèm theo URL hình ảnh đại diện.
-- Các trường:
--   - id: ID của bí danh.
--   - display_name: Tên hiển thị của bí danh.
--   - image_url: URL đầy đủ của hình ảnh đại diện cho bí danh.  Nếu không có hình ảnh, giá trị sẽ là NULL.
-- Sắp xếp: Theo tên hiển thị của bí danh.
create or replace view view_aliases_user_ranking as
select a.id,
       a.display_name,
       a.next_user_index                       as user_count,
       concat(i.base_url, i.id, '.', i.format) as image_url
from aliases a
         left join images i on a.icon_image_id = i.id
order by a.next_user_index desc nulls last, a.display_name;

select * from users;


-- View: view_schools_user_ranking
-- Mục đích: Xếp hạng các trường học dựa trên số lượng người dùng đã đăng ký, kèm theo thông tin về logo của trường.
-- Các trường:
--   - id: ID của trường học.
--   - name: Tên đầy đủ của trường học.
--   - short_name: Tên viết tắt của trường học.
--   - user_count: Số lượng người dùng liên kết với trường học.
--   - image_url: URL đầy đủ của logo trường học. Nếu không có logo, giá trị sẽ là NULL.
-- Sắp xếp: Theo số lượng người dùng giảm dần, sau đó theo tên viết tắt của trường.
create or replace view view_schools_user_ranking as
select s.id,
       s.name,
       s.short_name,
       count(u.id)                             as user_count,
       concat(i.base_url, i.id, '.', i.format) as image_url
from schools s
         left join
     users u ON u.school_id = s.id
         left join
     images i ON s.logo_image_id = i.id
group by s.id, s.name, s.short_name, i.base_url, i.id, i.format
order by user_count desc,
         s.short_name;

select *
from view_schools_user_ranking;


-- View: view_school_activity_stats
-- Mục đích: Thống kê hoạt động của người dùng theo từng trường học, bao gồm số lượng người dùng, confession, comment, like và report.
-- Các trường:
--   - school_id: ID của trường học.
--   - school_name: Tên của trường học.
--   - user_count: Số lượng người dùng đã đăng ký thuộc trường.
--   - confession_count: Số lượng confession đã được đăng trong trường (không tính confession đã bị xóa).
--   - comment_count: Số lượng comment đã được đăng trong các confession của trường (không tính comment đã bị xóa).
--   - confession_like_count: Tổng số lượt like trên các confession của trường.
--   - confession_report_count: Tổng số lượt report trên các confession của trường.
-- Nhóm: Theo ID và tên trường học.
create or replace view view_school_activity_stats as
select s.id                  as school_id,
       s.name                as school_name,
       count(distinct u.id)  as user_count,
       count(distinct c.id)  as confession_count,
       count(distinct cm.id) as comment_count,
       count(distinct cl.id) as confession_like_count,
       count(distinct cr.id) as confession_report_count
from schools s
         left join users u on u.school_id = s.id
         left join confessions c on c.school_id = s.id and c.deleted_at is null
         left join comments cm on cm.confession_id = c.id and cm.deleted_at is null
         left join confession_likes cl on cl.confession_id = c.id
         left join confession_reports cr on cr.confession_id = c.id
group by s.id, s.name;


-- View: view_top_confessions
-- Mục đích: Xác định các confession nổi bật nhất dựa trên số lượng like, comment và report.
-- Các trường:
--   - id: ID của confession.
--   - content: Nội dung của confession.
--   - user_id: ID của người dùng đã đăng confession.
--   - school_id: ID của trường học mà confession được đăng trong đó.
--   - status: Trạng thái của confession (ví dụ: 'pending', 'approved', 'rejected').
--   - created_at: Thời điểm confession được tạo.
--   - like_count: Số lượng like của confession.
--   - report_count: Số lượng report của confession.
--   - comment_count: Số lượng comment của confession (không tính comment đã bị xóa).
-- Sắp xếp: Theo số lượng like giảm dần, sau đó theo số lượng comment giảm dần, và cuối cùng theo số lượng report giảm dần.
create or replace view view_top_confessions as
select c.id,
       c.content,
       c.user_id,
       c.school_id,
       c.status,
       c.created_at,
       count(distinct cl.id) as like_count,
       count(distinct cr.id) as report_count,
       count(distinct cm.id) as comment_count
from confessions c
         left join confession_likes cl on cl.confession_id = c.id
         left join confession_reports cr on cr.confession_id = c.id
         left join comments cm on cm.confession_id = c.id and cm.deleted_at is null
where c.deleted_at is null
group by c.id, c.content, c.user_id, c.school_id, c.status, c.created_at
order by like_count desc, comment_count desc, report_count desc;


-- View: view_confession_details
-- Mục đích: Cung cấp thông tin chi tiết về mỗi confession, bao gồm thông tin người đăng, trường học, hình ảnh, số lượng like, report và comment.
-- Các trường:
--   - id: ID của confession.
--   - content: Nội dung của confession.
--   - user_id: ID của người dùng đã đăng confession.
--   - user_name: Tên người dùng của người đăng.
--   - school_id: ID của trường học mà confession được đăng trong đó.
--   - school_name: Tên của trường học.
--   - status: Trạng thái của confession.
--   - created_at: Thời điểm confession được tạo.
--   - updated_at: Thời điểm confession được cập nhật lần cuối.
--   - image_urls: Mảng các URL hình ảnh liên quan đến confession. Nếu không có hình ảnh, giá trị sẽ là NULL.
--   - like_count: Số lượng like của confession.
--   - report_count: Số lượng report của confession.
--   - comment_count: Số lượng comment của confession (không tính comment đã bị xóa).
create or replace view view_confession_details as
select c.id,
       c.content,
       c.user_id,
       u.user_name,
       c.school_id,
       s.short_name                                                                                as school_short_name,
       c.status,
       c.created_at,
       c.updated_at,
       array_agg(distinct concat(i.base_url, i.id, '.', i.format)) filter (where i.id is not null) as image_urls,
       (select count(*) from confession_likes cl where cl.confession_id = c.id)                    as like_count,
       (select count(*) from confession_reports cr where cr.confession_id = c.id)                  as report_count,
       (select count(*) from comments cm where cm.confession_id = c.id and cm.deleted_at is null)  as comment_count
from confessions c
         left join users u on c.user_id = u.id
         left join schools s on c.school_id = s.id
         left join confession_images ci on ci.confession_id = c.id
         left join images i on ci.image_id = i.id
where c.deleted_at is null
group by c.id, c.content, c.user_id, u.user_name, c.school_id, s.name, c.status, c.created_at, c.updated_at;


-- View: view_reported_contents
-- Mục đích: Tổng hợp thông tin về các nội dung bị report, bao gồm cả confession và comment.
-- Các trường:
--   - content_type: Loại nội dung bị report ('confession' hoặc 'comment').
--   - content_id: ID của nội dung bị report.
--   - content: Nội dung của confession hoặc comment bị report.
--   - reporter_id: ID của người dùng đã report nội dung.
--   - reason: Lý do report.
--   - reported_at: Thời điểm nội dung bị report.
-- Chú ý: View này sử dụng UNION ALL để kết hợp kết quả từ hai truy vấn khác nhau (confession reports và comment reports).  Điều này có nghĩa là nếu một nội dung (ví dụ, một confession) bị report nhiều lần, nó sẽ xuất hiện nhiều lần trong kết quả với mỗi lần report tương ứng.
--        Nếu bạn chỉ muốn biết mỗi nội dung bị report một lần, bạn có thể cần một truy vấn khác hoặc xử lý thêm kết quả của view này.
create or replace view view_reported_contents as
select 'confession'  as content_type,
       c.id          as content_id,
       c.content,
       cr.user_id    as reporter_id,
       cr.reason,
       cr.created_at as reported_at
from confessions c
         join confession_reports cr on cr.confession_id = c.id
where c.deleted_at is null

union all

select 'comment'     as content_type,
       cm.id         as content_id,
       cm.content,
       cr.user_id    as reporter_id,
       cr.reason,
       cr.created_at as reported_at
from comments cm
         join comment_reports cr on cr.comment_id = cm.id
where cm.deleted_at is null;


-- View: view_user_last_login
-- Mục đích: Xác định thời điểm đăng nhập gần nhất của mỗi người dùng.
-- Các trường:
--   - user_id: ID của người dùng.
--   - user_name: Tên người dùng của người dùng.
--   - last_login_at: Thời điểm đăng nhập gần nhất của người dùng. Nếu người dùng chưa bao giờ đăng nhập, giá trị sẽ là NULL.
-- Chú ý: View này sử dụng LEFT JOIN để bao gồm cả những người dùng chưa bao giờ đăng nhập (last_login_at sẽ là NULL).
--        Nếu bạn chỉ quan tâm đến những người dùng đã từng đăng nhập, bạn có thể thêm điều kiện WHERE l.logged_in_at IS NOT NULL.
create or replace view view_user_last_login as
select u.id                as user_id,
       u.user_name,
       max(l.logged_in_at) as last_login_at
from users u
         left join user_logins l on l.user_id = u.id
group by u.id, u.user_name;


-- View: view_user_notifications
-- Mục đích: Thống kê số lượng thông báo đã đọc và chưa đọc của mỗi người dùng.
-- Các trường:
--   - user_id: ID của người dùng.
--   - total_notifications: Tổng số thông báo mà người dùng nhận được.
--   - read_notifications: Số lượng thông báo mà người dùng đã đọc.
--   - unread_notifications: Số lượng thông báo mà người dùng chưa đọc.
-- Chú ý: View này sử dụng LEFT JOIN để bao gồm cả những người dùng có thể chưa có thông báo nào.
--        Nếu một người dùng không có thông báo nào, cả three trường số lượng sẽ có giá trị là 0.
create or replace view view_user_notifications as
select u.id                                                                   as user_id,
       count(distinct n.id)                                                   as total_notifications,
       count(distinct nr.id) filter (where nr.is_read)                        as read_notifications,
       count(distinct n.id) - count(distinct nr.id) filter (where nr.is_read) as unread_notifications
from users u
         left join notification_reads nr on nr.user_id = u.id
         left join notifications n on nr.notification_id = n.id
group by u.id;


-- View: view_alias_usage
-- Mục đích: Thống kê số lần sử dụng của mỗi bí danh (alias).
-- Các trường:
--   - id: ID của bí danh.
--   - display_name: Tên hiển thị của bí danh.
--   - used_count: Số lượng người dùng đang sử dụng bí danh này.
-- Chú ý: View này sử dụng LEFT JOIN để bao gồm cả những bí danh chưa được sử dụng.
--        Nếu một bí danh chưa được sử dụng, used_count sẽ có giá trị là 0.
--        Nếu bạn chỉ quan tâm đến những bí danh đã được sử dụng, bạn có thể thêm điều kiện WHERE used_count > 0.
create or replace view view_alias_usage as
select a.id,
       a.display_name,
       count(u.id) as used_count
from aliases a
         left join users u on u.alias_id = a.id
group by a.id, a.display_name;


-- View: view_user_signup_stats
-- Mục đích: Thống kê số lượng người dùng mới đăng ký theo ngày.
-- Các trường:
--   - signup_date: Ngày đăng ký.
--   - new_user_count: Số lượng người dùng mới đăng ký trong ngày đó.
-- Sắp xếp: Theo ngày đăng ký giảm dần (ngày mới nhất trước).
-- Chú ý: View này sử dụng hàm DATE() để trích xuất ngày từ trường created_at, cho phép nhóm người dùng theo ngày đăng ký.
--        Kết quả sẽ bao gồm tất cả các ngày có người dùng đăng ký, ngay cả khi chỉ có một người dùng đăng ký trong ngày đó.
create or replace view view_user_signup_stats as
select date(created_at) as signup_date,
       count(*)         as new_user_count
from users
group by date(created_at)
order by signup_date desc;