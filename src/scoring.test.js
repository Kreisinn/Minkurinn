import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  courseHandicap,
  strokesOnHole,
  stablefordPoints,
  resolveHole,
  playMatch,
  cupStanding,
  partnerRotation,
  DEFAULT_HOLE_WEIGHTS,
} from './scoring.js';

test('course handicap at full allowance', () => {
  assert.equal(courseHandicap(18.4, 128, 72.3, 72), 21);
  assert.equal(courseHandicap(4.2, 128, 72.3, 72), 5);
  assert.equal(courseHandicap(-1.5, 128, 72.3, 72), -1);
});

test('handicap rounding goes half away from zero, not toward positive', () => {
  assert.equal(courseHandicap(-1.5, 113, 72, 72), -2);
  assert.equal(courseHandicap(1.5, 113, 72, 72), 2);
});

test('stroke allocation wraps past 18', () => {
  assert.equal(strokesOnHole(21, 1), 2);
  assert.equal(strokesOnHole(21, 3), 2);
  assert.equal(strokesOnHole(21, 4), 1);
  assert.equal(strokesOnHole(21, 18), 1);
  assert.equal(strokesOnHole(0, 1), 0);
  assert.equal(strokesOnHole(-2, 18), -1);
  assert.equal(strokesOnHole(-2, 17), -1);
  assert.equal(strokesOnHole(-2, 16), 0);
});

test('stableford points including pickups', () => {
  assert.equal(stablefordPoints({ strokes: 4 }, 4, 0), 2);
  assert.equal(stablefordPoints({ strokes: 5 }, 4, 1), 2);
  assert.equal(stablefordPoints({ strokes: 3 }, 4, 0), 3);
  assert.equal(stablefordPoints({ strokes: 8 }, 4, 0), 0);
  assert.equal(stablefordPoints({ strokes: null, pickedUp: true }, 5, 2), 0);
});

test('hole resolution follows the house rule', () => {
  assert.equal(resolveHole([4, 1], [3, 3]).winner, 'A');
  assert.equal(resolveHole([4, 1], [3, 3]).decidedAt, 0);

  const tie = resolveHole([3, 3], [3, 2]);
  assert.equal(tie.winner, 'A');
  assert.equal(tie.decidedAt, 1, 'partner decides when best scores are level');

  assert.equal(resolveHole([3, 2], [3, 2]).winner, 'halved');
  assert.equal(resolveHole([4, 4], [3, 3]).winner, 'A', 'same-team tie at top still wins');
  assert.equal(resolveHole([0, 0], [0, 0]).winner, 'halved');
  assert.equal(resolveHole([2, 5], [5, 1]).winner, 'A', 'order of entry must not matter');
  assert.equal(resolveHole([3], [3, 0]).winner, 'B', 'lone player loses at depth 2');
});

const holes = Array.from({ length: 18 }, (_, i) => ({
  hole: i + 1,
  par: 4,
  strokeIndex: i + 1,
}));

const players = [
  { id: 'a1', team: 'A', courseHandicap: 0 },
  { id: 'a2', team: 'A', courseHandicap: 0 },
  { id: 'b1', team: 'B', courseHandicap: 0 },
  { id: 'b2', team: 'B', courseHandicap: 0 },
];

function card(perPlayer) {
  const scores = {};
  for (const [id, strokes] of Object.entries(perPlayer)) {
    scores[id] = {};
    for (let h = 1; h <= 18; h++) scores[id][h] = { strokes: strokes[h - 1] };
  }
  return scores;
}

test('the 18th hole counts double', () => {
  const par = new Array(18).fill(4);
  const aWins18 = [...par];
  aWins18[17] = 3;
  const m = playMatch({
    players,
    holes,
    scores: card({ a1: aWins18, a2: par, b1: par, b2: par }),
  });
  assert.equal(m.complete, true);
  assert.equal(m.margin, 2, 'one hole won on 18 is worth two');
  assert.deepEqual(m.matchPoints, { A: 1, B: 0 });
});

test('a two-hole lead can be erased on the last', () => {
  const par = new Array(18).fill(4);
  const aCard = [...par];
  aCard[0] = 3;
  aCard[1] = 3;
  const bCard = [...par];
  bCard[17] = 3;
  const m = playMatch({
    players,
    holes,
    scores: card({ a1: aCard, a2: par, b1: bCard, b2: par }),
  });
  assert.equal(m.margin, 0);
  assert.deepEqual(m.matchPoints, { A: 0.5, B: 0.5 });
});

test('match stays incomplete until all 18 are entered', () => {
  const par = new Array(18).fill(4);
  const short = [...par];
  short[17] = null;
  const m = playMatch({
    players,
    holes,
    scores: card({ a1: short, a2: par, b1: par, b2: par }),
  });
  assert.equal(m.played, 17);
  assert.equal(m.complete, false);
  assert.equal(m.matchPoints, null);
});

test('cup standing aggregates points and the hole-point tiebreak', () => {
  const t = cupStanding([
    { complete: true, played: 18, margin: 3, holePointsA: 7, holePointsB: 4, matchPoints: { A: 1, B: 0 } },
    { complete: true, played: 18, margin: -1, holePointsA: 5, holePointsB: 6, matchPoints: { A: 0, B: 1 } },
    { complete: true, played: 18, margin: 0, holePointsA: 6, holePointsB: 6, matchPoints: { A: 0.5, B: 0.5 } },
    { complete: false, played: 9, margin: 2, holePointsA: 4, holePointsB: 2, matchPoints: null },
  ]);
  assert.equal(t.A, 1.5);
  assert.equal(t.B, 1.5);
  assert.equal(t.leader, null);
  assert.equal(t.tiebreakLeader, 'A', 'hole points break a level cup');
  assert.equal(t.live, 1);
});

test('nobody partners the same man twice over five rounds', () => {
  const seen = new Set();
  for (let r = 1; r <= 5; r++) {
    const pairs = partnerRotation(r);
    assert.equal(pairs.length, 4);
    assert.deepEqual(
      [...new Set(pairs.flat())].sort((x, y) => x - y),
      [0, 1, 2, 3, 4, 5, 6, 7],
      'every player appears exactly once each round'
    );
    for (const p of pairs) {
      const key = [...p].sort((x, y) => x - y).join('-');
      assert.ok(!seen.has(key), `repeat partnership ${key} in round ${r}`);
      seen.add(key);
    }
  }
  assert.equal(seen.size, 20);
});

test('hole weights total nineteen', () => {
  assert.equal(DEFAULT_HOLE_WEIGHTS.reduce((a, b) => a + b, 0), 19);
});
