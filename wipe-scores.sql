-- Deletes ALL entered scores, for every round and match, and nothing else.
-- Players, teams, courses, tees, rounds, pairings, tee times and info pages
-- are untouched. Every leaderboard, match card and stat page resets to zero
-- because everything is derived from scores.
--
-- Use this to clear a test run while keeping the pairings, or for a clean
-- slate before the first tee shot in Barcelona.
--
-- This cannot be undone. Scores are the only data the app cannot recreate
-- with a button press.

delete from scores;
