// Scoring engine for the El Prat cup.
// Pure functions, no dependencies, no I/O. Everything downstream derives from here.

export const DEFAULT_HOLE_WEIGHTS = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2];

// WHS course handicap at full (100%) allowance.
export function courseHandicap(handicapIndex, slope, courseRating, par) {
  const raw = handicapIndex * (slope / 113) + (courseRating - par);
  return Math.sign(raw) * Math.round(Math.abs(raw));
}

// How many strokes a player receives on a hole of the given stroke index.
// Negative result means the player gives a stroke back (plus handicaps).
export function strokesOnHole(ch, strokeIndex) {
  if (ch === 0) return 0;
  if (ch < 0) {
    const give = -ch;
    return strokeIndex > 18 - give ? -1 : 0;
  }
  const base = Math.floor(ch / 18);
  const extra = strokeIndex <= ch % 18 ? 1 : 0;
  return base + extra;
}

// Stableford points. A pickup, a no-return or an unentered score is 0.
export function stablefordPoints({ strokes, pickedUp = false }, par, received) {
  if (pickedUp || strokes == null) return 0;
  const net = strokes - received;
  return Math.max(0, 2 + (par - net));
}

// The house rule: compare each team's points for the hole, sorted high to low,
// lexicographically. Best score decides; if level, the partner decides; if still
// level, the hole is halved. A team with fewer players loses any comparison at
// a depth where it has nobody left.
export function resolveHole(teamAPoints, teamBPoints) {
  const a = [...teamAPoints].sort((x, y) => y - x);
  const b = [...teamBPoints].sort((x, y) => y - x);
  const depth = Math.max(a.length, b.length);
  for (let i = 0; i < depth; i++) {
    const av = a[i] ?? -1;
    const bv = b[i] ?? -1;
    if (av !== bv) return { winner: av > bv ? 'A' : 'B', decidedAt: i, a, b };
  }
  return { winner: 'halved', decidedAt: null, a, b };
}

// Points a player scores on one hole of one course.
export function pointsFor(player, score, hole) {
  const received = strokesOnHole(player.courseHandicap, hole.strokeIndex);
  return stablefordPoints(score, hole.par, received);
}

// Resolve every hole of a match.
// players: [{ id, team: 'A'|'B', courseHandicap }]
// holes:   [{ hole, par, strokeIndex }] length 18
// scores:  { [playerId]: { [hole]: { strokes, pickedUp } } }
export function playMatch({ players, holes, scores, holeWeights = DEFAULT_HOLE_WEIGHTS }) {
  const teamA = players.filter((p) => p.team === 'A');
  const teamB = players.filter((p) => p.team === 'B');
  const results = [];

  for (const hole of holes) {
    const entered = players.every((p) => {
      const s = scores[p.id]?.[hole.hole];
      return s && (s.pickedUp || s.strokes != null);
    });
    if (!entered) break;

    const pts = (team) =>
      team.map((p) => pointsFor(p, scores[p.id][hole.hole], hole));
    const r = resolveHole(pts(teamA), pts(teamB));
    results.push({ hole: hole.hole, weight: holeWeights[hole.hole - 1], ...r });
  }

  let margin = 0;
  let holePointsA = 0;
  let holePointsB = 0;
  for (const r of results) {
    if (r.winner === 'A') {
      margin += r.weight;
      holePointsA += r.weight;
    } else if (r.winner === 'B') {
      margin -= r.weight;
      holePointsB += r.weight;
    }
  }

  const played = results.length;
  const complete = played === holes.length;
  const matchPoints = !complete
    ? null
    : margin > 0
      ? { A: 1, B: 0 }
      : margin < 0
        ? { A: 0, B: 1 }
        : { A: 0.5, B: 0.5 };

  return { results, played, complete, margin, holePointsA, holePointsB, matchPoints };
}

// Roll finished and in-flight matches into a cup standing.
export function cupStanding(matches) {
  const t = { A: 0, B: 0, holePointsA: 0, holePointsB: 0, complete: 0, live: 0 };
  for (const m of matches) {
    t.holePointsA += m.holePointsA;
    t.holePointsB += m.holePointsB;
    if (m.complete) {
      t.A += m.matchPoints.A;
      t.B += m.matchPoints.B;
      t.complete += 1;
    } else if (m.played > 0) {
      t.live += 1;
    }
  }
  t.leader = t.A === t.B ? null : t.A > t.B ? 'A' : 'B';
  t.tiebreakLeader =
    t.holePointsA === t.holePointsB ? null : t.holePointsA > t.holePointsB ? 'A' : 'B';
  return t;
}

// Repeat-free partner rotation for 8 players over up to 7 rounds.
// Returns [[i, j], ...] index pairs into a 0-based team array.
export function partnerRotation(round) {
  if (round < 1 || round > 7) throw new RangeError('round must be 1..7');
  const wrap = (n) => ((n - 1) % 7) + 1;
  const pairs = [[8, round]];
  for (let i = 1; i <= 3; i++) pairs.push([wrap(round + i), wrap(round - i + 7)]);
  return pairs.map(([x, y]) => [x - 1, y - 1]);
}
