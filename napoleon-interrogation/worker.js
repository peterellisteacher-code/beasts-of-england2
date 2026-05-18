import { NAPOLEON_SYSTEM_PROMPT } from './system-prompt.js';
import { buildContextBlock } from './lorebook.js';
import lorebook from './napoleon-lorebook.json';
import portraitManifest from './portrait-manifest.json';
import { escalate, bandFor, parseControlLine, selectPortrait, clampEmotion } from './menace.js';

const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';
const MODEL = 'anthropic/claude-haiku-4.5';
const MAX_TOKENS = 400;
const TEMPERATURE = 0.7;
const MAX_MESSAGE_CHARS = 1000;
const MAX_HISTORY = 20;

// Band labels written into the per-turn state line the model is given.
const BAND_LABEL = { composed: 'COMPOSED', wary: 'WARY', dangerous: 'DANGEROUS' };

// The portrait's threat must never read calmer than the menace band — floor it
// per band so the picture on screen can never contradict the meter.
const THREAT_FLOOR = { composed: 0.0, wary: 0.4, dangerous: 0.7 };

// Deterministic spoken warning, appended by the worker on the turn menace first
// crosses into the Dangerous band. The model is told only its INCOMING (lower)
// band, so it cannot voice the warning itself on the transition turn — this
// guarantees the non-negotiable fair-warning rule: the dogs are never untold.
const DANGEROUS_WARNING =
  '*Napoleon\'s great head lowers, and behind him the dogs rise from the straw and stand.* ' +
  '"Hear me, and hear me once. Press me again as you have, or raise your voice against my farm, ' +
  'and these dogs will have the last word with you. I will not say it twice."';

// The death narration. escalate() is the sole authority for when the dogs are
// loose; on a death turn the worker owns the text outright. Smoke-testing showed
// the model — told only its incoming band — writes a final warning rather than
// the death itself, so its text is never trusted once the dogs are ruled loose.
const DEATH_NARRATION =
  '*Napoleon does not raise his voice. He moves his great head a single degree toward the dogs, ' +
  'and they come off their haunches as one. There is no second warning. The straw, the lantern, ' +
  'the wall with its painted words — the barn is the last thing the visitor sees clearly.*';

function corsHeaders(origin) {
  return {
    'access-control-allow-origin': origin || '*',
    'access-control-allow-methods': 'POST, OPTIONS',
    'access-control-allow-headers': 'content-type',
  };
}

function jsonResponse(obj, status, origin) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'content-type': 'application/json', ...corsHeaders(origin) },
  });
}

// The client sends the menace it currently holds; never trust it blindly.
function clampMenace(v) {
  return Number.isInteger(v) ? Math.min(6, Math.max(0, v)) : 0;
}

