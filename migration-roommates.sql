-- Migration: the roommates round.
-- Run this ONLY if you already ran the original schema.sql. Fresh installs
-- get all of this from the updated schema.sql and don't need this file.

alter table rounds
  add column if not exists kind text not null default 'cup'
  check (kind in ('cup', 'roommates'));

alter table match_players
  add column if not exists pair smallint check (pair in (1, 2));

-- Round 1 becomes the roommates round: plain Stableford, no double 18th.
update rounds set
  kind = 'roommates',
  label = 'R1 - Thu 8 Oct - Roommates',
  hole_weights = '{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}'
where idx = 1;

-- Any pairings already generated used the old five-round rotation and are wrong
-- for the new shape: round 1 needs manual pairs, rounds 2-5 map onto rotation
-- rounds 1-4. This clears them (and cascades away any scores entered with them).
-- Regenerate rounds 2-5 from Admin, then assign round 1 pairs by hand.
delete from matches;
