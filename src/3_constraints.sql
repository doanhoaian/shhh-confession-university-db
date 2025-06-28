alter table posts add constraint check_confession_school_id
check (post_type != 'confession' or school_id is not null);