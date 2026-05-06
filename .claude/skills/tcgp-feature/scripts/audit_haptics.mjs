#!/usr/bin/env node
// audit_haptics.mjs
// Finds every call to `tap()` in src/ and reports the surrounding context so a
// reviewer can confirm each one is a deck-mutation or pin/unpin.
//
// Calls in any other context (filter clicks, modal opens, tab switches, scroll
// handlers, etc.) are policy violations per references/conventions.md.
//
// This script does not enforce — it surfaces. The human (or Claude) decides
// whether each site is legitimate. Output is grep-style.
//
// Usage:
//   node <skill-path>/scripts/audit_haptics.mjs
//   node audit_haptics.mjs --src /path/to/src

import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, resolve, relative } from 'node:path';

function parseArgs(argv) {
  const args = { src: 'src' };
  for (let i = 2; i < argv.length; i++) {
    if (argv[i] === '--src' && argv[i + 1]) { args.src = argv[i + 1]; i++; }
  }
  return args;
}

function walk(dir, results = []) {
  for (const entry of readdirSync(dir)) {
    if (entry.startsWith('.') || entry === 'node_modules') continue;
    const full = join(dir, entry);
    const stat = statSync(full);
    if (stat.isDirectory()) walk(full, results);
    else if (/\.(ts|tsx|js|jsx)$/.test(entry)) results.push(full);
  }
  return results;
}

const args = parseArgs(process.argv);
const srcDir = resolve(process.cwd(), args.src);

let files;
try {
  files = walk(srcDir);
} catch (e) {
  console.error(`ERROR: could not read ${srcDir}: ${e.message}`);
  console.error('Pass --src <path> or run from the repo root.');
  process.exit(2);
}

const ALLOWED_CONTEXTS = ['add', 'remove', 'increment', 'decrement', 'pin', 'unpin', 'mutate', 'save'];
const SUSPICIOUS_CONTEXTS = ['filter', 'modal', 'tab', 'scroll', 'hover', 'focus', 'open', 'close'];

let totalCalls = 0;
let suspiciousCalls = 0;
const findings = [];

for (const file of files) {
  if (file.endsWith('haptics.ts') || file.endsWith('haptics.js')) continue;

  const lines = readFileSync(file, 'utf8').split('\n');
  for (let i = 0; i < lines.length; i++) {
    if (/\btap\s*\(/.test(lines[i])) {
      totalCalls++;
      const start = Math.max(0, i - 3);
      const context = lines.slice(start, i + 1).join('\n');
      const lowered = context.toLowerCase();

      const looksAllowed = ALLOWED_CONTEXTS.some((kw) => lowered.includes(kw));
      const looksSuspicious = SUSPICIOUS_CONTEXTS.some((kw) => lowered.includes(kw));
      const verdict = looksSuspicious && !looksAllowed ? 'SUSPICIOUS'
                    : looksAllowed ? 'OK?'
                    : 'REVIEW';

      if (verdict === 'SUSPICIOUS') suspiciousCalls++;

      findings.push({
        file: relative(process.cwd(), file),
        line: i + 1,
        verdict,
        context: lines.slice(start, i + 1).map((l, idx) => `    ${start + idx + 1}: ${l}`).join('\n'),
      });
    }
  }
}

if (totalCalls === 0) {
  console.log('No tap() calls found. Either there are none or this script is looking in the wrong place.');
  process.exit(0);
}

console.log(`Found ${totalCalls} tap() call site(s) across ${files.length} file(s).`);
console.log(`  ${suspiciousCalls} flagged as SUSPICIOUS (in filter/modal/tab/etc context).\n`);

for (const f of findings) {
  console.log(`[${f.verdict}] ${f.file}:${f.line}`);
  console.log(f.context);
  console.log('');
}

console.log('Verdicts are heuristic. Review each call site against the rule:');
console.log('  tap() fires on deck mutations and pin/unpin only — never on navigation.');

process.exit(0);
