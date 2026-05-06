---
name: tcgp-feature
description: "Use whenever the user asks to add, modify, fix, refactor, or extend a feature in the TCGP Deck Builder repo (TheCryptoCanuck/pokemon). Triggers: any work in src/, public/cards-rich.json, scripts/fetch-rich-cards.mjs, .github/workflows/deploy.yml; mentions of TCGP, Pokémon TCG Pocket, deck builder, deck scoring, auto-build, meta decks, collection tab, video import, card modal, pinned decks, score tweens; phrases like 'add a tab', 'add a filter', 'tweak a heuristic', 'support a new card type', 'fix the deck editor'. Also use when debugging on Android Chrome, when a refactor risks the order-1 lg:order-2 mobile layout, or when changes might affect localStorage shape (tcgp-collection, tcgp-decks, tcgp-anthropic-key). Use even when the user just says 'work on the pokemon repo' inside the repo without naming TCGP. Do NOT use for native iOS/Android dev, unrelated React projects, or generic web-dev questions outside this repo."
---

# TCGP Deck Builder — Feature Work Skill

Repo: `TheCryptoCanuck/pokemon` — a React 19 + Vite 8 + TypeScript + Tailwind 4 mobile-first SPA, deployed to GitHub Pages, that lets the user manage a Pokémon TCG Pocket collection and build 20-card decks. The user runs it on Android Chrome.

This skill is the procedural deep-dive that complements `CLAUDE.md`. CLAUDE.md is the always-on map of the repo. This skill is what activates when feature work actually starts.

## Before you write any code

Run this checklist. It takes 60 seconds and saves PRs.

1. **Read `TODOS.md`.** The user keeps a backlog there with file paths and acceptance criteria. If your task is on it, use the entry's framing. If it isn't, check whether something adjacent is — duplicating work is wasteful and contradicting an entry is worse.
2. **Read the relevant existing component.** Don't propose a new pattern when an existing one fits. The Collection tab, Deck Builder tab, Pinned tab, and Meta Decks tab all share idioms — copy from a sibling before inventing.
3. **Identify which conventions in `references/conventions.md` your change touches.** Most changes touch at least 2-3.
4. **Decide if the change ships behind a feature flag or directly.** Direct is the default for this repo. Flags are warranted if the change is risky and the user is testing it on real Android.
5. **Plan the CHANGELOG entry and TODOS update before you write code, not after.** This forces you to articulate the user-visible value in one line.

