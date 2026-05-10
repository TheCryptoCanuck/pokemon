# Visual Design Refresh Plan — DogQuest

**Status:** Draft for review. Tier 2 design research; do NOT implement until T1 closes (per Active_Tasks tier discipline).
**Author:** Claude (visual-design-foundations skill).
**Date:** 2026-04-26.
**Scope:** App-wide visual system + logo. Excludes information architecture, copy, and gameplay loop changes (those live in `dog_found_dialog_redesign_spec.md`, `quiz_redesign_spec.md`, `lost_dog_improvements_spec.md`).

---

## 0. TL;DR

DogQuest already has a strong visual seed — **dark forest green base + warm amber accent** is on-brand for an outdoor-explorer collector app and the paw-with-spark mark is recognisable. What's missing is system. Right now the app is an ad-hoc collection of `SizedBox(height: 6/8/16/24)`, hand-rolled `TextStyle(fontSize: 32 / 22 / 15 / 13)` and three different ambers (`Colors.amber`, `#D4874E`, `#E8A96E`) used inconsistently across `main.dart`, `splash_screen.dart`, and the rarity scale. Avatars pull a clashing rainbow from the Material palette. There is no defined typeface, no elevation system, no motion tokens, and no component library — every screen reinvents card padding and chip styling.

The plan is incremental and lands in three phases:

1. **Tokenisation pass** (1 sprint): codify the system already implicit in the codebase into a `lib/theme/` module — `tokens.dart` (colors, type, spacing, radius, elevation, motion), a `DogQuestTheme` extension on `ThemeData`, and a small set of primitive widgets (`DqCard`, `DqChip`, `DqBadge`). Replace literal colors and font sizes one screen at a time.
2. **Logo + brand mark refresh** (parallel to phase 1, design only): pick one of the three directions sketched in §6 and ship a complete asset bundle (adaptive icon foreground, monochrome, splash wordmark, social avatar).
3. **Screen-level visual upgrades** (2–3 sprints, post-T1): apply Material 3 Expressive patterns to the highest-traffic screens — Identify result, Kennel grid, Profile, Pack, Map, Lost-Dog Hub. Add motion polish, glass overlays where they earn it, and a unified empty-state pattern.

Confidence: `solid` on the audit findings (read directly from `constants.dart`, `main.dart`, `splash_screen.dart`, `kennel_screen.dart`, `assets/app_icon.png`, `assets/splash_logo.png`). `uncertain` on which logo direction Jesse will prefer — that's a pick. `drift` on any specific 2026 trend longevity — trend cycles are 18-month windows.

---

## 1. Audit — what's there today

### 1.1 Color tokens (from `lib/constants.dart:35-49`)

| Token | Value | Used for |
|---|---|---|
| `bgDeep` | `#0F1A10` | Scaffold background |
| `bgCard` | `#1A2B1C` | Card surface (single elevation) |
| `bgNav` | `#0A1A0C` | Bottom nav bar |
| `accent` | `#D4874E` | Brand amber (warm) |
| `accentLight` | `#E8A96E` | Amber hover state |
| `accentGreen` | `#539548` | Mid forest green for nature/social contexts |
| `textPrimary` | `Colors.white` | Headings |
| `textSecondary` | `Colors.white70` | Body |
| Rarity common | `Colors.white70` | Common dogs |
| Rarity uncommon | `#C8A55A` | Desaturated gold |
| Rarity rare | `#5B9CF6` | Warm blue |
| Rarity legendary | `Colors.amber` | Material amber |
| Rarity unknown | `#CE93D8` | Lavender |

**Issues:**
- Three different ambers in play. `Colors.amber` (`#FFC107`) shows up in `main.dart:795,803,814` (theme primary, ElevatedButton bg, BottomNav selected) and in `splash_screen.dart:105` (tagline) — the brand `accent` (`#D4874E`) is *never* the theme primary. The legendary rarity is also `Colors.amber`, so legendary dogs and primary buttons share the same colour, weakening both signals.
- Only one card surface. Modal sheets, dialogs, and elevated chips all reuse `bgCard` with no tonal step, so you can't visually rank "this is on top of that".
- Common rarity = `white70` is functional but reads as "no rarity", which is fine for tier signalling but means the rarity strip on a kennel grid has only 3.5 visible tiers (white blends into white text).
- Rarity colours don't share a hue family with the brand. The blue `#5B9CF6` and lavender `#CE93D8` are genuinely off-brand.

