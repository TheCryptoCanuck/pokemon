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

### 10. Tabs clip at phone width — half the app hides behind horizontal scroll

- **Severity:** Bug — visible to user (mobile blocker)
- **Effort:** Medium
- **File:** `src/components/Layout.tsx`
- **Why it matters:** At 393px the H1 "TCGP Deck Builder" wraps to 2 lines
  and consumes ~50% of the header width. The tab strip uses
  `overflow-x-auto whitespace-nowrap`, so "Pinned" clips to "Pi" and
  "Meta Decks" is fully off-screen on first paint. Even the active tab can
  be invisible (e.g. when on Meta Decks). Confirmed at Pixel 7 (393×851)
  during the 2026-05-07 UX audit.
- **Acceptance:** at 393px, all four tabs (Collection, Deck Builder, Pinned,
  Meta Decks) are simultaneously visible and tappable without horizontal
  scroll; the active tab is always visible. Recommended approach: bottom
  tab bar with `safe-area-inset-bottom` (matches Marvel Snap, frees vertical
  space, thumb-friendly). Fallback approach: title shrinks to "TCGP" on
  `< 640px`, tab strip becomes a second row under the header.

### 11. Collection grid +/− buttons are hover-only — invisible on touch

- **Severity:** Bug — visible to user (mobile blocker)
- **Effort:** Medium
- **Files:** `src/components/shared/CardDisplay.tsx`,
  `src/components/collection/CardGrid.tsx`
- **Why it matters:** `CardDisplay.tsx:84` wraps the +/− buttons in a
  gradient overlay with `opacity-0 group-hover:opacity-100`. Touchscreens
  have no hover, so the buttons stay invisible. Tapping the card art opens
  the modal (parent `onClick`), which means on phone the only way to add a
  card to the collection is via the modal's "Add" button — the fast +/−
  loop the desktop user gets is unreachable.
- **Acceptance:** on Android Chrome at 393px, every Collection-grid card
  shows a persistent + (and − when count > 0) along with its count badge.
  Tapping the card art still opens the modal. Hover-reveal can stay on
  desktop or be replaced with the same persistent variant — not both.

### 12. Escape doesn't dismiss CardModal or AutoBuildModal; focus isn't trapped

- **Severity:** Bug — accessibility / keyboard expectation
- **Effort:** Trivial (Escape) + Small (focus trap)
- **Files:** `src/components/shared/CardModal.tsx`,
  `src/components/deck-builder/AutoBuildModal.tsx`
- **Why it matters:** Verified Escape leaves both modals open. Focus also
  escapes to background content under the backdrop because no focus trap
  is in place. Universal modal expectation; low-effort a11y win.
- **Acceptance:** Escape closes both modals. Initial focus moves to the
  close button on open; focus is trapped while open; focus returns to the
  trigger on close. Backdrop tap still closes. `role="dialog"` and
  `aria-modal="true"` are set if not already.

### 13. Deck delete (×) has no confirmation

- **Severity:** Bug — destructive without confirm
- **Effort:** Trivial
- **File:** `src/components/deck-builder/DeckBuilderPage.tsx` (deck tab strip)
- **Why it matters:** The "x" action on each deck tab deletes the deck on a
  single tap. Tap targets are small on phone; an accidental delete loses an
  Auto-Build (or any deck) with no recourse. No undo, no toast.
- **Acceptance:** tapping × on a deck tab shows a small inline two-step
  confirm ("Delete <deck name>? · Cancel · Delete"). Pinned decks gate
  behind the same confirm at minimum.

### 14. "cp" and "x" deck-tab labels render as raw text + lack `aria-label`

- **Severity:** Bug — discoverability + accessibility
- **Effort:** Trivial
- **File:** `src/components/deck-builder/DeckBuilderPage.tsx`
- **Why it matters:** The deck tab strip exposes "★ cp x" as visible
  labels. ★ has both `aria-label` and `title`; "cp" and "x" only have
  `title` ("Duplicate" / "Delete") and no `aria-label`. "cp" reads as
  nothing visually and "x" reads as close-modal.
- **Acceptance:** Duplicate uses a clipboard/copy SVG icon; Delete uses a
  trash SVG icon. Both gain `aria-label` matching their `title`.
  Tap-target stays ≥ 32×32.

### 15. "Show only owned cards" defaults on with empty collection — first run looks broken

- **Severity:** Bug — first-run UX
- **Effort:** Trivial
- **Files:** `src/components/deck-builder/DeckBuilderPage.tsx`,
  `src/components/deck-builder/DeckEditor.tsx`
- **Why it matters:** A new user with 0 owned cards opens Deck Builder; the
  card-browser column shows "0 cards" with no explanation because the
  toggle is on. The Auto-Build modal already handles this gracefully
  (`(collection empty)` annotation + auto-disabled "Use only cards I own"
  toggle). Mirror that here.
- **Acceptance:** with `collection.size === 0`, the toggle defaults off
  (or auto-disables with annotation); as soon as the user adds any card,
  it returns to default-on.

### 16. Persistent +/− and count display in CardModal

- **Severity:** Bug — usability
- **Effort:** Trivial
- **File:** `src/components/shared/CardModal.tsx`
- **Why it matters:** Modal shows a single green "Add" button with no count
  display and no decrement. Going from 1 → 2 means tap Add, close the
  modal, find the card again. The data is right there.
