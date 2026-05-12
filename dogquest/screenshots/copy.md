# Hound — Marketing Copy per Screen

Final headlines for each Play Store screenshot, chosen from the A/B/C options against Hound's positioning: **offline AI, no ads, 100% private, gamified collection, breed-spotting**.

## Picks

| # | Screen | Headline | Subhead (optional) | Why |
|---|---|---|---|---|
| 1 | Camera + live prediction | **Just point and tap** | _Works offline_ | "Effort = none, outcome = instant" sells the hero in 4 words. Subhead carries the #1 differentiator (offline AI) into the first impression. Competitors lead with speed claims; we win on simplicity. |
| 2 | Breed result dialog | **Breed details at a glance** | — | Matches the screen literally — the new size / origin / temperament chips ARE the "at a glance" payoff. Avoids overpromising ("learn everything") and avoids generic ("instant breed profiles"). |
| 3 | Kennel grid 47/150 | **Collect all 150+ breeds** | — | The "150+" is the gamification hook. Progress bar (47/150) is the visual proof. Tells the user "this is a game, here's the goal." Strongest motivation to download of the three. |
| 4 | Profile / XP / Achievements | **Level up your dog knowledge** | — | Combines the gamification verb (*level up*) with the value (*knowledge*). "Become a dog expert" implies expert status, which feels lofty. "Unlock achievements" describes mechanism, not benefit. |
| 5 | Share sheet (branded mock) | **Share your discoveries** | — | "Challenge your friends" implies competitive multiplayer — the social/friends backend is on a feature branch (phase-1/social-backend-realtime), not in v5.1. Don't promise features that aren't shipping. "Show off what you found" is too casual for a store hero. |
| 6 | Offline badge | **Works completely offline · No ads · 100% private** | — | Differentiation hammer. Three claims, each verifiable. Order matters: offline (technical), no ads (UX), private (trust). |

## Rejected variants — why

- **Screen 1 "What breed is that?"** — curiosity-bait, frames Hound as a quiz, not a tool. Lower install intent.
- **Screen 1 "Identify instantly"** — competes on speed, where every breed-ID app claims this. Doesn't differentiate.
- **Screen 2 "Learn everything about the breed"** — oversells; v5.1 shows ~5 fields, not "everything." Sets up disappointment.
- **Screen 3 "Build your personal collection"** — abstract. The 150+ number is the real hook.
- **Screen 3 "Track every breed you find"** — passive verb ("track"). Less compelling than "Collect all".
- **Screen 4 "Become a dog expert"** — final-state promise without a path. Levels show the path.
- **Screen 5 "Challenge your friends"** — features the friends backend isn't shipping yet. Risky.
- **Screen 5 "Show off what you found"** — registers as casual/childish in store context.

## Typography + overlay rules (handoff to Canva framing)

Apply consistently across all 18 framed assets:

- **Headline font:** SF Pro Display Bold (iOS-style — matches Hound's premium feel) or Inter Bold (open source fallback).
- **Headline size:** 56–64 pt at 1080 wide; 72 pt on tablet.
- **Color:** `#FFFFFF` on dark photo backgrounds (screens 1, 2); `#1A0F0A` (app `bgDeep`) or `#FFD700` (amber accent) on light/cream backgrounds.
- **Position:** Top third of frame, padded 64 pt from edges. Avoid covering breed image or progress bar.
- **Contrast check (WCAG AA):** Minimum 4.5:1 against the underlying photo region. If a screen has a busy background, add a 40% black gradient behind the text.
- **Subhead** (only screen 1): SF Pro Display Regular 28 pt, `#FFFFFFAA`, directly below headline.

## Per-device frame matrix

| Device label | Headline position | Frame |
|---|---|---|
| `pixel7` | Top, centered | Pixel 7 Obsidian shell |
| `galaxy_s24` | Top, centered | Galaxy S24 Onyx Black shell |
| `tablet_10` | Top-left, larger margins | Generic 10" tablet, landscape variant if needed |
