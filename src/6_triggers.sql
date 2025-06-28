-- User
create trigger trg_combined_user_trigger
    before insert or update
    on users
    for each row
execute function combined_user_trigger();

-- Post
create trigger on_check_post_report
    after insert
    on post_reports
    for each row
execute function trg_auto_hidden_post_on_report();


-- Comment
create trigger on_comment_report_insert
    after insert
    on comment_reports
    for each row
execute function trg_auto_delete_comment_on_report();


-- Updated automatic
create trigger trg_update_system_setting_updated_at
    before update
    on system_settings
    for each row
execute function update_updated_at_column();

create trigger trg_update_school_updated_at
    before update
    on schools
    for each row
execute function update_updated_at_column();

create trigger trg_update_alias_updated_at
    before update
    on aliases
    for each row
execute function update_updated_at_column();

create trigger trg_update_topic_updated_at
    before update
    on topics
    for each row
execute function update_updated_at_column();
