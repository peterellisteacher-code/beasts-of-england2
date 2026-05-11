/* =================================================================
   Act II — Squealer's milk-and-apples speech (Ch3, verbatim).
   Player listens line by line; after loaded lines, picks the
   rhetorical move from a multiple-choice tray.
   ================================================================= */

'use strict';

(function () {

// === Squealer's speech, broken into beats ============================
// Each beat: { text (verbatim or close paraphrase from Ch3),
//              move?: id of the rhetorical move it deploys (null = no move),
//              card: { id, type, name, body } generated card if spotted }
const BEATS = [
  { text: '"Comrades!" he cried. "You do not imagine, I hope, that we pigs are doing this in a spirit of selfishness and privilege?"',
    move: 'pre-emption',
    card: { id: 'L2-1', type: 'rhetoric', name: 'Expose the Pre-emption',
            body: '"You do not imagine, I hope" — name the move.', cost: 1 } },

  { text: '"Many of us actually dislike milk and apples. I dislike them myself."',
    move: 'false-sacrifice',
    card: { id: 'L2-2', type: 'rhetoric', name: 'Refuse the False Sacrifice',
            body: '"Many of us actually dislike milk and apples." Disprove it.', cost: 1 } },

  { text: '"Our sole object in taking these things is to preserve our health."',
    move: null },

  { text: '"Milk and apples (this has been proved by Science, comrades) contain substances absolutely necessary to the well-being of a pig."',
    move: 'authority-appeal',
    card: { id: 'L2-4', type: 'rhetoric', name: 'Question the Authority',
            body: '"This has been proved by Science." Whose science? Where?', cost: 1 } },

  { text: '"We pigs are brain-workers. The whole management and organisation of this farm depend on us. Day and night we are watching over your welfare."',
    move: null },

  { text: '"It is for your sake that we drink that milk and eat those apples."',
    move: 'false-altruism',
    card: { id: 'L2-5', type: 'rhetoric', name: 'Reverse the Charity',
            body: '"It is for your sake." It is for theirs.', cost: 1 } },

  { text: '"Do you know what would happen if we pigs failed in our duty? Jones would come back! Yes, Jones would come back!"',
    move: 'threat',
    card: { id: 'L2-3', type: 'rhetoric', name: 'Refuse the Threat',
            body: '"Jones would come back!" — but Jones is not at the gate.', cost: 2 } },

  { text: '"Surely, comrades, surely there is no one among you who wants to see Jones come back?"',
    move: null }
];

// All possible moves shown as buttons for each loaded beat.
const ALL_MOVES = [
  { id: 'pre-emption',      label: 'Pre-empts the objection' },
  { id: 'false-sacrifice',  label: 'Claims false personal sacrifice' },
  { id: 'authority-appeal', label: 'Appeals to authority ("Science")' },
  { id: 'false-altruism',   label: 'Reverses charity ("for your sake")' },
  { id: 'threat',           label: 'Threatens with Jones' },
  { id: 'status-claim',     label: 'Claims status ("brain-workers")' }
];

// === DOM refs ========================================================
const els = {};
['briefing-dialog','enter-speech','transcript','prompt-tray','move-buttons',
 'next-line-btn','tally-list','tally-progress','continue-zone','finish-btn',
 'hud-polite','hud-assertive']
  .forEach(id => els[id] = document.getElementById(id));

// === State ===========================================================
const state = {
  beatIndex: -1,
  spotted: [],     // card objects collected
  awaiting: false  // true while waiting for player to identify a move
};

// === Helpers =========================================================
function announce(msg, assertive=false) {
  const el = assertive ? els['hud-assertive'] : els['hud-polite'];
  if (el) el.textContent = msg;
}

function renderTally() {
  els['tally-list'].innerHTML = '';
  state.spotted.forEach(c => {
    const li = document.createElement('li');
    li.textContent = c.name;
    els['tally-list'].appendChild(li);
  });
  const loaded = BEATS.filter(b => b.move).length;
  els['tally-progress'].textContent = `${state.spotted.length} of ${loaded} moves spotted`;
  if (state.beatIndex >= BEATS.length - 1) {
    els['continue-zone'].hidden = false;
    els['next-line-btn'].style.display = 'none';
  }
}

function showLine(text, klass='unheard') {
  const p = document.createElement('p');
  p.className = `line ${klass}`;
  p.textContent = text;
  els['transcript'].appendChild(p);
  els['transcript'].scrollTop = els['transcript'].scrollHeight;
  return p;
}

function showPromptForBeat(beat, lineEl) {
  state.awaiting = true;
  // Hide tray first then re-render with shuffled buttons
  els['prompt-tray'].classList.add('show');
  els['move-buttons'].innerHTML = '';
  // Show 4 distractors + 1 correct
  const correct = ALL_MOVES.find(m => m.id === beat.move);
  const distractors = ALL_MOVES.filter(m => m.id !== beat.move);
  // Pick 3 random distractors
  const picks = [correct, ...shuffle(distractors).slice(0, 3)];
  shuffle(picks);
  picks.forEach(m => {
    const b = document.createElement('button');
    b.className = 'move-btn';
    b.type = 'button';
    b.textContent = m.label;
    b.dataset.id = m.id;
    b.addEventListener('click', () => handleMoveClick(b, beat, lineEl));
    els['move-buttons'].appendChild(b);
  });
  // Disable next-line button until they answer or skip
  els['next-line-btn'].disabled = false;
  els['next-line-btn'].textContent = 'Skip ⇢';
}

function handleMoveClick(btn, beat, lineEl) {
  const id = btn.dataset.id;
  if (id === beat.move) {
    btn.classList.add('correct');
    // Spotted! Tag the line + collect card.
    lineEl.classList.add('spotted');
    const tag = document.createElement('span');
    tag.className = 'move-tag';
    tag.textContent = beat.move.replace(/-/g, ' ').toUpperCase();
    lineEl.appendChild(tag);
    state.spotted.push(beat.card);
    persistCard(beat.card);
    announce(`${beat.card.name} added to your deck.`);
    renderTally();
    // Auto-advance after short pause
    setTimeout(() => {
      els['prompt-tray'].classList.remove('show');
      state.awaiting = false;
      els['next-line-btn'].textContent = 'Listen ⇢';
      // Auto-advance
      advance();
    }, 700);
  } else {
    btn.classList.add('wrong');
    setTimeout(() => btn.classList.remove('wrong'), 280);
  }
}

function persistCard(card) {
  const deck = JSON.parse(localStorage.getItem('animalDeck') || '[]');
  // Only add if not already present
  if (deck.find(c => c.id === card.id)) return;
  deck.push({ id: card.id, level: 2, type: card.type, name: card.name, body: card.body });
  localStorage.setItem('animalDeck', JSON.stringify(deck));
}

function advance() {
  if (state.awaiting) {
    // skip the prompt — mark as missed
    const beat = BEATS[state.beatIndex];
    const lines = els['transcript'].querySelectorAll('.line');
    const lineEl = lines[lines.length - 1];
    lineEl.classList.add('missed');
    const tag = document.createElement('span');
    tag.className = 'move-tag';
    tag.textContent = `MISSED: ${beat.move.replace(/-/g, ' ').toUpperCase()}`;
    lineEl.appendChild(tag);
    els['prompt-tray'].classList.remove('show');
    state.awaiting = false;
    els['next-line-btn'].textContent = 'Listen ⇢';
  }

  // Move to the next beat
  state.beatIndex++;
  if (state.beatIndex >= BEATS.length) {
    // Speech complete
    showLine('— Squealer concludes. The animals are silent. —', 'heard');
    els['next-line-btn'].style.display = 'none';
    els['continue-zone'].hidden = false;
    renderTally();
    return;
  }
  const beat = BEATS[state.beatIndex];
  const lineEl = showLine(beat.text, 'heard');
  if (beat.move) showPromptForBeat(beat, lineEl);
}

function shuffle(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

// === Boot ============================================================
function boot() {
  els['briefing-dialog'].showModal();
  els['enter-speech'].addEventListener('click', () => {
    els['briefing-dialog'].close();
    advance();  // first beat
  });
  els['next-line-btn'].addEventListener('click', advance);
  els['finish-btn'].addEventListener('click', () => {
    const completed = JSON.parse(localStorage.getItem('completedLevels') || '[]');
    if (!completed.includes(2)) completed.push(2);
    localStorage.setItem('completedLevels', JSON.stringify(completed));
    window.location.href = '../level-select/index.html';
  });
  renderTally();
}
if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
else boot();

})();