### 1.2 Typography

No defined typeface. The app inherits `ThemeData.dark()`, which gives Roboto on Android. Inline sizes spotted:
- `splash_screen.dart` — title 32 / tagline 14
- `kennel_screen.dart` empty state — heading 22 / body 15
- `main.dart` error widget — title 18 / body 12 / error fallback 16
- Migration dialog — title default Material / body 13

Letter-spacing only set in two places (`splash_screen.dart`: 2 on title, 1.5 on tagline). No fluid type, no defined line-heights, no semantic tokens (`headlineLarge` / `bodyMedium`).

### 1.3 Spacing

Pure ad-hoc `SizedBox(height: N)` with N ∈ {6, 8, 12, 16, 20, 24, 32, 48}. Roughly 8pt-aligned by accident. No named tokens, no rhythm utility.

### 1.4 Component primitives

Effectively none. `ElevatedButton` is themed in `main.dart:801-810` with amber bg, 16px radius, bold 16px label. Everything else (cards, chips, badges, dialogs) is built per-screen with raw `Container(decoration: BoxDecoration(...))`. The result: `dog_found_dialog`, `dog_detail_sheet`, `breed_share_sheet`, and `streak_break_dialog` look like four different products by four different designers.

### 1.5 Iconography

Material `Icons.*` everywhere (`Icons.pets`, `Icons.camera_alt_rounded`, `Icons.error_outline`). No custom set. No size tokens. Icons inherit colour from parent which mostly works but produces white-on-dark + amber-on-dark mixed states with no rules.

### 1.6 Logo + splash assets (`assets/`)

- `app_icon.png` — 1024×1024, paw silhouette in white on dark forest green (`#0F1A10` background match), single small amber sparkle top-right.
- `app_icon_foreground.png` — adaptive icon foreground.
- `app_icon_square.png` — square fallback.
- `splash_logo.png` — paw badge + "DogQuest" wordmark (cream "Dog" + amber "Quest") + green tagline "IDENTIFY · COLLECT · EXPLORE".

**Critique:**
- The paw is well-proportioned but reads as generic — there are dozens of pet apps with a white paw on a dark background. There's no DogQuest-specific signature.
- The sparkle is the right *idea* (quest/discovery) but it's tiny and disconnected; at 48px launcher size it disappears.
- The wordmark uses a default-weight sans in two colours, no custom letterforms. The "Q" of Quest is the only opportunity for a memorable letterform and it's untouched.
- Splash tagline uses `accentGreen` (`#539548`) at small size — fine on the marketing image, but in-app the splash uses `Colors.amber` for the tagline (`splash_screen.dart:105`). The two splash treatments don't match.
- No monochrome / single-colour version of the mark exists. Needed for press, in-app monochrome contexts, and dark-on-light variants.

---

## 2. Research — 2026 visual trends that matter for DogQuest

Three trends are directly applicable. The rest are noise for this app.

### 2.1 Material 3 Expressive
Google's evolution of Material 3 (rolling out through Flutter 3.41+, with deeper Expressive component coverage in Flutter 3.44 / 3.47). The relevant features for DogQuest: **larger rounded corner radii**, **springy motion curves**, **shape morph between states** (chip → expanded card on tap), and **dynamic colour from a seed** (Material's `ColorScheme.fromSeed`). DogQuest is on `ThemeData.dark()` and doesn't use M3 component theming yet; turning M3 on is two lines and unlocks the modern Flutter component look without a re-skin.

### 2.2 Disciplined dark glassmorphism ("Liquid Glass" era)
After Apple's iOS Liquid Glass push, frosted/translucent surfaces are mainstream again, but the 2026 take is **surgical**: only on overlays, modals, and bottom sheets that float over content. The Lost-Dog Hub bottom sheet, the Dog Detail sheet, and the Breed Share sheet are the right places. Don't blur the kennel cards themselves — that was the 2021 mistake.

### 2.3 Fluid typography + clear hierarchy
Modular type scales (Display/Headline/Title/Body/Label × small/medium/large) are now table stakes for serious apps. Replacing the ~12 ad-hoc `TextStyle(fontSize: N)` literals with `Theme.of(context).textTheme.bodyMedium` (etc.) gives consistent line-heights, a single source of truth, and free dynamic type support.

