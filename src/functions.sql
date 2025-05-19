-- Trigger cập nhật thời gian
create or replace function update_updated_at_column()
    returns trigger as
$$
begin
    NEW.updated_at = now(); -- Cập nhật updated_at khi có thay đổi
    return NEW;
end;
$$ language plpgsql;


-- Trigger cập nhật thời gian cho từng filed trong bảng users
create or replace function update_updated_at_for_user()
    returns trigger as
$$
begin
    NEW.updated_at := now(); -- Cập nhật updated_at khi có thay đổi

    if NEW.alias_id is distinct from OLD.alias_id then
        NEW.updated_alias_at := now();
    end if; -- Nếu alias_id thay đổi thì cập nhật updated_alias_at

    if NEW.user_name is distinct from OLD.user_name then
        NEW.updated_user_name_at := now();
    end if; -- Nếu user_name thay đổi thì cập nhật updated_user_name_at

    return NEW;
end;
$$ language plpgsql;

-- Trigger ẩn confession bị report nhiều cho bảng confessions
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
        update confessions set status = 'hidden' where id = NEW.confession_id;
    end if;

    return null;
end;
$$ language plpgsql;

-- Trigger xóa comment bị report nhiều cho bảng comments
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