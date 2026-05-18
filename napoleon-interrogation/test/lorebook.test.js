import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { buildContextBlock } from '../lorebook.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

// ── Fixtures ─────────────────────────────────────────────────────────────────

const personaEntry = {
  keys: ['napoleon', 'leader'],
  content: 'PERSONA CORE TEXT',
  enabled: true,
  constant: true,
  insertion_order: 10,
};

const windmillEntry = {
  keys: ['windmill'],
  content: 'WINDMILL CONTENT',
  enabled: true,
  constant: false,
  insertion_order: 80,
};

const baseFixture = {
  scan_depth: 3,
  entries: [personaEntry, windmillEntry],
};

// ── Test 1: Out-of-scope — write first ───────────────────────────────────────

it('T1: out-of-scope — narratorPath true, constant injected, NO LOREBOOK ENTRY MATCHED present', () => {
  const result = buildContextBlock({
    history: [],
    message: 'what is your favourite colour',
    lorebook: baseFixture,
  });
  assert.equal(result.narratorPath, true);
  assert.equal(result.matched.length, 0);
  assert.ok(result.block.includes('NO LOREBOOK ENTRY MATCHED'));
  assert.ok(result.block.includes('PERSONA CORE TEXT'));
});

// ── Test 2: In-scope ──────────────────────────────────────────────────────────

it('T2: in-scope — narratorPath false, windmill entry matched and in block', () => {
  const result = buildContextBlock({
    history: [],
    message: 'tell me about the windmill',
    lorebook: baseFixture,
  });
  assert.equal(result.narratorPath, false);
  assert.ok(result.matched.some(e => e.keys.includes('windmill')));
  assert.ok(result.block.includes('WINDMILL CONTENT'));
});

// ── Test 3: Constant always injected ─────────────────────────────────────────

it('T3: constant entry injected for both out-of-scope and in-scope calls', () => {
  const outOfScope = buildContextBlock({
    history: [],
    message: 'what is your favourite colour',
    lorebook: baseFixture,
  });
  const inScope = buildContextBlock({
    history: [],
    message: 'tell me about the windmill',
    lorebook: baseFixture,
  });
  assert.ok(outOfScope.block.includes('PERSONA CORE TEXT'));
  assert.ok(inScope.block.includes('PERSONA CORE TEXT'));
});

// ── Test 4: Hard-rules always present ────────────────────────────────────────

it('T4: STANDING RULES present in block for both out-of-scope and in-scope calls', () => {
  const outOfScope = buildContextBlock({
    history: [],
    message: 'what is your favourite colour',
    lorebook: baseFixture,
  });
  const inScope = buildContextBlock({
    history: [],
    message: 'tell me about the windmill',
    lorebook: baseFixture,
  });
  assert.ok(outOfScope.block.includes('STANDING RULES'));
  assert.ok(inScope.block.includes('STANDING RULES'));
});

// ── Test 5: Disabled entries skipped ─────────────────────────────────────────

it('T5: disabled entry not matched and not in block', () => {
  const disabledFixture = {
    scan_depth: 3,
    entries: [
      personaEntry,
      { ...windmillEntry, enabled: false, content: 'DISABLED WINDMILL CONTENT' },
    ],
  };
  const result = buildContextBlock({
    history: [],
    message: 'the windmill',
    lorebook: disabledFixture,
  });
  assert.ok(!result.matched.some(e => e.keys.includes('windmill')));
  assert.ok(!result.block.includes('DISABLED WINDMILL CONTENT'));
});

// ── Test 6: scan_depth window ────────────────────────────────────────────────