### 2.4 What to skip
- AI-generated dynamic visuals — overkill for a collector app.
- Skeumorphic 3D illustrations — would clash with the dark-collector mood.
- Full neumorphism — already past peak.

### 2.5 Pet-app brand benchmarks
Wild One (modern minimal, muted earth tones, geometric sans) and The Farmer's Dog (warm-cream + sage, friendly humanist serif) both lean **caregiver** brand archetype. DogQuest's positioning is closer to **explorer + caregiver hybrid** — questing/collecting for the explorer side, lost-dog recovery for the caregiver side. Visual language should signal both: nature/outdoor (deep greens, organic forms) for explorer; warmth/trust (warm amber, rounded shapes, no harsh edges) for caregiver.

---

## 3. Token system — proposed `lib/theme/tokens.dart`

This is the migration target. Drop-in compatible with current `bgDeep` / `bgCard` / `accent` so existing screens keep working until they're individually migrated.

### 3.1 Colour tokens (semantic + tonal)

```dart
// lib/theme/tokens.dart
import 'package:flutter/material.dart';

class DqColors {
  // ─── Surface tonal palette (5 steps for elevation) ──────────────────
  static const surface0  = Color(0xFF0A1410);  // deepest — splash, modals
  static const surface1  = Color(0xFF0F1A10);  // = current bgDeep — scaffold
  static const surface2  = Color(0xFF15231A);  // raised cards
  static const surface3  = Color(0xFF1A2B1C);  // = current bgCard — primary card
  static const surface4  = Color(0xFF223524);  // hover/pressed card
  static const surface5  = Color(0xFF2C4030);  // outlined inputs, dividers up

  // ─── Brand ───────────────────────────────────────────────────────────
  static const amber500  = Color(0xFFD4874E);  // = current accent — primary CTA
  static const amber400  = Color(0xFFE8A96E);  // = current accentLight — hover
  static const amber600  = Color(0xFFB36A33);  // pressed
  static const amber300  = Color(0xFFF2C49A);  // soft highlights, on-amber text

  static const forest500 = Color(0xFF539548);  // = current accentGreen
  static const forest400 = Color(0xFF6FAD64);  // hover
  static const forest300 = Color(0xFF8DC681);  // chips on dark surface

  // ─── Semantic ────────────────────────────────────────────────────────
  static const success   = Color(0xFF6FAD64);  // = forest400
  static const warning   = Color(0xFFE8A96E);  // = amber400 (warm not red)
  static const danger    = Color(0xFFE5634C);  // brick — harmonises with amber
  static const info      = Color(0xFF7AB8C9);  // muted teal — replaces blue

  // ─── Text ────────────────────────────────────────────────────────────
  static const textPrimary    = Color(0xFFF5F2EC);  // warm white (not pure)
  static const textSecondary  = Color(0xFFB8B4AB);  // warm grey
  static const textTertiary   = Color(0xFF7A766F);  // hints, disabled
  static const textOnAmber    = Color(0xFF1A0F08);  // CTA label

  // ─── Rarity (re-tuned to share hue family with brand) ────────────────
  static const rarityCommon    = Color(0xFFB8B4AB);  // warm grey (vs. white70)
  static const rarityUncommon  = Color(0xFF8DC681);  // forest300 — bound to brand
  static const rarityRare      = Color(0xFF7AB8C9);  // muted teal — was harsh blue
  static const rarityLegendary = Color(0xFFF2C49A);  // amber300 — golden, distinct from CTA amber
  static const rarityMythic    = Color(0xFFB78BD4);  // muted lavender — for v6 expansion
  static const rarityUnknown   = Color(0xFF7A766F);  // textTertiary

  // ─── Glass overlay ───────────────────────────────────────────────────
  static const glassFill   = Color(0x991A2B1C);  // 60% surface3
  static const glassStroke = Color(0x33F5F2EC);  // 20% textPrimary
}
```

**Migration rule:** `bgDeep` → `surface1`, `bgCard` → `surface3`, `accent` → `amber500`, `accentLight` → `amber400`, `accentGreen` → `forest500`. Replace `Colors.amber` literals (theme primary, ElevatedButton, BottomNav, splash tagline, legendary rarity) with `amber500` for CTAs and `rarityLegendary` for legendary dogs — finally separating the two signals.

