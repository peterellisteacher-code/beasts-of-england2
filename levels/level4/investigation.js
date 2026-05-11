/* =================================================================
   Act IV — Two-track investigation
   Track A: harness-room (windmill plans) — Snowball's vision.
   Track B: Mollie's stall — Clover's quiet investigation.
   Click hotspots to discover. Some discoveries earn Suspicion cards.
   ================================================================= */

'use strict';

(function () {

// === Hotspot definitions ===================================================
// Each hotspot: { id, track, title, body (verbatim or close-paraphrase from Ch5),
//                 card?: { id, type, name, body, cost } if it earns a card }
const HOTSPOTS = {
  // === TRACK A — Harness-room ===
  'A1': {
    track: 'windmill',
    title: 'The central drawing',
    body: '"The windmill itself was to be three storeys high, with a great spinning sail to be turned by the wind." Snowball has chalked it across the floor in painstaking detail. The proportions are correct; Snowball has read three books from the farmhouse to learn this.'
  },
  'A2': {
    track: 'windmill',
    title: 'Crank, dynamo, cables',
    body: '"It would supply electricity to the stalls and would warm them in winter; it would also turn the threshing-machine, the chaff-cutter, the root-slicer, the milking-machine, and the electric shearer." A future of less labour for every animal.',
    card: { id: 'L4-3', type: 'suspicion', name: 'Save the Plans on Paper',
            body: 'The windmill drawing is on the floor. Trace it onto something portable.', cost: 2 }
  },
  'A3': {
    track: 'windmill',
    title: 'Marginalia in pig\'s hand',
    body: '"Three years to build it. Then a shorter working week, even for the hens." A note in Snowball\'s own crooked writing, pencilled at the edge of the chalk drawing.'
  },
  'A4': {
    track: 'windmill',
    title: 'A wet patch in the corner',
    body: '"Napoleon had said no word, but he had stood looking sideways at Snowball\'s drawings, and then, without saying anything, he lifted his leg, urinated over the plans, and walked out." (Ch5) The animals who saw it have not spoken of it.',
    card: { id: 'L4-2', type: 'suspicion', name: 'Where Are the Puppies?',
            body: 'Napoleon took them in Chapter III. They are about to return.', cost: 2 }
  },

  // === TRACK B — Mollie's stall ===
  'B1': {
    track: 'mollie',
    title: 'A looking-glass on the wall',
    body: 'A small mirror, taken from somewhere in the farmhouse — perhaps Mrs. Jones\'s dressing-table the day after the Rebellion. Mollie has been spending whole afternoons before it, "flirting her long tail."'
  },
  'B2': {
    track: 'mollie',
    title: 'A pile of straw — and what it hides',
    body: '"A thought struck Clover. Without saying anything to the others, she went to Mollie\'s stall and turned over the straw with her hoof. Hidden under the straw was a little pile of lump sugar and several bunches of ribbon of different colours." (Ch5) The defection is already organised.',
    card: { id: 'L4-1', type: 'suspicion', name: 'The Hidden Sugar',
            body: 'Mollie\'s defection is not an accident. It is a pattern.', cost: 1 }
  },
  'B3': {
    track: 'mollie',
    title: 'The window onto the field',
    body: '"This morning I saw you looking over the hedge that divides Animal Farm from Foxwood. One of Mr. Pilkington\'s men was standing on the other side of the hedge — and I am almost certain I saw this — he was talking to you and you were allowing him to stroke your nose." (Clover, Ch5)',
    card: { id: 'L4-4', type: 'suspicion', name: 'Pilkington\'s Man Stroked Her Nose',
            body: 'Mollie\'s defection started weeks earlier. The neighbours have been waiting.', cost: 1 }
  },
  'B4': {
    track: 'mollie',
    title: 'The stall door, half open',
    body: '"Three days later Mollie disappeared. For some weeks nothing was known of her whereabouts, then the pigeons reported that they had seen her on the other side of Willingdon. She was between the shafts of a smart dogcart painted red and black, which was standing outside a public-house."'
  }
};

const TOTAL_HOTSPOTS = Object.keys(HOTSPOTS).length;

// === DOM refs ==============================================================
const els = {};
['briefing-dialog','enter-investigation','tab-windmill','tab-mollie',
 'track-windmill','track-mollie','findings-list','card-tally','findings-progress',
 'finish-btn','finding-dialog','finding-title','finding-body','finding-card-line',
 'finding-continue','hud-polite','hud-assertive']
  .forEach(id => els[id] = document.getElementById(id));

// === State =================================================================
const state = {
  found: new Set(),
  cards: []
};

// === Helpers ===============================================================
function announce(msg, assertive=false) {
  const el = assertive ? els['hud-assertive'] : els['hud-polite'];
  if (el) el.textContent = msg;
}

function persistCard(card) {
  const deck = JSON.parse(localStorage.getItem('animalDeck') || '[]');
  if (deck.find(c => c.id === card.id)) return;
  deck.push({ id: card.id, level: 4, type: card.type, name: card.name, body: card.body });
  try { localStorage.setItem('animalDeck', JSON.stringify(deck)); } catch(e) {}
}

// === Tab switching =========================================================
function switchTrack(name) {
  document.querySelectorAll('.tab').forEach(t => {
    const active = t.dataset.track === name;
    t.classList.toggle('active', active);
    t.setAttribute('aria-selected', active ? 'true' : 'false');
  });
  document.querySelectorAll('.track').forEach(t => {
    t.classList.toggle('active', t.id === `track-${name}`);
  });
  announce(`Switched to ${name === 'windmill' ? 'the harness-room' : 'Mollie\'s stall'}.`);
}

// === Hotspot handling ======================================================
function handleHotspot(btn) {
  const id = btn.dataset.id;
  const hot = HOTSPOTS[id];
  if (!hot || state.found.has(id)) return;

  state.found.add(id);
  btn.classList.add('found');

  // Add to findings list
  const empty = els['findings-list'].querySelector('.findings-empty');
  if (empty) empty.remove();
  const li = document.createElement('li');
  li.className = 'finding-entry';
  li.innerHTML = `<span class="finding-title">${id} · ${hot.title}</span>${hot.body.slice(0, 110)}${hot.body.length > 110 ? '…' : ''}`;
  els['findings-list'].appendChild(li);

  // Award card if any
  if (hot.card) {
    state.cards.push(hot.card);
    persistCard(hot.card);
    const cli = document.createElement('li');
    cli.textContent = hot.card.name;
    els['card-tally'].appendChild(cli);
    announce(`${hot.card.name} added to your deck.`, true);
  }

  // Update progress
  els['findings-progress'].textContent =
    `${state.found.size} of ${TOTAL_HOTSPOTS} hotspots inspected · ${state.cards.length} cards earned`;

  // Enable finish button after at least 4 hotspots inspected
  if (state.found.size >= 4) els['finish-btn'].disabled = false;

  // Show finding modal
  els['finding-title'].textContent = hot.title;
  els['finding-body'].textContent = hot.body;
  if (hot.card) {
    els['finding-card-line'].textContent = `★ Card earned: ${hot.card.name} — "${hot.card.body}"`;
    els['finding-card-line'].classList.add('show');
  } else {
    els['finding-card-line'].classList.remove('show');
  }
  els['finding-dialog'].showModal();
}

function finish() {
  const completed = JSON.parse(localStorage.getItem('completedLevels') || '[]');
  if (!completed.includes(4)) completed.push(4);
  try { localStorage.setItem('completedLevels', JSON.stringify(completed)); } catch(e) {}
  window.location.href = '../level-select/index.html';
}

// === Boot ==================================================================
function boot() {
  // Make sure the default tab is visually active (CSS .active class)
  switchTrack('windmill');
  els['briefing-dialog'].showModal();
  els['enter-investigation'].addEventListener('click', () => els['briefing-dialog'].close());
  els['tab-windmill'].addEventListener('click', () => switchTrack('windmill'));
  els['tab-mollie'].addEventListener('click', () => switchTrack('mollie'));
  document.querySelectorAll('.hotspot').forEach(b => {
    b.addEventListener('click', () => handleHotspot(b));
  });
  els['finding-continue'].addEventListener('click', () => els['finding-dialog'].close());
  els['finish-btn'].addEventListener('click', finish);
}
if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
else boot();

})();
