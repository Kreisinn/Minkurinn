-- Migration: multi-user. Trips get an owner and co-admins; scorers need the
-- trip's PIN. Run after migration-trips.sql. SAFE POST-TRIP: no data changes,
-- only ownership columns, new tables and replaced policies.
--
-- Who can do what afterwards:
--   anyone with the link   read a trip (unlisted, not secret)
--   anyone with the PIN    enter scores and set a player's tee for a round
--   trip admins            edit that trip: players, rounds, pairings, notes
--   trip owner             all of the above, plus add/remove admins, delete it
--   course owner           edit that course's holes and tees; anyone can use it
--
-- Every user that existed before this migration becomes an admin of every
-- existing trip, so nobody loses access. The oldest user becomes the owner.
-- Once this has run, signups can be turned back on in Supabase.

create extension if not exists "pgcrypto";

/* ---------- ownership ---------- */
alter table trips   add column if not exists owner_id uuid references auth.users(id) on delete set null;
alter table courses add column if not exists owner_id uuid references auth.users(id) on delete set null;
alter table trips   alter column owner_id set default auth.uid();
alter table courses alter column owner_id set default auth.uid();

update trips   set owner_id = (select id from auth.users order by created_at limit 1) where owner_id is null;
update courses set owner_id = (select id from auth.users order by created_at limit 1) where owner_id is null;

-- Co-admins are invited by email, so they can be added before they first sign in.
create table if not exists trip_admins (
  trip_id    uuid not null references trips(id) on delete cascade,
  email      text not null check (email = lower(email)),
  added_at   timestamptz not null default now(),
  primary key (trip_id, email)
);

insert into trip_admins (trip_id, email)
select t.id, lower(u.email) from trips t cross join auth.users u where u.email is not null
on conflict do nothing;

-- PIN hashes live apart from trips so the public read policy never exposes them.
create table if not exists trip_pins (
  trip_id  uuid primary key references trips(id) on delete cascade,
  pin_hash text not null
);
create table if not exists pin_failures (
  trip_id uuid not null references trips(id) on delete cascade,
  at      timestamptz not null default now()
);
create index if not exists pin_failures_trip_at on pin_failures (trip_id, at);