### 3.2 Typography scale

Adopt **Inter** (free, well-supported on Android) for UI + **Fraunces** display (variable, distinctive, free) for headings and the wordmark. Two files, both via `google_fonts` package (already-added pubspec entry).

```dart
class DqTypography {
  static const _ui      = 'Inter';
  static const _display = 'Fraunces';

  // Display — Fraunces, used sparingly: wordmark, hero kennel count, level-up
  static const displayLarge  = TextStyle(fontFamily: _display, fontSize: 56, height: 1.1, fontWeight: FontWeight.w700, letterSpacing: -0.5);
  static const displayMedium = TextStyle(fontFamily: _display, fontSize: 44, height: 1.15, fontWeight: FontWeight.w700, letterSpacing: -0.25);
  static const displaySmall  = TextStyle(fontFamily: _display, fontSize: 32, height: 1.2, fontWeight: FontWeight.w600);

  // Headline — Inter heavy, screen titles, dialog titles
  static const headlineLarge  = TextStyle(fontFamily: _ui, fontSize: 28, height: 1.2, fontWeight: FontWeight.w700);
  static const headlineMedium = TextStyle(fontFamily: _ui, fontSize: 22, height: 1.25, fontWeight: FontWeight.w700);
  static const headlineSmall  = TextStyle(fontFamily: _ui, fontSize: 18, height: 1.3, fontWeight: FontWeight.w600);

  // Title — section headers, card titles
  static const titleLarge  = TextStyle(fontFamily: _ui, fontSize: 17, height: 1.3, fontWeight: FontWeight.w600);
  static const titleMedium = TextStyle(fontFamily: _ui, fontSize: 15, height: 1.4, fontWeight: FontWeight.w600);
  static const titleSmall  = TextStyle(fontFamily: _ui, fontSize: 13, height: 1.4, fontWeight: FontWeight.w600);

  // Body — paragraphs, descriptions
  static const bodyLarge  = TextStyle(fontFamily: _ui, fontSize: 16, height: 1.5, fontWeight: FontWeight.w400);
  static const bodyMedium = TextStyle(fontFamily: _ui, fontSize: 14, height: 1.5, fontWeight: FontWeight.w400);
  static const bodySmall  = TextStyle(fontFamily: _ui, fontSize: 12, height: 1.4, fontWeight: FontWeight.w400);

  // Label — buttons, chips, tags, ALL CAPS where needed
  static const labelLarge  = TextStyle(fontFamily: _ui, fontSize: 14, height: 1.2, fontWeight: FontWeight.w600, letterSpacing: 0.5);
  static const labelMedium = TextStyle(fontFamily: _ui, fontSize: 12, height: 1.2, fontWeight: FontWeight.w600, letterSpacing: 0.5);
  static const labelSmall  = TextStyle(fontFamily: _ui, fontSize: 11, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: 1.0);  // tagline / rarity badge
}
```

Why Fraunces for display: it's a variable-axis serif with a **soft optical-sized cut** that reads warm and trustworthy (caregiver) while still feeling distinctive (explorer). It's been adopted by Mailchimp and Joybird. Pair with Inter for UI and you get one warm + one neutral — classic pairing rule.

### 3.3 Spacing scale (8pt grid)

```dart
class DqSpace {
  static const xs  = 4.0;
  static const sm  = 8.0;
  static const md  = 12.0;
  static const lg  = 16.0;
  static const xl  = 24.0;
  static const x2  = 32.0;
  static const x3  = 48.0;
  static const x4  = 64.0;
}
```

Replacement table for current literals: 6→sm, 8→sm, 12→md, 16→lg, 20→xl (round up), 24→xl, 32→x2, 48→x3.

### 3.4 Radius + elevation tokens

```dart
class DqRadius {
  static const sm  = 8.0;   // chips
  static const md  = 12.0;  // small cards, buttons
  static const lg  = 16.0;  // cards (current button radius)
  static const xl  = 20.0;  // bottom sheets, dialogs
  static const x2  = 28.0;  // hero cards, identify result
  static const x3  = 36.0;  // adaptive icon corner
  static const pill = 999.0;
}

class DqElevation {
  // Tonal elevation (M3 style) — colour shift, no shadow
  static const surface = DqColors.surface1;
  static const card    = DqColors.surface3;
  static const raised  = DqColors.surface4;
  static const overlay = DqColors.glassFill;  // backdropFilter applied at widget
}
```

