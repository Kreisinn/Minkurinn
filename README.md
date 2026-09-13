# El Prat Cup 2026

Live team match play scoring for the Barcelona golf trip, 8–11 October 2026.
Sixteen players, two teams, five rounds at Real Club de Golf El Prat.

A single static page backed by Supabase. No build step, no app store, no install —
players open a link and add it to their home screen.

## The format

Two competitions over five rounds.

**Round 1 — the Roommates Round.** A separate competition. Players compete in
pairs; a pair's score is the two players' combined Stableford points over 18
holes, highest total wins. Pairs are assigned by hand in Admin (they can cross
team lines), grouped two pairs to a tee time. Plain Stableford — no double 18th
unless you change the round's `hole_weights`.

**Rounds 2–5 — the El Prat Cup.** Team match play, four matches per round, two
players from each team in every group.

On each hole, compare the two teams' Stableford points:

1. Highest points wins the hole.
2. If the best scores are level across teams, the partners' scores decide it.
3. Level again, and the hole is halved.

The 18th hole counts double. Every match plays all 18 holes — no close-outs.
A won match is worth one point, a halved match a half. Four cup rounds means
sixteen points, so 8–8 is possible; aggregate hole-points are tracked as the
tiebreak. Cup pairings come from a rotation that gives every player a different
partner in each of the four rounds.

Handicaps are full allowance (100%), WHS course handicap, strokes by stroke index.

## Layout

```
index.html              the whole app
manifest.webmanifest    home-screen install
sw.js                   offline shell
icon-*.png              app icons
schema.sql              tables, RLS policies, realtime
seed.sql                players, placeholder course, info pages
src/scoring.js          scoring engine, extracted and testable
src/scoring.test.js     rules locked down by tests
```

The engine in `src/` mirrors the copy inside `index.html`. Change one, change both,
and run the tests.

```
node --test src/scoring.test.js
```

## Setup

1. Create a Supabase project. Put its URL and anon key in `CONFIG` at the top of
   the script in `index.html`.
2. Run `schema.sql`, then `seed.sql`, in the Supabase SQL editor.
3. Deploy this folder to any static host over HTTPS.
4. In Supabase, Authentication → URL Configuration: add the deployed URL to both
   Site URL and Redirect URLs, or magic-link sign-in will fail silently.
5. Open the app, sign in on the Admin tab, then **turn off new signups** in
   Supabase. The policies grant edit rights to any authenticated user, so an open
   signup form is an open admin door.
6. Generate pairings for each of the five rounds.

## Before the trip

- **Verify the course data on arrival.** Par, stroke index and men's ratings for
  the Amarillo and Rosa configurations are transcribed from the club's published
  scorecards (Sep 2026) and the booked tee times from the Barcelona Golf Travel
  confirmation. Check them against the physical card in the pro shop on day one;
  a changed stroke index changes hole winners. `courses-elprat.sql` reloads the
  course data on an existing database.
- Confirm which tees the club puts you on — rounds default to Amarillas, with
  Blancas one dropdown away in Admin.
- Replace the guessed handicap indexes in Admin with real ones.

## Notes

- Only gross strokes are stored. Net scores, points, hole winners and standings are
  all derived on read, so correcting a handicap mid-trip re-scores everything.
- Anyone with the link can enter scores. That is deliberate, and it is not a
  security boundary.
- Failed writes queue in memory and retry, so the scorer keeps working with no
  signal. The queue does not survive a force-quit.
