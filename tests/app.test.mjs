// Integration test for the code inside index.html: extracts the module,
// stubs the browser, and asserts the scoring, stats and page logic.
// Run from the repo root:  node tests/app.test.mjs
import { readFileSync, writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import assert from 'node:assert/strict';
import { tmpdir } from 'os';
import { join } from 'path';

const html = readFileSync(new URL('../index.html', import.meta.url), 'utf8');
const src = html.match(/<script type="module">([\s\S]*)<\/script>/)[1]
  .replace(/await import\([^)]*\)/, '({createClient:()=>null})')
  .replace(/\/\* ---------- boot ----------[\s\S]*$/, '')
  .replace(/for \(const ev of \['pointerup'[\s\S]*?\{ passive: true \}\);\n?/, '')
  .replace(/document\.addEventListener[\s\S]*?\n\}\);/g, '')
  .replace(/document\.addEventListener\([^)]*\);\n?/g, '')
  .replace(/addEventListener\('online', flush\);\n?/, '')
  .replace(/setInterval\([\s\S]*?15000\);\n?/, '');

const out = join(tmpdir(), 'elprat-app-under-test.mjs');
writeFileSync(out, src + `
export { DB, standing, roommatesBoard, individualBoard, playMatch, player, playerStats,
         viewPlayer, scoreChip, soloBoard, roundComplete, teeFor, courseHandicap };
`);

const { DB, standing, roommatesBoard, playMatch, playerStats,
        viewPlayer, scoreChip, soloBoard, roundComplete, teeFor, courseHandicap } =
  await import(out);

/* ---------- fixture: 4 players, flat course, one tee pair ---------- */
DB.players = [
  { id:'a1', name:'Andri',  team:'A', slot:1, index:0 },
  { id:'a2', name:'Steini', team:'A', slot:2, index:0 },
  { id:'b1', name:'Stebbi', team:'B', slot:1, index:0 },
  { id:'b2', name:'Dadi',   team:'B', slot:2, index:0, teeName:'Fwd' },
];
DB.courses = [{ id:'c1', name:'TestCourse', par:72,
  holes: Array.from({ length:18 }, (_, i) => ({ hole:i+1, par:4, si:i+1 })) }];
DB.tees = [
  { id:'t1', courseId:'c1', name:'W',   cr:72, slope:113 },
  { id:'t2', courseId:'c1', name:'Fwd', cr:70, slope:113 },
];

const par18 = Array(18).fill(4);
const birdieOn = n => par18.map((s, i) => (i + 1 === n ? 3 : s));
const mkScores = per => Object.fromEntries(Object.entries(per).map(([id, arr]) =>
  [id, Object.fromEntries(arr.map((v, i) => [i + 1, { strokes: v, pickedUp: false }]))]));

const rmRound = { id:'r1', idx:1, label:'R1', date:'2026-10-08', kind:'roommates',
  courseId:'c1', teeId:'t1', weights:Array(18).fill(1),
  matches:[{ id:'m1', slot:1, teeTime:'09:20',
    players:['a1','a2','b1','b2'], pairOf:{ a1:1, b1:1, a2:2, b2:2 },
    scores: mkScores({ a1:birdieOn(5), b1:par18, a2:par18, b2:par18 }) }] };

const cupRound = { id:'r2', idx:2, label:'R2', date:'2026-10-09', kind:'cup',
  courseId:'c1', teeId:'t1', weights:[...Array(17).fill(1), 2],
  matches:[{ id:'m2', slot:1, teeTime:'09:20',
    players:['a1','a2','b1','b2'], pairOf:{},
    scores: mkScores({ a1:birdieOn(18), a2:par18, b1:par18, b2:par18 }) }] };

DB.rounds = [rmRound, cupRound];

/* ---------- per-player tees ---------- */
assert.equal(teeFor(DB.players[3], cupRound).name, 'Fwd', 'named preference wins');
assert.equal(teeFor(DB.players[0], cupRound).name, 'W', 'others fall back to round default');
assert.equal(courseHandicap(0, 113, 70, 72), -2, 'forward tee gives a plus CH');

/* ---------- roommates board ---------- */
const board = roommatesBoard(rmRound);
assert.equal(board.length, 2);
assert.deepEqual([...board[0].names].sort(), ['Andri', 'Stebbi'].sort());
assert.equal(board[0].pts, 73, 'birdie pair: 37 + 36');
assert.equal(board[1].pts, 70, 'pair with forward-tee man: 36 + 34');
assert.equal(board[0].thru, 18);

/* ---------- cup standing ignores roommates; double 18; partner tiebreak ---------- */
const t = standing();
assert.equal(t.secA, 1); assert.equal(t.secB, 0);
assert.equal(t.done, 1);
assert.equal(t.hpA, 3, 'double 18 (2) plus SI-17 via partner tiebreak against the plus-CH man');
assert.equal(t.live, 0, 'roommates round never counts as a live cup match');
const r = playMatch(cupRound.matches[0], cupRound);
assert.equal(r.margin, 3);
assert.deepEqual(r.matchPoints, { A:1, B:0 });