### 3.5 Motion tokens

```dart
class DqMotion {
  // Durations
  static const fast    = Duration(milliseconds: 150);  // chip tap
  static const medium  = Duration(milliseconds: 250);  // card transition
  static const slow    = Duration(milliseconds: 400);  // dialog enter
  static const splashy = Duration(milliseconds: 800);  // XP gain, level up

  // Curves
  static const standard  = Curves.easeOutCubic;
  static const emphasis  = Curves.easeOutBack;       // celebratory
  static const elastic   = Curves.elasticOut;        // splash logo (existing)
}
```

---

## 4. Logo + brand mark refresh

### 4.1 Goals
1. Keep paw + spark concept — it's already on the icon, the splash, and any installed user's launcher. Don't reset recognition.
2. Differentiate from generic "white paw on dark" pet apps by adding one DogQuest-specific signature element.
3. Tighten the wordmark with a custom letterform on the "Q" of Quest.
4. Ship a complete asset bundle, not just one PNG.

### 4.2 Three logo directions

Mockups in `docs/session_2026-04-26/visual_design_refresh_logos.svg`. Pick one before phase-2 implementation.

**Direction A — "North Star Paw"** (recommended)
The current paw, but the sparkle becomes a **4-point compass-rose star** centred on the paw's middle pad. Reads as "quest" (compass + north star) and "find your dog" (the star marks the spot). The star is amber, the paw is warm-white. Adds a thin amber stroke around the paw silhouette so it gains definition at small sizes.

**Direction B — "Trail Tracker"**
The paw is rendered as a **stylised paw print pressed into ground**, with two smaller "fading" paw prints behind it suggesting a trail. Quest = trail. Strong outdoor/explorer signal but loses some of the friendly compactness. Better for a route/walking app, slightly off for a collector app.

**Direction C — "Constellation Paw"**
The paw silhouette is built from **5 connected dots like a constellation** (4 toes + 1 main pad), with a faint scatter of stars in the background. Pure quest/discovery vibe, very modern, but breaks the recognition with the current installed users' launcher icon. Highest risk, highest distinctiveness.

### 4.3 Wordmark recommendation

Switch wordmark to **Fraunces 700 italic** for "DogQuest" (one word, no two-tone), with a custom **flag-tail "Q"** that subtly forms a paw curl. Keep the tagline "IDENTIFY · COLLECT · EXPLORE" in **Inter 700 caps** at `labelSmall` (11/1.2/+1.0 tracking) in `forest500`. The current cream + amber two-tone treatment reads dated; a single warm amber wordmark with a custom Q has more longevity.

### 4.4 Asset bundle (deliverables for the picked direction)

| File | Size | Use |
|---|---|---|
| `assets/logo/app_icon.svg` | vector | source of truth |
| `assets/logo/app_icon_1024.png` | 1024² | Play Store, App Store |
| `assets/logo/app_icon_foreground.png` | 432² safe area | Android adaptive |
| `assets/logo/app_icon_monochrome.png` | 432² | Android 13+ themed icons |
| `assets/logo/app_icon_round.png` | 1024² | iOS / round launcher |
| `assets/logo/wordmark_horizontal.svg` | vector | navbars, marketing |
| `assets/logo/wordmark_stacked.svg` | vector | square crops, social avatar |
| `assets/logo/splash_logo.svg` | vector | replaces current PNG |
| `assets/logo/social_avatar_400.png` | 400² | Twitter/IG/etc. |
| `assets/logo/favicon.svg` | 32² | future web |

Migrate `flutter_launcher_icons.yaml` to consume the new SVG sources via the standard android/ios adaptive icon config.

### 4.5 Consistency fixes (non-logo, but brand-adjacent)

