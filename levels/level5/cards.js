/* =================================================================
   cards.js — card definitions + deck assembly for Act V.
   The deck is built from cards collected through Acts I–IV (in
   localStorage as 'animalDeck'). If the player skipped earlier acts,
   a starter deck is provided.
   ================================================================= */

'use strict';

// Card archetypes — keyed by id from the collecting levels.
// Each card: { id, type, name, body, cost, effect(state) }
window.CARD_DEFINITIONS = {

  // === ACT I — Animalist Principles (collected from L1 banner pickups) ===
  'L1-1': {
    type: 'principle', name: 'All Animals Are Equal',
    body: 'Old Major said it first. Some still remember.',
    cost: 2,
    effect: (s) => { s.sympathy = clamp(s.sympathy + 18, 0, 100); s.memory = clamp(s.memory + 6, 0, 100); s.log('player', 'You name the foundational principle. The hens at the back lift their heads.'); }
  },
  'L1-2': {
    type: 'principle', name: 'No Animal Shall Tyrannise Over His Own Kind',
    body: 'A direct quotation, audible across the whole barn.',
    cost: 2,
    effect: (s) => { s.sympathy = clamp(s.sympathy + 14, 0, 100); s.napoleonPower = max(0, s.napoleonPower - 8); s.log('player', '"No animal shall tyrannise" — three sheep stop bleating mid-bleat.'); }
  },
  'L1-3': {
    type: 'principle', name: 'Whatever Goes Upon Four Legs Is A Friend',
    body: 'A simple truth. The dogs are listening.',
    cost: 1,
    effect: (s) => { s.dogClock = max(0, s.dogClock - 1); s.log('player', 'You appeal to the dogs by their nature. One puppy at the door pauses, ears forward.'); }
  },

  // === ACT II — Rhetoric Counters (collected from L2 Squealer-spotting) ===
  'L2-1': {
    type: 'rhetoric', name: 'Expose the Pre-emption',
    body: '"You do not imagine, I hope" — name the move.',
    cost: 1,
    effect: (s) => { s.adversaryNextDamage = max(0, s.adversaryNextDamage - 12); s.memory = clamp(s.memory + 4, 0, 100); s.log('player', 'You name Squealer\'s opening as a move, not an opening. He has to start over.'); }
  },
  'L2-2': {
    type: 'rhetoric', name: 'Refuse the False Sacrifice',
    body: '"Many of us actually dislike milk and apples." Disprove it.',
    cost: 1,
    effect: (s) => { s.adversaryNextDamage = max(0, s.adversaryNextDamage - 10); s.sympathy = clamp(s.sympathy + 6, 0, 100); s.log('player', 'You point out that the harness-room is empty of windfalls every morning. Boxer turns his head.'); }
  },
  'L2-3': {
    type: 'rhetoric', name: 'Refuse the Threat',
    body: '"Jones would come back!" — but Jones is not at the gate.',
    cost: 2,
    effect: (s) => { s.adversaryNextDamage = max(0, s.adversaryNextDamage - 14); s.napoleonPower = max(0, s.napoleonPower - 6); s.log('player', 'You make the threat visible as a threat. The argument loses its grip.'); }
  },

  // === ACT III — Tactical Insights (from L3 Cowshed) ===
  'L3-1': {
    type: 'tactic', name: 'Hold the Door',
    body: 'A defensive stance. Buys time.',
    cost: 2,
    effect: (s) => { s.dogClock = max(0, s.dogClock - 2); s.log('player', 'Boxer plants himself at the barn door. The dogs slow.'); }
  },
  'L3-2': {
    type: 'tactic', name: 'Feint',
    body: 'Snowball used this at the Cowshed. Use it again.',
    cost: 1,
    effect: (s) => { s.napoleonPower = max(0, s.napoleonPower - 10); s.log('player', 'A feigned retreat. Napoleon\'s prepared move misses its target.'); }
  },
  'L3-3': {
    type: 'tactic', name: 'Coordinate',
    body: 'Pigeons, geese, sheep — each in formation.',
    cost: 2,
    effect: (s) => { s.sympathy = clamp(s.sympathy + 10, 0, 100); s.dogClock = max(0, s.dogClock - 1); s.log('player', 'You speak to the back of the barn — the smaller animals find their places.'); }
  },

  // === ACT IV — Suspicions (from L4 Mollie + Windmill) ===
  'L4-1': {
    type: 'suspicion', name: 'The Hidden Sugar',
    body: 'Mollie\'s defection is not an accident. It is a pattern.',
    cost: 1,
    effect: (s) => { s.memory = clamp(s.memory + 12, 0, 100); s.log('player', '"Some of us have been quietly leaving for sweeter mash." A few animals look down.'); }
  },
  'L4-2': {
    type: 'suspicion', name: 'Where Are the Puppies?',
    body: 'Napoleon took them in Chapter III. They are about to return.',
    cost: 2,
    effect: (s) => { s.napoleonPower = max(0, s.napoleonPower - 12); s.memory = clamp(s.memory + 8, 0, 100); s.log('player', '"Where are Bluebell\'s pups?" — Napoleon does not look up.'); }
  },
  'L4-3': {
    type: 'suspicion', name: 'Save the Plans on Paper',
    body: 'The windmill drawing is on the floor. Trace it onto something portable.',
    cost: 2,
    effect: (s) => { s.savedPlans = true; s.memory = clamp(s.memory + 16, 0, 100); s.log('player', 'You quietly transcribe Snowball\'s drawing onto a sheet from the harness-room.'); }
  },

  // === STARTER DECK — used if player skipped earlier acts ===
  'starter-protest': {
    type: 'principle', name: 'You Speak Up',
    body: 'A small voice from a young pig.',
    cost: 1,
    effect: (s) => { s.sympathy = clamp(s.sympathy + 8, 0, 100); s.log('player', 'You speak up. The crowd notices.'); }
  },
  'starter-listen': {
    type: 'tactic', name: 'You Listen',
    body: 'You hear what is not being said.',
    cost: 0,
    effect: (s) => { s.memory = clamp(s.memory + 6, 0, 100); s.log('player', 'You catch what is omitted from Squealer\'s sentence.'); }
  }
};

// === Helpers =================================================
function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }
function max(a, b) { return Math.max(a, b); }

// Build a deck from localStorage card IDs.
window.buildDeckFromStorage = function () {
  const stored = JSON.parse(localStorage.getItem('animalDeck') || '[]');
  const cardIds = stored.map(c => c.id).filter(id => window.CARD_DEFINITIONS[id]);

  // If empty, hand out a small starter deck
  if (cardIds.length === 0) {
    return [
      'starter-protest','starter-protest','starter-protest',
      'starter-listen','starter-listen','starter-listen',
      'starter-protest','starter-listen','starter-protest'
    ];
  }

  // Always include 2x starter-listen as a baseline so deck size is workable
  return [...cardIds, 'starter-listen', 'starter-listen', 'starter-protest'];
};

// Shuffle in place (Fisher-Yates).
window.shuffle = function (arr) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
};
