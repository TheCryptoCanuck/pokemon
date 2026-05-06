#!/usr/bin/env node
// diff_card_data.mjs
// Compares two versions of public/cards-rich.json (typically pre- and post-
// running fetch-rich-cards.mjs) and reports added/removed/changed cards.
//
// Usage:
//   # Compare working tree vs. last commit:
//   git show HEAD:public/cards-rich.json > /tmp/cards-rich.before.json
//   node <skill-path>/scripts/diff_card_data.mjs \
//        --before /tmp/cards-rich.before.json \
//        --after public/cards-rich.json
//
// Output is a summary plus per-card detail for changes.

import { readFileSync, existsSync } from 'node:fs';

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i++) {
    if (argv[i] === '--before' && argv[i + 1]) { args.before = argv[i + 1]; i++; }
    else if (argv[i] === '--after' && argv[i + 1]) { args.after = argv[i + 1]; i++; }
  }
  return args;
}

const args = parseArgs(process.argv);
if (!args.before || !args.after) {
  console.error('Usage: diff_card_data.mjs --before <path> --after <path>');
  process.exit(2);
}

if (!existsSync(args.before)) {
  console.error(`ERROR: before file not found: ${args.before}`);
  process.exit(2);
}
if (!existsSync(args.after)) {
  console.error(`ERROR: after file not found: ${args.after}`);
  process.exit(2);
}

let before, after;
try {
  before = JSON.parse(readFileSync(args.before, 'utf8'));
  after = JSON.parse(readFileSync(args.after, 'utf8'));
} catch (e) {
  console.error(`ERROR: could not parse JSON: ${e.message}`);
  process.exit(2);
}

// Index by card ID. The rich-card files may be either an array or a keyed
// object — handle both.
function indexById(data) {
  const map = new Map();
  if (Array.isArray(data)) {
    for (const card of data) {
      const id = card.id ?? `${card.set}-${card.number}`;
      if (id) map.set(id, card);
    }
  } else {
    for (const [id, card] of Object.entries(data)) {
      map.set(id, card);
    }
  }
  return map;
}

const beforeMap = indexById(before);
const afterMap = indexById(after);

const beforeIds = new Set(beforeMap.keys());
const afterIds = new Set(afterMap.keys());

const added = [...afterIds].filter((id) => !beforeIds.has(id)).sort();
const removed = [...beforeIds].filter((id) => !afterIds.has(id)).sort();

const changed = [];
for (const id of afterIds) {
  if (!beforeIds.has(id)) continue;
  const a = JSON.stringify(beforeMap.get(id));
  const b = JSON.stringify(afterMap.get(id));
  if (a !== b) changed.push(id);
}
changed.sort();

console.log(`Before: ${beforeMap.size} cards`);
console.log(`After:  ${afterMap.size} cards`);
console.log('');
console.log(`Added:   ${added.length}`);
console.log(`Removed: ${removed.length}`);
console.log(`Changed: ${changed.length}`);
console.log('');

if (removed.length > 0 && afterMap.size > beforeMap.size * 0.95) {
  console.warn(`WARN: ${removed.length} cards were removed even though total size barely changed.`);
  console.warn('That usually means the upstream renamed IDs or restructured. Investigate.');
  console.warn('');
}

if (added.length > 0) {
  console.log('--- ADDED ---');
  for (const id of added.slice(0, 50)) console.log(`  ${id}`);
  if (added.length > 50) console.log(`  ... and ${added.length - 50} more`);
  console.log('');
}

if (removed.length > 0) {
  console.log('--- REMOVED ---');
  for (const id of removed.slice(0, 50)) console.log(`  ${id}`);
  if (removed.length > 50) console.log(`  ... and ${removed.length - 50} more`);
  console.log('');
}

if (changed.length > 0) {
  console.log('--- CHANGED (first 20) ---');
  for (const id of changed.slice(0, 20)) {
    console.log(`  ${id}`);
    const b = beforeMap.get(id);
    const a = afterMap.get(id);
    const allKeys = new Set([...Object.keys(b), ...Object.keys(a)]);
    for (const k of allKeys) {
      const bv = JSON.stringify(b[k]);
      const av = JSON.stringify(a[k]);
      if (bv !== av) {
        console.log(`    ${k}:`);
        console.log(`      before: ${bv}`);
        console.log(`      after:  ${av}`);
      }
    }
  }
  if (changed.length > 20) console.log(`  ... and ${changed.length - 20} more changed`);
}

process.exit(0);
