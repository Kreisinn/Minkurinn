-- Full reset. Drops every app table so schema.sql + seed.sql can be run
-- fresh. Use this instead of the migration-*.sql files when there is no
-- data worth keeping (i.e. before the trip).
--
-- Order: 1) this file  2) schema.sql  3) seed.sql
--
-- Your admin sign-in is untouched (auth lives in a separate schema), but
-- re-check Authentication settings: signups should still be OFF and your
-- app URL still in the Redirect URLs list.

drop table if exists
  scores,
  match_players,
  matches,
  rounds,
  tees,
  course_holes,
  courses,
  players,
  teams,
  info_pages
cascade;
