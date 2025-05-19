-- Systems
create table system_settings
(
    key         varchar(64) primary key,
    value       varchar(255) not null,
    description text,
    updated_at  timestamp    not null default now(),

    deleted_at  timestamp    null
);


-- Images
create table images
(
    id         varchar(128) primary key,
    base_url   varchar(255) not null,
    format     varchar(10)  not null,
    width      int          not null,
    height     int          not null,
    size       bigint       not null,

    created_at timestamp    not null default now(),
    updated_at timestamp    not null default now()
);


-- Schools
create table schools
(
    id            serial primary key,
    logo_image_id varchar(128)  null references images (id) on delete set null,

    name          varchar(255) not null,
    short_name    varchar(10)  not null,
    type          school_types not null,

    created_at    timestamp    not null default now()
);


-- Aliases
create table aliases
(
    id            uuid primary key      default gen_random_uuid(),
    icon_image_id varchar(128)  null references images (id) on delete set null,

    display_name  varchar(100) not null,
    created_at    timestamp    not null default now()
);

-- User
create table users
(
    id                   varchar(128) primary key,
    school_id            int          not null references schools (id) on delete cascade,
    alias_id             uuid         null references aliases (id) on delete set null,

    user_name            varchar(50)  not null unique,
    email                varchar(255) not null unique,
    password_hash        varchar(255) null,

    is_active            boolean      not null default true,

    updated_alias_at     timestamp    null,
    updated_user_name_at timestamp    null,

    created_at           timestamp    not null default now(),
    updated_at           timestamp    not null default now(),

    deleted_at           timestamp    null
);

create table user_logins
(
    id           bigserial primary key,
    user_id      varchar(128) not null references users (id) on delete cascade,

    ip_address   inet         null,
    user_agent   text         null,
    device_id    varchar(255) null,
    platform     varchar(50)  null,
    location     text         null,

    logged_in_at timestamp    not null default now()
);

create table user_fcms
(
    id           bigserial primary key,
    user_id      varchar(128) not null references users (id) on delete cascade,

    fcm_token    text         not null,
    device_id    varchar(255) null,
    platform     varchar(50)  null,

    created_at   timestamp    not null default now(),
    last_used_at timestamp    not null default now()
);


-- Confessions
create table confessions
(
    id         bigserial primary key,
    user_id    varchar(128)      not null references users (id) on delete cascade,
    school_id  int               not null references schools (id) on delete cascade,

    status     confession_status not null default 'active',

    content    text              not null,

    created_at timestamp         not null default now(),
    updated_at timestamp         not null default now(),

    deleted_at timestamp         null
);

create table confession_images
(
    id            bigserial primary key,
    confession_id bigint      not null references confessions (id) on delete cascade,
    image_id      varchar(128) not null references images (id) on delete cascade,

    created_at    timestamp   not null default now(),

    unique (confession_id, image_id)
);

create table confession_likes
(
    id            bigserial primary key,
    confession_id bigint       not null references confessions (id) on delete cascade,
    user_id       varchar(128) not null references users (id) on delete cascade,

    created_at    timestamp    not null default now(),

    unique (confession_id, user_id)
);

create table confession_reports
(
    id            bigserial primary key,
    confession_id bigint       not null references confessions (id) on delete cascade,
    user_id       varchar(128) not null references users (id) on delete cascade,

    reason        text         not null,

    created_at    timestamp    not null default now(),

    unique (confession_id, user_id)
);

-- Comments
create table comments
(
    id                bigserial primary key,
    confession_id     bigint       not null references confessions (id) on delete cascade,
    user_id           varchar(128) not null references users (id) on delete cascade,
    parent_comment_id bigint       null references comments (id) on delete cascade,

    content           text         not null,

    created_at        timestamp    not null default now(),
    updated_at        timestamp    not null default now(),

    deleted_at        timestamp    null
);

create table comment_likes
(
    id         bigserial primary key,
    comment_id bigint       not null references comments (id) on delete cascade,
    user_id    varchar(128) not null references users (id) on delete cascade,

    created_at timestamp    not null default now(),

    unique (comment_id, user_id)
);

create table comment_reports
(
    id         bigserial primary key,
    comment_id bigint       not null references comments (id) on delete cascade,
    user_id    varchar(128) not null references users (id) on delete cascade,

    reason     text         not null,

    created_at timestamp    not null default now(),

    unique (comment_id, user_id)
);


-- Notifications
create table notifications
(
    id          bigserial primary key,

    type        varchar(50)  not null,
    title       text         not null,
    body        text         not null,
    data        jsonb        null,

    target_type varchar(20)  not null,
    target_id   varchar(128) null,

    created_at  timestamp    not null default now()
);

create table notification_reads
(
    id              bigserial primary key,
    notification_id bigint       not null references notifications (id) on delete cascade,
    user_id         varchar(128) not null references users (id) on delete cascade,

    is_read         boolean      not null default false,
    read_at         timestamp    null,

    unique (notification_id, user_id)
);