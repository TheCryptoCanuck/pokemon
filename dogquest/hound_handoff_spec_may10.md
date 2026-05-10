# Developer Handoff Spec: Hound v0.1 Design Fixes
**Generated:** May 10, 2026 | **Source:** Live device critique (15 screenshots) | **Stack:** Flutter/Dart, Riverpod, go_router

---

## Fix 1: Broken `/guide` Route (Critical Bug)

### Overview
Tapping something (likely a deep link or cached navigation state) routes to `/guide`, which no longer exists. The app shows a raw `GoException: no routes for location: /guide` error page. The old "Field Guide" tab was replaced by "Lost Dogs" (`/lost-dog`), but the `/guide` route was never redirected.

### Files to Change
| File | Change |
|------|--------|
| `lib/router.dart` | Add a `redirect` or a catch-all `GoRoute` for `/guide` |

### Implementation
Add a redirect at the top of the `GoRouter` config, inside the existing `redirect:` callback or as an explicit route:

```dart
GoRoute(
  path: '/guide',
  redirect: (_, __) => '/kennel', // Kennel is the closest equivalent
),
```

Alternatively, if `/guide` was the Field Guide (breed encyclopedia), consider restoring it as a sub-route under `/kennel` or `/map` since it was a core feature.

### Verification
- Cold-launch the app, navigate to every tab
- Deep-link test: `adb shell am start -a android.intent.action.VIEW -d "hound://guide"`
- Confirm no `GoException` appears anywhere

---

## Fix 2: Camera Loading Empty State

### Overview
The Identify tab (`/identify`) is the default landing screen. When the camera is initializing, users see a dark void with a small gray camera icon and "Camera loading..." text. This is the first interactive experience — it should feel alive.

### Files to Change
| File | Change |
|------|--------|
| `lib/screens/identify_screen.dart` | Replace camera loading placeholder |
| `lib/widgets/identify/` | New widget: `camera_loading_state.dart` |

### Design Tokens
| Token | Value | Usage |
|-------|-------|-------|
| `bgDeep` | `#0F1A10` | Background (already applied) |
| `accent` | `#D4874E` | Pulsing ring animation color |
| `textSecondary` | `Colors.white70` | "Preparing camera..." text |
| `textMuted` | `#B0B8B0` | Tip text below |

### Layout Spec
```
┌─────────────────────────────┐
│                             │
│                             │
│      ┌───────────────┐      │
│      │  Animated dog  │      │  ← Pulsing Hound logo silhouette
│      │   silhouette   │      │     or Lottie (80x80dp)
│      └───────────────┘      │
│                             │
│    Preparing camera...       │  ← textSecondary, 16sp, center
│                             │
│    💡 Tip: Point at any      │  ← textMuted, 14sp, center
│    dog to identify it!       │     Rotate tips every 3s:
│                             │     "Try the Gallery for saved photos"
│                             │     "Discover 150 breeds!"
│                             │     "Earn XP for every new breed"
│                             │
│                             │
│   [Daily Challenge pill]     │  ← Keep existing, move above Gallery
│   [Gallery]  [📷 Shutter]   │  ← Keep existing bottom controls
└─────────────────────────────┘
```

### States
| State | Behavior |
|-------|----------|
| Camera initializing | Show animated silhouette + rotating tips |
| Camera ready | Crossfade to live viewfinder (300ms, `Curves.easeOut`) |
| Camera permission denied | Show permission request card with icon + "Enable Camera" button |
| Camera error | Show error icon + "Retry" button + "Use Gallery instead" link |

### Animation
| Element | Trigger | Animation | Duration | Easing |
|---------|---------|-----------|----------|--------|
| Dog silhouette | On mount | Gentle pulse (scale 1.0→1.05→1.0) | 2000ms | `Curves.easeInOut`, repeat |
| Tip text | Every 3s | Fade out → swap → fade in | 400ms | `Curves.easeOut` |
| Viewfinder transition | Camera ready | Crossfade opacity 0→1 | 300ms | `Curves.easeOut` |

