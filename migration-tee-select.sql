-- Migration: tee selection from the scorer screen.
-- The scorer is anonymous, but players are admin-only writable. This grants
-- anon the ability to update EXACTLY ONE column - tee_name - via a
-- column-level grant. Names, handicaps, teams and slots stay admin-locked.
-- Run once on an existing database; also included in schema.sql for fresh
-- installs.

revoke update on players from anon;
grant update (tee_name) on players to anon;

drop policy if exists anon_set_tee on players;
create policy anon_set_tee on players
  for update to anon using (true) with check (true);
