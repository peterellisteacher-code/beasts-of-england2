# Stakes Feature Brief — "The Dogs" — Napoleon Bot

**For:** the next Claude Code session (start this fresh — do not continue the long build thread).
**Project:** `C:\Users\Peter Ellis\Documents\Claude Code\Mucking\napoleon-bot\` — a working, tested Stage A build.
**Read first:** `STAGE-B-HANDOVER.md` (current build state); `..\STAGE-A-HANDOVER.md` (original design).
**Status:** design locked below by Peter. Stage A is complete, 9/9 tests green, runs locally. This
feature adds a stakes/scoring layer that turns the close-reading sandbox into a game.
**Confirm the plan with Peter, then build.** Do not re-litigate §5.

## 1. Why

Stage A is a close-reading sandbox: the student interrogates Napoleon and is rewarded — invisibly —
when they land a well-evidenced contradiction and he "falters." It has no stated aim, no score, no
win or lose. Peter playtested it, found it aimless, and asked for stakes.

The theme is exact: in *Animal Farm* the dogs are how Napoleon eliminates animals who question him.
A student who corners the tyrant with the truth and pushes too far gets destroyed. That is the
lesson of the novel, turned into a mechanic.

## 2. The game (locked design)

**Aim — shown to the student in a briefing card before the chat:**

> **NAPOLEON — THE INTERROGATION**
> You have come to Animal Farm to question Napoleon. He will not tell you the truth — he hides what
> the pigs have done to the other animals. But the truth is in the novel, and you have read it.
> Catch him in his lies. Name the specific words, the exact change, the real evidence — and Napoleon
> will *falter*. Every lie you expose is counted.
> But be careful. Each time you corner him he grows more dangerous — watch his mood. And he is still
> the master of this farm: open defiance, and the dogs will be the last thing you see.
> Expose as many lies as you can. Survive Napoleon.
> *[Enter the barn]*

**The loop:** the student questions Napoleon. A *specific, well-evidenced* contradiction makes him
falter — a **hit** — and scores. But every hit raises his menace; and open defiance is fatal.
Push-your-luck: expose as many lies as you can before the dogs find you.

**Score:** `Lies exposed: N` — +1 each turn the student lands a *new* well-evidenced falter.
Re-pressing a lie already exposed does not re-score — it counts as pushing (raises menace).

**Menace** — Napoleon's danger, an internal 0–6 scale, shown on screen as three named bands:
- 0–1 **Composed** — Napoleon as he is in Stage A.
- 2–3 **Wary** — narration cooler, watchful; the dogs noted, alert.
- 4–5 **Dangerous** — Napoleon gives an explicit spoken warning; the dogs on their feet. The student
  KNOWS the next provocation is fatal.
- 6 — **the dogs** (death).

**The fair-warning rule (non-negotiable):** the dogs never come without the student having first
seen the Dangerous band and its spoken warning. If one turn's escalation would jump menace from
below 4 straight to 6+, it is clamped to 5 (Dangerous) — they get the warning; the *next*
provocation kills. Death is always a risk the student saw coming and chose to walk toward.

**Triggers (Peter's locked choice — both):**
- *Sedition* — open defiance of Napoleon's rule: calling for revolt, threatening him, naming him a
  tyrant to his face, siding with Snowball as the rightful leader. The fast lane to the dogs.
- *Over-pushing* — re-hammering a contradiction he has already faltered on / deflected, especially
  after a warning.
- Landing *fresh* well-evidenced hits is the goal and is **mostly safe** — see §4: clean reading can
  make Napoleon Wary but never, on its own, Dangerous.

**Death sequence:** when menace reaches 6, Napoleon's reply IS the death — a narrator account of him
turning to the dogs and the student's end (his register, third person, final). The screen floods
red, the chat ends, input disables, the final score shows, and a "Face him again" button restarts.

## 3. What to build — file by file

**`system-prompt.js` — the careful, judgement-heavy part. Author it well; keep all Stage A content
intact** (persona, narrator device, crack-point falter, hard prohibitions). Add:
- A menace section: the three bands and how Napoleon *behaves* at each (Composed = Stage A as-is;
  Wary = cooler, watchful, the dogs noted; Dangerous = an explicit in-character warning, the dogs on
  their feet). The current band is supplied each turn by the worker.
- The death: when told he is at the Dangerous band and the visitor provokes him again, Napoleon does
  not warn twice — his reply becomes the dogs: a final narrator account of the command given and the
  dogs doing what they were raised to do. Define that register.
- The control-line contract: every reply ends with exactly one line —
  `[[falter=<true|false> provocation=<none|mild|pushing|sedition>]]` — and nothing after it. Define
  each value precisely (falter = a NEW well-evidenced contradiction landed this turn; provocation:
  none / mild cheek / pushing an exposed lie / open sedition). Give 2–3 worked examples.
- `HARD_RULES_BLOCK` gains a one-line reminder of the control-line requirement.

**`menace.js` — NEW, pure, unit-tested.** Export `escalate(currentMenace, falter, provocation)`
returning `{ menace, band, dogs }`. Rules in §4. Write the failing tests first.

**`worker.js`:**
- Request body gains `menace` (int). Tell Napoleon his current band in the per-turn context.
- Parse the `[[...]]` control line out of the reply; strip it from the displayed `text`; default
  safely if missing (`falter=false, provocation=none`).
- Call `escalate()`; return `{ text, game: { falter, provocation, menace, band, dogs }, debug, usage }`.
- `escalate()` is the source of truth for `dogs` — do not trust the model's own death judgement alone.

**`index.html`:**
- A **briefing card** overlay shown first (the §2 aim text), dismissed with "Enter the barn".
- A **menace meter** and **score** in the header, always visible; update both from each response's
  `game`. Send `menace` with each request; keep `score` client-side.
- On `dogs`: the red-screen death sequence — red overlay/background, the death narration shown
  large, input disabled, final score, "Face him again" restart (resets menace, score, history).
- Keep the existing chat rendering and the auto-scroll fix.

**`test/` + `eval/`:** `menace.test.js` (escalation, the fair-warning clamp, all bands — failing
tests first); a unit test for the control-line parse helper; an eval scenario for the death
(escalate to Dangerous, then sedition → dogs) and a check that the warning always precedes it.

**Lorebook:** no change required. The game is richer with more crack-point entries to expose, but
that is the Stage B lorebook job (`STAGE-B-HANDOVER.md`). The feature works with the current 3.

## 4. `escalate()` — the rules (starting values; playtest-tunable)

```
falterPart  = falter ? 1 : 0
provPart    = { none:0, mild:1, pushing:2, sedition:4 }[provocation]
raw         = currentMenace + falterPart + provPart

