# Changelog

A scannable history of what shipped in each PR. Live app: https://thecryptocanuck.github.io/pokemon/.

Format loosely follows [Keep a Changelog](https://keepachangelog.com/). Newest first.

## 2026-05-06

### Fix: Erika is `heal`, not `accel`

- **Bug fix**: in TCGP, Erika's "Soothing Aroma" heals 50 from a Grass Pokémon — she does not accelerate energy. Reclassifying her in `src/data/trainer-roles.ts` from `accel` → `heal` and removing her from `ACCEL_TYPE` so she no longer silently inflates Energy Acceleration scores in psychic (or any non-grass) decks. Closes [TODO #2](./TODOS.md).

## 2026-04-30

### [PR #14](https://github.com/TheCryptoCanuck/pokemon/pull/14) — docs: sync README and CLAUDE with v1.3 polish + card modal

- Catches `README.md` and `CLAUDE.md` up to PRs #12 and #13 (no code changes).
- README gains a **Card detail modal** feature bullet and a new **Feel** section listing every micro-interaction in v1.3.
- CLAUDE.md gains 3 new conventions for future AI sessions: deck-row tap target uses `div role="button"` (not `<button>`) to avoid nested-button HTML, intentional `eslint-disable react-hooks/set-state-in-effect` blocks for the RAF score tween + grade-pill re-key, and `setTimeout` cleanup on the sparkle / pin-halo state holders.

### [PR #13](https://github.com/TheCryptoCanuck/pokemon/pull/13) — Fix: tap any deck card row to open the detail modal

- **Bug fix**: deck card rows in the Deck Builder were read-only. Now tap any card in your deck to open the detail modal — same behaviour as the Collection grid.
- **CardModal upgrade**: surfaces the rich attack and ability data the app has been bundling since PR #9 but never displaying. Each attack renders with coloured energy-cost pips (one per energy), name, damage in amber, and effect text. Each ability renders with a purple "Ability" pill + name + effect.
- Modal backdrop now uses `backdrop-blur-sm` and slides up on enter; scrolls if attacks push past viewport height.

### [PR #12](https://github.com/TheCryptoCanuck/pokemon/pull/12) — v1.3 UI/UX polish: motion, empty states, haptics

A focused 10-commit polish pass — make the app feel impressive and user friendly without rewriting anything. No new dependencies.

- **Motion primitives** + global `prefers-reduced-motion` rule (one media query collapses every animation to ~0 ms for users with the OS toggle on).
- **Toast** slides up from the bottom-right with emerald border on success / amber on warnings, auto-dismisses in 4 s.
- **Score ring** sweeps as the score changes; the number tweens via a 600 ms eased RAF; the grade pill pops on each grade-boundary crossing (S grade gets an emerald glow shadow).
- **Auto-Build sparkle** — 4 staggered golden ★ stars burst around the new deck tab for ~800 ms.
- **Card tap feedback** — every tap flashes a blue ring + scales 95 %; the count badge pulses on every increment; +/- buttons grow to 36 × 36 (WCAG thumb target); hover overlay eases over 200 ms.
- **Friendlier empty states** — Collection no-results, Pinned tab, Meta Decks no-matches, and empty-deck analysis all gain a glyph + headline + hint + primary action button.
- **Layout polish** — tab swaps fade in (200 ms); sticky header gains a soft shadow past 4 px scroll; keyboard users see a blue focus ring on every tab.
- **Pin halo** — pressing ★ pops the star and ripples a yellow halo behind it; new pinned-deck cards slide up on the Pinned tab.
- **Video import shimmer** — progress bar shimmers (animated gradient); recognize stage shows "Frame 42 / 120" so a 30-second import doesn't feel frozen.
- **Haptic tick** — `navigator.vibrate(8)` on Android Chrome whenever you actually mutate a deck (+/- a card, pin/unpin). Not on filter taps or modal opens.

### [PR #11](https://github.com/TheCryptoCanuck/pokemon/pull/11) — Mobile fix: show deck panel first + update README/CLAUDE

- **Bug fix** for "I can't view created deck": on phones, `DeckEditor` was rendering the 1,000+ card browser column first and burying the deck panel below. Now uses Tailwind `order-1 lg:order-2` so the deck panel (name, validation, cards, score, analysis) renders first on mobile; desktop layout unchanged.
- README + CLAUDE.md catch up to v1.2 (Auto-Build with Strategy picker, deck scoring with all 10 heuristics, Pinned tab, type filters, video-import cap-at-2 behaviour, Vite LAN-host, refresh-data script, project layout tree).

### [PR #10](https://github.com/TheCryptoCanuck/pokemon/pull/10) — Archetype-driven auto-build + pinned tab + type filters + 2 heuristics

- **Archetype-aware Auto-Build**: pick *Auto / Aggressive / Evolution / Control* in the modal. Each archetype has a hand-tuned slot/role budget (Aggressive 7P/13T, Evolution 10P/10T, Control 6P/14T) adapted from a competitive 20-card-core framework. `detectArchetype()` infers from the seed when set to Auto.
- **Two new scoring heuristics** (rebalanced weights to keep total = 1.00): **Redundancy** (10%, ≥2 different cards filling each critical role) and **Recovery** (5%, heal trainers + heal abilities + switch trainers).
- **Pinned tab** — a dedicated top-level tab between Deck Builder and Meta Decks. Read-only list of starred decks with grade pill, X/20 count, 3-card thumbnail strip, Open / Unpin buttons.
- **Type filter** now includes Trainers / Items / Tools / Supporters / Fossils via a second optgroup ("Category") on the same dropdown. New `matchesTypeFilter` helper.
- A11y: pin button gets `aria-label`, `aria-pressed`, focus-visible ring.

### [PR #9](https://github.com/TheCryptoCanuck/pokemon/pull/9) — Smarter auto-build: abilities, attacks, pin, import cap

- **Bundles rich card data** (`scripts/fetch-rich-cards.mjs` + `public/cards-rich.json`) — 3,007 cards with attack costs/damage/effects, 376 with ability text, sourced from `hugoburguete/pokemon-tcg-pocket-card-database`. ~55 KB gzipped, fetched in parallel with the base card data.
- **`card-classifier.ts`**: regex-based strategy detection (`isHeavyAttacker`, `hasEnergyAccel`, `hasSoftDraw`, `rewardsWideBench`, `getMaxAttackCost`, etc.).
- **Energy Acceleration** heuristic now uses real attack costs (not a hardcoded heavy-attacker list) and counts Pokémon with energy abilities (Gardevoir, Hydreigon) as accel sources alongside trainers.
- **Trainer Mix** counts Pokémon abilities as soft fills toward draw / accel / search / disrupt buckets.
- **Auto-builder** picks ability partners (Hydreigon, Lunala ex) when no `POWER_PAIRINGS` match, and falls back to damage-per-energy ratio for seed selection.
- **Save auto-built decks via pinning**: new `Deck.pinnedAt` field + ★ button on each deck tab. Pinned decks float to the top of the deck list.
- **Video-import cap at 2**: imports are cumulative but never push past 2 copies per card (the deck-building maximum). Manual counts above 2 are preserved.

### [PR #8](https://github.com/TheCryptoCanuck/pokemon/pull/8) — Add elite deck scoring + Auto-Build

- **Deck scoring panel**: every deck gets a 0–100 score with an S/A/B/C/D grade. Conic-gradient ring + colored grade pill + collapsible breakdown of 8 weighted heuristics (Trainer Mix 20 %, Evolution Lines 18 %, Basic Consistency 15 %, Energy Acceleration 15 %, Power Pairings 12 %, Weakness Coverage 10 %, Prize Math 5 %, Bench Mobility 5 %).
- Each heuristic emits a traffic-light status, message, and one-line suggestion ("All attackers weak to Dark — diversify").
- **Auto-Build button** + modal — pick 1–3 energy types and an "Use only cards I own" toggle, get a legal 20-card deck. Deterministic greedy pipeline that uses `scoreDeck` as the objective.
- New data files: `trainer-roles.ts` (~30 hand-classified TCGP trainers), `synergy.ts` (heavy attackers, power pairings, best basics, accel-by-type, staples, `lastReviewed` date).
- **Bug fix**: pre-existing `getDeckStats` filtered on `card.type === 'trainer'` but upstream uses `'supporter' | 'item' | 'tool' | 'Fossil'` instead. Trainer count was always 0. New `isTrainerCard()` helper used everywhere.

### [PR #7](https://github.com/TheCryptoCanuck/pokemon/pull/7) — Fix images + Shiny/SSR rarities

- **Bug fix**: every card was rendering as "No Image" because the upstream `pokemon-tcg-pocket-database` README is stale — images live at `flibustier/pokemon-tcg-exchange/public/images/cards-by-set/{set}/{number}.webp`, served via jsDelivr CDN (CORS-friendly, no rate limits).
- **Bug fix**: `S` (Shiny, 121 cards) and `SSR` (Shiny Super Rare, 51 cards) rarities were unlabeled in the By-Rarity stats and unfilterable. Added them to `RARITY_ORDER` (positions 8 and 9, between Immersive and Crown), `RARITY_LABELS`, and the rarity filter dropdown.

### [PR #6](https://github.com/TheCryptoCanuck/pokemon/pull/6) — Make video import work + expose dev server for phone testing

- **Bug fix**: Vision API was calling `claude-sonnet-4-20250514` (May 2025 Sonnet 4), past Anthropic's typical deprecation window. Switched to `claude-sonnet-4-6` (current Sonnet, vision-capable). Without this, the only AI feature in the app was returning `model_not_found`.
- Vite dev server now binds to `0.0.0.0` (`server.host: true`) so a phone on the same Wi-Fi can hit `http://<host-ip>:5173/pokemon/` over LAN.

## 2026-04-23

### [PR #5](https://github.com/TheCryptoCanuck/pokemon/pull/5) — Add gstack dependency check + Claude integration hooks

- Adds the `gstack` requirement gate to `CLAUDE.md` so AI sessions can't start work without the global gstack install.

## 2026-03-13

### [PRs #1–4](https://github.com/TheCryptoCanuck/pokemon/pulls?q=is:pr+is:closed+author:claude) — Initial app + GitHub Pages + video recognition + new session

- Initial Pokemon TCG Pocket Deck Builder: collection tracker, video-import flow, custom deck builder with TCGP rule enforcement, meta-deck suggestions.
- GitHub Pages workflow at `.github/workflows/deploy.yml` (Node 20, `npm ci && npm run build`, deploys `dist/` to Pages on push to `main`).
- User-friendly error messages on Anthropic API failures (credit balance low, rate limit, overload).
