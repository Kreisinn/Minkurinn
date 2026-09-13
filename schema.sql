-- El Prat cup, 8-11 October 2026.
-- Run this in the Supabase SQL editor.

create extension if not exists "pgcrypto";

create table teams (
  key   text primary key check (key in ('A', 'B')),
  name  text not null,
  color text not null
);

create table players (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  team            text not null references teams(key),
  slot            int  not null check (slot between 1 and 8),
  handicap_index  numeric(4,1) not null,
  tee_name        text not null default 'Amarillas',
  unique (team, slot)
);

-- A course is one specific 18-hole configuration, not "El Prat".
-- Bosque+Arriba and Piscina+Abajo are two different rows.
create table courses (
  id   uuid primary key default gen_random_uuid(),
  name text not null unique,
  par  int  not null
);

create table course_holes (
  course_id    uuid not null references courses(id) on delete cascade,
  hole         int  not null check (hole between 1 and 18),
  par          int  not null,
  stroke_index int  not null check (stroke_index between 1 and 18),
  primary key (course_id, hole),
  unique (course_id, stroke_index)
);

create table tees (
  id            uuid primary key default gen_random_uuid(),
  course_id     uuid not null references courses(id) on delete cascade,
  name          text not null,
  course_rating numeric(4,1) not null,
  slope         int not null check (slope between 55 and 155),
  unique (course_id, name)
);

-- Rounds are keyed by index, never by date: two are played on 9 October.
create table rounds (
  id           uuid primary key default gen_random_uuid(),
  idx          int  not null unique check (idx between 1 and 5),
  label        text not null,
  play_date    date not null,
  start_time   time,
  kind         text not null default 'cup' check (kind in ('cup', 'roommates')),
  course_id    uuid references courses(id),
  tee_id       uuid references tees(id),
  hole_weights int[] not null default '{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2}',
  status       text not null default 'scheduled'
                 check (status in ('scheduled', 'live', 'final')),
  constraint hole_weights_len check (array_length(hole_weights, 1) = 18)
);

create table matches (
  id       uuid primary key default gen_random_uuid(),
  round_id uuid not null references rounds(id) on delete cascade,
  slot     int  not null check (slot between 1 and 4),
  tee_time time,
  unique (round_id, slot)
);

create table match_players (
  match_id  uuid not null references matches(id) on delete cascade,
  player_id uuid not null references players(id),
  pair      smallint check (pair in (1, 2)),  -- roommates round only
  primary key (match_id, player_id)
);

-- Gross strokes only. Net, points, hole winners and standings are all derived,
-- so a corrected handicap on day two re-scores the whole week for free.
create table scores (
  match_id   uuid not null references matches(id) on delete cascade,
  player_id  uuid not null references players(id),
  hole       int  not null check (hole between 1 and 18),
  strokes    int  check (strokes between 1 and 20),
  picked_up  boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (match_id, player_id, hole),
  constraint score_or_pickup check (picked_up or strokes is not null)
);

-- Practical info: travel, hotel, dinners, rules, whatever.
create table info_pages (
  id    uuid primary key default gen_random_uuid(),
  slug  text unique not null,
  title text not null,
  body  text not null,
  sort  int not null default 0
);

insert into teams (key, name, color) values
  ('A', 'Gamlir', '#1B4B8F'),
  ('B', 'Ungir', '#B3322A');

insert into rounds (idx, label, play_date, kind, hole_weights) values
  (1, 'R1 - Thu 8 Oct - Roommates', '2026-10-08', 'roommates', '{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}'),
  (2, 'R2 - Fri 9 Oct AM',  '2026-10-09', 'cup', default),
  (3, 'R3 - Fri 9 Oct PM',  '2026-10-09', 'cup', default),
  (4, 'R4 - Sat 10 Oct',    '2026-10-10', 'cup', default),
  (5, 'R5 - Sun 11 Oct',    '2026-10-11', 'cup', default);

alter table teams         enable row level security;
alter table players       enable row level security;
alter table courses       enable row level security;
alter table course_holes  enable row level security;
alter table tees          enable row level security;
alter table rounds        enable row level security;
alter table matches       enable row level security;
alter table match_players enable row level security;
alter table scores        enable row level security;
alter table info_pages    enable row level security;

do $$
declare t text;
begin
  foreach t in array array['teams','players','courses','course_holes','tees',
                           'rounds','matches','match_players','scores','info_pages']
  loop
    execute format('create policy read_all on %I for select using (true)', t);
  end loop;
end $$;

-- Anyone with the link can post scores. Admin tables need a signed-in user.
create policy write_scores on scores for all using (true) with check (true);

do $$
declare t text;
begin
  foreach t in array array['players','courses','course_holes','tees',
                           'rounds','matches','match_players','info_pages']
  loop
    execute format(
      'create policy admin_write on %I for all to authenticated using (true) with check (true)', t);
  end loop;
end $$;

alter publication supabase_realtime add table scores;
alter publication supabase_realtime add table rounds;
