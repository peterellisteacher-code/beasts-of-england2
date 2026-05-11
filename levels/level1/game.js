/* =================================================================
   Beasts of England — L1: The Rebellion (Chapter II)
   Side-scrolling rebellion runner.
   Forked from LittleJS engine (KilledByAPixel/LittleJS, MIT) —
   sprites from Pixel Frog's "Kings and Pigs" pack (CC0).
   ================================================================= */

'use strict';

setShowSplashScreen(false);
setTileDefaultBleed(0.5);
setCanvasFixedSize(vec2(1280, 720));

// --- Sprite paths (textureInfos[] index in load order) ---
const SPRITES = {
  pigIdle:   { path: '../../assets/sprites/pig/pig-idle.png',           frames: 11, w: 64, h: 64 },
  pigRun:    { path: '../../assets/sprites/pig/pig-run.png',            frames: 6,  w: 64, h: 64 },
  pigJump:   { path: '../../assets/sprites/pig/pig-jump.png',           frames: 1,  w: 64, h: 64 },
  pigFall:   { path: '../../assets/sprites/pig/pig-fall.png',           frames: 1,  w: 64, h: 64 },
  jonesIdle: { path: '../../assets/sprites/king-human/jones-idle.png',  frames: 11, w: 96, h: 96 },
  jonesRun:  { path: '../../assets/sprites/king-human/jones-run.png',   frames: 8,  w: 96, h: 96 },
  jonesHit:  { path: '../../assets/sprites/king-human/jones-hit.png',   frames: 2,  w: 96, h: 96 },
  terrain:   { path: '../../assets/sprites/tiles/terrain.png',          frames: 1,  w: 32, h: 32 },
  diamond:   { path: '../../assets/sprites/effects/big-diamond-idle.png', frames: 10, w: 18, h: 14 },
  bg:        { path: '../../assets/backgrounds/bg-level1-farm.jpg',     frames: 1,  w: 1920, h: 720 },
};
const ASSET_LIST = Object.values(SPRITES).map(s => s.path);
const TEX = {};
Object.keys(SPRITES).forEach((k, i) => TEX[k] = i);

// --- Game state ---
let player, jones;
let cardsCollected = 0;
let cardsTotal = 3;
let levelComplete = false;
let cinematicShown = false;

// Animalism palette (for procedural elements)
const COL = {
  paper: hsl(0.13, 0.4, 0.88),     // paper-cream
  ink: hsl(0.1, 0.15, 0.1),        // ink-black
  red: hsl(0, 0.7, 0.36),          // propaganda-red
  green: hsl(0.32, 0.5, 0.3),      // pasture-green
  sky: hsl(0.55, 0.4, 0.6),        // morning sky
};

///////////////////////////////////////////////////////////////////////////////
// Pig — anthropomorphic upright player character
class Pig extends EngineObject {
  constructor(pos) {
    super(pos, vec2(2.0, 2.4));   // size in world units (~2 tiles tall)
    this.setCollision(true, true);
    this.gravityScale = 1;
    this.mass = 1;
    this.damping = 0.85;
    this.friction = 0.4;
    this.frame = 0;
    this.frameTime = 0;
    this.facing = 1;
    this.state = 'idle';
    this.coyoteTime = 0;
  }