- **Splash tagline colour** — change `Colors.amber` (line 105 of `splash_screen.dart`) to `DqColors.forest500` so the in-app splash matches the marketing splash.
- **App theme primary** — change `primaryColor: Colors.amber` (line 795 `main.dart`) to `DqColors.amber500`.
- **ElevatedButton bg** — change `backgroundColor: Colors.amber` (line 803) to `DqColors.amber500`.
- **BottomNav selected** — change `selectedItemColor: Colors.amber` (line 814) to `DqColors.amber500`.
- **Legendary rarity** — keep as `DqColors.rarityLegendary` (`#F2C49A`), distinct from CTA amber, so a legendary kennel card and a primary button no longer share a hue.

---

## 5. Screen-level visual upgrades — phase 3 sequencing

Apply tokens + M3 Expressive treatments to the highest-traffic screens first. Each screen lists the top 3 changes only — full per-screen specs are out of scope for this plan.

### 5.1 Identify result (`dog_found_dialog.dart`) — coordinates with T2 dialog redesign spec
1. Bottom sheet, not centre dialog. Drags up from camera. Glass overlay (`backdropFilter` blur 20, `glassFill` over a dim shade of the camera frame).
2. Top-3 candidate tiles use `surface3` cards with a 4px left edge in the candidate's `rarity` colour. Tap a tile → `surface4` press state → confirm.
3. XP/rarity badges use `labelMedium` chips in pill shape, coloured by tier — kills the inline rainbow text.

### 5.2 Kennel grid (`kennel_screen.dart`)
1. Replace 2-column grid with **adaptive grid** (`SliverGridDelegateWithMaxCrossAxisExtent: 180`). On wide phones it goes to 3 columns automatically.
2. Cards get a 4px **rarity rim** (top-left to top-right) and a tonal `surface3 → surface2` gradient from top to bottom. No shadow.
3. Empty state replaces the lonely `Icons.pets` with the **paw silhouette from the new logo** at 96px in `forest500`. Same warmth as the brand.

### 5.3 Profile (`profile_screen.dart`, 1268 lines — also a tech-debt target)
1. Hero header: full-bleed `Fraunces displayMedium` username over a `forest500 → amber500` 30° gradient at 8% opacity on `surface1`. Avatar overlapping the gradient.
2. Stat cards in a horizontal scroller (kennel count / streak / level / XP) — each `surface3` rounded `lg`, `Fraunces displaySmall` numeral + `labelMedium` label.
3. Achievement strip uses badge clusters (3 visible + "+N more" pill) instead of the current full grid that pushes everything else down.

