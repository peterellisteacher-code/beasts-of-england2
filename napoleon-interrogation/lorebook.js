import { HARD_RULES_BLOCK } from './system-prompt.js';

export function buildContextBlock({ history, message, lorebook }) {
  const seq = [...history, { role: 'student', content: message }];

  const depth =
    Number.isInteger(lorebook.scan_depth) && lorebook.scan_depth > 0
      ? lorebook.scan_depth
      : 1;

  const window = seq.slice(-depth);
  const scanText = window.map(item => item.content).join(' ').toLowerCase();

  const enabledEntries = lorebook.entries.filter(e => e.enabled === true);

  const matched = enabledEntries.filter(e =>
    e.keys.some(k => scanText.includes(k.toLowerCase()))
  );

  // narratorPath fires only when nothing matched a keyword — constant entries
  // included. A constant-only match (a question about Napoleon or the Rebellion)
  // is in scope, so the narrator device must not fire for it.
  const narratorPath = matched.length === 0;

  // injected = enabled constants + enabled keyword-matched entries, deduplicated, sorted
  const injectedSet = new Map();
  for (const e of enabledEntries) {
    if (e.constant || matched.includes(e)) {
      injectedSet.set(e, true);
    }
  }
  const injected = [...injectedSet.keys()].sort(
    (a, b) => a.insertion_order - b.insertion_order
  );

  const parts = ['[CONTEXT]', ...injected.map(e => e.content)];

  if (narratorPath) {
    parts.push(
      'NO LOREBOOK ENTRY MATCHED — the visitor\'s question is not covered by any passage above. Use the narrator device: reply with a single line of italic third-person narration of Napoleon declining. Do not answer from outside knowledge.'
    );
  }

  parts.push('---', HARD_RULES_BLOCK, '[END CONTEXT]');

  const block = parts.join('\n\n');

  return { block, matched, narratorPath };
}
