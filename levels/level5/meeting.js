/* =================================================================
   meeting.js — Act V turn loop, adversary AI, outcome resolution.
   ================================================================= */

'use strict';

(function () {

const MAX_TURNS = 7;
const DOG_ARRIVAL = 6;   // dog clock threshold — arrival fires before MAX_TURNS
const MAX_CONVICTION = 3;
const HAND_SIZE = 5;

// === Game state ==========================================================
const state = {
  turn: 1,
  conviction: MAX_CONVICTION,
  sympathy: 50,           // 0–100 — how much of the meeting still listens to Snowball
  memory: 100,            // 0–100 — how much of the original principles will outlive this meeting
  dogClock: 0,            // dogs arrive at DOG_ARRIVAL
  napoleonPower: 30,      // accumulating force; high = adversary moves do more damage
  adversaryNextDamage: 0, // pending damage from telegraphed move
  savedPlans: false,
  cardsPlayed: 0,
  reshuffleCount: 0,
  deck: [],
  hand: [],
  discard: [],
  ended: false,
  log: addLog,
};

// === Adversary script ====================================================
// Each turn the adversary takes a telegraphed move. Cycle: Squealer → Napoleon-silent → Dogs-approach.
const ADVERSARY_SCRIPT = [
  {
    speaker: 'Squealer',
    intent: '"Comrades, you do not imagine —"',
    moves: [
      'Pre-emptive defence ("you do not imagine")',
      'False sacrifice ("we pigs dislike milk and apples")',
      'Threat ("Jones would come back!")'
    ],
    apply(s) {
      // Squealer scales with Napoleon's accumulated power — the longer Napoleon
      // has been silent, the harder Squealer's threat lands.
      const base = 15 + Math.floor(s.napoleonPower / 10);
      const dmg = max(0, base - s.adversaryNextDamage);
      s.sympathy = clamp(s.sympathy - dmg, 0, 100);
      addLog('adversary', `Squealer skips and frisks. The threat lands. (−${dmg} sympathy)`);
      s.adversaryNextDamage = 0;
    }
  },
  {
    speaker: 'Napoleon',
    intent: '— silence —',
    moves: ['Gathers power off-stage'],
    apply(s) {
      const gain = 8 + Math.floor(s.napoleonPower / 6);
      s.napoleonPower += gain;
      // Napoleon's silent turn brings the dogs significantly closer
      s.dogClock = clamp(s.dogClock + 2, 0, MAX_TURNS);
      addLog('adversary', `Napoleon does not speak. The pile of his power grows. (+${gain} power, dogs +2)`);
    }
  },
  {
    speaker: 'The Dogs',
    intent: 'Padding closer.',
    moves: ['Audible at the gate', 'Audible at the door', 'In the doorway'],
    apply(s) {
      s.dogClock = clamp(s.dogClock + 2, 0, MAX_TURNS);
      addLog('dog', 'The padding of paws on packed earth grows louder. (dogs +2)');
    }
  }
];

// === Snowball script — what he says each turn (Ch5-grounded) ==============
const SNOWBALL_SCRIPT = [
  'Comrades — the windmill will provide power for our farm.',
  'It will warm our stalls in winter. It will save our backs the haulage.',
  'The plans on the floor are mine. I have studied Mr. Jones\'s books from the farmhouse.',
  'Three years to build. Then a shorter working week, even for the hens.',
  'Comrades, I beg you — listen.',
  'I see Napoleon does not answer. Why does he not answer?',
  '— Snowball stops mid-sentence —'
];

// === Snowball outcome lines per ending ====================================
const ENDING_LINES = {
  bronze: {
    title: 'Bronze — The Exile',
    body: '<p>Napoleon stands. The dogs are inside the barn before anyone has time to look round. Snowball runs through the five-barred gate as though he had been doing it for weeks. The drawing of the windmill on the harness-room floor is rubbed out within the hour. The animals find that the matter is closed.</p><p>The principles you tried to invoke do not survive the silence afterwards.</p>'
  },
  silver: {
    title: 'Silver — The Memory Held',
    body: '<p>Napoleon stands. The dogs come. Snowball escapes — bleeding, but alive — through the orchard.</p><p>One of the cows looks at the others. "I do not think that is what we agreed," she says, quietly, hours later. The matter is closed in the meeting; it is not closed in her head.</p>'
  },
  gold: {
    title: 'Gold — The Plans Survived',
    body: '<p>Napoleon stands. The dogs come. But before they enter the barn you have already smuggled the windmill drawing onto a sheet from the harness-room and hidden it under the loose floor-board.</p><p>Snowball escapes through the orchard. Three animals — Clover, Benjamin, the hen with the white feather — are openly skeptical for weeks. The drawing will be found again. The principles will be remembered, even when the words on the wall change.</p>'
  }
};

// === DOM elements ========================================================
const els = {};
function $(id) { return document.getElementById(id); }
['turn-num','turn-max','conviction-fill','conviction-label','sympathy-fill','sympathy-label',
 'memory-fill','memory-label','dog-fill','dog-status','adversary-name','adversary-intent',
 'adversary-moves','snowball-line','log-window','hand-cards','deck-remaining','discard-count',
 'end-turn-btn','briefing-dialog','enter-meeting','outcome-dialog','outcome-title',
 'outcome-body','final-sympathy','final-memory','cards-played','restart-meeting']
  .forEach(id => els[id] = $(id));

// === Helpers ============================================================
function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }
function max(a, b) { return Math.max(a, b); }

function addLog(kind, text) {
  const p = document.createElement('p');
  p.className = 'log-line ' + kind;
  p.textContent = text;
  els['log-window'].appendChild(p);
  els['log-window'].scrollTop = els['log-window'].scrollHeight;
}

function announce(msg) {
  const el = $('hud-polite');
  if (el) el.textContent = msg;
}

// === Deck management ====================================================
function dealHand() {
  while (state.hand.length < HAND_SIZE && (state.deck.length > 0 || state.discard.length > 0)) {
    if (state.deck.length === 0) {
      state.deck = window.shuffle([...state.discard]);
      state.discard = [];
      if (state.reshuffleCount === 0) {
        addLog('narrator', 'You shuffle your remembered moves back into your hand.');
      }
      state.reshuffleCount++;
    }
    state.hand.push(state.deck.pop());
  }
  renderHand();
  renderResources();
}

function renderHand() {
  const c = els['hand-cards'];
  c.innerHTML = '';
  state.hand.forEach((cardId, idx) => {
    const def = window.CARD_DEFINITIONS[cardId];
    if (!def) return;
    const card = document.createElement('div');
    card.className = 'card';
    card.dataset.idx = idx;
    card.dataset.costTooHigh = def.cost > state.conviction ? 'true' : 'false';
    card.tabIndex = 0;
    card.setAttribute('role', 'button');
    card.setAttribute('aria-label', `${def.name}, costs ${def.cost} conviction. ${def.body}`);
    card.innerHTML = `
      <span class="cost-pip">${def.cost}</span>
      <div class="card-type" data-type="${def.type}">${def.type}</div>
      <h3 class="card-name">${def.name}</h3>
      <div class="card-body">${def.body}</div>
      <div class="card-effect">▶ tap to play</div>
    `;
    card.addEventListener('click', () => playCard(idx));
    card.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); playCard(idx); } });
    c.appendChild(card);
  });
  els['deck-remaining'].textContent = state.deck.length;
  els['discard-count'].textContent = state.discard.length;
}

