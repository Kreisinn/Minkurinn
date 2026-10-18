-- Migration: Irish Rumble on the final round, groups v groups.
-- Per hole, the best N Stableford scores in the group count:
--   holes 1-6: best 1, holes 7-12: best 2, holes 13-17: best 3, hole 18: all 4.
-- Change the array below if your variant differs. Null on a round = no rumble.
-- SAFE MID-TRIP: purely additive, derived at read time, touches no scores.

alter table rounds add column if not exists rumble int[]
  check (rumble is null or array_length(rumble, 1) = 18);

update rounds
set rumble = '{1,1,1,1,1,1,2,2,2,2,2,2,3,3,3,3,3,4}'
where idx = 5;
