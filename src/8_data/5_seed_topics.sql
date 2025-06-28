insert into topics (value, label, category, is_hot, display_order)
values 
    -- nhóm xã hội & giải trí
    ('tam-su', 'Tâm sự', 'social', true, 1),
    ('tinh-yeu', 'Tình yêu', 'social', false, 2),
    ('hai-huoc-meme', 'Hài hước & memes', 'social', true, 3),
    ('chuyen-truong-lop', 'Chuyện trường lớp', 'social', false, 4),

    -- nhóm học thuật & phát triển
    ('goc-hoc-tap', 'Góc học tập', 'academic', false, 5),
    ('review-mon-hoc', 'Review môn học', 'academic', false, 6),
    ('thuc-tap-viec-lam', 'Thực tập & việc làm', 'academic', true, 7),
    
    -- nhóm tiện ích & đời sống
    ('nha-tro-pass-do', 'Nhà trọ & pass đồ', 'utility', false, 8),
    ('tim-do-hoi-dap', 'Tìm đồ & hỏi đáp', 'utility', false, 9),

    -- nhóm sự kiện
    ('su-kien', 'Sự kiện', 'event', false, 10),
    
    -- topic chung
    ('chuyen-linh-tinh', 'Chuyện linh tinh', 'social', false, 99);