  update() {
    const right = keyIsDown('ArrowRight') || keyIsDown('KeyD');
    const left  = keyIsDown('ArrowLeft')  || keyIsDown('KeyA');
    const jump  = keyWasPressed('Space')  || keyWasPressed('ArrowUp') || keyWasPressed('KeyW');

    const accel = 0.06;
    const maxSpeed = 0.32;
    if (right) { this.velocity.x = min(this.velocity.x + accel, maxSpeed);  this.facing = 1; }
    if (left)  { this.velocity.x = max(this.velocity.x - accel, -maxSpeed); this.facing = -1; }

    // Coyote time
    if (this.groundObject) this.coyoteTime = 0.15;
    else this.coyoteTime = max(0, this.coyoteTime - 1/60);

    if (jump && this.coyoteTime > 0) {
      this.velocity.y = 0.9;
      this.coyoteTime = 0;
      // Dust kick — small particle burst
      new ParticleEmitter(
        this.pos.add(vec2(0, -1)), 0,
        1, 0.1, 30, PI,
        undefined,
        hsl(0.1,0.2,0.7,1), hsl(0.1,0.1,0.5,1),
        hsl(0.1,0.2,0.7,0), hsl(0.1,0.1,0.5,0),
        0.4, 0.1, 0.2, 0.05, 0.05,
        0.95, 0.95, 0.5, PI,
        0.05, 0.5, false, false
      );
    }

    super.update();

    // Determine animation state
    if (!this.groundObject && this.velocity.y > 0.05) this.state = 'jump';
    else if (!this.groundObject && this.velocity.y < -0.05) this.state = 'fall';
    else if (abs(this.velocity.x) > 0.04) this.state = 'run';
    else this.state = 'idle';

    this.frameTime += 1/60;
    if (this.frameTime > 0.08) { this.frame++; this.frameTime = 0; }
  }

  render() {
    const stateMap = {
      idle: { tex: TEX.pigIdle, frames: SPRITES.pigIdle.frames, w: 64, h: 64 },
      run:  { tex: TEX.pigRun,  frames: SPRITES.pigRun.frames,  w: 64, h: 64 },
      jump: { tex: TEX.pigJump, frames: 1, w: 64, h: 64 },
      fall: { tex: TEX.pigFall, frames: 1, w: 64, h: 64 },
    };
    const a = stateMap[this.state] || stateMap.idle;
    const frame = this.frame % a.frames;
    const t = tile(frame, vec2(a.w, a.h), a.tex);
    drawTile(this.pos, vec2(this.size.x * (this.facing < 0 ? -1 : 1), this.size.y), t);
  }
}

///////////////////////////////////////////////////////////////////////////////
// Mr. Jones — boss / level goal
class MrJones extends EngineObject {
  constructor(pos) {
    super(pos, vec2(3.5, 3.0));
    this.setCollision(false, false);  // no physics box — win is triggered by proximity check
    this.gravityScale = 0;
    this.mass = 0;
    this.frame = 0;
    this.frameTime = 0;
    this.state = 'idle';
    this.fleeing = false;
    this.fleeStart = 0;
  }
  update() {
    super.update();
    if (this.fleeing) {
      this.velocity.x = 0.18;     // running right off-screen
      this.state = 'run';
    }
    this.frameTime += 1/60;
    if (this.frameTime > 0.1) { this.frame++; this.frameTime = 0; }
  }
  render() {
    const stateMap = {
      idle: { tex: TEX.jonesIdle, frames: SPRITES.jonesIdle.frames, w: 96, h: 96 },
      run:  { tex: TEX.jonesRun,  frames: SPRITES.jonesRun.frames,  w: 96, h: 96 },
      hit:  { tex: TEX.jonesHit,  frames: SPRITES.jonesHit.frames,  w: 96, h: 96 },
    };
    const a = stateMap[this.state] || stateMap.idle;
    const frame = this.frame % a.frames;
    const t = tile(frame, vec2(a.w, a.h), a.tex);
    // Face left when idle (looking at incoming pig), right when fleeing
    const facing = this.fleeing ? 1 : -1;
    drawTile(this.pos, vec2(this.size.x * (facing < 0 ? -1 : 1), this.size.y), t);
  }
  flee() {
    if (this.fleeing) return;
    this.fleeing = true;
    this.state = 'hit';
    setTimeout(() => { this.state = 'run'; }, 800);
  }
}

