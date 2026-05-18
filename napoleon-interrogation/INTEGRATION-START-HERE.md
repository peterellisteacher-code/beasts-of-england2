# Napoleon Interrogation — Fold-In Instructions

**For:** the Claude Code session building *Beasts of England*.
**What this folder is:** a complete, separately-built and verified "interrogate
Napoleon" activity, intended to become the **final level** of *Beasts of England*.
The backend and game logic are done, tested, and live-verified; the Godot
front-end is a stub still to be built out.

## What the activity is

The student interrogates Napoleon. He conceals the novel's uncomfortable truths;
a *specific, well-evidenced* contradiction makes him **falter** — and scores a
point. A hidden 0–6 **menace** meter rises as he is cornered or openly defied:
Composed → Wary → Dangerous → the dogs (death, game over). A fair-warning rule
guarantees a spoken Dangerous-band warning before any death. Each turn the model
also emits a hidden 4-axis emotion vector that selects one of 16 portraits.

## Chapter scope (settled)

The interrogation's lorebook covers *Animal Farm* **chapters 1–7**; the game's
five acts cover **chapters 1–5**. This is intentional — the interrogation is a
deliberate chapters 1–7 capstone. Leave it as is.

## What's in this folder

| Part | Files |
|---|---|
| Backend (Cloudflare Worker — engine-agnostic) | `worker.js`, `menace.js`, `system-prompt.js`, `lorebook.js`, `napoleon-lorebook.json`, `portrait-manifest.json`, `wrangler.toml`, `package.json` |
| Web reference client | `index.html` — a complete working visual-novel UI; the reference for the look |
| Godot path | `GODOT-INTEGRATION.md` (guide) + `godot/napoleon_interrogation.gd` (Godot 4 logic stub: HTTP client, state machine, signals, faithful `selectPortrait` port) |
| Art | `assets/portraits/` — 16 portraits + `portrait-manifest.json` |
| Tests | `test/` (28 unit tests — `npm test`); `eval/` (LLM-behaviour evals) |
| Design docs | `STAKES-VISUAL-HANDOVER.md` (full build state + the worker API contract — **read this first**), `STAKES-FEATURE-BRIEF.md`, `STAGE-B-HANDOVER.md` |
| Key / cache | `.dev.vars.example` (template for the worker's OpenRouter key — the real `.dev.vars` is git-ignored, kept only in the working copy), `.wrangler/` (wrangler dev cache) |

## To make it work

1. **Run / deploy the worker.** It proxies OpenRouter (Claude Haiku 4.5). The
   worker reads its key from `.dev.vars`. That file is **git-ignored** — GitHub's
   push protection blocks committing API keys — so it is not in the repo, only in
   the working copy on Peter's machine. On a fresh clone, recreate it: copy
   `.dev.vars.example` to `.dev.vars` and paste the key (a low-value,
   US$10-capped OpenRouter key — ask Peter). `wrangler dev` then runs locally. To
   put the worker **online** for the classroom: run `wrangler deploy`, and set the
   key in Cloudflare once with `wrangler secret put OPENROUTER_API_KEY` — the
   deployed worker reads it from there, not from `.dev.vars`. Note the resulting
   `*.workers.dev` URL.

2. **Build the interrogation as a Godot scene.** *Beasts of England* is Godot 4.6
   → HTML5. Rebuild the visual-novel UI as a Godot scene (the final act): use
   `godot/napoleon_interrogation.gd` as the logic core — it does the HTTP call,
   the menace/score state, the portrait nearest-neighbour, and emits signals —
   and wire those signals to Godot UI nodes (a dialogue box, a menace meter, a
   portrait `TextureRect`). Copy `assets/portraits/` + `portrait-manifest.json`
   into the Godot project. `index.html` is the visual reference. Set `WORKER_URL`
   in the GDScript to the deployed worker URL. Detail: `GODOT-INTEGRATION.md`.

3. **HTML5 / CORS.** The game is a Web export. Godot's `HTTPRequest` works
   in-browser, but the worker's CORS must allow the game's origin. The worker
   currently allows `*` — fine for dev and classroom use; tighten it later only
   if wanted.

4. **Wire it as the finale.** Trigger the interrogation after Act 5; on
   `game.dogs === true` (the dogs / death) or the student choosing to stop,
   return to *Beasts of England* with an ending.

## Verification status

- 28/28 unit tests pass (`npm test`).
- A live smoke-test passed all four critical paths: lorebook grounding, the
  out-of-scope narrator refusal, the falter, and death-by-dogs.
- Three bugs were found and fixed during integration testing.
- The worker and game logic are solid and verified. **The Godot front-end is a
  starting stub — building it out is the main remaining work.**
