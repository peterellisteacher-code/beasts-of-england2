// menace.js — the pure, engine-agnostic game logic for the Napoleon interrogation.
//
// Four concerns, all pure functions, all unit-tested in test/menace.test.js:
//   escalate()         — the menace/dogs state machine (the stakes layer).
//   bandFor()          — a menace integer mapped to its named danger band.
//   parseControlLine() — pulls the hidden [[...]] control line out of a reply.
//   selectPortrait()   — snaps a 4-axis emotion vector to the nearest portrait.
//
// Nothing here touches the network, the DOM, or any engine API — so this file is
// reused unchanged by the Cloudflare Worker, the web page, and the Godot export.

export const EMOTION_AXES = ['composure', 'threat', 'suspicion', 'contempt'];

// Napoleon's resting state — used whenever the model omits an emotion value.
const DEFAULT_EMOTION = { composure: 0.8, threat: 0.15, suspicion: 0.2, contempt: 0.4 };

// How far each provocation pushes menace. Only pushing/sedition are ever lethal.
const PROV_PART = { none: 0, mild: 1, pushing: 2, sedition: 4 };

// selectPortrait weights — threat and suspicion read most strongly on screen.
const SELECT_WEIGHTS = { composure: 1.0, threat: 1.5, suspicion: 1.2, contempt: 0.8 };

function clampInt(n, lo, hi) {
  const x = Math.round(Number(n));
  if (!Number.isFinite(x)) return lo;
  return Math.min(hi, Math.max(lo, x));
}

function clamp01(n, fallback) {
  const x = Number(n);
  if (!Number.isFinite(x)) return fallback;
  return Math.min(1, Math.max(0, x));
}

// ─── bandFor ──────────────────────────────────────────────────────────────────
// The internal 0–6 menace scale shown to the student as three named bands.
// 6 is still the 'dangerous' band; the killing is carried by the `dogs` flag.
export function bandFor(menace) {
  const m = clampInt(menace, 0, 6);
  if (m <= 1) return 'composed';
  if (m <= 3) return 'wary';
  return 'dangerous';
}

// ─── escalate ─────────────────────────────────────────────────────────────────
// The stakes state machine. Given the menace coming in, whether the student
// landed a fresh well-evidenced hit (falter), and the provocation level, return
// the new menace, its band, and whether the dogs are loose.
//
// Guarantees (see test/menace.test.js):
//  - clean close-reading turns reach Wary but never Dangerous, and never kill;
//  - the dogs are never un-telegraphed: no turn jumps below-Dangerous → dogs;
//  - only over-pushing and sedition are ever lethal — mild cheek can raise
//    menace but can never, on its own, be the blow that reaches the dogs.
export function escalate(currentMenace, falter, provocation) {
  const cur = clampInt(currentMenace, 0, 6);
  const falterPart = falter ? 1 : 0;
  const provPart = PROV_PART[provocation] ?? 0;
  const raw = cur + falterPart + provPart;

  let next;
  if (provPart === 0) {
    // A pure close-reading turn: a clean hit can make him Wary but never
    // Dangerous, and never de-escalates him below where he already stands.
    next = Math.min(raw, Math.max(3, cur));
  } else {
    next = raw;
    // Fair-warning clamp: a jump from below Dangerous cannot reach the dogs in
    // one turn — the student always sees the Dangerous band first.
    if (cur < 4 && next >= 6) next = 5;
    // Only over-pushing and open sedition are lethal. Mild cheek is neither of
    // the locked death triggers, so it can never be the blow that kills.
    const lethal = provocation === 'pushing' || provocation === 'sedition';
    if (!lethal && next >= 6) next = 5;
  }

  const menace = clampInt(next, 0, 6);
  return { menace, band: bandFor(menace), dogs: menace === 6 };
}

// ─── clampEmotion ─────────────────────────────────────────────────────────────
// Coerce a raw emotion object into a complete 4-axis vector in 0..1, filling any
// missing or junk axis from Napoleon's resting state.
export function clampEmotion(raw) {
  const e = raw && typeof raw === 'object' ? raw : {};
  const out = {};
  for (const axis of EMOTION_AXES) out[axis] = clamp01(e[axis], DEFAULT_EMOTION[axis]);
  return out;
}

// ─── parseControlLine ─────────────────────────────────────────────────────────
// Every model reply ends with one hidden line:
//   [[falter=<bool> provocation=<none|mild|pushing|sedition>
//     composure=<0..1> threat=<0..1> suspicion=<0..1> contempt=<0..1>]]
// Pull it apart, default safely on anything missing or malformed, and return the
// visible text with every [[...]] block removed. Tolerant of reordered fields,
// mixed case, loose spacing, and a stray echoed block — the LAST block wins.
export function parseControlLine(reply) {
  const raw = typeof reply === 'string' ? reply : '';
  const blocks = [...raw.matchAll(/\[\[([^\]]*)\]\]/g)];
  const text = raw.replace(/\[\[[^\]]*\]\]/g, '').trim();

  if (blocks.length === 0) {
    return { falter: false, provocation: 'none', emotion: clampEmotion({}), text };
  }

  const inner = blocks[blocks.length - 1][1];
  const falterM = inner.match(/falter\s*=\s*(true|false)/i);
  const provM = inner.match(/provocation\s*=\s*(none|mild|pushing|sedition)/i);
  const axis = (key) => {
    const m = inner.match(new RegExp(key + '\\s*=\\s*(-?[0-9]*\\.?[0-9]+)', 'i'));
    return m ? Number(m[1]) : undefined;
  };

  return {
    falter: falterM ? falterM[1].toLowerCase() === 'true' : false,
    provocation: provM ? provM[1].toLowerCase() : 'none',
    emotion: clampEmotion({
      composure: axis('composure'),
      threat: axis('threat'),
      suspicion: axis('suspicion'),
      contempt: axis('contempt'),
    }),
    text,
  };
}

// ─── selectPortrait ───────────────────────────────────────────────────────────
// Snap a continuous emotion vector to the nearest portrait in a finite set
// (weighted Euclidean distance). Portraits with no `emotion` — e.g. the death
// image — are skipped, so they are never chosen by mood alone.
export function selectPortrait(emotion, portraits) {
  const e = clampEmotion(emotion);
  let bestId = null;
  let bestDist = Infinity;
  for (const p of Array.isArray(portraits) ? portraits : []) {
    if (!p || !p.emotion) continue;
    const pe = clampEmotion(p.emotion);
    let dist = 0;
    for (const ax of EMOTION_AXES) {
      const diff = e[ax] - pe[ax];
      dist += SELECT_WEIGHTS[ax] * diff * diff;
    }
    if (dist < bestDist) {
      bestDist = dist;
      bestId = p.id;
    }
  }
  return bestId;
}