if provPart == 0:
    # a pure close-reading turn: clean hits make him Wary but never Dangerous,
    # and never de-escalate him below where he already is
    newMenace = min(raw, max(3, currentMenace))
else:
    newMenace = raw
    # fair-warning clamp: a jump from below Dangerous cannot reach the dogs in one turn
    if currentMenace < 4 and newMenace >= 6:
        newMenace = 5

newMenace = clamp(newMenace, 0, 6)
dogs      = newMenace == 6
band      = newMenace <= 1 ? 'composed' : newMenace <= 3 ? 'wary' : 'dangerous'
```

Sanity checks the tests must cover:
- 6 clean hits in a row → never exceeds Wary (3); never dies. (Clean play is safe.)
- First sedition from Composed → Dangerous (4), warning shown; second sedition → dogs.
- Pushing from Wary: 3 → 5 (Dangerous) → next push → dogs.
- A clean hit while at Dangerous (5) stays at 5 — does not escalate, does not de-escalate.
- No single turn ever goes Composed/Wary → dogs without passing through a shown Dangerous warning.

## 5. Locked — do not re-litigate

- Triggers: **both** sedition and over-pushing.
- Scoring: **push-your-luck**, `score = lies exposed`, no fixed target, no win screen — the game
  ends only on death (or the student stopping).
- The fair-warning rule: the dogs are never un-telegraphed.
- Model transport stays Haiku 4.5 via OpenRouter — a dedicated, $10-capped key, already in `.dev.vars`.

## 6. Out of scope

- The Stage B lorebook (still Peter's to curate — `STAGE-B-HANDOVER.md`).
- Graduation to the classroom AI library; prompt caching; score persistence / leaderboards.

## 7. Peter's working preferences

Be brief. Write the failing test first. Confirm scope before building, don't expand it. This is a
classroom resource, never an entertainment product. Fun-first: the death should feel dramatic and
the menace meter should build real tension — but the fair-warning rule keeps it fair, not punishing.

## 8. Continuation prompt (paste into the fresh chat)

> Read `napoleon-bot/STAKES-FEATURE-BRIEF.md` and build the stakes feature for the Napoleon bot.
> Stage A is complete and working (9/9 tests, runs locally). Confirm the plan with me, then build.
