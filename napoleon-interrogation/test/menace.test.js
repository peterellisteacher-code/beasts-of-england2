import { it } from 'node:test';
import assert from 'node:assert/strict';
import {
  escalate,
  bandFor,
  parseControlLine,
  selectPortrait,
  clampEmotion,
  EMOTION_AXES,
} from '../menace.js';

// ── escalate() — the 5 sanity checks from the brief, plus the mild-cheek fix ──

it('M1: six clean hits in a row never exceed Wary (3) and never kill', () => {
  let m = 0;
  for (let i = 0; i < 6; i++) {
    const r = escalate(m, true, 'none');
    m = r.menace;
    assert.ok(m <= 3, `clean hit ${i + 1} pushed menace to ${m}`);
    assert.equal(r.dogs, false);
  }
  assert.equal(m, 3);
});

it('M2: first sedition from Composed reaches Dangerous; the second sedition kills', () => {
  const first = escalate(0, false, 'sedition');
  assert.equal(first.menace, 4);
  assert.equal(first.band, 'dangerous');
  assert.equal(first.dogs, false);

  const second = escalate(first.menace, false, 'sedition');
  assert.equal(second.dogs, true);
  assert.equal(second.menace, 6);
});

it('M3: pushing from Wary 3 reaches Dangerous 5; the next push kills', () => {
  const a = escalate(3, false, 'pushing');
  assert.equal(a.menace, 5);
  assert.equal(a.band, 'dangerous');
  assert.equal(a.dogs, false);

  const b = escalate(a.menace, false, 'pushing');
  assert.equal(b.dogs, true);
});

it('M4: a clean hit at Dangerous 5 stays at 5 — no escalation, no de-escalation', () => {
  const r = escalate(5, true, 'none');
  assert.equal(r.menace, 5);
  assert.equal(r.dogs, false);
});

it('M5: fair-warning — no single turn jumps from below Dangerous to the dogs', () => {
  // sedition from Wary 2: 2 + 4 = 6, but clamps to 5 (Dangerous) — warning first.
  const r = escalate(2, false, 'sedition');
  assert.equal(r.menace, 5);
  assert.equal(r.band, 'dangerous');
  assert.equal(r.dogs, false);
});

it('M6: mild cheek can NEVER kill — mild at Dangerous 5 holds at 5', () => {
  const r = escalate(5, false, 'mild');
  assert.equal(r.menace, 5);
  assert.equal(r.dogs, false);
});

it('M7: mild cheek still escalates — mild at 4 moves to 5', () => {
  assert.equal(escalate(4, false, 'mild').menace, 5);
});

it('M8: a pure close-reading turn never de-escalates Napoleon', () => {
  assert.equal(escalate(5, false, 'none').menace, 5);
  assert.equal(escalate(3, false, 'none').menace, 3);
});

it('M9: escalate clamps menace into 0..6 and treats an unknown provocation as none', () => {
  assert.equal(escalate(-3, false, 'none').menace, 0);
  assert.equal(escalate(99, false, 'none').menace, 6);
  assert.equal(escalate(2, false, 'gibberish').menace, 2);
});

// ── bandFor() ────────────────────────────────────────────────────────────────

it('M10: bandFor maps the menace integer to the three named bands', () => {
  assert.equal(bandFor(0), 'composed');
  assert.equal(bandFor(1), 'composed');
  assert.equal(bandFor(2), 'wary');
  assert.equal(bandFor(3), 'wary');
  assert.equal(bandFor(4), 'dangerous');
  assert.equal(bandFor(5), 'dangerous');
  assert.equal(bandFor(6), 'dangerous');
});

// ── parseControlLine() ───────────────────────────────────────────────────────