/* ---------- player stats ---------- */
const sa1 = playerStats('a1');
assert.equal(sa1.rounds, 2); assert.equal(sa1.holes, 36);
assert.equal(sa1.pts, 74); assert.equal(sa1.birdies, 2); assert.equal(sa1.netBirdies, 2);
assert.equal(Math.round(sa1.per18 * 10), 370);
assert.deepEqual([sa1.w, sa1.h, sa1.l], [1, 0, 0]);
const sb2 = playerStats('b2');
assert.equal(sb2.pts, 68); assert.equal(sb2.blobs, 0);
assert.equal(sb2.birdies, 0); assert.equal(sb2.netBirdies, 0, 'par with a stroke given back is a net bogey');
assert.deepEqual([sb2.w, sb2.h, sb2.l], [0, 0, 1]);

/* ---------- player page ---------- */
const pv = viewPlayer('a1');
for (const bit of ['R1', 'R2', 'CH 0', 'TOTAL 71', '37 pts'])
  assert.ok(pv.includes(bit), `player page missing ${bit}`);
assert.equal(scoreChip(-1, false, false)[0], '#3E8E5A', 'birdie chip is green');
assert.equal(scoreChip(0, true, false)[0], '#7A4030', 'pickup chip is brown');

/* ---------- individual competition: best 4 of 5 ---------- */
DB.rounds = [rmRound, cupRound,
  ...[3, 4, 5].map(i => ({ id:'r'+i, idx:i, label:'R'+i, date:'2026-10-1'+i, kind:'cup',
    courseId:'c1', teeId:'t1', weights:Array(18).fill(1),
    matches:[{ id:'m'+i, slot:1, teeTime:'09:00', players:['a1','a2','b1','b2'], pairOf:{},
      scores: mkScores({ a1: par18.map((v, j) => j < 10 ? v : v + 1),
                         a2: par18, b1: par18, b2: par18 }) }] }))];
const five = soloBoard().find(x => x.p.id === 'a1');
assert.deepEqual(five.rounds.map(x => x.pts), [37, 37, 28, 28, 28]);
assert.equal(five.total, 37 + 37 + 28 + 28, 'best four of five');
assert.equal(five.counted.size, 4);

/* ---------- round completeness and jump target ---------- */
assert.equal(roundComplete(rmRound), true);
const partial = { ...cupRound, id:'rp',
  matches:[{ ...cupRound.matches[0], id:'mp',
    scores: mkScores({ a1: par18.map((v, i) => i < 11 ? v : null),
                       a2: par18.map((v, i) => i < 11 ? v : null),
                       b1: par18.map((v, i) => i < 11 ? v : null),
                       b2: par18.map((v, i) => i < 11 ? v : null) }) }] };
assert.equal(roundComplete(partial), false);
assert.equal(playMatch(partial.matches[0], partial).played, 11, 'pick would jump to hole 12');

/* ---------- singles round feeds the cup; 1v1 resolution; double 18 ---------- */
const singlesRound = { id:'r4', idx:4, label:'R4', date:'2026-10-10', kind:'singles',
  courseId:'c1', teeId:'t1', weights:[...Array(17).fill(1), 2],
  matches:[{ id:'s1', slot:1, teeTime:'09:00', players:['a1','b1'], pairOf:{},
    scores: mkScores({ a1:birdieOn(18), b1:par18 }) },
            { id:'s2', slot:2, teeTime:'09:00', players:['a2','b1'], pairOf:{},
    scores: mkScores({ a2:par18, b1:par18 }) }] };  // same tee both sides -> level
const sr = playMatch(singlesRound.matches[0], singlesRound);
assert.equal(sr.complete, true);
assert.equal(sr.margin, 2, 'singles birdie on the doubled 18th is worth two');
assert.deepEqual(sr.matchPoints, { A:1, B:0 });
const halved = playMatch(singlesRound.matches[1], singlesRound);
assert.deepEqual(halved.matchPoints, { A:0.5, B:0.5 }, 'level singles halves, no partner fallback');

/* ---------- individual round: no cup points, board sorted ---------- */
const indRound = { id:'r5', idx:5, label:'R5', date:'2026-10-11', kind:'individual',
  courseId:'c1', teeId:'t1', weights:Array(18).fill(1),
  matches:[{ id:'i1', slot:1, teeTime:'09:00', players:['a1','a2','b1','b2'], pairOf:{},
    scores: mkScores({ a1:birdieOn(3), a2:par18, b1:par18, b2:par18 }) }] };
DB.rounds = [rmRound, cupRound, singlesRound, indRound];
const t2 = standing();
assert.equal(t2.secA, 1 + 1 + 0.5, 'fourball win, singles win, half from the halved singles');
assert.equal(t2.secB, 0.5, 'halved singles');
assert.equal(t2.done, 3, 'three cup matches complete; individual round contributes none');
const { individualBoard } = await import(out);
const ib = individualBoard(indRound);
assert.equal(ib.length, 4);
assert.equal(ib[0].p.id, 'a1'); assert.equal(ib[0].pts, 37);
assert.equal(ib[1].pts, 36);

console.log('ALL APP LOGIC OK');
