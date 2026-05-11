# Beasts of England — Game Concept

**Title**: Beasts of England  
**Curriculum**: Year 10 English — Animal Farm by George Orwell (Chapters 1–5)  
**Genre**: 2D pixel art educational game — multi-mechanic, 4 acts  
**Engine**: Godot 4.6 → HTML5/Web export  
**Audience**: Year 10 students (15–16 years old), classroom play  
**Design philosophy**: Fun-first. Students must have a reason to engage independent of knowing the text. Loss states are real. Secrets reward close readers. The game IS the analysis.

---

## Core Fantasy

You are inside Animal Farm as it corrupts. Each act puts you in the body of a different animal — you feel their limits, their loyalties, their inevitable defeat. By Act 4, the mechanics themselves enact the totalitarianism the text describes.

---

## Visual Identity

Soviet constructivist propaganda poster aesthetic, degrading across acts:
- Act 1: clean, hopeful, pre-Revolutionary colours
- Act 4: washed-out, corrupted, commandments rewritten

**Palette**: `#8B1A1A` propaganda-red · `#2D5016` animalism-green · `#1A1209` soil-black · `#F5F0E8` bone-white · `#C4A24A` wheat-gold

**Progress tracker**: Seven Commandments on a barn wall — corrupted one by one (not a progress bar)

**Sound**: "Beasts of England" folk melody as corrupting leitmotif

---

## Act Structure

| Act | Chapter | Mechanic | Protagonist | Win Condition | Loss Condition |
|-----|---------|----------|-------------|---------------|----------------|
| 1 | Ch.1 | Side-scrolling platformer | Old Major | Reach barn entrance + rescue lamb | 3 hearts depleted |
| 2 | Ch.2 | Top-down action | Boxer | Drive off all 5 Jones' men + pass gatekeeper quiz | 3 Jones' men regroup |
| 3 | Ch.4 | Zelda overworld + Pokémon battles | Boxer | Win all 4 battles | Any battle loss (retry that battle) |
| 4 | Ch.5 | Turn-based tactics on shrinking grid | Snowball | Survival (inevitable loss) | Grid shrinks until Snowball is expelled |

---

## Act 1 — Old Major's Night Journey (Ch.1)

Old Major travels from the pig pen to the barn at night to deliver his revolutionary speech.

**Mechanics**:
- CharacterBody2D platformer (Godot 4), gravity + jump
- 3 hearts — lose all → loss state → restart act
- **Ability 1**: Double jump — unlocked by collecting Hay Bale item
- **Ability 2**: Lantern Blind — raise lantern, nearby Jones' men stunned for 2 seconds
- 2 key/door puzzles blocking progression
- Rescue lamb — lamb follows player to barn once touched
- **SECRET**: A hidden breakable box (hit 3× from above) contains a torn scroll → sets `GameState.has_secret_scroll = true`

**Enemies**:
- Jones' Man: left-right patrol on platforms. Touch → lose heart
- Moses the Raven: sine-wave aerial hazard. Touch → lose heart. Cannot be defeated

**Completion**: Reach barn door. Triggers first Commandment corruption. Transitions to Act 2.

---

## Act 2 — The Revolution (Ch.2)

Boxer and the animals chase Jones' men off the farm. The farmhouse gatekeeper quiz follows.

**Mechanics**:
- Top-down movement (Lango-Zelda-RPG patterns, ported to Godot 4 CharacterBody2D)
- Boxer's CHARGE: sprint tackle that pushes Jones' men when activated
- 5 Jones' men flee when Boxer approaches, driven off-screen = success
- Failure: if 3+ men regroup (sneak back onto farm)
- **Gatekeeper quiz**: verbatim Animal Farm quotes, multiple choice
  - If `GameState.has_secret_scroll == true`: a special question appears about Old Major's private writings
  - Correct secret answer → `GameState.has_gatekeeper_bonus = true`
- After quiz: Seven Commandments written one by one on barn wall (reveal animation)

**Completion**: All commandments revealed. Second corruption. Transitions to Act 3.

---

## Act 3 — Battle of the Cowshed (Ch.4)

Boxer traverses the farm overworld and fights 4 turn-based battles against Jones' allies.

**Mechanics**:
- Zelda-style top-down overworld (Lango patterns) to approach each encounter zone
- Pokémon-style turn-based combat (PokemonUnity patterns, ported to GDScript)
- Gen 6 damage formula: `floor(((2*level/5+2) * power * atk/def) / 50 + 2)`
- PP system (moves have limited uses)
- Stat stages (-6 to +6 multipliers)

