create or replace view view_aliases_list as
select
  a.id,
  a.display_name,
  concat(i.base_url, i.id, '.', i.format) as image_url
from aliases a
left join images i on a.icon_image_id = i.id
order by a.display_name;

select * from view_aliases_list;