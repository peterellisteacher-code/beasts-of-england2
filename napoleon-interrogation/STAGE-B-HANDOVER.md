# Stage B Handover — Napoleon (Animal Farm) Character Bot

**For:** the next Claude Code session — and Peter, since lorebook curation is yours.
**Project:** `C:\Users\Peter Ellis\Documents\Claude Code\Mucking\napoleon-bot\`
**Status:** Stage A complete, verified, and running locally. Stage B not started.
**Predecessor:** `..\STAGE-A-HANDOVER.md` (the brief this build was made from).

## 1. What Stage A delivered

A working "lorebook-grounded persona bot" — Napoleon from *Animal Farm*, for Year 10
English. Students ask questions; he answers in character, grounded only in
keyword-triggered lorebook passages; refuses out-of-scope questions with an in-world
narrator stage-direction; and "cracks" (visibly falters, never confesses) when hit with
a specific, well-evidenced contradiction.

Files, all in `napoleon-bot/`:

- `napoleon-lorebook.json` — the **sample** lorebook, 12 hand-authored entries. A Stage A
  test fixture, not the real thing.
- `system-prompt.js` — Napoleon's character: the 10-section system prompt, the scripted
  first message, and the hard-rules block. Hand-authored; treat as the voice source of truth.
- `lorebook.js` — the keyword-injection engine. One export: `buildContextBlock()`.
- `worker.js` — the Cloudflare Worker. `POST /napoleon`, proxies to OpenRouter.
- `wrangler.toml`, `.dev.vars.example`, `.dev.vars` — worker config and the local secret.
- `package.json` — scripts: `test`, `dev`, `serve`, `eval`.
- `index.html` — a minimal local chat page.
- `test/lorebook.test.js` — 9 unit tests for the engine.
- `eval/napoleon-eval.js` — manual LLM-behaviour checks (in-character / narrator / crack-point).

## 2. Verified state

- **Unit tests: 9/9 green** (`npm test`). Cover keyword matching, constant-entry
  injection, the narrator path, `scan_depth` windowing, `insertion_order` sort, disabled
  entries, and real-lorebook schema validation.
- **Live run-through done** against the running worker — all three mechanisms confirmed:
  - lorebook hit → grounded, in-character answer;
  - out-of-scope ("capital of Australia?") → narrator stage-direction, no answer;
  - crack-point (the altered Commandments; Boxer and the knacker) → visible falter,
    then rewrite/deflect, no confession.
- **Browser path confirmed** — `index.html` → worker → OpenRouter → rendered reply;
  italics and em-dashes render cleanly; no console errors.

## 3. Decisions and deviations from STAGE-A-HANDOVER.md

- **Model transport: Haiku 4.5 via OpenRouter, not direct Anthropic.** Done on Peter's
  instruction (there is no persistent Anthropic key). The worker calls
  `openrouter.ai/api/v1/chat/completions`, model `anthropic/claude-haiku-4.5`, OpenAI
  request format. The key is **PAL's `OPENROUTER_API_KEY`** (from PAL's MCP config in
  `~/.claude.json`), copied into `napoleon-bot/.dev.vars`.
- **Flat directory** — no `api/` subfolder. The original brief said "mirror the Plato
  tree"; a flat layout is simpler for one worker + one page. The Plato *deployment shape*
  (Cloudflare Worker, plain JS, Workers Secret, CORS) was mirrored — the tree was not.
- **Language: JavaScript.** Confirmed from the Plato worker (`worker.js`, no TypeScript),
  per the brief's "or the Plato worker's language" — so `lorebook.js`, not `.ts`.
- **A bug was found and fixed.** The first build excluded `constant` entries from keyword
  matching, so in-scope questions answered only by a constant entry (about Napoleon
  himself, or the Rebellion) wrongly triggered the silent narrator refusal — disguising a
  real answer as Napoleon choosing not to speak. Caught in review, reproduced with a
  failing test (T9), then fixed in `lorebook.js`.
- **Prompt caching dropped.** The original used Anthropic ephemeral caching; OpenRouter's
  passthrough caching is fiddlier and a prototype does not need it. See §6.

## 4. How to run it

From `napoleon-bot/`:

```
wrangler dev --port 8787      # the worker; reads .dev.vars for OPENROUTER_API_KEY
python -m http.server 8000    # serves index.html  (or: npm run serve)
```

Then open `http://localhost:8000/index.html` and talk to Napoleon.
(Both servers were left running at the end of the build session.)

