-- Migration: the final competition format.
--   R1 roommates (pairs, counts in individual)
--   R2-R3 fourball cup (partner tiebreak, double 18)
--   R4 SINGLES cup - eight 1v1 matches, double 18 (4+4+8 = 16 points, 8.5 wins)
--   R5 individual only - plain Stableford, no team points
-- Run ONLY on an existing database; fresh installs get this from schema.sql.

alter table rounds drop constraint if exists rounds_kind_check;
alter table rounds add constraint rounds_kind_check
  check (kind in ('cup', 'roommates', 'singles', 'individual'));

-- Singles needs eight match slots per round.
alter table matches drop constraint if exists matches_slot_check;
alter table matches add constraint matches_slot_check
  check (slot between 1 and 8);

update rounds set kind = 'singles',
  label = 'R4 - Sat 10 Oct - Singles'
where idx = 4;

update rounds set kind = 'individual',
  label = 'R5 - Sun 11 Oct - Individual',
  hole_weights = '{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}'
where idx = 5;

-- Old fourball pairings for rounds 4 and 5 don't fit the new formats.
-- This clears them (and any scores entered with them); regenerate R4 (singles
-- draw) and R5 (groups) from Admin.
delete from matches where round_id in (select id from rounds where idx in (4, 5));
