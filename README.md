# TCGP Deck Builder

A mobile-first web app for managing your Pokémon TCG Pocket card collection and building competitive 20-card decks. Designed to run on Android via GitHub Pages — no install required.

**Live:** https://thecryptocanuck.github.io/pokemon/

**What's shipped:** [CHANGELOG.md](./CHANGELOG.md) — a per-PR scannable history.

> On phones the deck panel (deck name, cards, score, analysis) renders first; the 1,000+ card browser drops below it. Open any deck and you see your deck immediately, not a wall of cards. On desktop the card browser stays on the left, deck panel on the right.

## Features

- **Collection tracker** — browse 2,500+ TCGP cards, filter by element / category (Pokémon / Supporter / Item / Tool / Fossil) / set / rarity / ownership.
- **Video import** — upload a screen recording of your TCGP collection and Claude Vision identifies the cards automatically. Imports are cumulative but capped at 2 copies per card (the deck-building maximum), so re-importing is safe.
- **Auto-Build** — pick 1–3 energy types and a strategy (Auto / Aggressive / Evolution / Control) and the app generates a legal 20-card deck tuned to that archetype, using rich attack and ability data to pick the best seed, partner, and trainer mix.
- **Elite deck scoring** — every deck gets a 0–100 score with an S/A/B/C/D grade. The score breaks down into 10 weighted heuristics, each with traffic-light status and a one-line suggestion (e.g. *"All attackers weak to Dark — diversify"*).
- **Card detail modal** — tap any card in the Collection grid or any row inside a deck to open a full-detail modal: HP, type, weakness, retreat, every attack (with coloured energy-cost pips, damage, and effect text), and any abilities.
- **Pinned decks** — star any deck to save it. Pinned decks float to the top of the deck list and live in their own **Pinned** tab for one-tap access.
- **Meta decks** — 12 hand-curated meta decks; the app shows you which ones your collection can build, ranked by completeness.

## Feel

The app puts care into every state change so it doesn't feel like a static form on a phone:

- **Score ring sweeps + number tweens** when you add or remove cards (600 ms eased RAF tween); the grade pill pops on each grade-boundary crossing.
- **Toast slides up** from the bottom on Auto-Build with an emerald left-border for success / amber for warnings, auto-dismisses in 4 s.
- **Sparkle burst** — golden ★ stars fan out around the new deck tab when Auto-Build succeeds.
- **Card tap ring** + count-pulse when you increment / decrement a card.
- **Pin halo** — pressing ★ pops the star and ripples a yellow halo behind it.
- **Tab switch fade** + a sticky-header drop-shadow on scroll.
- **Haptic tick** (`navigator.vibrate(8)`) on Android Chrome whenever you actually mutate a deck — not on filter taps or modal opens.
- **Reduced motion** — a single global `@media (prefers-reduced-motion: reduce)` rule collapses every animation to ~0 ms, so users with the OS toggle on get instant state changes.

## Quick start

```bash
git clone https://github.com/TheCryptoCanuck/pokemon
cd pokemon
npm install
npm run dev
```

Vite serves on port 5173 with `host: true`, so you'll see both a Local URL and a Network URL. Open the **Network** URL in Chrome on your Android phone (same Wi-Fi as the dev machine) to use the app from your phone.

To deploy: push to `main`. The GitHub Pages workflow at `.github/workflows/deploy.yml` builds and publishes automatically.

## Video import