If any of these surface a conflict (you're touching `Card.type` directly, or breaking a localStorage key shape, or skipping `prefers-reduced-motion`), stop and resolve it before writing code.

## Conventions that bite

These are the conventions Claude most often violates in this repo. The `references/conventions.md` file has the full list with rationale; the short version:

- **Card type checks**: never write `card.type === 'trainer'`. There is no `'trainer'` value in the upstream data — types are `'pokemon' | 'supporter' | 'item' | 'tool' | 'Fossil'`. Always go through `isTrainerCard(card)` from `src/types/card.ts`. Same applies to `matchesTypeFilter` for element filtering.
- **Curly apostrophes**: card names from the upstream DB use U+2019, not ASCII. Hardcoded name lists (Professor's Research, Sabrina's, etc.) must use the curly form. Failing this means the card never matches.
- **Card IDs**: format is `${SET}-${number}` with set uppercased and number `parseInt`-clean (no zero pad). `A1-7` is right; `a1-007` is wrong.
- **localStorage keys**: `tcgp-anthropic-key`, `tcgp-collection`, `tcgp-decks`. Existing users have data stored under these — never break the shape without a migration. If you must extend `Deck` or `Card`, add optional fields and handle the absent case.
- **Pinned decks**: a deck is pinned iff `Deck.pinnedAt` is a non-empty ISO string. Sort: pinned first by `pinnedAt asc`, then unpinned by `createdAt desc`. Don't introduce a separate `isPinned` boolean.
- **Mobile-first DeckEditor layout**: `DeckEditor.tsx` uses `order-1 lg:order-2` on the deck panel and `order-2 lg:order-1` on the card browser. On phones (single column) the user sees their deck immediately, not a wall of cards. **Never drop the `order-*` classes when refactoring.** This is the single most-reverted regression in this repo.
- **Deck-row tap target**: each row in `DeckEditor.tsx` is a `<div role="button" tabIndex={0}>` with `onClick` + Enter/Space handlers — *not* a `<button>` — because the inner `−` remove control is itself a `<button>` and nesting buttons is invalid HTML. The inner button uses `e.stopPropagation()`. Don't change either side.
- **Anthropic Vision**: model ID is `claude-sonnet-4-6`. Browser-direct calls to `api.anthropic.com` need the `anthropic-dangerous-direct-browser-access: true` header. The API key is read from `tcgp-anthropic-key` localStorage and is never sent anywhere except `api.anthropic.com`.
- **Score-tween + grade-pop hooks** in `DeckAnalysis.tsx` are wrapped in `eslint-disable react-hooks/set-state-in-effect`. Both disables are intentional — RAF tweening and grade-pill remounting are exactly the "synchronizing state with an external system" carve-out the React docs allow. Don't remove them.
- **Sparkle / pin-halo timers** in `DeckBuilderPage.tsx` use `setTimeout` (~700-900ms) inside `useEffect`. Always include the `clearTimeout` cleanup so an unmount mid-animation doesn't leak.

If you find yourself about to violate one of these, the right move is almost always to read the rationale in `references/conventions.md` and rework the approach, not to override.

## Adding a new feature: the standard path

Most feature work in this repo follows the same shape. Map your task to one of these and you'll move fast:

### Adding a new tab

- Add the value to `Tab` in `src/types/card.ts`.
- Add the entry to `Layout.tsx` (the top nav).
- Create `src/components/<area>/<NewTab>Page.tsx` matching the layout of an existing page (e.g. `PinnedPage.tsx` is the simplest reference).
- Wire it into `App.tsx` — add the case to whatever the tab-routing function is.
- Decide what hook the page needs: `useCollection`, `useDecks`, both, or neither. If neither, you probably don't need a new tab — it might belong inside an existing one.

### Adding a new collection filter

- Filters live in `src/components/collection/`. Read the existing rarity / set / element / category / ownership filters first.
- Filter state belongs in the Collection page component, not the global App state, unless multiple tabs need it.
- New filters must compose with existing filters (AND, not OR). Test the empty-result state.
- Filter UI on mobile: prefer pill-style chips that wrap, not dropdowns. The phone has the screen width; use it.

### Adding or tuning a deck-scoring heuristic

This is delicate. See `references/scoring-rules.md` for the full procedure. The short version:

- Weights in `deck-scoring.ts` must sum to exactly 1.00. Run `scripts/validate_weights.mjs` before committing.
- A new heuristic is a function returning `HeuristicResult`. It must produce a `status` (green/yellow/red), a `score` in [0, 1], and a one-line `suggestion`.
- Adding a heuristic means re-tuning at least one other weight to keep the sum invariant. Don't take that adjustment lightly — the README's scoring table needs to be updated to match.
- Run `scripts/score_regression.mjs` against the bundled fixture decks before/after. Score deltas larger than 5 points on any deck need a written justification in the PR.

### Adding a new card-data field

Three places need changes in lockstep:

1. The `Card` interface in `src/types/card.ts`.
2. The merge logic in `src/data/cards.ts` that joins base + rich.
3. Any consumer that accesses the field — usually `CardModal.tsx`, sometimes `card-classifier.ts` for strategy detection.

If the field comes from the rich-card upstream, also confirm `scripts/fetch-rich-cards.mjs` carries it through. If the field comes from a new upstream source entirely, propose that as a separate PR — don't roll source-changes and feature-changes into one diff.

### Adding an animation

- New keyframes go in `src/index.css` inside the `@theme` block, exposed as an `animate-*` Tailwind utility.
- The global `@media (prefers-reduced-motion: reduce)` rule must collapse it. If you add a new animation utility, verify it. Run `scripts/check_reduced_motion.mjs` to be sure.
- Durations: match the existing motion vocabulary — 600ms for the score ring, 4s for toasts, 700-900ms for sparkle/pin-halo. Don't introduce a 250ms or 1500ms duration without a reason.
- Haptics: only call `tap()` from `src/utils/haptics.ts` on **deck mutations** and **pin/unpin**. Never on filter taps, modal opens, tab switches, or anything else. The user notices haptic noise.

### Touching the Anthropic Vision flow

Read `references/vision-pipeline.md` first. The pipeline is browser → Claude Vision API directly, no backend. Pieces that interact:

- `src/services/video-processor.ts` extracts frames every 2s via Canvas.
- `src/services/card-recognizer.ts` sends each frame to `claude-sonnet-4-6`, parses the response, matches names against the database.
- The recognizer caps imports at 2 copies per card (the deck-building max). Re-importing the same video is therefore safe — never remove this cap.
- API key handling: read once from `tcgp-anthropic-key` at request time. Never log, persist elsewhere, or include in any error reporting.

Changes here that need extra care: prompt edits (re-test on at least 2 real videos), model swaps (only swap to a model with vision support; verify cost), error handling (network errors are common on phones — fail gracefully, don't lose the partial import).

## After you've written the code

Three checks before declaring done. Each takes under a minute.

1. **TypeScript clean**: `npm run build` with no errors. Type errors are blocking — never commit with `as any` to bypass them.
2. **CHANGELOG and TODOS**: add a one-line CHANGELOG entry under the current PR section. If your change closes a TODOS item, move it to `## Done` with a link to the PR.
3. **Mobile sanity**: if the change touches layout, animation, or a tap target, the user will test it on Android Chrome. Mention what they should specifically check.

For Android-specific gotchas (cache busting, `navigator.vibrate` quirks, Chrome version differences), see `references/android-chrome.md`.

## Bundled scripts

| Script | When to run |
|---|---|
| `scripts/validate_weights.mjs` | Before committing any change to `deck-scoring.ts` |
| `scripts/score_regression.mjs` | When tuning a heuristic; shows score deltas across fixture decks |
| `scripts/check_reduced_motion.mjs` | When adding any animation utility to `index.css` |
| `scripts/audit_haptics.mjs` | When you've added or moved a `tap()` call; flags suspicious sites |
| `scripts/diff_card_data.mjs` | After running `fetch-rich-cards.mjs`; surfaces what changed |

All scripts are pure Node, no extra dependencies. Run them with `node scripts/<name>.mjs` from the consuming repo's root.

## Reference files

- `references/conventions.md` — full convention list with rationale for each
- `references/scoring-rules.md` — heuristic procedure, weight invariants, fixture decks
- `references/vision-pipeline.md` — Anthropic Vision integration details
- `references/android-chrome.md` — deployment-target gotchas (cache, haptics, viewport)
