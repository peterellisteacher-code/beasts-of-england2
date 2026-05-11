/* =================================================================
   Act III — Battle of the Cowshed
   Three timing-based waves following the canonical structure.
   ================================================================= */

'use strict';

(function () {

const STRIKE_ZONE_LEFT = 0.28;   // 28% — left edge of strike zone
const STRIKE_ZONE_RIGHT = 0.36;  // 36% — right edge

// === Wave script ============================================================
// Each wave: { label, narration, enemies: [{ type, label, icon, speed (s) }],
//              card: { id, type, name, body, cost } awarded if successful }
// Sprite-based enemies. Mr. Jones uses the actual King-Human sprite from KP.
// Other enemies are styled silhouettes (silk-screen look) — keeping aesthetic consistency.
const WAVES = [
  {
    label: 'WAVE I — The Skirmishers',
    narration: 'Pigeons and geese swoop and bite. Snowball: "Drive them off — but do not engage." The men hesitate.',
    enemies: [
      { type: 'man', label: 'STABLE BOY', sprite: null, speed: 5 },
      { type: 'man', label: 'FARMHAND',   sprite: null, speed: 4.5 },
      { type: 'man', label: 'FARMHAND',   sprite: null, speed: 4 },
    ],
    card: { id: 'L3-3', type: 'tactic', name: 'Coordinate',
            body: 'Pigeons, geese, sheep — each in formation.', cost: 2 }
  },
  {
    label: 'WAVE II — The Feigned Retreat',
    narration: 'Snowball orders the animals back into the yard. The men press forward with whoops, thinking they have won.',
    enemies: [
      { type: 'man',   label: 'PILKINGTON\'S MAN', sprite: null, speed: 3.5 },
      { type: 'jones', label: 'MR. JONES',
        sprite: '../../assets/sprites/king-human/jones-idle.png',
        spriteFrame: 0, spriteWidth: 96, spriteHeight: 96, totalFrames: 11, speed: 3 },
    ],
    card: { id: 'L3-2', type: 'tactic', name: 'Feint',
            body: 'Snowball used this at the Cowshed. Use it again.', cost: 1 }
  },
  {
    label: 'WAVE III — The Cowshed Ambush',
    narration: 'The cows, sheep and three horses charge from inside the cowshed. Boxer rears up. The dogs are at his hooves.',
    enemies: [
      { type: 'dog', label: 'DOG', sprite: null, speed: 2.5 },
      { type: 'dog', label: 'DOG', sprite: null, speed: 2.4 },
      { type: 'jones', label: 'MR. JONES',
        sprite: '../../assets/sprites/king-human/jones-idle.png',
        spriteFrame: 0, spriteWidth: 96, spriteHeight: 96, totalFrames: 11, speed: 2.2 },
    ],
    card: { id: 'L3-1', type: 'tactic', name: 'Hold the Door',
            body: 'A defensive stance. Buys time.', cost: 2 }
  }
];

// === DOM refs ==============================================================
const els = {};
['briefing-dialog','enter-battle','wave-label','wave-narration','wave-num',
 'arena','enemy-track','strike-zone','boxer','action-btn','action-hint','action-sub',
 'card-tally','hp-fill','outcome-dialog','outcome-title','outcome-body','outcome-stats',
 'restart-battle','hud-polite','hud-assertive']
  .forEach(id => els[id] = document.getElementById(id));

// === State =================================================================
const state = {
  waveIdx: -1,
  hp: 100,
  cardsEarned: [],
  totalKills: 0,
  totalEscapes: 0,
  waveEscapes: 0,
  enemiesInPlay: [],
  spawnTimer: 0,
  waveStartTime: 0,
  waveEnemyIdx: 0,
  waitingForNextWave: false
};

// === Helpers ===============================================================
function announce(msg, assertive=false) {
  const el = assertive ? els['hud-assertive'] : els['hud-polite'];
  if (el) el.textContent = msg;
}

function renderTally() {
  els['card-tally'].innerHTML = '';
  state.cardsEarned.forEach(c => {
    const li = document.createElement('li');
    li.textContent = c.name;
    els['card-tally'].appendChild(li);
  });
  els['hp-fill'].style.width = state.hp + '%';
  els['hp-fill'].className = 'hp-fill';
  if (state.hp < 60) els['hp-fill'].classList.add('warning');
  if (state.hp < 30) els['hp-fill'].classList.add('danger');
}

// === Wave management =======================================================
function startNextWave() {
  state.waveIdx++;
  if (state.waveIdx >= WAVES.length) {
    finishBattle();
    return;
  }
  const wave = WAVES[state.waveIdx];
  els['wave-label'].textContent = wave.label;
  els['wave-narration'].textContent = wave.narration;
  document.getElementById('wave-num').textContent = `${state.waveIdx + 1} / 3`;
  state.waveEnemyIdx = 0;
  state.waveEscapes = 0;
  state.spawnTimer = 0;
  state.waveStartTime = performance.now();
  state.waitingForNextWave = false;

  els['action-btn'].disabled = false;
  els['action-hint'].textContent = '— prepare —';
  announce(wave.label, true);

  // Spawn first enemy after short delay
  setTimeout(() => spawnNextEnemy(), 800);
}

function spawnNextEnemy() {
  const wave = WAVES[state.waveIdx];
  if (state.waveEnemyIdx >= wave.enemies.length) return;
  const def = wave.enemies[state.waveEnemyIdx++];

  const e = document.createElement('div');
  e.className = `enemy ${def.type}`;
  if (def.sprite) {
    // Use animated sprite frame (first frame as static — animating mid-transit is overkill)
    e.innerHTML = `<div class="enemy-sprite" style="background-image:url('${def.sprite}'); background-size: ${def.totalFrames * 100}% 100%; background-position: 0% 0%;" aria-hidden="true"></div><span class="label">${def.label}</span>`;
  } else {
    // Styled silhouette — clean vector look, no emoji
    e.innerHTML = `<div class="enemy-silhouette enemy-silhouette-${def.type}" aria-hidden="true"></div><span class="label">${def.label}</span>`;
  }
  e.style.left = '100%';
  e.style.transition = `left ${def.speed}s linear`;
  els['arena'].appendChild(e);

  // Force reflow then animate to left edge
  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      e.style.left = '14%';   // ends at Boxer's position (left of cowshed)
    });
  });

  const enemy = { el: e, def, spawnedAt: performance.now(), hit: false, escaped: false };
  state.enemiesInPlay.push(enemy);

  // Schedule next spawn
  if (state.waveEnemyIdx < wave.enemies.length) {
    setTimeout(() => spawnNextEnemy(), 1200 + Math.random() * 800);
  }

  // Schedule arrival check
  setTimeout(() => {
    if (!enemy.hit && !enemy.escaped) {
      // Enemy reached Boxer — damage cowshed, remove
      enemy.escaped = true;
      enemy.el.classList.add('escaped');
      state.hp = Math.max(0, state.hp - 18);
      state.totalEscapes++;
      state.waveEscapes++;
      renderTally();
      announce('An attacker reached the cowshed!', true);
      setTimeout(() => enemy.el.remove(), 360);
      checkWaveEnd();
    }
  }, def.speed * 1000);
}