### Accessibility
- `Semantics(label: 'Camera is loading. Please wait.')` on the loading container
- Tips should be `aria-live: polite` equivalent (`SemanticsService.announce`)
- Shutter button: `Semantics(label: 'Take photo to identify dog breed', button: true)`

---

## Fix 3: "Start here." Tooltip Overlap

### Overview
The onboarding tooltip "Start here." overlaps the "Daily..." challenge pill, creating visual clutter. Both compete for the same vertical space above the shutter button.

### Files to Change
| File | Change |
|------|--------|
| `lib/screens/identify_screen.dart` or the tooltip widget | Adjust positioning and show logic |

### Spec
- Show "Start here." tooltip **only on first app launch** (gate on `player.totalSightings == 0`)
- Position it **above** the shutter button, not overlapping any other UI
- After first identification, never show again (persist flag in Hive: `dogquest_onboarding_tooltip_shown`)
- If daily challenge pill is also visible, stack: challenge pill at top, tooltip arrow pointing to shutter

---

## Fix 4: ID Result — Simplify Actions

### Overview
The identification result bottom area has 5 competing actions: "Save [Breed] to your Kennel" card (with "Create account →" and "Maybe later"), "Skip", "Add Anyway", and "Search breeds manually." This creates decision paralysis at the moment of delight.

### Files to Change
| File | Change |
|------|--------|
| `lib/widgets/dog_found_dialog.dart` | Restructure bottom action area |

### Current vs. Proposed Layout

**Current (bottom of result):**
```
┌─ Save Bulldog to your Kennel ──────┐
│  [Create account →]  [Maybe later] │
└────────────────────────────────────┘
   [< Share]              [Add Anyway]
              [Skip]
```

**Proposed:**
```
┌────────────────────────────────────┐
│  [★ Add to Kennel]                 │  ← Primary: accent bg, full-width
│                                    │     Saves locally (offline mode)
│  [Not this breed? Search manually] │  ← Text link, textMuted, centered
└────────────────────────────────────┘
   [< Share]              [Skip →]
```

### Design Tokens
| Element | Token | Value |
|---------|-------|-------|
| "Add to Kennel" button bg | `accent` | `#D4874E` |
| "Add to Kennel" text | `bgDeep` | `#0F1A10` (dark on amber) |
| "Not this breed?" link | `textMuted` | `#B0B8B0` |
| "Share" / "Skip" | `textSecondary` | `Colors.white70` |

### Interaction
| Element | Action | Behavior |
|---------|--------|----------|
| "Add to Kennel" | Tap | Save breed locally → XP animation → navigate to Kennel with highlight |
| "Not this breed?" | Tap | Expand to show alternative breeds + manual search (existing UI) |
| "Share" | Tap | Share sheet with breed card image |
| "Skip" | Tap | Dismiss result, return to camera |

### Account creation nudge
Move to the Me tab. After 3+ breeds collected without an account, show a one-time card: "Back up your collection — Sign in to save across devices." Do not interrupt the identification reward flow.

---

## Fix 5: Me Tab — Progressive Disclosure

### Overview
The Me tab (`/profile`, `ProfileScreen`) has 10+ sections in a single scroll: greeting, stats grid, level ring, Add Your Dog CTA, Start a Pack CTA, backup CTA, Your Journey, Daily Challenges, Daily Sweep, Weekly Mission, Dogs to Find, Next Up, Achievements, Collection & Stats. This creates information overload.

### Files to Change
| File | Change |
|------|--------|
| `lib/screens/profile_screen.dart` (1,268 lines) | Restructure into progressive sections |

### Proposed Layout — Above the Fold

