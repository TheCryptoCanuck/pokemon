# Score regression fixtures

Each `*.json` file in this directory is a deck whose expected score is known.
`score_regression.mjs` runs every fixture through the current scoring code and
flags drift.

Shape:

```json
{
  "name": "charizard-aggro",
  "deck": { /* full Deck object — name, cards, energyTypes, etc. */ },
  "expectedScore": 78
}
```

When you tune a heuristic on purpose, update the affected fixtures'
`expectedScore` in the same PR. Reviewers should see both the scoring change
and the fixture change in the diff.

When you add a new fixture, pick a deck that exercises a corner the existing
fixtures don't:

- 0 supporters
- 6 different attackers (no redundancy)
- a stage-2 evolution line
- a wall-only control deck
- a deck where every attacker shares one weakness type

The fixtures are how we discover regressions. The more diverse, the more useful.