function playCard(idx) {
  const cardId = state.hand[idx];
  const def = window.CARD_DEFINITIONS[cardId];
  if (!def) return;
  if (def.cost > state.conviction) {
    announce('Not enough conviction.');
    return;
  }
  const cardEl = els['hand-cards'].querySelector(`.card[data-idx="${idx}"]`);
  if (cardEl) cardEl.classList.add('playing');

  // Apply cost + effect
  state.conviction -= def.cost;
  state.cardsPlayed++;
  def.effect(state);

  // Remove from hand to discard after animation
  setTimeout(() => {
    state.hand.splice(idx, 1);
    state.discard.push(cardId);
    renderHand();
    renderResources();
    checkEnd();
  }, 300);
}

// === Resources rendering ================================================
function renderResources() {
  els['conviction-fill'].style.width = `${(state.conviction / MAX_CONVICTION) * 100}%`;
  els['conviction-label'].textContent = `${state.conviction} / ${MAX_CONVICTION}`;
  els['sympathy-fill'].style.width = `${state.sympathy}%`;
  els['sympathy-label'].textContent = `${Math.round(state.sympathy)} %`;
  els['memory-fill'].style.width = `${state.memory}%`;
  els['memory-label'].textContent = `${Math.round(state.memory)} %`;
  els['dog-fill'].style.width = `${Math.min(100, (state.dogClock / DOG_ARRIVAL) * 100)}%`;
  els['dog-status'].textContent =
    state.dogClock < 2 ? '— not yet released —' :
    state.dogClock < 4 ? '— audible at the gate —' :
    state.dogClock < 6 ? '— inside the yard —' : '— at the door —';
}

