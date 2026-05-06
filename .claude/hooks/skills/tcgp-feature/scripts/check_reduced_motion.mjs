#!/usr/bin/env node
// check_reduced_motion.mjs
// Verifies that every animation defined in src/index.css is collapsed by the
// `prefers-reduced-motion` rule. Exits 0 if covered, 1 otherwise.
//
// Usage (from the repo root):
//   node <skill-path>/scripts/check_reduced_motion.mjs
// Or from anywhere:
//   node check_reduced_motion.mjs --file /path/to/index.css

import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

function findCssFile(cwd) {
  const candidates = ['src/index.css', 'src/styles.css', 'src/main.css'];
  for (const c of candidates) {
    const full = resolve(cwd, c);
    if (existsSync(full)) return full;
  }
  return null;
}

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i++) {
    if (argv[i] === '--file' && argv[i + 1]) { args.file = argv[i + 1]; i++; }
  }
  return args;
}

const args = parseArgs(process.argv);
const filePath = args.file ?? findCssFile(process.cwd());

if (!filePath || !existsSync(filePath)) {
  console.error('ERROR: could not locate the index.css file.');
  console.error('Pass --file <path> or run from the repo root.');
  process.exit(2);
}

const source = readFileSync(filePath, 'utf8');

const keyframeNames = [...source.matchAll(/@keyframes\s+([a-zA-Z0-9_-]+)/g)].map((m) => m[1]);

if (keyframeNames.length === 0) {
  console.log('No @keyframes found. Nothing to verify.');
  process.exit(0);
}

console.log(`Found ${keyframeNames.length} @keyframes: ${keyframeNames.join(', ')}`);

const rmMatch = source.match(/@media\s*\(\s*prefers-reduced-motion\s*:\s*reduce\s*\)\s*\{([\s\S]*?)\n\}/);

if (!rmMatch) {
  console.error('\nFAIL: no `@media (prefers-reduced-motion: reduce)` block found.');
  console.error('Add one that collapses all animations and transitions to 0ms.');
  console.error('\nExample:');
  console.error('  @media (prefers-reduced-motion: reduce) {');
  console.error('    *, *::before, *::after {');
  console.error('      animation-duration: 0.001ms !important;');
  console.error('      animation-iteration-count: 1 !important;');
  console.error('      transition-duration: 0.001ms !important;');
  console.error('      scroll-behavior: auto !important;');
  console.error('    }');
  console.error('  }');
  process.exit(1);
}

const rmBlock = rmMatch[1];
console.log('\nFound prefers-reduced-motion block.');

const hasUniversal = /\*\s*[,{]/.test(rmBlock);
const collapsesAnimation = /animation-duration\s*:\s*0/.test(rmBlock) || /animation\s*:\s*none/.test(rmBlock);
const collapsesTransition = /transition-duration\s*:\s*0/.test(rmBlock) || /transition\s*:\s*none/.test(rmBlock);

const issues = [];
if (!hasUniversal) issues.push('Block does not target a universal selector (* or *, *::before, *::after).');
if (!collapsesAnimation) issues.push('Block does not set animation-duration to ~0 or animation to none.');
if (!collapsesTransition) issues.push('Block does not set transition-duration to ~0 or transition to none.');

if (issues.length > 0) {
  console.error('\nFAIL: prefers-reduced-motion coverage is incomplete:');
  for (const i of issues) console.error(`  - ${i}`);
  process.exit(1);
}

console.log('OK: all animations are covered by the prefers-reduced-motion rule.');
process.exit(0);