/* ---------- helpers ---------- */
-- security definer: they read trip_admins/rounds/matches without tripping RLS.
create or replace function is_trip_admin(tid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (
    exists (select 1 from trips where id = tid and owner_id = auth.uid())
    or exists (select 1 from trip_admins
               where trip_id = tid and email = lower(auth.jwt() ->> 'email')));
$$;

create or replace function is_trip_owner(tid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null
     and exists (select 1 from trips where id = tid and owner_id = auth.uid());
$$;

create or replace function round_trip(rid uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select trip_id from rounds where id = rid;
$$;

create or replace function match_trip(mid uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select r.trip_id from matches m join rounds r on r.id = m.round_id where m.id = mid;
$$;

create or replace function is_course_owner(cid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null
     and exists (select 1 from courses where id = cid and owner_id = auth.uid());
$$;

/* ---------- policies: drop the old "any signed-in user" ones ---------- */
do $$
declare t text;
begin
  foreach t in array array['trips','teams','players','courses','course_holes','tees',
                           'rounds','matches','match_players','info_pages']
  loop
    execute format('drop policy if exists admin_write on %I', t);
  end loop;
end $$;
drop policy if exists write_scores       on scores;
drop policy if exists anon_set_tee       on players;
drop policy if exists anon_set_match_tee on match_players;
revoke update (tee_name) on players       from anon;
revoke update (tee_name) on match_players from anon;

-- trips: anyone reads; signed-in users create their own; admins edit; owner deletes.
create policy trip_insert on trips for insert to authenticated with check (owner_id = auth.uid());
create policy trip_update on trips for update to authenticated
  using (is_trip_admin(id)) with check (is_trip_admin(id));
create policy trip_delete on trips for delete to authenticated using (owner_id = auth.uid());

-- Tables that carry trip_id directly.
do $$
declare t text;
begin
  foreach t in array array['teams','players','rounds','info_pages']
  loop
    execute format(
      'create policy trip_admin_write on %I for all to authenticated
         using (is_trip_admin(trip_id)) with check (is_trip_admin(trip_id))', t);
  end loop;
end $$;

create policy trip_admin_write on matches for all to authenticated
  using (is_trip_admin(round_trip(round_id))) with check (is_trip_admin(round_trip(round_id)));
create policy trip_admin_write on match_players for all to authenticated
  using (is_trip_admin(match_trip(match_id))) with check (is_trip_admin(match_trip(match_id)));
create policy trip_admin_write on scores for all to authenticated
  using (is_trip_admin(match_trip(match_id))) with check (is_trip_admin(match_trip(match_id)));

-- Courses are a shared catalogue: anyone reads, the creator edits.
create policy course_owner_write on courses for all to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy course_owner_write on course_holes for all to authenticated
  using (is_course_owner(course_id)) with check (is_course_owner(course_id));
create policy course_owner_write on tees for all to authenticated
  using (is_course_owner(course_id)) with check (is_course_owner(course_id));

-- Admin list: admins see it, you see your own row, the owner manages it.
alter table trip_admins  enable row level security;
alter table trip_pins    enable row level security;   -- no policies: RPC only
alter table pin_failures enable row level security;   -- no policies: RPC only
create policy admins_read on trip_admins for select to authenticated
  using (is_trip_admin(trip_id) or email = lower(auth.jwt() ->> 'email'));
create policy admins_owner_write on trip_admins for all to authenticated
  using (is_trip_owner(trip_id)) with check (is_trip_owner(trip_id));

/* ---------- RPCs ---------- */
-- Trips the signed-in user can edit, newest first.
create or replace function my_trips() returns setof trips
language sql stable security definer set search_path = public as $$
  select * from trips where is_trip_admin(id) order by start_date desc nulls last, name;
$$;

-- Admins set (or clear, with null/'') the scorer PIN. 4-8 digits.
create or replace function set_scorer_pin(p_trip uuid, p_pin text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not is_trip_admin(p_trip) then raise exception 'not an admin of this trip' using errcode = '42501'; end if;
  if coalesce(p_pin, '') = '' then delete from trip_pins where trip_id = p_trip; return; end if;
  if p_pin !~ '^[0-9]{4,8}$' then raise exception 'PIN must be 4-8 digits' using errcode = '22023'; end if;
  insert into trip_pins (trip_id, pin_hash) values (p_trip, crypt(p_pin, gen_salt('bf')))
  on conflict (trip_id) do update set pin_hash = excluded.pin_hash;
  delete from pin_failures where trip_id = p_trip;
end $$;

create or replace function has_scorer_pin(p_trip uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from trip_pins where trip_id = p_trip);
$$;

-- 'ok' | 'bad_pin' | 'locked' | 'no_pin'. Returns rather than raises, so the
-- failure log survives; ten misses in ten minutes locks the trip's PIN briefly.
create or replace function check_scorer_pin(p_trip uuid, p_pin text) returns text
language plpgsql security definer set search_path = public, extensions as $$
declare h text;
begin
  if is_trip_admin(p_trip) then return 'ok'; end if;
  select pin_hash into h from trip_pins where trip_id = p_trip;
  if h is null then return 'no_pin'; end if;
  if coalesce(p_pin, '') = '' then return 'bad_pin'; end if;   -- no guess, no strike
  if (select count(*) from pin_failures
      where trip_id = p_trip and at > now() - interval '10 minutes') >= 10 then
    return 'locked';
  end if;
  if crypt(p_pin, h) = h then return 'ok'; end if;
  insert into pin_failures (trip_id) values (p_trip);
  delete from pin_failures where at < now() - interval '1 day';
  return 'bad_pin';
end $$;

-- Scorer writes. The player must be in the match, so a PIN for one trip can
-- never touch another trip's scores.
create or replace function save_score(p_pin text, p_match uuid, p_player uuid, p_hole int,
                                      p_strokes int, p_picked_up boolean) returns text
language plpgsql security definer set search_path = public as $$
declare tid uuid := match_trip(p_match); res text;
begin
  if tid is null or not exists (select 1 from match_players
                                where match_id = p_match and player_id = p_player) then
    return 'not_found';
  end if;
  res := check_scorer_pin(tid, p_pin);
  if res <> 'ok' then return res; end if;
  insert into scores (match_id, player_id, hole, strokes, picked_up, updated_at)
  values (p_match, p_player, p_hole, p_strokes, coalesce(p_picked_up, false), now())
  on conflict (match_id, player_id, hole) do update
    set strokes = excluded.strokes, picked_up = excluded.picked_up, updated_at = now();
  return 'ok';
end $$;

create or replace function set_match_tee(p_pin text, p_match uuid, p_player uuid, p_tee text) returns text
language plpgsql security definer set search_path = public as $$
declare tid uuid := match_trip(p_match); res text;
begin
  if tid is null then return 'not_found'; end if;
  res := check_scorer_pin(tid, p_pin);
  if res <> 'ok' then return res; end if;
  update match_players set tee_name = p_tee where match_id = p_match and player_id = p_player;
  return case when found then 'ok' else 'not_found' end;
end $$;

revoke all on function set_scorer_pin(uuid, text) from public, anon;
grant execute on function set_scorer_pin(uuid, text) to authenticated;
revoke all on function my_trips() from public, anon;
grant execute on function my_trips() to authenticated;
grant execute on function has_scorer_pin(uuid)                              to anon, authenticated;
grant execute on function check_scorer_pin(uuid, text)                      to anon, authenticated;
grant execute on function save_score(text, uuid, uuid, int, int, boolean)   to anon, authenticated;
grant execute on function set_match_tee(text, uuid, uuid, text)             to anon, authenticated;
