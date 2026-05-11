# Beasts of England — Claude Code Game Studios

Year 10 English classroom game covering Animal Farm Chapters 1–5.
Five-act Godot 4 HTML5 pixel-art game: platformer → top-down action → exploration+dialogue → Zelda overworld+turn-based battles → turn-based tactics.

## Technology Stack

- **Engine**: Godot 4.6
- **Language**: GDScript
- **Build System**: SCons (engine), Godot Export Templates
- **Asset Pipeline**: Godot Import System + custom resource pipeline
- **Target Platform**: HTML5/Web (browser play in classroom)
- **Renderer**: gl_compatibility (required for Web export)
- **Viewport**: 1280×720

## Project Structure

@.claude/docs/directory-structure.md

## Engine Version Reference

@docs/engine-reference/godot/VERSION.md

## Technical Preferences

@.claude/docs/technical-preferences.md

## Coordination Rules

@.claude/docs/coordination-rules.md

## Coding Standards

@.claude/docs/coding-standards.md

## Context Management

@.claude/docs/context-management.md

## Game Summary

**Title**: Beasts of England
**Curriculum**: Year 10 English — Animal Farm (Chapters 1–5)
**Genre**: 2D pixel art — multi-mechanic educational game
**Engine**: Godot 4.6 → HTML5 export

### Act Structure
| Act | Chapter | Mechanic | Protagonist |
|---|---|---|---|
| 1 | Ch.1 | Platformer (stall → barn) | Old Major |
| 2 | Ch.2 | Top-down action (Rebellion) | Boxer |
| 3 | Ch.3 | Top-down exploration + dialogue | Boxer + Squealer |
| 4 | Ch.4 | Zelda overworld + turn-based battles | Boxer |
| 5 | Ch.5 | Turn-based tactics (Snowball's expulsion) | Snowball |

### Aesthetic Identity
- Visual: Soviet constructivist propaganda poster, corrupting across acts
- Palette: #8B1A1A propaganda-red, #2D5016 animalism-green, #1A1209 soil-black, #F5F0E8 bone-white, #C4A24A wheat-gold
- Progress system: Seven Commandments on barn wall (not a bar)
- Sound: "Beasts of England" folk melody as corrupting leitmotif

### Asset Sources (priority order)
1. RD ASSETS library: `C:\Users\Peter Ellis\Documents\RD ASSETS\` (29 existing sprites)
2. Tiny Swords pack: `C:\Users\Peter Ellis\Documents\Asset Packs\Tiny Swords (Free Pack)\` (medieval sprites for Act 4)
3. User-provided assets (barn backgrounds, item sprites, Napoleon character)
4. itch.io free assets
5. RD generation (backgrounds/tiles/animations only — NOT initial character sprites)
6. fal-ai (initial character designs when new characters needed)

### Reference Code Sources
- Lango-Zelda-RPG: `C:\Users\Peter Ellis\Games Workshop\reference-library\04-strategy\lango-zelda-rpg\` (top-down movement, enemy AI, room transitions)
- PokemonUnity: `C:\Users\Peter Ellis\Games Workshop\reference-library\04-strategy\pokemon-unity\` (battle system patterns — port to GDScript)
- GDQuest Combat: `C:\Users\Peter Ellis\Games Workshop\reference-library\04-strategy\gdquest-combat\` (hitbox patterns, state machines)

## Collaboration Protocol

This is an autonomous build session. All 72 CCGS skills are pre-authorized.
No new gameplay mechanics are to be invented — only existing reference code is reskinned and stitched together.

> **Key constraint**: Do NOT invent new gameplay mechanics. Read from reference repos, port patterns to GDScript, apply Animal Farm skins.