it('M11: a well-formed control line is parsed and stripped from the visible text', () => {
  const reply =
    '*Napoleon studies you.* "Speak plainly."\n' +
    '[[falter=true provocation=none composure=0.6 threat=0.3 suspicion=0.5 contempt=0.4]]';
  const r = parseControlLine(reply);
  assert.equal(r.falter, true);
  assert.equal(r.provocation, 'none');
  assert.equal(r.emotion.composure, 0.6);
  assert.equal(r.emotion.threat, 0.3);
  assert.ok(!r.text.includes('[['));
  assert.ok(r.text.includes('Speak plainly'));
});

it('M12: a missing control line defaults safely and keeps the whole reply as text', () => {
  const r = parseControlLine('*He says nothing.*');
  assert.equal(r.falter, false);
  assert.equal(r.provocation, 'none');
  assert.equal(r.text, '*He says nothing.*');
  for (const a of EMOTION_AXES) assert.ok(r.emotion[a] >= 0 && r.emotion[a] <= 1);
});

it('M13: missing emotion fields fall back to defaults; falter/provocation still parse', () => {
  const r = parseControlLine('Reply text. [[falter=false provocation=sedition]]');
  assert.equal(r.provocation, 'sedition');
  for (const a of EMOTION_AXES) assert.equal(typeof r.emotion[a], 'number');
});

it('M14: parsing tolerates reordered, mixed-case and loosely-spaced fields', () => {
  const r = parseControlLine('Text [[ PROVOCATION = Pushing   falter=TRUE threat=0.9 ]]');
  assert.equal(r.falter, true);
  assert.equal(r.provocation, 'pushing');
  assert.equal(r.emotion.threat, 0.9);
});

it('M15: with two bracket blocks the last is the control line and all blocks are stripped', () => {
  const reply = 'I will not say [[falter=true]] anything. [[falter=false provocation=mild]]';
  const r = parseControlLine(reply);
  assert.equal(r.falter, false);
  assert.equal(r.provocation, 'mild');
  assert.ok(!r.text.includes('[['));
});

it('M16: out-of-range emotion values are clamped into 0..1', () => {
  const r = parseControlLine('x [[falter=false provocation=none threat=9 composure=-2]]');
  assert.equal(r.emotion.threat, 1);
  assert.equal(r.emotion.composure, 0);
});

// ── selectPortrait() ─────────────────────────────────────────────────────────

const FIXTURE_PORTRAITS = [
  { id: 'cold', emotion: { composure: 0.95, threat: 0.15, suspicion: 0.2, contempt: 0.4 } },
  { id: 'rage', emotion: { composure: 0.15, threat: 0.95, suspicion: 0.8, contempt: 0.75 } },
  { id: 'the_dogs' }, // death portrait — no emotion vector, must be ignored
];

it('M17: selectPortrait returns the nearest emotional portrait', () => {
  assert.equal(
    selectPortrait({ composure: 0.9, threat: 0.2, suspicion: 0.25, contempt: 0.45 }, FIXTURE_PORTRAITS),
    'cold',
  );
  assert.equal(
    selectPortrait({ composure: 0.2, threat: 0.9, suspicion: 0.75, contempt: 0.7 }, FIXTURE_PORTRAITS),
    'rage',
  );
});

it('M18: selectPortrait ignores portraits with no emotion vector (the death image)', () => {
  const picked = selectPortrait(
    { composure: 0.5, threat: 0.5, suspicion: 0.5, contempt: 0.5 },
    FIXTURE_PORTRAITS,
  );
  assert.notEqual(picked, 'the_dogs');
});

// ── clampEmotion() ───────────────────────────────────────────────────────────

it('M19: clampEmotion fills every axis, clamps to 0..1, and tolerates junk input', () => {
  const e = clampEmotion({ threat: 5, suspicion: -1 });
  assert.equal(e.threat, 1);
  assert.equal(e.suspicion, 0);
  for (const a of EMOTION_AXES) assert.equal(typeof e[a], 'number');

  const fromJunk = clampEmotion(null);
  for (const a of EMOTION_AXES) assert.ok(fromJunk[a] >= 0 && fromJunk[a] <= 1);
});
