# Design Critique: Hound v0.1.0
**Date:** May 10, 2026 | **Source:** 15 fresh device screenshots | **Stage:** Pre-beta polish

---

## Overall Impression

Hound has a strong visual identity — the dark forest green palette with warm amber accents feels premium and nature-themed. The gamification layer (XP, levels, combos, daily challenges) is genuinely deep. The breed identification result card is the best screen in the app: rewarding, informative, and well-structured.

The biggest opportunities are: reducing information overload on the Me tab, fixing the broken `/guide` route, and polishing the camera loading state which is currently the first thing a new user sees after the splash.

---

## Screen-by-Screen Critique

### 1. Splash Screen

| Finding | Severity | Recommendation |
|---------|----------|----------------|
| Redundant taglines — logo reads "SCAN · IDENTIFY · CARE" while text below says "Discover. Identify. Collect." | :yellow_circle: Moderate | Pick one. "Discover. Identify. Collect." is stronger — it maps to the core loop. Remove the logo subtitle or make them match. |
| "Ready!" text has poor contrast — light gray on dark green | :yellow_circle: Moderate | Use `textPrimary` (white) or `accent` (amber) for the ready state. Currently reads as disabled. |
| The progress bar completes but the splash lingers | :green_circle: Minor | Auto-navigate on completion. If there's a deliberate delay, show a "Tap to start" button instead of passive "Ready!" text. |
| Logo + wordmark + tagline + progress bar + "Ready!" = 5 elements stacked vertically | :green_circle: Minor | Consider collapsing: logo animates in → tagline fades in → auto-navigates. Less to read, more to feel. |

**What works well:** The Hound logo is distinctive and memorable. The green-on-dark color scheme immediately sets the outdoor/nature tone.

---

### 2. Identify Tab (Camera)

| Finding | Severity | Recommendation |
|---------|----------|----------------|
| "Camera loading..." state dominates the screen — user sees a gray icon + text centered in a vast empty dark void | :red_circle: Critical | This is the default landing screen. The empty state needs to be inviting, not clinical. Show a lottie/animated dog silhouette, pulsing camera ring, or tip cards while loading. |
| "Start here." tooltip overlaps and partially covers the "Daily..." challenge pill behind it | :yellow_circle: Moderate | Stack them vertically or show the tooltip only on first launch, then dismiss. Currently they compete. |
| Camera shutter button is well-designed (amber ring, dark icon) but sits alone — Gallery is the only other option | :green_circle: Minor | Consider adding a "Tip: Point at any dog!" micro-text above the shutter on first use. The empty viewfinder gives no affordance. |
| No zoom slider visible (1x/15x slider from archive screenshots is gone) | :green_circle: Minor | If zoom was removed, fine. If it only appears after camera loads, ensure it's discoverable. |
| Bottom nav: "Identify" tab icon is a camera inside a filled circle — the only filled icon in the nav bar | :green_circle: Minor | This is actually good — it draws the eye to the primary action. Keep it. |

**What works well:** The shutter button design is satisfying — the amber/gold ring with dark center says "primary action." Gallery placement (left of shutter) follows camera app conventions.

---

### 3. Identification Result Cards (Boxer / Bulldog)