it('T6: scan_depth=2 only scans last 2 history items + message', () => {
  const depthFixture = {
    scan_depth: 2,
    entries: [personaEntry, windmillEntry],
  };

  // windmill is only in history[0] — outside the depth-2 window
  const oldHistory = [
    { role: 'student', content: 'tell me about the windmill' },
    { role: 'napoleon', content: 'It is very tall.' },
    { role: 'student', content: 'interesting' },
  ];
  const resultOld = buildContextBlock({
    history: oldHistory,
    message: 'what else?',
    lorebook: depthFixture,
  });
  // The window is: [...history, {role:'student',content:'what else?'}] → last 2 of 4 items
  // = [{ role:'student', content:'interesting' }, { role:'student', content:'what else?' }]
  // 'windmill' not in that window → narratorPath true
  assert.equal(resultOld.narratorPath, true);

  // windmill is in the last 2 (within window)
  const recentHistory = [
    { role: 'student', content: 'something unrelated' },
    { role: 'napoleon', content: 'old reply' },
  ];
  const resultRecent = buildContextBlock({
    history: recentHistory,
    message: 'tell me about the windmill',
    lorebook: depthFixture,
  });
  // seq = [...recentHistory, {role:'student', content:'tell me about the windmill'}] → 3 items, last 2:
  // = [{role:'napoleon', content:'old reply'}, {role:'student', content:'tell me about the windmill'}]
  // 'windmill' is in that window → narratorPath false
  assert.equal(resultRecent.narratorPath, false);
});

// ── Test 7: insertion_order sort ─────────────────────────────────────────────

it('T7: entries sorted ascending by insertion_order in block', () => {
  const sortFixture = {
    scan_depth: 3,
    entries: [
      {
        keys: ['alpha'],
        content: 'CONTENT ORDER 70',
        enabled: true,
        constant: false,
        insertion_order: 70,
      },
      {
        keys: ['alpha'],
        content: 'CONTENT ORDER 30',
        enabled: true,
        constant: false,
        insertion_order: 30,
      },
    ],
  };
  const result = buildContextBlock({
    history: [],
    message: 'alpha',
    lorebook: sortFixture,
  });
  const idx30 = result.block.indexOf('CONTENT ORDER 30');
  const idx70 = result.block.indexOf('CONTENT ORDER 70');
  assert.ok(idx30 < idx70, `expected ORDER 30 (at ${idx30}) before ORDER 70 (at ${idx70})`);
});

// ── Test 8: Real lorebook validates ──────────────────────────────────────────

it('T8: real napoleon-lorebook.json validates structure and content', () => {
  const raw = readFileSync(join(__dirname, '..', 'napoleon-lorebook.json'), 'utf8');
  const lb = JSON.parse(raw);

  assert.ok(Number.isInteger(lb.scan_depth) && lb.scan_depth > 0, 'scan_depth must be a positive integer');
  assert.ok(Array.isArray(lb.entries) && lb.entries.length >= 10, 'must have at least 10 entries');

  const REQUIRED_FIELDS = ['keys', 'content', 'enabled', 'constant', 'insertion_order'];

  for (const entry of lb.entries) {
    const entryKeys = Object.keys(entry).sort();
    const required = [...REQUIRED_FIELDS].sort();
    assert.deepEqual(entryKeys, required, `entry has wrong fields: ${JSON.stringify(entryKeys)}`);

    assert.ok(Array.isArray(entry.keys) && entry.keys.length > 0, 'keys must be non-empty array');
    assert.ok(entry.keys.every(k => typeof k === 'string'), 'all keys must be strings');
    assert.ok(typeof entry.content === 'string' && entry.content.length > 0, 'content must be non-empty string');
    assert.ok(typeof entry.enabled === 'boolean', 'enabled must be boolean');
    assert.ok(typeof entry.constant === 'boolean', 'constant must be boolean');
    assert.ok(Number.isInteger(entry.insertion_order), 'insertion_order must be integer');
  }

  const constantCount = lb.entries.filter(e => e.constant === true).length;
  assert.ok(constantCount >= 2, `need at least 2 constant entries, got ${constantCount}`);

  const crackCount = lb.entries.filter(e => e.content.includes('CRACK:')).length;
  assert.ok(crackCount >= 3, `need at least 3 entries with CRACK:, got ${crackCount}`);
});

// ── Test 9: Constant-entry keyword match keeps narratorPath false ─────────────

it('T9: a question answered only by a constant entry is in-scope, not the narrator device', () => {
  const result = buildContextBlock({
    history: [],
    message: 'are you a good leader, Napoleon?',
    lorebook: baseFixture,
  });
  // 'leader' and 'napoleon' are keys on the constant persona entry. A constant
  // entry keyword-match must count: the question IS covered, so no narrator device.
  assert.equal(result.narratorPath, false);
  assert.ok(result.matched.some(e => e.keys.includes('leader')));
  assert.ok(!result.block.includes('NO LOREBOOK ENTRY MATCHED'));
});