// === Turn loop ==========================================================
function startTurn() {
  els['turn-num'].textContent = state.turn;
  els['turn-max'].textContent = MAX_TURNS;
  state.conviction = MAX_CONVICTION;

  // Snowball speaks
  els['snowball-line'].textContent = SNOWBALL_SCRIPT[Math.min(state.turn - 1, SNOWBALL_SCRIPT.length - 1)];

  // Adversary telegraphs next move
  const idx = (state.turn - 1) % ADVERSARY_SCRIPT.length;
  const adv = ADVERSARY_SCRIPT[idx];
  els['adversary-name'].textContent = adv.speaker;
  els['adversary-intent'].textContent = adv.intent;
  els['adversary-moves'].innerHTML = adv.moves.map(m => `<li>${m}</li>`).join('');

  addLog('narrator', `Turn ${state.turn}. Snowball: "${SNOWBALL_SCRIPT[Math.min(state.turn - 1, SNOWBALL_SCRIPT.length - 1)]}"`);

  dealHand();
  renderResources();
}

function endTurn() {
  if (state.ended) return;
  // Adversary resolves
  const idx = (state.turn - 1) % ADVERSARY_SCRIPT.length;
  ADVERSARY_SCRIPT[idx].apply(state);

  // Memory decays slowly each turn
  state.memory = clamp(state.memory - 4, 0, 100);

  // Discard remaining hand
  state.discard.push(...state.hand);
  state.hand = [];

  state.turn++;
  renderResources();

  if (!checkEnd()) startTurn();
}

// === End-state check ====================================================
function checkEnd() {
  if (state.ended) return true;
  // Dog clock at or above 6 — dogs arrive (changed from MAX_TURNS=7 so this end condition is reachable in normal play)
  if (state.dogClock >= DOG_ARRIVAL) {
    finish('Napoleon stands. The dogs are inside the barn before anyone can react.');
    return true;
  }
  // Out of turns
  if (state.turn > MAX_TURNS) {
    finish('Napoleon stands. The dogs come.');
    return true;
  }
  // Sympathy crashed — Snowball loses the room before the dogs even arrive
  if (state.sympathy <= 0) {
    finish('Snowball has lost the room. Napoleon does not need to call the dogs.');
    return true;
  }
  return false;
}

function finish(narrationLine) {
  state.ended = true;
  addLog('narrator', narrationLine);

  // Decide ending
  let ending = 'bronze';
  if (state.memory >= 60 && state.savedPlans) ending = 'gold';
  else if (state.memory >= 50 || state.sympathy >= 60) ending = 'silver';

  // Mark L5 complete + record ending
  const completed = JSON.parse(localStorage.getItem('completedLevels') || '[]');
  if (!completed.includes(5)) completed.push(5);
  try { localStorage.setItem('completedLevels', JSON.stringify(completed)); } catch(e) {}
  try { localStorage.setItem('finalEnding', ending); } catch(e) {}

  // Render outcome modal
  els['outcome-title'].textContent = ENDING_LINES[ending].title;
  els['outcome-body'].innerHTML = ENDING_LINES[ending].body;
  els['final-sympathy'].textContent = `${Math.round(state.sympathy)} %`;
  els['final-memory'].textContent = `${Math.round(state.memory)} %`;
  els['cards-played'].textContent = state.cardsPlayed;
  els['outcome-dialog'].showModal();
  announce(`Outcome: ${ENDING_LINES[ending].title}`);
}

// === Boot ===============================================================
function boot() {
  state.deck = window.shuffle(window.buildDeckFromStorage());

  els['briefing-dialog'].showModal();
  els['enter-meeting'].addEventListener('click', () => {
    els['briefing-dialog'].close();
    startTurn();
  });
  els['end-turn-btn'].addEventListener('click', () => endTurn());
  els['restart-meeting'].addEventListener('click', () => window.location.reload());
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', boot);
} else {
  boot();
}

})();
