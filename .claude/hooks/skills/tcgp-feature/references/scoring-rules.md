# Deck scoring — rules and procedures

The scoring system in `src/utils/deck-scoring.ts` runs 10 weighted heuristics. This file is the procedure for changing them.

## The invariant

The 10 weights must sum to **exactly 1.00**. Not 0.999, not 1.001 — exactly 1.00. The aggregate score is computed as `sum(weight_i * score_i) * 100` and rounded; weight drift means scores drift.

The current weights (sum check: 0.15+0.15+0.15+0.10+0.10+0.10+0.10+0.05+0.05+0.05 = 1.00):

| Weight | Heuristic |
|---|---|
| 0.15 | Basic Consistency |
| 0.15 | Evolution Lines |
| 0.15 | Energy Acceleration |
| 0.10 | Trainer Mix |
| 0.10 | Power Pairings |
| 0.10 | Weakness Coverage |
| 0.10 | Redundancy |
| 0.05 | Recovery |
| 0.05 | Prize Math (ex Density) |
| 0.05 | Bench Mobility |

Run `scripts/validate_weights.mjs` before every commit that touches `deck-scoring.ts`.

## The HeuristicResult shape

Every heuristic returns the same shape:

```ts
interface HeuristicResult {
  score: number;        // [0, 1]
  status: 'green' | 'yellow' | 'red';
  suggestion: string;   // one line, user-facing, actionable
}
```

**Score thresholds for status:**
- `score >= 0.75` → green
- `0.40 <= score < 0.75` → yellow
- `score < 0.40` → red

These thresholds are consistent across all heuristics. Don't introduce per-heuristic thresholds without a strong reason — the user reads the traffic-light row and expects "red means seriously broken" regardless of which heuristic.

**Suggestion writing.** The suggestion is what the user reads. It should:

- Be actionable — "Add a third draw supporter" beats "Draw is low".
- Cite specifics where possible — "All 4 attackers weak to Dark — diversify" beats "Weakness coverage is poor".
- Stay under ~70 characters so it doesn't wrap awkwardly on phones.
- Read as a sentence. No telegraphic shorthand.

## Adding a new heuristic

1. Pick its weight. Total must remain 1.00, so you're stealing from somewhere. Document the trade in the PR.
2. Decide what input it consumes. Most heuristics take `(deck: Deck, cards: Card[])`. If you need new card metadata, add it to `Card` first, in a separate PR.
3. Write the heuristic as a pure function returning `HeuristicResult`.
4. Add its row to the weights table and the README's scoring table.
5. Run `scripts/score_regression.mjs` — see how it shifts the fixture deck scores.
6. Update the README's heuristic table.

## Tuning an existing heuristic

The danger here is "improving" the heuristic for one deck while making it worse for others. The score-regression script protects against this.

1. Make the change.
2. Run `scripts/score_regression.mjs`. It runs all fixture decks through both old and new versions and reports deltas.
3. Any individual deck delta over **5 points** needs a written justification in the PR description.
4. Aggregate change in mean score across all fixtures over **2 points** (in either direction) is a red flag — your change is more than a tweak.

## Fixture decks

Stored in `scripts/fixtures/decks/*.json`. Each one is a real or hand-built deck with:

- A name (`charizard-aggro.json`, `mewtwo-control.json`, etc.)
- The card list
- The expected score at last commit

Adding a new fixture: include a deck that exercises a corner the existing fixtures don't (a deck with 0 supporters, a deck with 6 different attackers, a stage-2 evolution deck). The fixtures are how we discover regressions.

When a fixture's expected score legitimately changes (because you tuned a heuristic on purpose), update its expected score in the same PR. Reviewers should see both the heuristic change and the fixture change in the diff.

## The README scoring table

Every weight or heuristic change requires updating the table in `README.md` under "Deck scoring". Out-of-sync README is itself a bug — the user reads that table to understand what's changing in their decks.

The table format is fixed columns: Weight | Heuristic | What it checks. The "What it checks" column should be the simplest accurate description; "Hypergeometric P(no mulligan) from Basic count" is right because it tells the user the math; "Various Basic-related checks" is wrong because it tells the user nothing.

## Things that look like scoring changes but aren't

These don't need the regression-test ritual:

- Renaming a heuristic (cosmetic).
- Reformatting the suggestion string without changing its content.

These do need the ritual:

- Any change to a heuristic's logic.
- Any change to a weight.
- Any change to the status thresholds (it changes the traffic lights even if not the score).
- Adding or removing a heuristic.
- Changing how `deck-scoring.ts` reads card data (e.g. switching from `attacks[0]` to `attacks.find(...)` — that's logic, not formatting).
