
insert into topics (value, label, is_toxic, is_hot, display_order)
values ('tinh-yeu', 'tình yêu', false, false, 1),
       ('hoc-tap', 'học tập', false, false, 2),
       ('meme-troll', 'meme/troll', true, true, 3),
       ('cuoc-song-sinh-vien', 'cuộc sống sinh viên', false, false, 4),
       ('ban-be', 'bạn bè', false, false, 5),
       ('su-kien-truong-hoc', 'sự kiện trường học', false, false, 6),
       ('tam-su-ca-nhan', 'tâm sự cá nhân', false, false, 7),
       ('cau-hoi', 'câu hỏi', false, false, 8),
       ('chia-se-bi-kip', 'chia sẻ bí kíp', false, false, 9),
       ('chuyen-hot', 'chuyện hot', true, true, 10),
       ('hai-huoc', 'hài hước', false, true, 11);

select * from topics where is_hidden = false order by is_hot desc, display_order;