- **Acceptance:** modal shows the current owned count (e.g. "Owned: 1 / 2")
  plus −/+ controls that update the collection in place; the standalone
  "Add" button is removed.

### 17. Auto-Build success toast covers the score ring

- **Severity:** Bug — motion/feedback overlap (polish)
- **Effort:** Trivial
- **File:** the toast component / `src/components/deck-builder/DeckBuilderPage.tsx`
- **Why it matters:** Toast slides up from the bottom-right and overlaps
  the score panel exactly when its message says "Tap to expand the
  breakdown" — the call-to-action is hidden under the toast itself.
- **Acceptance:** at 393×851 the Auto-Build toast does not visually overlap
  the score ring or the "Show breakdown" link. Either offset higher
  (`bottom-20` on phone) or center-bottom with margin from the deck panel.

### 18. Score breakdown summary copy is static after expansion

- **Severity:** Bug — polish
- **Effort:** Trivial
- **File:** `src/components/deck-builder/DeckAnalysis.tsx`
- **Why it matters:** Chevron flips ▶ → ▼ on expand, but the
  "Tap to expand the breakdown" prose stays the same. Minor confusion.
- **Acceptance:** expanded state reads "Tap to collapse the breakdown" (or
  equivalent); collapsed state stays as today.

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

### 19. Element-color chips on Auto-Build modal + Collection Type filter

- **Severity:** Feature — visual hierarchy / usability
- **Effort:** Medium
- **Files:** `src/components/deck-builder/AutoBuildModal.tsx`,
  `src/components/collection/CardFilters.tsx`
- **Why it matters:** The 10 element buttons in Auto-Build are text-only
  pills. The Collection Type filter is a native `<select>`. Pokémon TCG
  players orient by element color (grass=green, fire=red, water=blue, …),
  not text. `src/components/shared/CardDisplay.tsx` already exports an
  `ELEMENT_COLORS` map; reuse it. Pattern borrowed from MTG Arena's
  color-chip filter.
- **Acceptance:** Auto-Build energy-type buttons are color-filled per
  element (and remain accessible — colors meet contrast against the active
  state). Collection Type filter splits into a horizontally-scrollable chip
  strip on phone (10 elements + Pokémon / Trainers / Items / Tools /
  Fossils / Supporters), still backed by the existing `matchesTypeFilter`
  helper.

### 20. Compress Collection stats panel on phone widths

- **Severity:** Feature — information hierarchy / mobile
- **Effort:** Medium
- **File:** `src/components/collection/CollectionPage.tsx`
- **Why it matters:** At 393px the four stat tiles (Cards Owned, Total
  Cards, Complete, Sets) + the By-Rarity strip + Import button + 4-row
  filter stack push the actual card grid beyond ~1100px scroll. New users
  open the app and see no cards on first paint.
- **Acceptance:** at `< 640px`, the four stat tiles collapse to a single
  horizontal-scroll chip strip; By-Rarity moves behind a "Stats" disclosure
  (default collapsed). Card grid begins above ~600px scroll on first paint.

## Backlog (polish)

Smaller polish items surfaced by the 2026-05-07 UX audit. Pick when
convenient — none are blockers and most are trivial.

- **Card thumbnails on Meta Decks card-breakdown rows** —
  `src/components/meta/MetaDeckCard.tsx`. Reuse the 32×44 thumbnail
  pattern from `DeckEditor.tsx:229-233`. Trivial.
- **Replace `opacity-40 grayscale` for unowned with a "not owned" corner
  badge + `opacity-70`** — `src/components/shared/CardDisplay.tsx`. Keeps
  the art readable; lets us reserve a distinct treatment for "invalid for
  this deck" later. Trivial.
- **By-Rarity abbreviations gain `title` tooltips** —
  `src/components/collection/CollectionPage.tsx`. Use existing
  `RARITY_LABELS`. Trivial.
- **Visible rename affordance on the deck name** —
  `src/components/deck-builder/DeckEditor.tsx:192-201`. Pencil icon next to
  the H3. Trivial.
- **Long-press preview from the deck-builder card browser** —
  `src/components/deck-builder/DeckEditor.tsx:138-154`. Today: tap commits
  silently. Add long-press → modal preview. Medium.
- **Drop-zone copy: "Tap to choose a video" instead of "Drop a video or
  click to upload"** — `src/components/collection/VideoImport.tsx`. Phones
  don't drag-drop. Trivial.
- **Confirm API-key input is `type="password"` + `autocomplete="off"`** —
  `src/components/collection/VideoImport.tsx`. Hardening overlap with
  TODO #5. Trivial.
- **Replace meta-deck chevron `v` / `^` text with a Heroicons SVG** —
  `src/components/meta/MetaDeckCard.tsx`. Trivial.
- **Folder / grouping for decks** — borrowed from Limitless TCG. Useful
  once a user has > ~10 decks. Significant. v1.5 candidate.

## Done

_Move closed items here with the PR link, e.g._

- ~~Tap any deck card row to open the detail modal~~ — closed by [PR #13](https://github.com/TheCryptoCanuck/pokemon/pull/13)
- ~~Erika misclassified as `accel`~~ — closed by [PR #19](https://github.com/TheCryptoCanuck/pokemon/pull/19)
