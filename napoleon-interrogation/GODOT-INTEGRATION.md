# Napoleon Interrogation — Godot 4 Integration Guide

## Overview

The Napoleon interrogation runs as a Cloudflare Worker at a shared backend URL.
Godot is just a client: it POSTs JSON to the worker and renders the response.
No logic needs re-implementing in GDScript beyond the client side — `menace`,
`score`, and portrait selection are handled exactly as the web client does.

The stub at `godot/napoleon_interrogation.gd` is a starting point; wire its
signals into your scene's UI nodes.

---

## Worker API

**Endpoint:** `POST https://<your-worker>.workers.dev/napoleon`

**Request body (JSON):**

```json
{
  "message": "The Seven Commandments were changed. You added 'with sheets'.",
  "history": [
    { "role": "napoleon", "content": "You have come at an odd hour…" },
    { "role": "student",  "content": "I want to ask about the barn wall." }
  ],
  "menace": 2
}
```

- `message` — the student's current input (max 1 000 chars; trimmed by worker).
- `history` — alternating `napoleon`/`student` turns from all previous exchanges,
  newest turns at the end. Send the full history each turn (the worker slices to
  the last 20 internally). On the very first message, send an empty array `[]`.
- `menace` — the integer (0–6) held **client-side** from the previous turn's
  `game.menace`. Start at `0`. Always send what you last received; the worker
  clamps it so it cannot be spoofed above 6 or below 0.

**Response body (JSON):**

```json
{
  "text":    "Napoleon's great head does not move…",
  "game": {
    "falter":      false,
    "provocation": "none",
    "menace":      3,
    "band":        "wary",
    "dogs":        false
  },
  "emotion": {
    "composure": 0.75,
    "threat":    0.45,
    "suspicion": 0.70,
    "contempt":  0.40
  },
  "portrait": {
    "id":   "watchful",
    "file": "assets/portraits/watchful.png"
  },
  "debug": { ... },
  "usage": { ... }
}
```

Key fields:

| Field | Meaning |
|---|---|
| `text` | Napoleon's spoken reply; display this. `*…*` marks narrator italics. |
| `game.menace` | **Store this** client-side; send it back next turn. |
| `game.band` | `"composed"` / `"wary"` / `"dangerous"` — use for HUD colour. |
| `game.falter` | `true` → student exposed a lie → `score += 1`. |
| `game.dogs` | `true` → game over; show death sequence. |
| `portrait.id` | ID of the portrait to show (see manifest). |
| `portrait.file` | Relative path string (matches manifest). Use the manifest in Godot for the actual `Texture2D`. |

---

## Client-side state (mirrors `index.html`)

```
var menace: int = 0   # updated from game.menace each turn
var score:  int = 0   # incremented when game.falter == true
var history: Array = []  # Array of {role, content} Dicts
```

Each turn:
1. Append `{role="student", content=message}` to `history`.
2. POST `{message, history=history.slice(0,-1), menace}`.
3. On success: `menace = game.menace`, `if game.falter: score += 1`.
4. Append `{role="napoleon", content=text}` to `history`.
5. If `game.dogs == true` → trigger death; disable input permanently until restart.

On restart: reset all three state vars and `history` to their initial values.

---

## Portrait assets

Copy the following into your Godot project (maintaining the relative path structure):

```
assets/portraits/cold_authority.png
assets/portraits/false_warmth.png
assets/portraits/dismissive.png
assets/portraits/sharp_interest.png
assets/portraits/watchful.png
assets/portraits/faltered.png
assets/portraits/irritated.png
assets/portraits/cold_contempt.png
assets/portraits/suspicion_hardening.png
assets/portraits/warning.png
assets/portraits/dogs_alert.png
assets/portraits/controlled_fury.png
assets/portraits/paranoid_accusation.png
assets/portraits/snarling_rage.png
assets/portraits/triumphant_cruelty.png
assets/portraits/the_dogs.png          # death image only
portrait-manifest.json
```

The manifest (`portrait-manifest.json`) holds each portrait's `id`, `file`
path, and 4-axis emotion vector. Load it at startup; build a `Dictionary`
keyed by `id` to look up `Texture2D` resources via `portrait.file`.

The base portrait at game start is `cold_authority` (`manifest.basePortrait`).
The death portrait is `the_dogs` (`manifest.deathPortrait`).

---

## Death trigger

When `game.dogs == true`:

- The worker has already replaced `text` with the fixed death narration.
- Cross-fade to `the_dogs` portrait.
- Display `text` in the dialogue box.
- Show the death/score overlay.
- Disable all input until the player restarts.

The death portrait has no `emotion` field in the manifest — it is never chosen
by nearest-neighbour logic, only when `game.dogs` is `true`.

---

## Portrait selection (GDScript equivalent of `menace.js selectPortrait`)

The stub in `godot/napoleon_interrogation.gd` includes a faithful GDScript port
of the weighted nearest-neighbour selection. Weights: `threat × 1.5`,
`suspicion × 1.2`, `composure × 1.0`, `contempt × 0.8`. The worker already
returns the correct `portrait.id` — the GDScript port is provided for offline
fallback or if you ever run the portrait logic locally.

---

## Deployment note

The worker is deployed via Cloudflare Workers (Wrangler). The web client and
Godot game share the same backend URL — no changes to the worker are needed
when adding a Godot frontend.