///////////////////////////////////////////////////////////////////////////////
// BannerFragment — pickup
class BannerFragment extends EngineObject {
  constructor(pos, text) {
    super(pos, vec2(1.4, 1.4));
    this.setCollision(false, false);
    this.gravityScale = 0;
    this.mass = 0;
    this.frame = 0;
    this.frameTime = 0;
    this.text = text || 'A principle of Animalism';
    this.collected = false;
    this.bobPhase = randInt(0, 100) / 50;
  }
  update() {
    super.update();
    this.frameTime += 1/60;
    if (this.frameTime > 0.1) { this.frame++; this.frameTime = 0; }
    // Bob up and down
    this.pos.y += Math.sin(time * 3 + this.bobPhase) * 0.005;
    // Check pickup
    if (!this.collected && player) {
      const d = this.pos.subtract(player.pos);
      if (d.length() < 1.4) this.collect();
    }
  }
  render() {
    if (this.collected) return;
    const t = tile(this.frame % SPRITES.diamond.frames, vec2(18, 14), TEX.diamond);
    drawTile(this.pos, this.size, t);
  }
  collect() {
    this.collected = true;
    cardsCollected++;
    updateHUD();
    announce(`Banner fragment collected: ${this.text}`);
    // Save card to localStorage
    const deck = JSON.parse(localStorage.getItem('animalDeck') || '[]');
    deck.push({ id: `L1-${cardsCollected}`, level: 1, type: 'principle', text: this.text });
    try { localStorage.setItem('animalDeck', JSON.stringify(deck)); } catch(e) {}
    // Particle burst
    new ParticleEmitter(
      this.pos, 0,
      0.5, 0.2, 60, PI,
      undefined,
      hsl(0,0.7,0.5,1), hsl(0.1,0.7,0.6,1),
      hsl(0,0.7,0.5,0), hsl(0.1,0.7,0.6,0),
      0.5, 0.15, 0.2, 0.08, 0.05,
      0.95, 1, 0.6, PI,
      0.1, 0.5, false, true
    );
    this.destroy();
  }
}

// Platform positions — shared between buildLevel() and gameRender()
const PLATFORMS = [
  [10, 5], [12, 5],
  [18, 6], [19, 6], [20, 6],
  [26, 5],
  [34, 7], [35, 7], [36, 7], [37, 7],
  [46, 5], [47, 5],
  [54, 6], [55, 6], [56, 6],
  [64, 5],
];

///////////////////////////////////////////////////////////////////////////////
// Level construction — a side-scrolling farmyard
function buildLevel() {
  // Tile collision layer — collision only; visuals drawn in gameRender()
  // LittleJS TileLayer always reads from texture 0, so we use invisible tiles
  // and paint the ground manually to avoid pig sprites appearing as terrain.
  const layer = new TileCollisionLayer(vec2(0,0), vec2(80, 24));
  const invisible = () => new TileLayerData(-1, 0, false, hsl(0,0,1,0));

  // Ground collision (y=0,1,2)
  for (let x = 0; x < 80; x++) {
    layer.setData(vec2(x, 2), invisible());
    layer.setData(vec2(x, 1), invisible());
    layer.setData(vec2(x, 0), invisible());
    layer.setCollisionData(vec2(x, 2));
    layer.setCollisionData(vec2(x, 1));
    layer.setCollisionData(vec2(x, 0));
  }

  // Platform collision
  for (const [x, y] of PLATFORMS) {
    layer.setData(vec2(x, y), invisible());
    layer.setCollisionData(vec2(x, y));
  }

  // Barn wall collision (x=78-79)
  for (let y = 3; y < 12; y++) {
    layer.setData(vec2(78, y), invisible());
    layer.setData(vec2(79, y), invisible());
    layer.setCollisionData(vec2(78, y));
    layer.setCollisionData(vec2(79, y));
  }

  layer.redraw();

  // Spawn player at left
  player = new Pig(vec2(3, 5));

  // Spawn Mr. Jones at right (just before the barn wall)
  jones = new MrJones(vec2(74, 5));

  // Spawn 3 banner fragments at strategic points
  new BannerFragment(vec2(13, 7), 'All animals are equal.');
  new BannerFragment(vec2(36, 9), 'No animal shall ever tyrannise over his own kind.');
  new BannerFragment(vec2(55, 8), 'Whatever goes upon four legs is a friend.');
}

///////////////////////////////////////////////////////////////////////////////
// HUD updates (DOM-side)
function updateHUD() {
  const el = document.getElementById('cards-collected');
  if (el) el.textContent = `Banner fragments: ${cardsCollected} / ${cardsTotal}`;
}
function announce(msg) {
  const el = document.getElementById('hud-polite');
  if (el) el.textContent = msg;
}

