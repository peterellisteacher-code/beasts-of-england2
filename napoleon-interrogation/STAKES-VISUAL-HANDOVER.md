# Napoleon Interrogation — Build Complete

**Project:** `C:\Users\Peter Ellis\Documents\Claude Code\Mucking\napoleon-bot\`
**Status:** the stakes feature, the visual layer, the chapters 1–7 lorebook, and the
Godot export are all built, verified, and test-passing (28/28). A live smoke-test
passed. What remains is deployment and a classroom playtest — no code work.

## What the game is

A Year 10 English resource: students interrogate Napoleon (Orwell's *Animal Farm*).
He conceals the novel's truths; a specific, well-evidenced contradiction makes him
*falter* and scores a point. A hidden 0–6 "menace" meter rises as he is cornered or
defied — Composed → Wary → Dangerous → the dogs. The fair-warning rule guarantees a
spoken Dangerous warning before any death. Designed to become the final "boss"
level of a larger pixel-art Animal Farm game (Godot).

## Files

- `menace.js` + `test/menace.test.js` — pure game logic (escalate, bandFor,
  parseControlLine, selectPortrait, clampEmotion); 28 unit tests.
- `system-prompt.js` — Napoleon's character; menace bands, the death, the hidden
  control line + 4-axis emotion. Scoped to *Animal Farm* chapters 1–7.
- `worker.js` — the Cloudflare Worker. `escalate()` is the sole authority for the
  dogs; the worker owns the death narration; the fair-warning is auto-injected.
- `napoleon-lorebook.json` — 16 entries, chapters 1–7, curated from the teacher's
  `Animal Farm - Novel.md`; 5 crack-points (bed/sheets commandment, Snowball's
  decoration, milk & apples, the Battle of the Cowshed, the chapter 7 executions).
- `portrait-manifest.json` + `assets/portraits/` — 16 portraits, 4 emotion axes.
- `index.html` — the visual-novel barn UI (briefing card, crossfading portrait,
  menace meter, dialogue box, red death screen).
- `GODOT-INTEGRATION.md` + `godot/napoleon_interrogation.gd` — the Godot 4 export
  (HTTP client, state machine, signals, a faithful `selectPortrait` port).
- `eval/napoleon-eval.js` — LLM-behaviour evals incl. the death scenario (Check 5).
  Run with `npm run eval` (needs `OPENROUTER_API_KEY` as an env var).

## Verified

- **28/28** unit tests (`npm test`).
- **Live smoke-test, 4/4:** lorebook hit (grounded answer), out-of-scope narrator
  refusal, falter (model correctly judged a well-evidenced contradiction), and
  death-by-dogs (sedition at the Dangerous band).
- 3 bugs found & fixed: index.html restart double-seed; index.html inputs
  re-enabling after death; worker death-text desync (model wrote a warning instead
  of a death — worker now owns the death narration outright).

## How to run locally

From `napoleon-bot/`:
- `npx wrangler dev --port 8787` — the worker (reads `.dev.vars` for `OPENROUTER_API_KEY`).
- `python -m http.server 8000` — serves `index.html`.
- Open `http://localhost:8000/index.html`.

## Remaining — deployment & classroom (no code)

1. **Deploy the worker:** `wrangler secret put OPENROUTER_API_KEY`, then
   `wrangler deploy`. Set `index.html`'s `API_URL` and the Godot stub's
   `WORKER_URL` to the deployed `*.workers.dev` URL; tighten the worker's CORS
   from `*` to the real page origin.
2. Before any `git init`: add a `.gitignore` with `.dev.vars` and `node_modules/`.
3. **Classroom playtest** — talk to Napoleon, judge the feel. `escalate()`'s
   numbers in `menace.js` are playtest-tunable; the structure is locked.
4. Optional polish: the model sometimes parrots the section-7 narrator-refusal
   example verbatim — a small prompt tweak could vary it. One fixed death
   narration currently; add variants if a repeated death feels stale.

## Notes

- The 16-portrait set is the `flux-pro/kontext` set. A bake-off (kontext vs
  nano-banana-2 vs gpt-image-2) found kontext the most faithful editor;
  gpt-image-2's fal endpoint is blocked (needs OpenAI verified-org credentials).
- `cold_authority.png` is the pristine cropped base (the teacher's mockup 2); the
  other 15 are kontext re-draws — a faint render difference on that one
  transition, hidden by the 300 ms crossfade.

## Continuation prompt

> Read `napoleon-bot/STAKES-VISUAL-HANDOVER.md`. The build is complete and verified
> (28/28 tests, live smoke-test passed). Deploy the worker to Cloudflare, point the
> web and Godot clients at the deployed URL, tighten CORS, and add the `.gitignore`.