async function handleNapoleon(body, env, origin) {
  if (!env.OPENROUTER_API_KEY) {
    return jsonResponse({ error: 'Server misconfigured: OPENROUTER_API_KEY not set' }, 500, origin);
  }

  const rawMessage = typeof body.message === 'string' ? body.message.slice(0, MAX_MESSAGE_CHARS) : '';
  const message = rawMessage.trim();
  if (!message) {
    return jsonResponse({ error: 'Empty message' }, 400, origin);
  }

  const menaceIn = clampMenace(body.menace);
  const bandIn = bandFor(menaceIn);

  const rawHistory = Array.isArray(body.history) ? body.history : [];
  const history = rawHistory
    .filter(
      item =>
        item && typeof item === 'object' &&
        ['student', 'napoleon'].includes(item.role) &&
        typeof item.content === 'string'
    )
    .slice(-MAX_HISTORY);

  const ctx = buildContextBlock({ history, message, lorebook });

  const mapped = history.map(item => ({
    role: item.role === 'napoleon' ? 'assistant' : 'user',
    content: item.content,
  }));

  while (mapped.length && mapped[0].role === 'assistant') mapped.shift();

  // Tell Napoleon his current menace band for this turn (section 4 of the prompt).
  const stateLine =
    `[NAPOLEON'S STATE THIS TURN] ${BAND_LABEL[bandIn]} — ` +
    `behave as section 4 directs for the ${BAND_LABEL[bandIn]} state.`;

  mapped.push({ role: 'user', content: ctx.block + '\n\n' + stateLine + '\n\nVisitor: ' + message });

  let res;
  try {
    res = await fetch(OPENROUTER_URL, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${env.OPENROUTER_API_KEY}`,
        'content-type': 'application/json',
        'x-title': 'Napoleon Bot (Stakes)',
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: MAX_TOKENS,
        temperature: TEMPERATURE,
        messages: [{ role: 'system', content: NAPOLEON_SYSTEM_PROMPT }, ...mapped],
      }),
    });
  } catch {
    return jsonResponse({ error: 'Upstream unavailable' }, 502, origin);
  }

  if (!res.ok) {
    return jsonResponse({ error: 'Upstream error', status: res.status }, 502, origin);
  }

  const data = await res.json();
  const rawReply = data?.choices?.[0]?.message?.content ?? '';

  // Pull the hidden control line out of the reply; default safely if it is missing.
  const parsed = parseControlLine(rawReply);
  let text = parsed.text;

  // The menace state machine. escalate() is the SOLE authority for `dogs` — the
  // model's own death judgement is never trusted on its own.
  const result = escalate(menaceIn, parsed.falter, parsed.provocation);

  // Fair-warning enforcement: if this turn first carries Napoleon into the
  // Dangerous band (and it is not itself a death), make sure the spoken warning
  // is heard — the model only knew its lower incoming band.
  if (result.band === 'dangerous' && bandIn !== 'dangerous' && !result.dogs) {
    text = (text ? text + '\n\n' : '') + DANGEROUS_WARNING;
  }

  // If the dogs are loose, the reply IS the death — the worker owns that
  // narration so the death screen can never show a hedged warning instead.
  if (result.dogs) {
    text = DEATH_NARRATION;
  }

  // Portrait: the death image when the dogs are loose, otherwise the nearest
  // emotional portrait. Threat is floored to the band so picture matches meter.
  const emotion = clampEmotion(parsed.emotion);
  emotion.threat = Math.max(emotion.threat, THREAT_FLOOR[result.band] ?? 0);
  const portraitId = result.dogs
    ? (portraitManifest.deathPortrait || 'the_dogs')
    : selectPortrait(emotion, portraitManifest.portraits);
  const portraitEntry = portraitManifest.portraits.find(p => p.id === portraitId) || null;

  return jsonResponse(
    {
      text,
      game: {
        falter: parsed.falter,
        provocation: parsed.provocation,
        menace: result.menace,
        band: result.band,
        dogs: result.dogs,
      },
      emotion,
      portrait: {
        id: portraitId,
        file: portraitEntry ? portraitEntry.file : null,
      },
      debug: {
        narratorPath: ctx.narratorPath,
        matchedKeys: ctx.matched.map(e => e.keys[0] || '?'),
        menaceIn,
        bandIn,
      },
      usage: data?.usage ?? null,
    },
    200,
    origin
  );
}

export default {
  async fetch(req, env) {
    const origin = req.headers.get('origin') || '*';

    if (req.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(origin) });
    }

    if (req.method !== 'POST') {
      return jsonResponse({ error: 'Method not allowed' }, 405, origin);
    }

    let body;
    try {
      body = await req.json();
    } catch {
      return jsonResponse({ error: 'Bad JSON' }, 400, origin);
    }

    const url = new URL(req.url);
    const lastSegment = url.pathname.split('/').filter(Boolean).at(-1) ?? '';

    if (lastSegment === 'napoleon' || lastSegment === '') {
      return handleNapoleon(body, env, origin);
    }

    return jsonResponse({ error: 'Not found' }, 404, origin);
  },
};