///////////////////////////////////////////////////////////////////////////////
// Cinematic
function showCinematic() {
  if (cinematicShown) return;
  cinematicShown = true;
  // Fade the canvas via a CSS overlay
  const cine = document.getElementById('cinematic');
  if (cine) {
    cine.classList.add('show');
    document.getElementById('cine-continue').addEventListener('click', () => {
      // Persist completion + go to level select (or refresh for now)
      const completed = JSON.parse(localStorage.getItem('completedLevels') || '[]');
      if (!completed.includes(1)) completed.push(1);
      try { localStorage.setItem('completedLevels', JSON.stringify(completed)); } catch(e) {}
      // Go to level-select hub (or stub for now)
      window.location.href = '../level-select/index.html';
    });
  }
}

///////////////////////////////////////////////////////////////////////////////
// Engine lifecycle
function gameInit() {
  setGravity(vec2(0, -0.012));
  setObjectDefaultDamping(0.99);
  setObjectDefaultAngleDamping(0.99);
  setCameraScale(48);
  setCameraPos(vec2(12, 6));
  // Background colour shows through any gaps — sky blue
  if (typeof setBackgroundColor === 'function') {
    setBackgroundColor(hsl(0.58, 0.15, 0.18));   // dark slate — background image covers this
  } else if (typeof setCanvasClearColor === 'function') {
    setCanvasClearColor(hsl(0.58, 0.15, 0.18));
  }
  buildLevel();
  updateHUD();
}

function gameUpdate() {
  // Win check — player touches Jones
  if (player && jones && !levelComplete && !jones.fleeing) {
    const d = player.pos.subtract(jones.pos);
    if (d.length() < 2.5) {
      jones.flee();
      // Slight cam shake
      setCameraPos(cameraPos.add(vec2(rand(0.1, -0.1), rand(0.1, -0.1))));
    }
  }

  // After Jones starts fleeing, show cinematic after a short delay
  if (jones && jones.fleeing) {
    if (!levelComplete) {
      levelComplete = true;
      jones.fleeStart = time;
    }
    if (time - jones.fleeStart > 0.8) showCinematic();
  }

  // Respawn if player falls out of level bounds — skip when level is already won
  if (!levelComplete && player && (player.pos.x < -1 || player.pos.x > 81 || player.pos.y < 0)) {
    player.pos = vec2(3, 5);
    player.velocity = vec2(0, 0);
  }

  // Restart key
  if (keyWasPressed('KeyR')) window.location.reload();
}

function gameUpdatePost() {
  // Camera follows player horizontally; clamp at level bounds
  if (player) {
    const target = vec2(clamp(player.pos.x, 12, 74), 6);
    setCameraPos(cameraPos.lerp(target, 0.08));
  }
}

function gameRender() {
  // Illustrated farm background — always centred on camera so no gaps appear
  const bgW = SPRITES.bg.w / 48;
  const bgH = SPRITES.bg.h / 48;
  drawTile(vec2(cameraPos.x, 11), vec2(bgW, bgH),
    tile(0, vec2(SPRITES.bg.w, SPRITES.bg.h), TEX.bg));

  // Ground — drawn here because LittleJS TileLayer reads texture 0 by default
  drawRect(vec2(40, 1),    vec2(160, 4),    hsl(0.08, 0.45, 0.18));  // deep earth
  drawRect(vec2(40, 2.55), vec2(160, 0.45), hsl(0.26, 0.35, 0.26));  // mud-grass surface

  // Platforms — ochre hay-bale colour
  for (const [x, y] of PLATFORMS) {
    drawRect(vec2(x + 0.5, y), vec2(1.1, 0.3), hsl(0.10, 0.55, 0.46));
  }

  // Barn wall at right end of level
  drawRect(vec2(78.5, 7.5), vec2(2.2, 9.4), hsl(0.60, 0.12, 0.26));
}

function gameRenderPost() {
  // Subtle parallax could go here
}

///////////////////////////////////////////////////////////////////////////////
// Boot
engineInit(gameInit, gameUpdate, gameUpdatePost, gameRender, gameRenderPost, ASSET_LIST);