**Boxer's moves** (unlocked progressively):
1. Charge (Headbutt, 70 power) — always available
2. Brace (Defense Curl, +Def) — always available
3. Stamp (Stomp, 65 power, 30% flinch) — after Battle 1
4. Endure (survive at 1 HP) — after Battle 2
5. I Will Work Harder (Rollout variant, 80 power, doubles next turn) — after Battle 3
6. **Solidarity** (heal 10 HP) — BONUS if `GameState.has_gatekeeper_bonus == true`

**4 Battles**:
1. Jones' Pawn (HP 35, weak)
2. Red Archer (HP 45, faster)
3. Foxwood Lancer (HP 60, high defense)
4. Stable-lad CLIMAX (HP 70, balanced — drawn from novel text)

**Loss state**: Battle loss → retry that battle (not full act restart)

**Completion**: Win all 4 battles. Third corruption. Transitions to Act 4.

---

## Act 4 — The Political Turn (Ch.5)

Turn-based tactics on a shrinking grid. Snowball vs Napoleon's dogs + Squealer.

**Mechanics**:
- Grid: 8 columns × 6 rows
- Grid loses its leftmost column every 3 turns (Napoleon consolidates power)
- Snowball (player): Move 3 squares (Manhattan distance), Battle Cry (push adjacent dog), Windmill Plans (skip turn, +2 def next turn)
- Napoleon's Dogs ×2: Move 2, attack adjacent
- Squealer: Move 1, "Gaslight" reduces Snowball's effective movement
- **The game is designed to be unwinnable** — this IS the pedagogy. Snowball cannot survive.

**Ending**: Snowball expelled or defeated → all Seven Commandments shown in corrupted form → debrief screen with reflection questions

---

## Cross-Cutting Systems

### GameState Autoload
- `commandments_corrupted: int` (0–7)
- `has_secret_scroll: bool` — set in Act 1
- `has_gatekeeper_bonus: bool` — set in Act 2
- `boxer_moves: Array[String]` — grows across Act 3
- `hearts: int` — Act 1 hearts
- Save/load via `user://boe_save.json`

### Scene Flow
```
Opening → Act 1 → Act 2 → Act 3 (overworld + 4 battles) → Act 4 → Corruption Ending → Credits/Debrief
```

### Loss States
- Act 1: hearts = 0 → loss screen → restart act (secrets reset)
- Act 2: 3 Jones' men regroup → loss screen → restart act
- Act 3: battle loss → retry that battle only
- Act 4: no recoverable loss — Snowball's expulsion is the intended end

---

## Asset Sources

1. **RD ASSETS library** (`Documents\RD ASSETS\`): Boxer horse sprites (overworld + battle), Moses raven, Napoleon's dogs
2. **Tiny Swords (Free Pack)**: Sheep sprites (lamb, Act 1), Pawn sprites (Jones' men, Acts 1–2), Warriors (Act 3 enemies)
3. **Pixel Adventure**: 32×32 character sprites, 16×16 terrain tileset, breakable boxes (secret scroll container)
4. **fal.ai nano-banana-2**: Old Major portrait/sprite (generated with transparent cutout)

---

## Reference Code Sources

| System | Source | Port Notes |
|--------|--------|-----------|
| Top-down movement | `Lango-Zelda-RPG/Player/Player.gd` | Godot 3 → 4: KinematicBody2D→CharacterBody2D, move_and_slide(velocity)→move_and_slide() |
| Enemy AI | `Lango-Zelda-RPG/Enemies/Enemy.gd` | IDLE/WANDER/CHASE state machine |
| Battle system | `PokemonUnity/Attack.cs` | C# → GDScript: Gen 6 damage formula, PP system, stat stages |
| Hitboxes | `GDQuest-Combat/hitbox patterns` | Area2D collision for damage zones |
| Platformer | Pixel Adventure character controller | GRAVITY + JUMP_VELOCITY constants |

---

## MVP Definition

All 4 acts playable, linked, and completable. Loss states functional. Secret scroll chain functional. Runs in HTML5 export (gl_compatibility renderer).

**Not in MVP**: Sound/music, sprite animations (animated sprite frames), tile maps (coloured placeholders), polish pass
