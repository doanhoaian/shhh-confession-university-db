-- Users
create trigger combined_user_trigger
    before insert or update
    on users
    for each row
execute function combined_user_trigger();

-- Confessions
create trigger trg_update_confessions_updated_at
    before update
    on confessions
    for each row
execute function update_updated_at_column();

create trigger trg_check_confession_report
    after insert
    on confession_reports
    for each row
execute function check_confession_report();

-- Comments
create trigger trg_check_comment_report
    after insert
    on comment_reports
    for each row
execute function check_comment_report();