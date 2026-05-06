#!/usr/bin/env node
// score_regression.mjs
// Runs every fixture deck through the current scoring code and compares the
// result against the deck's expected score. Reports deltas.
//
// Fixtures are stored alongside this script in fixtures/decks/*.json. Each
// fixture has the shape:
//   { "name": "...", "deck": <Deck>, "expectedScore": <number 0-100> }
//
// Usage (from the repo root, via tsx so .ts imports work):
//   npx tsx <skill-path>/scripts/score_regression.mjs \
//     --scoring src/utils/deck-scoring.ts \
//     --fixtures <skill-path>/scripts/fixtures/decks
//
// Or pass --scoring pointing at a built JS file if you prefer not to use tsx.

import { readdirSync, readFileSync, existsSync } from 'node:fs';
import { resolve, join, dirname } from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i++) {
    if (argv[i] === '--fixtures' && argv[i + 1]) { args.fixtures = argv[i + 1]; i++; }
    else if (argv[i] === '--scoring' && argv[i + 1]) { args.scoring = argv[i + 1]; i++; }
  }
  return args;
}

const args = parseArgs(process.argv);
const cwd = process.cwd();
const __dirname = dirname(fileURLToPath(import.meta.url));

const fixturesDir = args.fixtures
  ? resolve(args.fixtures)
  : resolve(__dirname, 'fixtures/decks');

const scoringPath = args.scoring ? resolve(args.scoring) : null;

if (!scoringPath || !existsSync(scoringPath)) {
  console.error('ERROR: cannot locate the scoring module.');
  console.error('Pass --scoring <path> pointing to a runnable module that exports `scoreDeck`.');
  console.error('');
  console.error('Recommended: run via tsx so the .ts file works directly:');
  console.error('  npx tsx <skill-path>/scripts/score_regression.mjs --scoring src/utils/deck-scoring.ts');
  process.exit(2);
}

if (!existsSync(fixturesDir)) {
  console.error(`ERROR: fixtures directory not found: ${fixturesDir}`);
  console.error('Create it and add at least one fixture before running this script.');
  process.exit(2);
}

let scoreDeck;
try {
  const mod = await import(pathToFileURL(scoringPath).href);
  scoreDeck = mod.scoreDeck ?? mod.default?.scoreDeck;
  if (typeof scoreDeck !== 'function') {
    throw new Error('scoreDeck is not a function in the imported module');
  }
} catch (e) {
  console.error(`ERROR: could not import scoring module: ${e.message}`);
  console.error('If the module is a .ts file, you must run this script via tsx or ts-node.');
  process.exit(2);
}

const fixtureFiles = readdirSync(fixturesDir).filter((f) => f.endsWith('.json'));
if (fixtureFiles.length === 0) {
  console.warn(`WARN: no fixtures in ${fixturesDir}`);
  console.warn('Add fixture JSON files following the documented shape.');
  process.exit(0);
}

const TOLERANCE = 0.5;
const REGRESSION_THRESHOLD = 5;
let totalDelta = 0;
let largeRegressions = 0;
const rows = [];

for (const file of fixtureFiles) {
  let fixture;
  try {
    fixture = JSON.parse(readFileSync(join(fixturesDir, file), 'utf8'));
  } catch (e) {
    console.warn(`SKIP: ${file} — invalid JSON: ${e.message}`);
    continue;
  }

  const { name, deck, expectedScore } = fixture;
  if (!deck || expectedScore == null) {
    console.warn(`SKIP: ${file} — missing 'deck' or 'expectedScore'`);
    continue;
  }

  let actual;
  try {
    const result = scoreDeck(deck);
    actual = typeof result === 'number' ? result : result.total ?? result.score;
  } catch (e) {
    console.warn(`SKIP: ${name ?? file} — scoreDeck threw: ${e.message}`);
    continue;
  }

  const delta = actual - expectedScore;
  totalDelta += delta;
  if (Math.abs(delta) >= REGRESSION_THRESHOLD) largeRegressions++;

  const status = Math.abs(delta) < TOLERANCE ? 'OK'
               : Math.abs(delta) < REGRESSION_THRESHOLD ? 'DRIFT'
               : 'REGRESSION';
  rows.push({ name: name ?? file, expected: expectedScore, actual, delta, status });
}

console.log('Score regression report');
console.log('=======================');
console.log('');
console.log('Name                                      Expected   Actual    Delta   Status');
console.log('--------------------------------------------------------------------------------');
for (const r of rows) {
  const sign = r.delta >= 0 ? '+' : '';
  console.log(
    `${r.name.padEnd(40)}  ${String(r.expected).padStart(7)}   ${r.actual.toFixed(1).padStart(6)}   ${(sign + r.delta.toFixed(1)).padStart(6)}   ${r.status}`
  );
}
console.log('');
console.log(`Total fixtures: ${rows.length}`);
console.log(`Mean delta:     ${(totalDelta / Math.max(rows.length, 1)).toFixed(2)} points`);
console.log(`Large regressions (>= ${REGRESSION_THRESHOLD} pts): ${largeRegressions}`);

if (largeRegressions > 0) {
  console.log('');
  console.log('Large regressions need a written justification in the PR description.');
  process.exit(1);
}
process.exit(0);