- `npm test` — the 9 unit tests (no key, no network needed).
- `npm run eval` — the LLM-behaviour checks; needs `OPENROUTER_API_KEY` set as an
  environment variable (it does not read `.dev.vars`).

## 5. Stage B — the real work

**5a. The full lorebook (Peter curates this).** `napoleon-lorebook.json` is a 12-entry
*sample*. Stage B replaces it with entries drawn from the actual novel text, each verified
against the book. The schema is locked — 6 fields total:

- per entry: `keys` (array of lowercase strings; matched case-insensitively as
  substrings), `content` (string), `enabled` (bool), `constant` (bool — always injected;
  use for persona core), `insertion_order` (int — assembly order in the context block);
- lorebook-level: `scan_depth` (int — how many recent turns are scanned for keywords).

Conventions used in the sample — carry them forward:
- 2 `constant` entries hold persona core, so Napoleon never loses character.
- Concealment entries put a `CONCEALMENT:` note in `content` — what Napoleon hides and
  how he spins it.
- Crack-point entries add a `CRACK:` note saying what specific evidence triggers the
  falter. The *model* judges whether the student's evidence is specific enough; the
  wrapper only injects the entry on a keyword hit.

**5b. Keyword brittleness (the known watch-out).** Matching is brittle: a covered question
phrased vaguely (no keyword fires) wrongly gets the narrator refusal, disguising a
retrieval miss as Napoleon "choosing" not to answer. Watch for this in classroom testing.
The eventual fix, only if testing shows it matters, is a free local embedding fallback
(`all-MiniLM-L6-v2`) run only on a zero-keyword-match. Not Stage A; not necessarily Stage B.

**5c. Graduation (out of scope until classroom-proven).** The `_pitch.md` / `_review.md`
companion pair; moving the toy into `peter-classroom-ai-library/`; the
`ai-agent-implementator` routing entry. None of this until Napoleon has been used with
students and the pattern is proven.

## 6. Watch-outs / before you ship

- **`.dev.vars` holds a live OpenRouter key.** There is no git repo yet. **Before any
  `git init`, add a `.gitignore` containing `.dev.vars` and `node_modules/`.**
  `.dev.vars.example` is the safe, committable template.
- **Deploying the worker:** `wrangler secret put OPENROUTER_API_KEY`, then
  `wrangler deploy`. Change `index.html`'s `API_URL` from `localhost:8787` to the deployed
  `*.workers.dev` URL, and tighten the worker's CORS (currently permissive for local dev)
  to the real page origin.
- **Add prompt caching** for the classroom deployment — OpenRouter passes Anthropic
  caching through via `cache_control` on a system-message content part. Worth doing once
  class sizes make the per-call system-prompt cost add up.
- Tooling note, not a product bug: during the build the preview tool's automated click
  did not reliably fire the page's Send handler; a native/real click works. The button is
  fine for real users — do not chase this.

## 7. Continuation prompt for the next session

> Read `napoleon-bot/STAGE-B-HANDOVER.md`. Stage A is complete and verified (9/9 tests,
> live demo done). [Then one of:] "Peter has curated the full lorebook into
> `napoleon-lorebook.json` — review it against the §5a schema and conventions, then run
> `npm test`." / "Begin the embedding fallback in §5b." / "Begin graduation per §5c."
