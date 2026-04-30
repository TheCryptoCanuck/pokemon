# TODOs

Open follow-ups for the TCGP Deck Builder. Each item includes a severity
tag, effort estimate, and the file paths a future session needs.

When you finish one, move it to a `## Done` section at the bottom with a
link to the PR that closed it.

## Bugs

### 1. Meta deck templates are 18 cards, not 20

- **Severity:** Bug — visible to user
- **Effort:** Small (~30 min) once you know which 2 cards to add per deck
- **File:** `src/data/meta-decks.ts`
- **Why it matters:** Each of the 12 entries sums to 18 cards. `validateDeck`
  in `src/utils/deck-rules.ts:15` only flags `> 20`, so the templates render
  fine; but if you tap "Build this deck" from the Meta Decks tab the
  resulting deck is illegal at 18/20. Flagged as out-of-scope since PR #6;
  fixing it needs real TCGP meta knowledge for which 2 cards to add per deck.
- **Acceptance:** every entry in `META_DECKS` sums (`reduce(s + count)`) to 20.

### 2. Erika misclassified as `accel`

- **Severity:** Bug — silently inflates Energy Acceleration scores
- **Effort:** Trivial (1 line)
- **File:** `src/data/trainer-roles.ts` (line for `Erika`)
- **Why it matters:** In TCGP, Erika's "Soothing Aroma" heals 50 from a Grass
  Pokémon — she's a `heal`, not `accel`. Currently any psychic deck with
  Erika gets a free Energy Acceleration boost. Move her to `heal` and remove
  her from `ACCEL_TYPE`.
- **Acceptance:** rebuilding a psychic deck no longer credits "1 accel
  trainer (grass)" for an Erika that doesn't accelerate psychic energy.

### 3. Energy Acceleration heuristic doesn't type-match

- **Severity:** Bug — minor score inflation
- **Effort:** Small
- **Files:** `src/utils/deck-scoring.ts` (`energyAccel`),
  `src/data/trainer-roles.ts` (`ACCEL_TYPE`)
- **Why it matters:** A grass accel trainer (Erika once #2 is fixed —
  pretend Brock for fighting) still counts as an accel source in a psychic
  deck even though it can't accelerate psychic energy. The heuristic should
  intersect `ACCEL_TYPE[trainer]` with `opts.energyTypes` before crediting.
- **Acceptance:** Auto-Build → psychic does NOT show "(grass)" in the Energy
  Acceleration message.

### 4. Investigate Mewtwo ex HP shown as 50

- **Severity:** Bug — possibly upstream data, possibly modal display
- **Effort:** Small (data investigation)
- **File:** `src/components/shared/CardModal.tsx` (HP rendering)
- **Why it matters:** Dogfood during PR #13 showed Mewtwo ex with HP 50; the
  card has 150 HP in TCGP. May be the upstream `cards.extra.json` having
  wrong data for a specific printing, or a unit mix-up between `health`
  (correct base field) and a future field. Verify a few other ex Pokémon to
  see if the issue is one card or general.
- **Acceptance:** all ex Pokémon show their published HP in the modal.

## Hardening

### 5. Add "Clear stored API key" button

- **Severity:** Hardening — defensive
- **Effort:** Small
- **File:** `src/components/collection/VideoImport.tsx`
- **Why it matters:** The Anthropic API key is stored in localStorage as
  `tcgp-anthropic-key`. If the user lends their phone, anyone can hit
  console.anthropic.com on it with that key. Add a small "Clear stored key"
  link below the API key input that calls `setStoredApiKey("")` and clears
  the input field.
- **Acceptance:** tapping the link wipes the stored key; reloading the page
  shows an empty key field.

### 6. Automate rich card data refresh via GitHub Action

- **Severity:** Hardening — convenience
- **Effort:** Medium
- **File:** new `.github/workflows/fetch-rich-cards.yml`
- **Why it matters:** When a new TCGP set ships, attack/ability data is
  stale until someone runs `node scripts/fetch-rich-cards.mjs` and commits
  `public/cards-rich.json`. A weekly scheduled Action that runs the script
  and opens a PR if the diff is non-trivial would catch new sets without
  manual intervention.
- **Acceptance:** a scheduled workflow opens a PR when hugoburguete ships a
  new set; the deploy workflow runs on merge as today.

## v1.4 candidates

### 7. PWA install prompt

- **Severity:** Feature
- **Effort:** Medium (~1 hour)
- **Files:** new `public/manifest.json`, new icon assets, `index.html` link
  tags, optional `public/sw.js` for offline cards-rich caching
- **Why it matters:** Adds an "Add to home screen" prompt on Android Chrome
  so the app opens with its own icon and full-screen chrome (no Chrome tab
  bar). Needs a 192×192 + 512×512 icon and a `manifest.json` with display
  `standalone`. Service worker is optional but unlocks offline use.
- **Acceptance:** Chrome menu on Android shows "Install app"; tapping it
  drops a TCGP icon on the launcher; cold-launch opens directly in the SPA.

### 8. Auto-discover power pairings from ability data

- **Severity:** Feature
- **Effort:** Medium
- **Files:** `src/data/synergy.ts` (extend or replace `POWER_PAIRINGS`),
  `src/utils/deck-scoring.ts` (`powerPairings` heuristic)
- **Why it matters:** `POWER_PAIRINGS` is hand-curated and dates fast. With
  `cards-rich.json` we can detect synergy programmatically: a Pokémon with an
  energy-accel ability (`hasEnergyAccel`) of element X paired with a heavy
  attacker of element X is likely a real synergy. The hand list becomes a
  curated *bonus* list on top of the auto-discovered baseline.
- **Acceptance:** scoring a Hydreigon + Mega Absol ex deck (not in the
  hand list) correctly credits a power pairing.

### 9. "Build this deck" button on Meta Decks tab

- **Severity:** Feature
- **Effort:** Small (composition)
- **Files:** `src/components/meta/MetaDeckCard.tsx` (button), `src/App.tsx`
  (`handleBuildMetaDeck` → call `autoBuild` to fill to 20)
- **Why it matters:** Today's "Build this deck" creates a literal copy of
  the meta template (18 cards, not legal — see TODO #1). Pipe through
  `auto-build.ts`'s greedy fill so the result is always a legal 20-card
  deck. Effectively closes TODO #1 from a UX angle even before the data
  fix.
- **Acceptance:** every meta-deck "Build" produces a 20/20 valid deck with
  the original 18 cards as the seed and the auto-builder filling the
  remaining 2 from staples or backup attackers.

## Done

_Move closed items here with the PR link, e.g._

- ~~Tap any deck card row to open the detail modal~~ — closed by [PR #13](https://github.com/TheCryptoCanuck/pokemon/pull/13)