function attemptStrike() {
  if (state.waitingForNextWave || state.waveIdx < 0) return;
  // Find any enemy currently in the strike zone
  const arenaW = els['arena'].clientWidth;
  let target = null;
  let bestDist = Infinity;
  state.enemiesInPlay.forEach(en => {
    if (en.hit || en.escaped) return;
    const r = en.el.getBoundingClientRect();
    const arenaR = els['arena'].getBoundingClientRect();
    const centerX = (r.left + r.right) / 2 - arenaR.left;
    const centerPct = centerX / arenaW;
    if (centerPct >= STRIKE_ZONE_LEFT && centerPct <= STRIKE_ZONE_RIGHT) {
      const distFromCenter = Math.abs(centerPct - (STRIKE_ZONE_LEFT + STRIKE_ZONE_RIGHT) / 2);
      if (distFromCenter < bestDist) { bestDist = distFromCenter; target = en; }
    }
  });

  // Boxer animation
  els['boxer'].classList.remove('attacking');
  void els['boxer'].offsetWidth;
  els['boxer'].classList.add('attacking');

  if (target) {
    target.hit = true;
    target.el.classList.add('hit');
    state.totalKills++;
    setTimeout(() => target.el.remove(), 320);
    announce(`${target.def.label} struck down.`);
    checkWaveEnd();
  } else {
    // Miss — small penalty
    state.hp = Math.max(0, state.hp - 4);
    renderTally();
    announce('Miss — Boxer strikes the empty air.');
  }
}