### 5.4 Map / Lost-Dog Hub (`map_tab.dart`, `lost_dog_map_screen.dart`)
1. Custom OSM tile overlay with a **dark theme** — current default OSM tiles are bright and clash with `surface1`. Use [Stadia Alidade Smooth Dark](https://stadiamaps.com/stamen/) or self-host CartoDB Dark Matter.
2. Lost-dog pins use a custom `amber500` paw-pin marker (vector, not Material default red).
3. Bottom sheet with help-find / missing-dogs tabs uses **glass overlay** (`backdropFilter` blur 16) — this is the primary glassmorphism use site in the app.

### 5.5 Quiz (`quiz_screen.dart`)
1. Question card is `surface3`, `radius xl`, with a **progress ring** in `forest500` instead of the current linear bar — feels less like a slog.
2. Answer options use **shape-morph M3 chips**: tap → chip expands into a card with the breed image revealed.
3. Streak indicator at top in `amber500` with a flame icon — wins consistency with the streak break dialog.

### 5.6 Pack (`pack_screen.dart`, 1253 lines)
1. Member cards horizontal scroller, each card `surface3` with avatar + name + role pill.
2. Activity feed below uses **dividerless list** with `surface3` row backgrounds and `lg` vertical padding. Drops the boxy card look.
3. CTA "Add member" floats as an `amber500` extended FAB at the bottom — discoverable.

### 5.7 Microinteractions to add (cross-cutting)
- **Capture button press**: scale 0.96 + haptic medium (already wired in `haptic_service.dart`?).
- **Card tap**: 150ms `surface3 → surface4` colour transition.
- **XP gain**: number rolls up + sparkle particles in `amber400` (existing `xp_gain_animation.dart` — re-skin to use tokens).
- **Streak fire**: gentle pulse 1s loop on the streak chip when ≥3 days.
- **Empty states**: slide-up 200ms + fade.

---

## 6. Roll-out sequence (respects T1-then-T2 tier discipline)

| Phase | Effort | When | What ships |
|---|---|---|---|
| **0. Spec (this doc)** | ✓ done | now | This document. Jesse picks logo direction. |
| **1. Tokens infra** | ~6 hr | post-T1 close | `lib/theme/tokens.dart` + `dogquest_theme.dart` + 3 primitive widgets (`DqCard`, `DqChip`, `DqBadge`). Migration rules documented. Existing constants in `constants.dart` aliased to new tokens for back-compat. No screen behaviour changes. |
| **2. Logo refresh** | ~4 hr design + ~2 hr integration | parallel to phase 1 | New SVG sources, `flutter_launcher_icons` regen, splash colour fix, theme `Colors.amber` → `amber500` swap. |
| **3a. Identify + Kennel migration** | ~8 hr | sprint after phase 1 | Migrate `identify_screen`, `dog_found_dialog`, `kennel_screen`, `dog_detail_sheet` to tokens. Combines well with the T2 dialog redesign spec. |
| **3b. Profile + Pack** | ~6 hr | next sprint | Hits two of the largest god-class files; pair with the existing T5 god-class extraction queue. |
| **3c. Map + Lost-Dog Hub** | ~8 hr | next sprint | Dark tile provider switch + glass bottom sheet + custom paw pin. |
| **3d. Quiz + remaining screens** | ~6 hr | trailing | Cleanup pass; gates on quiz redesign spec. |
| **4. Polish** | ~4 hr | ongoing | Microinteractions, motion tokens, empty-state pattern. |

**Total:** ~44 hr design+implementation. Spread across ~3 sprints alongside other T2/T3 work. None of this blocks closed beta — closed beta ships with the current visual system; the refresh lands in beta cycle 2.

### Verification protocol per cowork-Windows split (per Memory.md workflow)
- Token + theme work: I edit files → Jesse runs `dart format . && dart analyze && flutter test` → Jesse commits per phase with `(VIS-N)` tags.
- Logo work: SVGs done in Cowork → Jesse runs `flutter_launcher_icons` locally to regen platform assets → screenshots back for review.
- Per-screen migrations: one screen per commit, named `(VIS-3a-identify)` etc. — friction worth it for surgical revert.

---

## 7. Open questions for Jesse

1. **Logo direction** — A (North Star Paw, recommended), B (Trail Tracker), or C (Constellation Paw)? See `visual_design_refresh_logos.svg`.
2. **Typeface licensing** — OK to add `google_fonts: ^6.2.1` to pubspec? It's MIT, Inter and Fraunces are both free under SIL OFL. Adds ~150KB to app size after tree-shaking.
3. **Migration cadence** — strict per-screen commits (8+ commits) or batch by area (3 commits)? Memory.md says "per-finding-ID commits" by default.
4. **Dark-only or eventual light mode?** Plan above is dark-only. Adding light mode adds ~20% to phase 1 effort; defer until post-beta unless requested.
5. **OSM tile provider** — Stadia (free up to 200k tiles/mo, attribution required) or self-host CartoDB? Stadia is the fast path; self-host is the no-vendor-risk path.

---

## 8. Confidence tags

- Audit findings (§1): **solid** — read directly from source files cited.
- Trend research (§2): **drift** — trend cycles are 18-month windows; what's hot in April 2026 may be tired by April 2027. Recommendations skew conservative on purpose.
- Token system (§3): **solid** on math (8pt grid, type scale ratios, contrast ratios all verified). **uncertain** on whether Inter+Fraunces is the right pair vs. e.g. Inter+Space Grotesk — pick is reversible.
- Logo critique (§4): **solid** on the issues, **uncertain** on which direction Jesse will prefer.
- Roll-out estimates (§6): **drift** — Flutter migration estimates are notoriously optimistic. Add 30% buffer.

---

## 9. Related notes

- `docs/session_2026-04-26/dog_found_dialog_redesign_spec.md` — coordinates with §5.1.
- `docs/session_2026-04-26/quiz_redesign_spec.md` — coordinates with §5.5.
- `docs/session_2026-04-26/lost_dog_improvements_spec.md` — coordinates with §5.4.
- `lib/constants.dart` — current colour tokens to be aliased.
- `assets/app_icon.png`, `assets/splash_logo.png` — current logo assets.
- `.second_brain/01_Memory/Memory.md` — workflow constraints (Cowork edits + Windows verification).
