-- Systems
insert into system_settings (key, value, description)
values ('enable_confession_post', 'true', 'Cho phép người dùng đăng confession'),
       ('enable_comment', 'true', 'Bật/tắt chức năng bình luận'),
       ('enable_like', 'true', 'Bật/tắt chức năng like'),
       ('max_reports_to_hide_confession', '10', 'Số report cần để ẩn confession'),
       ('max_reports_to_delete_comment', '5', 'Số report cần để xoá comment cứng'),
       ('maintenance_mode', 'false', 'Chế độ bảo trì ứng dụng'),

       ('min_app_version_android', '1', 'Tối thiểu phiên bản Android'),
       ('latest_app_version_android', '1', 'Phiên bản Android mới nhất'),
       ('app_download_link_android', 'https://play.google.com/store/apps/details?id=vn.dihaver.tech.shhh.confession',
        'Link tải app Android'),
       ('min_app_version_ios', '1', 'Tối thiểu phiên bản iOS'),
       ('latest_app_version_ios', '1', 'Phiên bản iOS mới nhất'),
       ('app_download_link_ios', 'https://apps.apple.com/app/id123456789', 'Link tải app iOS');