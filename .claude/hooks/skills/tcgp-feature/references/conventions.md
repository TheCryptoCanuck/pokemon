# Conventions reference

The full list of conventions in the TCGP Deck Builder repo, with the *why* behind each one. CLAUDE.md has the short list; this is the deep version.

## Card type checks

**Rule.** Never write `card.type === 'trainer'`. Always go through `isTrainerCard(card)` from `src/types/card.ts`.

**Why.** The upstream card data uses `'pokemon' | 'supporter' | 'item' | 'tool' | 'Fossil'` — there is no `'trainer'` value. `isTrainerCard` is the union check that maps the upstream shape to the conceptual category the UI uses. Bypassing it means the check silently returns false on every card.

**Same shape:** `matchesTypeFilter` for element filtering, `getCardId` for ID construction, `getCardImageUrl` for image URLs. Don't reimplement these inline.

## Curly apostrophes in card names

**Rule.** Card names in upstream data use U+2019, not ASCII U+0027. Hardcoded name lists must use the curly form.

**Why.** The upstream JSON ships with curly quotes. Any hardcoded comparison against ASCII apostrophes silently misses cards whose names contain one — Professor's Research, Sabrina's Recall, Cyrus' Plot, etc.

**How to verify.** When hardcoding a name, copy-paste it from the rendered UI or from `cards-rich.json`, never type it from memory. In the editor, the curly apostrophe is visually distinct.

## Card IDs

**Format.** `${SET}-${number}` with the set uppercased and the number `parseInt`-clean (no zero pad).

- Right: `A1-7`, `A2-180`, `PROMO-A-1`
- Wrong: `a1-007`, `A1-007`, `a1-7`

**Why.** ID matching is exact-string. A1-7 and A1-007 are different strings. The collection localStorage key is keyed on this format; mismatch means the user's owned-cards mapping silently breaks.

## localStorage keys and shape

| Key | Stores |
|---|---|
| `tcgp-anthropic-key` | The user's Anthropic API key (string) |
| `tcgp-collection` | `Record<cardId, count>` — count of each card the user owns, capped at 2 |
| `tcgp-decks` | `Deck[]` — all decks including pinned |

**Rule.** Never break the shape of these without writing a migration in the corresponding hook (`useCollection.ts`, `useDecks.ts`). Existing users have data stored.

**Adding fields to `Deck` or `Card`.** Add them as optional. Handle the absent case in every reader. Don't backfill in storage — backfill at read time.

**Removing fields.** Don't. If a field is genuinely obsolete, leave it in the type as `@deprecated` and stop reading it.

## Pinned decks

**Shape.** `Deck.pinnedAt?: string` — an ISO 8601 timestamp if pinned, `undefined`/absent if not.

**Sort order.**
1. Pinned decks first, ordered by `pinnedAt` ascending (earliest pin at the top).
2. Then unpinned decks, ordered by `createdAt` descending (newest first).

**Don't.** Don't introduce a separate `isPinned: boolean` field. The optional `pinnedAt` is the source of truth for both the boolean and the sort.

## Mobile-first DeckEditor layout

**The single most-reverted regression in this repo.** `DeckEditor.tsx` uses Tailwind ordering classes to flip the panel order between mobile and desktop:

- Deck panel (deck name, cards, score, analysis): `order-1 lg:order-2`
- Card browser (the 1,000+ card grid): `order-2 lg:order-1`

**On phones** (single column): the deck panel renders first. The user opens a deck and sees their deck immediately, not a wall of cards.

**On desktop** (`lg:` breakpoint): the card browser sits on the left, deck panel on the right — the conventional two-pane editor layout.

**Don't drop the `order-*` classes when refactoring.** This includes when extracting subcomponents — pass the ordering through, or apply it on the wrapping element.

## Deck-row tap targets

Each deck row in `DeckEditor.tsx` is a `<div role="button" tabIndex={0}>` with `onClick`, `onKeyDown` (Enter and Space), **not** a `<button>`.

