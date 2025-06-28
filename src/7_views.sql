-- View: view_aliases_user_ranking
create or replace view view_aliases_user_ranking as
select a.id,
       a.display_name,
       a.next_user_index                       as user_count,
       concat(i.base_url, i.id, '.', i.format) as image_url
from aliases a
         left join images i on a.icon_image_id = i.id
order by a.next_user_index desc nulls last, a.display_name;

-- View: view_schools_user_ranking
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
where s.is_active = true
group by s.id, s.name, s.short_name, i.base_url, i.id, i.format
order by user_count desc,
         s.short_name;


-- View: view_school_activity_stats
create or replace view view_school_activity_stats as
select s.id                  as school_id,
       s.name                as school_name,
       count(distinct u.id)  as user_count,
       count(distinct c.id)  as post_count,
       count(distinct cm.id) as comment_count,
       count(distinct cl.id) as post_like_count,
       count(distinct cr.id) as post_report_count
from schools s
         left join users u on u.school_id = s.id
         left join posts c on c.school_id = s.id and c.deleted_at is null
         left join comments cm on cm.post_id = c.id and cm.deleted_at is null
         left join post_likes cl on cl.post_id = c.id
         left join post_reports cr on cr.post_id = c.id
group by s.id, s.name;

-- View: view_top_posts
create or replace view view_top_posts as
select c.id,
       c.content,
       c.user_id,
       c.school_id,
       c.status,
       c.created_at,
       count(distinct cl.id) as like_count,
       count(distinct cr.id) as report_count,
       count(distinct cm.id) as comment_count
from posts c
         left join post_likes cl on cl.post_id = c.id
         left join post_reports cr on cr.post_id = c.id
         left join comments cm on cm.post_id = c.id and cm.deleted_at is null
where c.deleted_at is null
group by c.id, c.content, c.user_id, c.school_id, c.status, c.created_at
order by like_count desc, comment_count desc, report_count desc;


-- View: view_user_notifications
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
create or replace view view_alias_usage as
select a.id,
       a.display_name,
       count(u.id) as used_count
from aliases a
         left join users u on u.alias_id = a.id
group by a.id, a.display_name;


-- View: view_user_signup_stats
create or replace view view_user_signup_stats as
select date(created_at) as signup_date,
       count(*)         as new_user_count
from users
group by date(created_at)
order by signup_date desc;