```
┌─────────────────────────────────────┐
│  👤 Hello, Doger!   🏘️ Community 🔍 ⚙️ │
│                                     │
│  Level 1           XP: 320 / 1000   │
│  ████████░░░░░░░░░░░░░░░░░░░░░░░░  │
│                                     │
│     ┌──────┐                        │
│     │  1   │  ← Level ring          │
│     │Puppy │     (keep as-is,       │
│     └──────┘      this is great)    │
│                                     │
│   4 Breeds  ·  4 Sightings  ·  1 Badge │  ← Single row, 3 key stats
│                                     │
│  ┌─ [Contextual CTA] ────────────┐  │  ← ONE card, not three
│  │  Add Your Dog — earn 50 XP! → │  │     Rotates based on state
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

### Progressive CTA Logic
| User State | CTA Shown |
|------------|-----------|
| No dog profile | "Add Your Dog — earn 50 XP!" |
| Has dog, no pack | "Start a Pack — share with family!" |
| Has pack, no account | "Back up your collection — Sign in" |
| Has account | Hide CTA section entirely |

### Below the Fold — Collapsible Sections
| Section | Default State | Contains |
|---------|--------------|----------|
| **Daily Challenges** | Expanded | Daily challenges + Daily Sweep + Weekly Mission (merged) |
| **Your Journey** | Expanded | Journey milestones + Next Up achievements |
| **Dogs to Find** | Collapsed | Legendary breed suggestions |
| **Quizzes / Families / Mastered** | Collapsed | Secondary stats (moved from top grid) |
| **Achievements** | Collapsed | Full achievement list |
| **Collection & Stats** | Collapsed | Detailed collection stats |

### Stats Grid Change
Reduce from 3x2 (6 items) to a single row of 3:

| Current | Proposed |
|---------|----------|
| Breeds, Sightings, Badges | Keep (top row) |
| Quizzes, Families, Mastered | Move to "Collection & Stats" section |

---

## Fix 6: Nav Bar — Restore Field Guide

### Overview
The current nav bar is: Discover · Identify · Kennel · Lost Dogs · Me. "Lost Dogs" is a niche feature occupying primary navigation, while the breed encyclopedia (Field Guide) — a core discovery feature — is gone.

### Files to Change
| File | Change |
|------|--------|
| `lib/screens/home_shell.dart` | Change tab labels and icons |
| `lib/router.dart` | Restructure `StatefulShellRoute` branches |
| New: `lib/screens/field_guide_screen.dart` | Restore or create breed encyclopedia |

### Proposed Nav Bar
```
  Discover  ·  Identify  ·  Kennel  ·  Breeds  ·  Me
    🧭          📷           🗂️         📖        👤
```

| Tab | Route | Screen | Change |
|-----|-------|--------|--------|
| Discover | `/map` | `MapTab` | Rename from current. Add Lost Dogs as a sub-section within Discover. |
| Identify | `/identify` | `IdentifyScreen` | No change |
| Kennel | `/kennel` | `KennelScreen` | No change |
| Breeds | `/breeds` | Field Guide / Breed encyclopedia | Restore. Was `/guide`, now `/breeds`. |
| Me | `/profile` | `ProfileScreen` | No change |

### Lost Dogs Placement
Move Lost Dogs into the Discover tab as a chip/sub-tab alongside Hood, Log, Breeds, Live Map:

```
Discover tab:
  [Hood] [Log] [Breeds] [Live Map] [Lost Dogs]