**Why.** The row contains an inner `−` (remove) button. Nesting a `<button>` inside another `<button>` is invalid HTML and produces unpredictable behavior across browsers. The outer `<div role="button">` gives us the tap-anywhere-to-open-modal behavior; the inner real `<button>` handles remove. The inner button calls `e.stopPropagation()` to prevent the modal from opening when the user just wants to decrement the count.

**Accessibility.** The `role="button"` + `tabIndex={0}` + `onKeyDown` combination is the screen-reader-friendly pattern for non-button elements that need to be activatable. Keep all three.

## Anthropic Vision integration

- **Model ID**: `claude-sonnet-4-6`. Don't downgrade to a non-vision model.
- **Endpoint**: `https://api.anthropic.com/v1/messages`. Browser-direct.
- **Required header**: `anthropic-dangerous-direct-browser-access: true`. Without it, CORS fails.
- **API key source**: `localStorage.getItem('tcgp-anthropic-key')`, set by the user via the Settings flow in the Collection tab. The key never leaves the device except in outbound requests to `api.anthropic.com`.
- **Never log the API key.** Not in console, not in error messages, not in crash reports.

## Score-tween and grade-pop in DeckAnalysis.tsx

Two `setState`-in-`useEffect` blocks are wrapped in `eslint-disable react-hooks/set-state-in-effect`:

1. The RAF score tween (animates the displayed score from old to new over ~600ms with eased timing).
2. The grade-pill remount on grade-boundary crossing (changes the React key so the pill re-mounts and replays its pop animation).

**Both disables are intentional.** The React docs explicitly carve out "synchronizing state with an external system" (RAF, DOM remount) as a valid use case for this pattern. The lint rule fires false-positive here.

**Don't remove the disables.** If a linter upgrade complains, re-pin the disable comment, don't restructure the hook.

## Sparkle and pin-halo cleanup

`DeckBuilderPage.tsx` holds short-lived state (`sparkleDeckId`, `justPinnedId`) that drives one-shot animations. Each is set on a user action and cleared via `setTimeout` (~700-900ms) inside `useEffect`.

**Always include the `clearTimeout` cleanup return.** If a user unmounts the page mid-animation (tab switch), the timer fires against an unmounted component and React logs a warning. The cleanup prevents that.

```ts
useEffect(() => {
  if (!sparkleDeckId) return;
  const t = setTimeout(() => setSparkleDeckId(null), 800);
  return () => clearTimeout(t);
}, [sparkleDeckId]);
```

## Animations

All custom animations live in `src/index.css` inside the Tailwind 4 `@theme` block. There are 5 right now: `slide-up-fade`, `pop`, `sparkle`, `shimmer`, `count-pulse`. Each is exposed as an `animate-*` utility class.

**The `prefers-reduced-motion` rule** at the bottom of `index.css` collapses every animation and transition to ~0ms. **When you add a new animation, verify the rule still covers it** — if you bypass `transition` and `animation` properties (e.g. by manually setting `animation-name` somewhere), the rule won't catch you. Run `scripts/check_reduced_motion.mjs`.

## Haptics

`src/utils/haptics.ts` exports `tap()` which calls `navigator.vibrate(8)` on Android. It's a no-op on iOS (Safari doesn't support it) and a no-op when `prefers-reduced-motion` is set.

**Where `tap()` belongs:**
- After a deck mutation (add card, remove card, reorder).
- On pin/unpin.

**Where `tap()` does NOT belong:**
- On filter chip taps. The user is exploring; haptic noise is annoying.
- On modal opens or closes. Modal entry is already a strong visual signal.
- On tab switches.
- On scroll, hover, or focus changes.
- On card image taps that just open a detail modal (no mutation).

The rule: haptics fire when the user *changes their data*, not when they *navigate the UI*.

## Card name encoding round-trip

When you read a card name from the DB and put it into a deck, then re-read it from localStorage, then compare it against a hardcoded list — every step preserves the curly apostrophe. The bug pattern is: a developer hardcodes a list with ASCII apostrophes for "easier typing", and matching silently fails for names like Professor's Research even though the deck is correct.

If you're maintaining a hardcoded list (synergy pairs, banned cards, archetype seeds), open the rendered card name in the UI and copy-paste from there.