| Finding | Severity | Recommendation |
|---------|----------|----------------|
| "Possible Match" label appears alongside "Worth checking" and "Best guess" as secondary labels — the distinction between these is unclear | :yellow_circle: Moderate | Define and display one confidence tier: "Confident Match" / "Likely Match" / "Possible Match." Drop the ambiguous sub-labels. |
| Bottom action area has 5 competing actions: Skip, Add Anyway, Create account, Maybe later, Search breeds manually | :yellow_circle: Moderate | Simplify to 2: a primary "Add to Kennel" and a text-link "Not this breed? Search manually." Move account creation to Me tab or a post-collection prompt. |
| "Save Bulldog to your Kennel" card with "Create account →" and "Maybe later" pushes account creation at the moment of delight | :yellow_circle: Moderate | This interrupts the reward loop. Let the user save locally first (they're already in offline mode), then nudge account creation on the Me tab. |
| "Canis lupus familiaris (Working)" — the Latin name adds no value for 99% of users | :green_circle: Minor | Replace with AKC group + origin (e.g., "Working Group · Germany"). Already flagged in CLAUDE.md design backlog. |
| XP reward "+25 XP" is clear but small | :green_circle: Minor | Consider a brief XP animation (number flies up to a counter) to make the reward feel earned. |

**What works well:** The "NEW BREED DISCOVERED!" banner with star icons is genuinely exciting. The breed photo, fun fact text, and "Did you mean one of these?" alternative suggestion are all excellent. This screen nails the core loop.

---

### 4. Kennel Tab

| Finding | Severity | Recommendation |
|---------|----------|----------------|
| "294 coming" text in top-right corner is nearly invisible — tiny, muted text | :yellow_circle: Moderate | Either remove it (it's a dev detail) or make it a proper badge: "150 breeds · 294 coming in v2" |
| Ghost cards with "?" icons for undiscovered breeds are a strong collection mechanic | :green_circle: Positive | This is well done — it creates aspiration. The breed name visible below the "?" is a nice touch. |
| Filter chips (4 common, 0 uncommon, 0 rare, 0 legendary) — the "0" counts feel discouraging for a new user | :green_circle: Minor | Consider hiding zero-count chips or showing them as locked/dimmed with the total available (e.g., "0/77 uncommon"). |
| Grid/Families/Sets tab row + Legendary filter chip row = two horizontal scrolling rows stacked | :green_circle: Minor | This works but adds visual noise. Consider merging into a single filter system. |
| Share button in breed card corners — purpose is unclear at a glance | :green_circle: Minor | Add a tooltip on first encounter or use a more recognizable icon. |

**What works well:** The grid layout with real breed photos is visually rich. The progress bar (green fill) and "4 / 150 breeds" counter give clear progress feedback. The search bar is well-placed.

---

### 5. Discover Tab (Hood / Neighborhood)

| Finding | Severity | Recommendation |
|---------|----------|----------------|
| Tab chips at top are clipped: "Log" (truncated), "Live Map" (truncated) | :yellow_circle: Moderate | Use shorter labels ("Hood", "Log", "Breeds", "Map") or make the chip row scrollable with full labels visible. |
| Empty state ("Your Neighborhood — Add your dog in the Profile tab") is clear but the screen is 90% blank | :yellow_circle: Moderate | Add illustration variety, or show nearby breed statistics / "X dogs discovered in your area" even without a profile dog. Give the user a reason to come back. |
| "Discover" as a nav tab name is vague — it could mean discover breeds, discover nearby dogs, discover the app | :green_circle: Minor | The old "Sightings" was more specific. Consider "Explore" or "Nearby" to signal location-based features. |

**What works well:** The houses illustration is charming and on-brand. The tab chip UI (Hood/Log/Breeds/Live Map) promises rich functionality once populated.

---

### 6. Me Tab (Profile)

| Finding | Severity | Recommendation |
|---------|----------|----------------|
| Information overload: the Me tab has 10+ distinct sections stacked vertically — stats grid, level ring, Add Your Dog CTA, Start a Pack CTA, Back up collection, Your Journey, Daily Challenges, Daily Sweep, Weekly Mission, Dogs to Find, Next Up, Achievements, Collection & Stats | :red_circle: Critical | This is a dashboard trying to be a feed. Group into 2-3 collapsible sections: "Your Progress" (level ring + stats + journey), "Challenges" (daily/weekly), "Your Dogs" (add dog, pack). Or use a tab bar within Me. |
| "Hello, Doger!" — the default username feels like a placeholder | :yellow_circle: Moderate | Use "Hello, Dog Lover!" or prompt for a name on first launch. "Doger" reads as a typo of "Dodger." |
| Three CTA cards stacked (Add Your Dog, Start a Pack, Back up collection) — all competing for attention on first load | :yellow_circle: Moderate | Show one contextual CTA at a time. New user → "Add Your Dog." After dog added → "Start a Pack." After pack → "Back up collection." Progressive disclosure. |
| "Back up your collection / Sign in to sync your collection" card with "Sign In" button — this is the third place account creation is pushed (also in ID result and Settings) | :green_circle: Minor | Consolidate to one gentle nudge. |
| Level ring ("1 / Puppy") is the visual anchor — well-designed and satisfying | :green_circle: Positive | The green arc, level number, and title work together. This should be even more prominent. |
| Stats grid (Breeds, Sightings, Badges, Quizzes, Families, Mastered) — 6 stats in a 3x2 grid is dense | :green_circle: Minor | The top row (Breeds, Sightings, Badges) matters most. Consider moving Quizzes/Families/Mastered to Collection & Stats section. |
| "Dogs to Find" section shows 4 legendary breeds (Kooikerhondje, Chinook, Kai Ken, Catalburun) — nice aspiration mechanic | :green_circle: Positive | Good use of the legendary rarity to drive exploration. |

**What works well:** The level ring is the standout element. Daily Challenges and Weekly Mission cards have clear progress bars. The "Next Up" achievement previews are motivating. The overall depth of gamification is impressive.

---

### 7. Settings

| Finding | Severity | Recommendation |
|---------|----------|----------------|
| Section headers use amber/gold color consistently — clean and scannable | :green_circle: Positive | Well-structured settings page. |
| Destructive actions ("Delete Sighting History", "Delete All App Data") use red/orange text — correct pattern | :green_circle: Positive | Good use of color to signal danger. |
| "Contribute to Science" toggle is a nice touch but the description is vague | :green_circle: Minor | Add a "Learn more" link or expand the subtitle: "Help researchers study breed distribution patterns." |
| Demo Mode section ("Seeds 25+ breeds, sightings, and stats for investor demos") — this should be hidden in production builds | :yellow_circle: Moderate | Gate behind a developer toggle or remove from release builds entirely. Users shouldn't see "investor demos." |
| About section shows a generic amber circle with "A" — not the Hound logo | :green_circle: Minor | Replace with the actual Hound dog logo for brand consistency. |

---

### 8. Broken Route: /guide

| Finding | Severity | Recommendation |
|---------|----------|----------------|
| "Page Not Found — GoException: no routes for location: /guide" | :red_circle: Critical | The old "Field Guide" tab route is broken. The nav was renamed to "Lost Dogs" but something still links to `/guide`. Fix the route or add a redirect. |

---

## Cross-Screen Issues

### Navigation Bar Changes
The nav bar now reads: **Discover · Identify · Kennel · Lost Dogs · Me** (was: Sightings · Identify · Kennel · Field Guide · Me). "Lost Dogs" as a primary nav item is an unusual choice — it's a niche feature promoted to top-level navigation over the breed encyclopedia (Field Guide), which was a core feature. Consider whether Lost Dogs belongs in the Discover tab instead, and restoring Field Guide/Breeds to the nav bar.

### Persistent Snackbar
"New breed added! [Share]" appears at the bottom of nearly every screenshot. Either it's stuck (bug) or it persists too long. Snackbars should auto-dismiss after 4-6 seconds.

### Color Contrast Concerns
- "Ready!" on splash: ~3:1 ratio (fails WCAG AA for normal text)
- Rarity labels on Kennel ghost cards ("rare"): small amber text on dark card
- "294 coming" counter: very small muted text
- Green progress bars on dark green backgrounds: low contrast

### Typography
The app uses a clean sans-serif throughout. Hierarchy is generally clear (bold breed names, muted subtitles). The main issue is text size in secondary labels — several are too small to scan quickly on a phone.

---

## Priority Recommendations

1. **Fix the /guide route crash** — this is a shipped bug that shows a raw exception to users. Either restore the Field Guide screen or redirect `/guide` to the Kennel's breed list view.

2. **Redesign the camera loading state** — this is the first interactive screen users see. Replace the gray icon + "Camera loading..." with an animated, branded loading experience. Show tips, the daily challenge, or a breed-of-the-day while the camera initializes.

3. **Tame the Me tab** — collapse the 10+ sections into progressive disclosure. Show the level ring + top 3 stats + one contextual CTA above the fold. Everything else goes into expandable sections or sub-tabs.

4. **Simplify the ID result actions** — remove account creation from the result flow. Two actions: "Add to Kennel" (primary) and "Not this breed?" (secondary). Let the reward moment be pure.

5. **Reconsider nav bar composition** — Lost Dogs as a primary tab is premature for v0.1. Restore a breed encyclopedia (Field Guide / Breeds) to the nav and move Lost Dogs under Discover.

6. **Hide Demo Mode in production** — the "investor demos" language breaks immersion. Gate it behind a hidden gesture (tap version 7 times) or compile it out of release builds.

7. **Fix the persistent snackbar** — "New breed added!" should auto-dismiss, not follow the user across every tab.

---

## What Works Well

- The **dark forest green + amber** palette is cohesive and distinctive
- The **breed identification result card** is genuinely exciting — the "NEW BREED DISCOVERED!" moment is the best screen in the app
- **Ghost collection cards** in the Kennel create strong collection drive
- **Gamification depth** (XP, levels, combos, daily/weekly challenges, achievements, breed sets) is impressive for v0.1
- The **level ring** on the Me tab is a satisfying progress visualization
- **Settings** is well-organized with proper destructive action styling
- The **shutter button** design is visually satisfying and clearly the primary action