```

---

## Fix 7: Persistent Snackbar Bug

### Overview
"New breed added! [Share]" snackbar appears at the bottom of every screen across every tab. It either never auto-dismisses or is being re-triggered on every navigation.

### Files to Change
| File | Change |
|------|--------|
| Likely `lib/widgets/dog_found_dialog.dart` or wherever `ScaffoldMessenger` is called | Fix snackbar duration |

### Spec
- Snackbar duration: `Duration(seconds: 4)`
- Use `ScaffoldMessenger.of(context).showSnackBar()` with `SnackBarBehavior.floating`
- Ensure it's only triggered once per identification, not on every route change
- Add `ScaffoldMessenger.of(context).clearSnackBars()` on tab navigation if needed

---

## Fix 8: Settings — Hide Demo Mode

### Overview
The Settings screen exposes "Demo Mode" with the description "Seeds 25+ breeds, sightings, and stats for investor demos." End users should not see this.

### Files to Change
| File | Change |
|------|--------|
| `lib/screens/settings_screen.dart` | Gate Demo Mode behind dev toggle |

### Spec
- Hide Demo Mode section in release builds: `if (kDebugMode)` guard
- Or: hide behind a gesture — tap "Version 0.1.0" label 7 times to reveal (Android Easter egg pattern)
- Replace About icon (generic amber "A" circle) with actual Hound logo asset (`assets/app_icon.png`)

---

## Fix 9: Splash — Contrast & Redundancy

### Files to Change
| File | Change |
|------|--------|
| `lib/screens/splash_screen.dart` | Fix "Ready!" contrast, remove redundant tagline |

### Spec
| Element | Current | Proposed |
|---------|---------|----------|
| "Ready!" text color | `textHint` (`#8A948A`) — ~3:1 contrast ratio | `accent` (`#D4874E`) — ~7:1 contrast ratio, passes WCAG AA |
| Logo subtitle "SCAN · IDENTIFY · CARE" | Visible in logo | Remove from logo SVG, or keep logo as-is and remove the separate "Discover. Identify. Collect." text |
| Behavior on "Ready!" | Passive text, user waits | Auto-navigate after 500ms delay, or show "Tap to start" with `accent` color |

---

## Fix 10: "Hello, Doger!" Default Username

### Files to Change
| File | Change |
|------|--------|
| `lib/services/player_service.dart` or model | Change default username |

### Spec
- Change default from "Doger" to "Dog Lover" (matches the older screenshot naming)
- Or: prompt for username during first identification flow (after first breed added)
- Username field in Settings already exists — just fix the default

---

## Global Design Tokens Reference

| Token | Hex | Usage |
|-------|-----|-------|
| `bgDeep` | `#0F1A10` | App background, scaffolds |
| `bgCard` | `#1A2B1C` | Card surfaces, bottom sheets |
| `bgNav` | `#0A1A0C` | Bottom navigation bar |
| `accent` | `#D4874E` | Primary actions, CTAs, active tab |
| `accentLight` | `#E8A96E` | Hover/highlight states |
| `accentGreen` | `#539548` | Nature/social contexts, progress bars |
| `textPrimary` | `#FFFFFF` | Headings, primary text |
| `textSecondary` | `#FFFFFFB3` | Body text, secondary labels |
| `textMuted` | `#B0B8B0` | Captions, hints |
| `textHint` | `#8A948A` | Placeholder text, disabled |
| Rarity: common | `#FFFFFFB3` | Common breed labels |
| Rarity: uncommon | `#C8A55A` | Uncommon breed labels |
| Rarity: rare | `#5B9CF6` | Rare breed labels |
| Rarity: legendary | `Colors.amber` | Legendary breed labels |

---

## Implementation Priority

| # | Fix | Effort | Impact |
|---|-----|--------|--------|
| 1 | `/guide` route crash | 15 min | Blocks any user hitting the old route |
| 7 | Persistent snackbar | 30 min | Visible on every screen, looks broken |
| 9 | Splash contrast | 30 min | First screen users see |
| 10 | Default username | 10 min | Quick win |
| 8 | Hide Demo Mode | 15 min | Investor-facing text visible to users |
| 4 | Simplify ID result actions | 2-3 hrs | Core loop polish |
| 2 | Camera loading state | 3-4 hrs | First interactive experience |
| 3 | Tooltip overlap | 1 hr | Onboarding polish |
| 5 | Me tab restructure | 4-6 hrs | Largest refactor, highest long-term impact |
| 6 | Nav bar restructure | 3-4 hrs | Requires route + screen changes |
