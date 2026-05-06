#!/usr/bin/env node
// validate_weights.mjs
// Asserts that the weights in src/utils/deck-scoring.ts sum to exactly 1.00.
// Exit code 0 if valid, 1 otherwise.
//
// Usage (from the repo root):
//   node <skill-path>/scripts/validate_weights.mjs
// Or from anywhere:
//   node validate_weights.mjs --file /path/to/deck-scoring.ts

import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

function findScoringFile(cwd) {
  const candidates = ['src/utils/deck-scoring.ts', 'src/utils/deckScoring.ts', 'src/utils/scoring.ts'];
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
const filePath = args.file ?? findScoringFile(process.cwd());

if (!filePath || !existsSync(filePath)) {
  console.error('ERROR: could not locate deck-scoring file.');
  console.error('Pass --file <path> or run from the repo root.');
  process.exit(2);
}

const source = readFileSync(filePath, 'utf8');
const weightMatches = [...source.matchAll(/\bweight\s*:\s*(-?\d+(?:\.\d+)?)/g)];

if (weightMatches.length === 0) {
  console.error(`ERROR: no \`weight: <number>\` patterns found in ${filePath}`);
  console.error('If the file has been refactored, update validate_weights.mjs to match.');
  process.exit(2);
}

const weights = weightMatches.map((m) => parseFloat(m[1]));
const sum = weights.reduce((a, b) => a + b, 0);
const expected = 1.0;
const tolerance = 1e-9;

console.log(`Found ${weights.length} weight declarations in ${filePath}`);
console.log(`Weights: ${weights.map((w) => w.toFixed(2)).join(', ')}`);
console.log(`Sum: ${sum.toFixed(10)}`);

if (Math.abs(sum - expected) > tolerance) {
  console.error(`\nFAIL: weights sum to ${sum.toFixed(4)}, expected 1.00 (tolerance ${tolerance}).`);
  console.error('Adjust one or more weights so the total is exactly 1.00.');
  process.exit(1);
}

console.log('\nOK: weights sum to 1.00.');
process.exit(0);
