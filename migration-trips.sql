-- Migration: the trips layer. Everything the app shows becomes scoped to a
-- trip; the existing El Prat 2026 data is wrapped as trip #1, unchanged.
-- SAFE POST-TRIP: additive columns, backfilled, then constrained.

create table if not exists trips (
  id          uuid primary key default gen_random_uuid(),
  slug        text not null unique,
  name        text not null,
  destination text,
  start_date  date,
  end_date    date,
  cup_target  int not null default 16,   -- total cup points; win line = half + 0.5
  solo_best   int not null default 4     -- rounds counting in the individual race
);

insert into trips (slug, name, destination, start_date, end_date)
values ('el-prat-2026', 'El Prat Cup 2026', 'Barcelona, Spain', '2026-10-08', '2026-10-11')
on conflict (slug) do nothing;

-- Attach the existing world to trip #1.
alter table teams      add column if not exists trip_id uuid references trips(id) on delete cascade;
alter table players    add column if not exists trip_id uuid references trips(id) on delete cascade;
alter table rounds     add column if not exists trip_id uuid references trips(id) on delete cascade;
alter table info_pages add column if not exists trip_id uuid references trips(id) on delete cascade;

update teams      set trip_id = (select id from trips where slug = 'el-prat-2026') where trip_id is null;
update players    set trip_id = (select id from trips where slug = 'el-prat-2026') where trip_id is null;
update rounds     set trip_id = (select id from trips where slug = 'el-prat-2026') where trip_id is null;
update info_pages set trip_id = (select id from trips where slug = 'el-prat-2026') where trip_id is null;

alter table teams      alter column trip_id set not null;
alter table players    alter column trip_id set not null;
alter table rounds     alter column trip_id set not null;
alter table info_pages alter column trip_id set not null;

-- Uniqueness moves inside the trip; sizes loosen for future trip shapes.
-- teams: key is unique per trip now; the players.team FK moves with it.
alter table teams drop constraint if exists teams_pkey cascade;
alter table teams add primary key (trip_id, key);
alter table players add constraint players_team_fk
  foreign key (trip_id, team) references teams (trip_id, key);

alter table players drop constraint if exists players_team_slot_key;
alter table players drop constraint if exists players_slot_check;
alter table players add constraint players_slot_check check (slot between 1 and 12);
alter table players add constraint players_trip_team_slot unique (trip_id, team, slot);

alter table rounds drop constraint if exists rounds_idx_key;
alter table rounds drop constraint if exists rounds_idx_check;
alter table rounds add constraint rounds_idx_check check (idx between 1 and 12);
alter table rounds add constraint rounds_trip_idx unique (trip_id, idx);

alter table matches drop constraint if exists matches_slot_check;
alter table matches add constraint matches_slot_check check (slot between 1 and 12);

alter table info_pages drop constraint if exists info_pages_slug_key;
alter table info_pages add constraint info_pages_trip_slug unique (trip_id, slug);

-- Access: same shape as everything else - world-readable, admin-writable.
alter table trips enable row level security;
create policy read_all   on trips for select using (true);
create policy admin_write on trips for all to authenticated using (true) with check (true);