1. Open Pokémon TCG Pocket on your phone.
2. Go to your card collection.
3. Screen-record yourself slowly scrolling through every card.
4. Open the deck builder, **Collection** tab → **Import from Video**.
5. Paste your Anthropic API key (stored only in your phone's localStorage; sent only to `api.anthropic.com`).
6. Pick the video. The app extracts frames every 2 seconds, sends each to Claude Vision (`claude-sonnet-4-6`), and matches recognized card names against the database.

## Auto-Build

The auto-builder runs a deterministic, score-driven pipeline. Pick:

- **1–3 energy types** — at least one Pokémon-element. Trainers are universal.
- **Strategy** — *Auto* detects the archetype from the seed; *Aggressive* / *Evolution* / *Control* override it.
- **Use only cards I own** — restricts the candidate pool to your collection.

| Archetype | Pokémon | Trainers | Goal |
|---|---|---|---|
| Aggressive | 7 (4 main + 2 support + 1 backup) | 13 (4 search · 3 draw · 2 switch · 2 disrupt · 2 accel) | Hit turn 2, take first 2 prizes |
| Evolution | 10 (2-2-2 line + 2 backup + 2 support) | 10 (4 search · 2 draw · 2 accel · 1 switch · 1 disrupt) | Set up safely, overwhelm |
| Control | 6 (2 wall + 2 support + 1 backup + 1 utility) | 14 (4 search · 3 disrupt · 2 heal · 2 switch · 3 draw) | Deny + prize-control or deck-out |

Each result is named `Auto: <energies> · <Archetype>`, scored, and saved alongside your manual decks.

## Deck scoring

Each deck is scored on 10 weighted heuristics (sum = 100%):

| Weight | Heuristic | What it checks |
|---|---|---|
| 15% | **Basic Consistency** | Hypergeometric `P(no mulligan)` from Basic count |
| 15% | **Evolution Lines** | Walks `evolvesFrom` chains, penalises orphaned stages |
| 15% | **Energy Acceleration** | Real attack-cost-based heavy-attacker detection vs accel sources (trainers + abilities) |
| 10% | **Trainer Mix** | Bucketed: ≥2 search, ≥2 draw, ≥1 disrupt, ≥1 type-matched accel |
| 10% | **Power Pairings** | Hand-curated S/A-tier two-card synergies (Mewtwo+Gardevoir, Gyarados+Misty, …) |
| 10% | **Weakness Coverage** | Max share of attackers sharing one weakness type |
| 10% | **Redundancy** | Each critical role filled by ≥2 *different* cards (not just 2 copies of one) |
| 5% | **Recovery** | Heal trainers, heal abilities, switch trainers — can the deck survive a KO? |
| 5% | **Prize Math (ex Density)** | Sweet spot 2–4 ex Pokémon |
| 5% | **Bench Mobility** | Average retreat cost; flag if >2 without an X Speed |

## Tech stack

- **React 19** + **TypeScript** + **Vite 8**
- **Tailwind CSS 4**
- **Claude Vision API** for card recognition (browser → `api.anthropic.com`, no backend)
- Card data from [`flibustier/pokemon-tcg-pocket-database`](https://github.com/flibustier/pokemon-tcg-pocket-database) (base) + [`hugoburguete/pokemon-tcg-pocket-card-database`](https://github.com/hugoburguete/pokemon-tcg-pocket-card-database) (attacks + abilities)
- Card images via [jsDelivr CDN](https://www.jsdelivr.com/) → `flibustier/pokemon-tcg-exchange`

## Updating card data

When a new TCGP set ships, refresh the bundled rich-card data:

```bash
node scripts/fetch-rich-cards.mjs
```

This pulls the latest set files from hugoburguete, normalises card IDs to the `${set}-${number}` convention, and rewrites `public/cards-rich.json` (~470 KB raw / 55 KB gzipped).

## Project layout

```
src/
├── App.tsx                       Tab routing + state hooks
├── components/
│   ├── Layout.tsx                Top nav (Collection / Deck Builder / Pinned / Meta Decks)
│   ├── collection/               Collection tab + filters + video import
│   ├── deck-builder/             Deck Builder tab, Auto-Build modal, Pinned tab, Score panel
│   ├── meta/                     Meta Decks tab
│   └── shared/                   CardDisplay, CardModal
├── hooks/
│   ├── useCollection.ts          localStorage-backed collection (cap-2 imports)
│   └── useDecks.ts               localStorage-backed decks + pin support
├── services/
│   ├── card-recognizer.ts        Claude Vision API integration
│   └── video-processor.ts        Canvas-based frame extraction
├── utils/
│   ├── deck-rules.ts             20-card / 2-copy / Basic / 3-energy validation
│   ├── deck-scoring.ts           10 weighted heuristics → DeckScore
│   ├── auto-build.ts             Archetype-aware greedy builder
│   ├── collection-match.ts       Match meta decks against your collection
│   ├── card-classifier.ts        Regex strategy detection on attacks/abilities
│   └── haptics.ts                navigator.vibrate(8) on deck mutations
├── data/
│   ├── cards.ts                  Fetches base + rich card data, merges
│   ├── archetypes.ts             Slot/role budgets per archetype
│   ├── trainer-roles.ts          Hand-classified trainer roles
│   ├── synergy.ts                Heavy attackers, power pairings, best basics
│   └── meta-decks.ts             12 curated meta deck templates
└── types/
    └── card.ts                   Card / Deck / Tab interfaces + helpers

scripts/
└── fetch-rich-cards.mjs          Build-time fetcher for hugoburguete data

public/
├── cards-rich.json               Bundled attacks/abilities (regenerate via script above)
└── favicon.svg, icons.svg
```
