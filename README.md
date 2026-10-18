# El Prat Cup 2026

Live team match play scoring for the Barcelona golf trip, 8–11 October 2026.
Sixteen players, two teams, five rounds at Real Club de Golf El Prat.

A single static page backed by Supabase. No build step, no app store, no install —
players open a link and add it to their home screen.

## The format

Two competitions over five rounds.

**Round 1 — the Roommates Round (herbergjakeppni).** A separate competition.
Players compete in pairs, scored as traditional better ball: on each hole the
pair counts the higher of the two players' Stableford points, highest 18-hole
total wins. Pairs are assigned by hand in Admin (they can cross
team lines), grouped two pairs to a tee time. Plain Stableford — no double 18th
unless you change the round's `hole_weights`.

**Rounds 2–3 — fourball cup.** Team match play, four matches per round, two
players from each team in every group.

On each hole, compare the two teams' Stableford points:

1. Highest points wins the hole.
2. If the best scores are level across teams, the partners' scores decide it.
3. Level again, and the hole is halved.

The 18th hole counts double. Every match plays all 18 holes — no close-outs.

**Round 4 — singles cup.** Eight 1v1 matches: higher Stableford points wins the
hole, level halves it, the 18th counts double. Default draw is slot v slot;
captains rearrange in Admin.

**Round 5 — individual only.** Plain Stableford, no team points. Groups are
generated from the individual standings, leaders out last.

A won match is worth one point, a halved match a half: 4 + 4 + 8 = sixteen cup
points, so 8–8 is possible; aggregate hole-points are the tiebreak. Fourball
pairings come from a rotation that gives every player a different partner.
All five rounds count toward the individual competition, best four of five.

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

If the database was created from an older version of these files (symptom:
only a "White" tee exists), run `reset.sql` first, then continue below - the
migration-*.sql files are only for preserving data that matters.

1. Create a Supabase project. Put its URL and anon key in `CONFIG` at the top of
   the script in `index.html`.
2. Run `schema.sql`, then `seed.sql`, then `migration-trips.sql`, then
   `migration-auth.sql`, in the Supabase SQL editor. The app is multi-trip and
   multi-user: the seed becomes trip #1, and anyone who signs in can create
   their own trips from the Admin tab.
3. Deploy this folder to any static host over HTTPS.
4. In Supabase, Authentication → URL Configuration: add the deployed URL to
   Site URL, and the deployed URL followed by `**` to Redirect URLs (links carry
   `?trip=…`), or magic-link sign-in will fail silently.
5. Leave email signups on, with email confirmation on. Policies key co-admins
   on the signed-in email address, so it must be a verified one.
6. Open the app, sign in, set a scoring PIN in Admin → Access, and generate
   pairings for each round.

### Upgrading an existing database to multi-user

Run `migration-auth.sql` **before** deploying the new `index.html` — the new
page saves scores through RPCs the migration creates. Every user that already
existed becomes an admin of every existing trip and the oldest one becomes
the owner, so nobody loses access. Then set a scoring PIN, and only then turn
signups back on.

## Who can do what

| Who | Can |
| --- | --- |
| Anyone with the link | View the trip. Trips are unlisted, not secret. |
| Anyone with the trip's PIN | Enter scores, change a player's tee for a round. |
| Trip admins | Edit the trip: players, rounds, pairings, teams, notes, the PIN. |
| Trip owner | All of that, plus add and remove admins, delete the trip. |
| Course owner | Edit that course's holes and tees. Anyone can play it. |

The PIN is checked in the database, not the page. Ten wrong guesses in ten
minutes locks it for the trip until the window passes. Admins are invited by
email and can be added before they first sign in.

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
- Scoring needs the trip's PIN, entered once per phone. A 4-digit PIN keeps
  out strangers and mischief; it is not strong security.
- Failed writes queue in memory and retry, so the scorer keeps working with no
  signal. The queue does not survive a force-quit.
