-- Migration: tee choice is stored per player PER ROUND (on match_players),
-- falling back to the player's default tee, then the round default.
--
-- SAFE MID-TRIP: the new column starts null everywhere, and null means
-- "use the player's default" - exactly the current behaviour. No existing
-- round's scoring changes by running this.

alter table match_players add column if not exists tee_name text;

-- The scorer is anonymous; let it set this one column and nothing else
-- (same pattern as players.tee_name).
revoke update on match_players from anon;
grant update (tee_name) on match_players to anon;

drop policy if exists anon_set_match_tee on match_players;
create policy anon_set_match_tee on match_players
  for update to anon using (true) with check (true);