function checkWaveEnd() {
  const wave = WAVES[state.waveIdx];
  // Wave ends when all enemies have been hit or escaped
  const allDone = state.waveEnemyIdx >= wave.enemies.length &&
                  state.enemiesInPlay.every(en => en.hit || en.escaped);
  if (allDone && !state.waitingForNextWave) {
    state.waitingForNextWave = true;
    state.enemiesInPlay = [];

    // Award card if at most 1 enemy escaped this wave
    const earnedCard = state.waveEscapes < 2;
    if (earnedCard && wave.card) {
      state.cardsEarned.push(wave.card);
      persistCard(wave.card);
      announce(`${wave.card.name} added to your deck.`, true);
    }
    renderTally();

    if (state.hp <= 0) {
      setTimeout(finishBattle, 800);
      return;
    }

    setTimeout(() => {
      els['wave-label'].textContent = '— wave clear —';
      els['wave-narration'].textContent = 'A pause. The animals catch their breath.';
      setTimeout(() => startNextWave(), 1500);
    }, 800);
  }
}

function finishBattle() {
  els['action-btn'].disabled = true;
  els['action-hint'].textContent = '— battle over —';

  let title, body;
  if (state.hp >= 80 && state.cardsEarned.length === 3) {
    title = 'Famous Victory';
    body = '<p>The men have fled. Snowball is awarded "Animal Hero, First Class" for his wound and his strategy. Boxer wears a brass medallion. The Battle of the Cowshed enters the farm\'s mythology — for now, accurately.</p>';
  } else if (state.hp >= 50) {
    title = 'A Costly Win';
    body = '<p>The men retreat over the broken hedge. The cowshed door hangs by one hinge. A sheep lies dead on the dung-heap. The animals are victorious — but the victory feels narrower than Snowball will later remember it.</p>';
  } else {
    title = 'A Pyrrhic Defence';
    body = '<p>The cowshed is half-burned. The men leave when they tire of it, not when the animals defeat them. Snowball is wounded; Boxer is exhausted. Napoleon, who took no part, watches from the loft window.</p>';
  }

  els['outcome-title'].textContent = title;
  els['outcome-body'].innerHTML = body;
  els['outcome-stats'].innerHTML =
    `Kills: <strong>${state.totalKills}</strong> · ` +
    `Cowshed integrity: <strong>${state.hp}%</strong> · ` +
    `Cards earned: <strong>${state.cardsEarned.length}</strong>`;

  const completed = JSON.parse(localStorage.getItem('completedLevels') || '[]');
  if (!completed.includes(3)) completed.push(3);
  try { localStorage.setItem('completedLevels', JSON.stringify(completed)); } catch(e) {}

  els['outcome-dialog'].showModal();
}

function persistCard(card) {
  const deck = JSON.parse(localStorage.getItem('animalDeck') || '[]');
  if (deck.find(c => c.id === card.id)) return;
  deck.push({ id: card.id, level: 3, type: card.type, name: card.name, body: card.body });
  try { localStorage.setItem('animalDeck', JSON.stringify(deck)); } catch(e) {}
}

// === Boot ==================================================================
function boot() {
  els['briefing-dialog'].showModal();
  els['enter-battle'].addEventListener('click', () => {
    els['briefing-dialog'].close();
    renderTally();
    setTimeout(() => startNextWave(), 600);
  });
  els['action-btn'].addEventListener('click', attemptStrike);
  document.addEventListener('keydown', (e) => {
    if (e.code === 'Space') { e.preventDefault(); attemptStrike(); }
  });
  els['restart-battle'].addEventListener('click', () => window.location.reload());
}
if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
else boot();

})();
