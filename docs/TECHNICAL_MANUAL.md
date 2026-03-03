# AviQuest Technical Manual

**A Comprehensive Architecture & Implementation Guide**

Version 1.0 | March 2026

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Architecture Overview](#2-architecture-overview)
3. [Technology Stack](#3-technology-stack)
4. [Project Structure](#4-project-structure)
5. [Application Lifecycle](#5-application-lifecycle)
6. [Data Model & Bird Database](#6-data-model--bird-database)
7. [Core Components Deep Dive](#7-core-components-deep-dive)
8. [State Management](#8-state-management)
9. [Persistence Layer](#9-persistence-layer)
10. [Navigation Architecture](#10-navigation-architecture)
11. [Game Mechanics & Progression System](#11-game-mechanics--progression-system)
12. [Camera & Hardware Integration](#12-camera--hardware-integration)
13. [Audio System](#13-audio-system)
14. [UI/UX Design System](#14-uiux-design-system)
15. [Image Loading & Caching](#15-image-loading--caching)
16. [Android Platform Configuration](#16-android-platform-configuration)
17. [Error Handling & Resilience](#17-error-handling--resilience)
18. [Known Issues & Bug Fix History](#18-known-issues--bug-fix-history)
19. [Performance Characteristics](#19-performance-characteristics)
20. [Security Considerations](#20-security-considerations)
21. [Future Roadmap](#21-future-roadmap)
22. [Developer Onboarding Guide](#22-developer-onboarding-guide)
23. [Appendix A: Complete Bird Rarity Distribution](#appendix-a-complete-bird-rarity-distribution)
24. [Appendix B: Achievement Catalogue](#appendix-b-achievement-catalogue)
25. [Appendix C: Level Progression Table](#appendix-c-level-progression-table)
26. [Appendix D: Glossary](#appendix-d-glossary)

---

## 1. Executive Summary

**AviQuest** is a cross-platform mobile application built with Flutter that gamifies birdwatching. Players identify birds through their device's camera or microphone, collect species in a virtual aviary, earn experience points, level up through a tiered progression system, and unlock achievements. The app features a curated database of 393 bird species spanning four rarity tiers, with images sourced from Wikimedia Commons and audio calls from Xeno-Canto.

### Key Characteristics

| Attribute | Detail |
|-----------|--------|
| **Framework** | Flutter (Dart 3.x) |
| **Platform** | Android (primary), cross-platform capable |
| **Architecture** | Single-file monolith (~5,400 lines) |
| **Storage** | Local-only via Hive (no backend) |
| **Authentication** | None (single-player, offline) |
| **Database** | 393 bird species, 4 rarity tiers |
| **Identification** | Simulated (weighted random selection) |

### Reading Paths

- **New Developers**: Start with sections 2-5 for the big picture, then 7 for component details.
- **Architects**: Focus on sections 2, 8-10, and 19 for design patterns and trade-offs.
- **Game Designers**: Sections 6, 11, and Appendices A-C cover the full progression system.
- **Operations/DevOps**: Sections 16 and 22 cover platform configuration and build setup.

---

## 2. Architecture Overview

### System Boundary Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         AviQuest App                            │
│                                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │  Camera   │  │  Audio   │  │   Hive   │  │  Network     │   │
│  │  Plugin   │  │  Player  │  │  Storage │  │  (Images)    │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └──────┬───────┘   │
│       │              │             │                │           │
│  ┌────┴──────────────┴─────────────┴────────────────┴───────┐  │
│  │                    HomeScreen Widget                      │  │
│  │                  (_HomeScreenState)                       │  │
│  │                                                          │  │
│  │  ┌──────┐ ┌────────┐ ┌────────┐ ┌───────┐ ┌─────────┐  │  │
│  │  │ Map  │ │Identify│ │Aviary  │ │ Field │ │ Profile │  │  │
│  │  │ Tab  │ │  Tab   │ │  Tab   │ │ Guide │ │   Tab   │  │  │
│  │  └──────┘ └────────┘ └────────┘ └───────┘ └─────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                  Bird Database (In-Memory)                │  │
│  │              393 species × 9 fields each                  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                  Game Logic Layer                         │  │
│  │  XP System │ Leveling │ Achievements │ Weighted Random   │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
   ┌──────────┐       ┌──────────────┐     ┌─────────────┐
   │  Device  │       │  Wikimedia   │     │ Xeno-Canto  │
   │  Camera  │       │  Commons     │     │   (Audio)   │
   └──────────┘       └──────────────┘     └─────────────┘
```

### Architectural Decision: Monolithic Single-File

The entire application resides in a single Dart file (`aviquest/lib/main.dart`:1-5397). This decision has clear trade-offs:

**Advantages:**
- Zero import management overhead
- Simple mental model for the full codebase
- Easy to search and navigate with standard text tools
- No circular dependency concerns

**Disadvantages:**
- Challenging to work on collaboratively (merge conflicts)
- No separation of concerns at the file level
- All 393 bird definitions are inline (>4,300 lines of data)
- Cannot selectively rebuild individual modules

> **Note:** For a production application at scale, the recommended approach would be to extract the bird database into a separate data file (JSON or SQLite), separate UI components into individual widget files, and introduce a state management solution like Provider or Riverpod. See [Section 21: Future Roadmap](#21-future-roadmap) for migration guidance.

---

## 3. Technology Stack

### Core Dependencies

| Package | Version | Purpose | Source Reference |
|---------|---------|---------|-----------------|
| `flutter` | SDK | Core UI framework | `aviquest/pubspec.yaml`:10-11 |
| `flutter_animate` | ^4.5.0 | Declarative animations | `aviquest/pubspec.yaml`:12 |
| `just_audio` | ^0.9.36 | Bird call playback | `aviquest/pubspec.yaml`:13 |
| `camera` | ^0.10.5 | Device camera access | `aviquest/pubspec.yaml`:14 |
| `permission_handler` | ^11.3.0 | Android runtime permissions | `aviquest/pubspec.yaml`:15 |
| `cached_network_image` | ^3.3.1 | Efficient image loading & caching | `aviquest/pubspec.yaml`:16 |
| `hive_flutter` | ^1.1.0 | Local key-value persistence | `aviquest/pubspec.yaml`:17 |
| `shimmer` | ^3.0.0 | Loading placeholder animations | `aviquest/pubspec.yaml`:18 |

### Dev Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_test` | SDK | Unit/widget testing framework |
| `flutter_lints` | ^3.0.0 | Static analysis rules |

### Dart SDK Constraint

```yaml
sdk: '>=3.0.0 <4.0.0'
```

This requires Dart 3.x, enabling records, patterns, and sealed classes (though the app primarily uses records for the achievements tuple structure).

### Android Build Toolchain

| Tool | Version |
|------|---------|
| Gradle | 8.1.0 |
| Kotlin | 1.8.22 |
| AndroidX | Enabled |
| Jetifier | Enabled |

---

## 4. Project Structure

```
AviQuest-/
├── README.md                                    # Project README (placeholder)
├── docs/
│   └── TECHNICAL_MANUAL.md                      # This document
└── aviquest/                                    # Flutter project root
    ├── .gitignore                               # Dart/Flutter ignore rules
    ├── pubspec.yaml                             # Dependency manifest
    ├── lib/
    │   └── main.dart                            # Entire application (5,397 lines)
    └── android/
        ├── build.gradle                         # Root Gradle config
        ├── gradle.properties                    # JVM settings (-Xmx4G)
        ├── settings.gradle                      # Plugin management
        └── app/
            ├── build.gradle                     # App-level build config
            └── src/main/
                ├── AndroidManifest.xml           # Permissions & activity config
                ├── kotlin/com/example/aviquest/
                │   └── MainActivity.kt           # Flutter activity wrapper
                └── res/values/
                    └── styles.xml                # Android launch themes
```

### File-Level Anatomy of `main.dart`

| Line Range | Section | Description |
|------------|---------|-------------|
| 1-11 | **Imports** | Dart and package imports |
| 13-24 | **Constants** | Color palette and rarity color map |
| 26-62 | **Bird Class** | Data model with XP calculation |
| 64-4415 | **Bird Database** | 393 species definitions |
| 4417-4475 | **Helpers** | Level titles, XP formula, weighted random, achievements |
| 4479-4521 | **App Entry** | `main()`, `AviQuest` root widget, theme definition |
| 4526-5397 | **HomeScreen** | All UI tabs, state, and game logic |

---

## 5. Application Lifecycle

### Startup Sequence

```
main() ──► WidgetsFlutterBinding.ensureInitialized()
       ──► Hive.initFlutter()
       ──► SystemChrome.setPreferredOrientations([portraitUp])
       ──► runApp(AviQuest())
              │
              ▼
         AviQuest (StatelessWidget)
              │
              ▼
         MaterialApp(home: HomeScreen())
              │
              ▼
         _HomeScreenState.initState()
              ├── _initHive()  ──► Opens 'aviary_v2' box
              └── _initCamera() ──► Initializes back camera
```

**Reference:** `aviquest/lib/main.dart`:4479-4589

### Initialization Details

1. **Flutter Binding** (`main.dart`:4480): Required before calling any native plugins. Must be called before `Hive.initFlutter()`.

2. **Hive Initialization** (`main.dart`:4481): Sets up the Hive storage engine. The Flutter variant (`initFlutter`) automatically determines the correct application documents directory.

3. **Orientation Lock** (`main.dart`:4483): Forces portrait-up orientation. This is a deliberate UX decision — birdwatching apps work best in portrait mode where the camera viewfinder is natural to hold.

4. **Hive Box Opening** (`main.dart`:4569-4573): Opens the `aviary_v2` box asynchronously. The `hiveReady` flag prevents UI rendering of the Aviary tab before storage is available.

5. **Camera Initialization** (`main.dart`:4576-4589): Attempts to acquire the first available camera at high resolution. Gracefully degrades if no camera is present or permissions are denied.

### Widget Lifecycle

```
initState() ──► _initHive() + _initCamera()
                     │
                     ▼ (async completion)
              setState(hiveReady = true)
              setState(_camReady = true)
                     │
                     ▼
              build() renders full UI
                     │
                     ▼ (when user leaves)
              dispose() ──► _cam?.dispose()
                        ──► _player.dispose()
```

---

## 6. Data Model & Bird Database

### The Bird Class

**Source:** `aviquest/lib/main.dart`:29-62

```dart
class Bird {
  final String name;              // Common name (e.g., "Snowy Owl")
  final String scientificName;    // Binomial name (e.g., "Bubo scandiacus")
  final String imageUrl;          // Wikimedia Commons image URL
  final String audioUrl;          // Xeno-Canto MP3 URL (may be empty)
  final String lore;              // Fun fact or species description
  final String habitat;           // Natural habitat description
  final String conservationStatus;// IUCN status (e.g., "Least Concern")
  final String rarity;            // Game rarity tier
  final int baseXp;               // Base experience points
}
```

### Computed Properties

**Rarity Color** (`main.dart`:52):
```dart
Color get rarityColor => _rarityColors[rarity] ?? Colors.white70;
```

Maps the string rarity to a visual color. Falls back to `Colors.white70` for unknown rarities.

**XP Calculation** (`main.dart`:54-61):
```dart
int get xp {
  switch (rarity) {
    case 'uncommon': return (baseXp * 1.5).round();
    case 'rare':     return baseXp * 2;
    case 'legendary': return baseXp * 5;
    default:         return baseXp;  // common + unknown
  }
}
```

The `xp` getter applies a multiplier based on rarity tier. This means the displayed XP is always the *effective* XP, not the raw `baseXp` value.

| Rarity | Multiplier | Typical Base XP | Effective XP Range |
|--------|------------|-----------------|-------------------|
| Common | 1.0x | 20-50 | 20-50 |
| Uncommon | 1.5x | 65-115 | 97-172 |
| Rare | 2.0x | 150-295 | 300-590 |
| Legendary | 5.0x | 500-900 | 2,500-4,500 |

### Bird Database Structure

**Source:** `aviquest/lib/main.dart`:64-4415

The database is a top-level `final List<Bird>` containing 393 hand-curated bird entries. Each entry includes:

- **Realistic ornithological data**: Scientific names, habitats, conservation statuses
- **Educational lore**: Interesting facts about each species
- **Media references**: Direct URLs to Wikimedia images and Xeno-Canto audio files
- **Game balance data**: Rarity tier and base XP value

**Sample Entry:**
```dart
Bird(
  name: 'Black-capped Chickadee',
  scientificName: 'Poecile atricapillus',
  imageUrl: 'https://upload.wikimedia.org/.../Black-capped_Chickadee.jpg',
  audioUrl: 'https://xeno-canto.org/.../XC637613-Black-capped%20Chickadee.mp3',
  lore: 'Cheerful winter friend that remembers exactly who feeds it...',
  habitat: 'Deciduous and mixed forests, parks, suburbs',
  conservationStatus: 'Least Concern',
  rarity: 'common',
  baseXp: 50,
),
```

### Rarity Distribution

The 393 birds are distributed across tiers to match the weighted random selection probabilities:

| Rarity | Pool % | Approx. Count | Selection Probability |
|--------|--------|---------------|----------------------|
| Common | ~60% | ~236 | 60% |
| Uncommon | ~25% | ~98 | 25% |
| Rare | ~12% | ~48 | 12% |
| Legendary | ~3% | ~11 | 3% |

### The Unknown Bird Fallback

**Source:** `aviquest/lib/main.dart`:4432-4446

When a stored bird name doesn't match any entry in the `birds` list (e.g., after a database update removes a species), the `unknownBird()` function creates a placeholder:

```dart
Bird unknownBird(String name) => Bird(
  name: name,
  scientificName: 'Species not yet in database',
  imageUrl: '',
  audioUrl: '',
  lore: 'You found something we\'ve never seen before!...',
  habitat: 'Unknown',
  conservationStatus: 'Unknown',
  rarity: 'unknown',
  baseXp: 100, // reward curiosity
);
```

This design choice prevents data corruption — the stored name is preserved in Hive, and when the database is eventually updated, the bird will resolve correctly. The `unknown` rarity displays with a distinctive soft purple color (`#CE93D8`).

---

## 7. Core Components Deep Dive

### 7.1 Root Widget — `AviQuest`

**Source:** `aviquest/lib/main.dart`:4487-4521

The root widget is a stateless `MaterialApp` that defines the application-wide theme. It does not manage any state — all state lives in `HomeScreen`.

**Theme Configuration:**
- Base: `ThemeData.dark()` (Material dark theme)
- Primary color: `Colors.amber`
- Secondary color: `Color(0xFF4CAF50)` (Material green)
- Scaffold background: `_bgDeep` (`#0A1F0F`, deep forest green)
- Surface color: `_bgCard` (`#1A2F1F`, card green)
- Button style: Amber background, black text, 16px rounded corners
- Bottom nav: Fixed type, amber selected, white54 unselected

### 7.2 HomeScreen — The Application Shell

**Source:** `aviquest/lib/main.dart`:4526-5397

`HomeScreen` is the only route in the application. It is a `StatefulWidget` whose state class (`_HomeScreenState`) manages:

- Player progression (level, XP, streak, achievements)
- Hardware controllers (camera, audio player)
- UI state (current tab, search filters)
- Persistent storage (Hive box reference)

### 7.3 Identify Tab

**Source:** `aviquest/lib/main.dart`:4928-4992

The primary gameplay screen. Displays:
1. A live camera preview (or graceful fallback placeholder)
2. "Identify by Photo" button — triggers `_takePhoto()`
3. "By Call" button — triggers `_simulateIdentify()` directly

**Identification Flow:**

```
User taps "Identify" ──► _takePhoto()
                              │
                              ▼
                    Permission.camera.request()
                              │
                              ▼
                    _cam.takePicture() ──► File object
                              │
                              ▼
                    _simulateIdentify(file)
                              │
                              ▼
                    _weightedRandomBird(rng)
                              │
                              ▼
                    Show "Analysing..." dialog (1.8s delay)
                              │
                              ▼
                    _showFoundDialog(bird)
                              │
                         ┌────┴────┐
                         ▼         ▼
                      "Skip"   "Add to Aviary"
                                   │
                                   ▼
                              _addBird(bird)
```

> **Important Design Note:** Bird identification is currently simulated via weighted random selection (`main.dart`:4448-4463). The camera captures a real photo, but the identification result is algorithmically determined, not based on image analysis. This is a placeholder for a future ML-based bird recognition system.

### 7.4 Aviary Tab

**Source:** `aviquest/lib/main.dart`:4994-5085

Displays the player's collected birds in a 2-column grid. Key implementation details:

- **Reactive updates** via `ValueListenableBuilder<Box<String>>` — the grid automatically rebuilds when new birds are added to Hive storage
- **Empty state** shows a friendly message with a "Go Identify" CTA button
- **Bird resolution**: Each stored name is looked up in the `birds` list. If not found, `unknownBird()` provides a fallback
- **Grid layout**: `SliverGridDelegateWithFixedCrossAxisCount` with 0.82 aspect ratio
- **Card design**: Each card shows the bird image full-bleed with a gradient overlay at the bottom containing the name and rarity badge

### 7.5 Field Guide Tab

**Source:** `aviquest/lib/main.dart`:5087-5208

A searchable, filterable reference for all 393 bird species. Features:

- **Search bar**: Filters by common name or scientific name (case-insensitive)
- **Rarity filter chips**: Horizontal scroll of filter options (All, Common, Uncommon, Rare, Legendary)
- **List view**: Each entry shows thumbnail, name, scientific name, rarity badge, and XP value
- **Tap interaction**: Opens `_showBirdDetail()` modal bottom sheet

**Filtering Logic** (`main.dart`:5088-5094):
```dart
final filtered = birds.where((b) {
  final matchRarity = _guideRarityFilter == 'all' || b.rarity == _guideRarityFilter;
  final matchSearch = _guideSearch.isEmpty ||
      b.name.toLowerCase().contains(_guideSearch.toLowerCase()) ||
      b.scientificName.toLowerCase().contains(_guideSearch.toLowerCase());
  return matchRarity && matchSearch;
}).toList();
```

### 7.6 Profile Tab

**Source:** `aviquest/lib/main.dart`:5240-5349

Displays the player's progression stats:

- **Avatar ring** with amber-to-green gradient and eagle emoji
- **Level title** (e.g., "Fledgling", "Warbler") with numeric level
- **XP progress bar** — linear indicator showing progress to next level
- **Stats row** — three cards showing day streak, species count, and badge count
- **Achievements grid** — 3x3 wrap of achievement badges (locked/unlocked)
- **Eco Impact card** — motivational message about contributing to bird science

### 7.7 Map Tab

**Source:** `aviquest/lib/main.dart`:5210-5238

A placeholder tab for future interactive mapping functionality. Currently displays:
- A map icon with "Interactive Map" heading
- "Coming soon" subtitle mentioning hotspot mapping and community sightings
- A mock stat card showing "1,247 sightings logged today"

### 7.8 Bird Detail Sheet

**Source:** `aviquest/lib/main.dart`:4805-4891

A draggable modal bottom sheet that shows comprehensive information about a single bird. Triggered from both the Aviary and Field Guide tabs.

**Layout:**
1. Drag handle indicator
2. Rarity badge (color-coded)
3. Bird name (amber, 26px bold)
4. Scientific name (italic, white54)
5. Image (or unknown placeholder)
6. Detail rows: Lore, Habitat, Conservation, XP Value
7. "Play Bird Call" button (only if `audioUrl` is non-empty)

The sheet uses `DraggableScrollableSheet` with:
- Initial size: 70% of screen height
- Max size: 95% of screen height
- Scrollable content

### 7.9 Found Dialog

**Source:** `aviquest/lib/main.dart`:4626-4725

Shown immediately after bird identification. Presents:
- Rarity badge with animated fade-in and scale
- Bird name with sparkle emoji (or telescope for unknown)
- Bird image (or "Not in our database" placeholder for unknown birds)
- Lore text
- XP reward amount
- Two action buttons: "Skip" and "Add to Aviary"

---

## 8. State Management

### Architecture: Local StatefulWidget

AviQuest uses Flutter's built-in `setState()` for all state management. There is no external state management library (no Provider, Bloc, Riverpod, or GetX).

### State Variables

**Source:** `aviquest/lib/main.dart`:4533-4552

| Variable | Type | Scope | Persisted? | Description |
|----------|------|-------|-----------|-------------|
| `level` | `int` | Session | No | Player's current level |
| `xp` | `int` | Session | No | Current XP within level |
| `streak` | `int` | Session | No | Day streak counter |
| `unlockedAchievements` | `Set<String>` | Session | No | Set of achievement keys |
| `aviaryBox` | `Box<String>` | Persistent | Yes (Hive) | Collected bird names |
| `hiveReady` | `bool` | Session | No | Hive initialization flag |
| `_player` | `AudioPlayer` | Session | No | Audio player instance |
| `_rng` | `Random` | Session | No | Random number generator |
| `_cam` | `CameraController?` | Session | No | Camera controller |
| `_camReady` | `bool` | Session | No | Camera initialization flag |
| `_tab` | `int` | Session | No | Current bottom nav index |
| `_guideSearch` | `String` | Session | No | Field Guide search query |
| `_guideRarityFilter` | `String` | Session | No | Field Guide rarity filter |

> **Critical Observation:** Player level, XP, streak, and achievements are **not persisted**. They reset to defaults on every app launch. Only the bird collection (aviary) survives across sessions via Hive. This is likely an oversight — see [Section 21](#21-future-roadmap) for recommended fixes.

### State Flow: Adding a Bird

```
_addBird(bird) ──► setState() {
                     aviaryBox.add(bird.name)     // Persists to Hive
                     xp += bird.xp                // In-memory only
                     while (xp >= xpForNextLevel) // Level-up loop
                       level++
                       _showLevelUp()
                     _checkAchievements(bird)     // Unlock check
                   }
```

---

## 9. Persistence Layer

### Hive Configuration

**Engine:** Hive (via `hive_flutter` ^1.1.0)

Hive is a lightweight, key-value database written in pure Dart. It provides:
- No native dependencies
- AES-256 encryption support (not currently used)
- Lazy-loading boxes
- `ValueListenable` support for reactive UI updates

### Storage Schema

| Box Name | Type | Content | Opened At |
|----------|------|---------|-----------|
| `aviary_v2` | `Box<String>` | Bird name strings | `main.dart`:4570 |

**Why `Box<String>` instead of `Box<Bird>`?**

The original implementation used `Box<Bird>`, which required registering a Hive `TypeAdapter`. This approach crashed because the adapter wasn't properly registered. The fix (FIX 3) simplified storage to plain strings — bird names are stored as strings and resolved back to `Bird` objects at read time by searching the in-memory `birds` list.

**Trade-offs of this approach:**
- (+) No TypeAdapter required, no serialization bugs
- (+) Storage is human-readable
- (-) Requires O(n) lookup per bird on read
- (-) If a bird is renamed in the database, the stored name becomes orphaned (handled by `unknownBird()`)

### Data Flow

```
Write Path:
_addBird(bird) ──► aviaryBox.add(bird.name) ──► Hive persists to disk

Read Path:
aviaryBox.getAt(i) ──► "Black-capped Chickadee" (String)
       │
       ▼
birds.firstWhere(
  (b) => b.name == birdName,
  orElse: () => unknownBird(birdName)
)
       │
       ▼
Full Bird object with all fields
```

### Reactive Updates

The Aviary tab uses `ValueListenableBuilder` to react to box changes:

```dart
ValueListenableBuilder<Box<String>>(
  valueListenable: aviaryBox.listenable(),
  builder: (context, box, _) { ... },
)
```

This means the aviary grid rebuilds automatically whenever a bird is added — no manual notification required.

---

## 10. Navigation Architecture

### Single-Screen, Tab-Based Navigation

AviQuest uses a single `Scaffold` with a `BottomNavigationBar` and `IndexedStack` for tab management. There are no named routes, no `Navigator.push` for screen transitions, and no deep linking.

**Source:** `aviquest/lib/main.dart`:5367-5396

### Tab Configuration

| Index | Label | Icon | Builder Method | Default? |
|-------|-------|------|---------------|----------|
| 0 | Map | `Icons.map` | `_buildMapTab()` | No |
| 1 | Identify | `Icons.camera_alt` | `_buildIdentifyTab()` | **Yes** |
| 2 | Aviary | `Icons.collections` | `_buildAviaryTab()` | No |
| 3 | Field Guide | `Icons.menu_book` | `_buildFieldGuideTab()` | No |
| 4 | Me | `Icons.person` | `_buildProfileTab()` | No |

### IndexedStack Behavior

```dart
IndexedStack(index: _tab, children: tabs)
```

`IndexedStack` keeps all five tabs alive simultaneously but only displays the one at `_tab`. This means:
- Tab state is preserved when switching (e.g., scroll position, search text)
- All tabs are built on first render (including camera preview)
- Memory usage is higher than lazy tab building

### Modal Navigation

Beyond tabs, the app uses two types of modal overlays:

1. **AlertDialog** (`showDialog`): Used for the "Analysing..." spinner and the "Bird Found" result
2. **ModalBottomSheet** (`showModalBottomSheet`): Used for bird detail views with `DraggableScrollableSheet`

### Tab Selection Feedback

```dart
onTap: (i) {
  HapticFeedback.selectionClick();
  setState(() => _tab = i);
},
```

Tab changes trigger haptic feedback via `HapticFeedback.selectionClick()` for a tactile interaction feel.

---

## 11. Game Mechanics & Progression System

### 11.1 Experience Points (XP)

**Earning XP:**
Every identified bird awards XP equal to its computed `bird.xp` value (base XP × rarity multiplier). XP is added immediately upon tapping "Add to Aviary".

**XP per Rarity Tier:**

| Rarity | Base Range | Multiplier | Effective Range |
|--------|-----------|------------|-----------------|
| Common | 20-50 | 1.0x | 20-50 |
| Uncommon | 65-115 | 1.5x | 97-172 |
| Rare | 150-295 | 2.0x | 300-590 |
| Legendary | 500-900 | 5.0x | 2,500-4,500 |
| Unknown | 100 (fixed) | 1.0x | 100 |

### 11.2 Leveling System

**XP Threshold Formula:**

**Source:** `aviquest/lib/main.dart`:4430

```dart
int xpForNextLevel(int level) => (1000 * pow(level, 1.4)).round();
```

This produces an exponential curve where each level requires progressively more XP:

| Level | XP Required | Cumulative XP |
|-------|------------|---------------|
| 1 | 1,000 | 1,000 |
| 2 | 2,639 | 3,639 |
| 3 | 4,656 | 8,295 |
| 5 | 9,518 | 25,543 |
| 10 | 25,119 | 108,574 |
| 15 | 44,306 | 267,028 |
| 20 | 66,287 | 513,040 |
| 30 | 117,072 | 1,236,753 |
| 40 | 175,075 | 2,360,502 |

**Level-Up Mechanic** (`main.dart`:4739-4743):
```dart
while (xp >= xpForNextLevel(level)) {
  xp -= xpForNextLevel(level);
  level++;
  _showLevelUp();
}
```

The `while` loop handles multi-level jumps (e.g., a legendary bird granting enough XP to skip multiple levels at once).

### 11.3 Level Titles

**Source:** `aviquest/lib/main.dart`:4419-4428

| Level Range | Title |
|-------------|-------|
| 1-2 | Fledgling |
| 3-5 | Nestling |
| 6-9 | Sparrow |
| 10-14 | Warbler |
| 15-19 | Songweaver |
| 20-29 | Falconer |
| 30-39 | Eagle Scout |
| 40+ | Master Birder |

### 11.4 Weighted Random Bird Selection

**Source:** `aviquest/lib/main.dart`:4448-4463

```dart
Bird _weightedRandomBird(Random rng) {
  final r = rng.nextDouble();  // 0.0 to 1.0
  late String rarity;
  if (r < 0.60)      rarity = 'common';
  else if (r < 0.85) rarity = 'uncommon';
  else if (r < 0.97) rarity = 'rare';
  else                rarity = 'legendary';

  final pool = birds.where((b) => b.rarity == rarity).toList();
  return pool[rng.nextInt(pool.length)];
}
```

**Selection Process:**
1. Generate a random double [0.0, 1.0)
2. Map to rarity tier based on thresholds
3. Filter the full bird list to that rarity
4. Select uniformly at random within the tier

This means all common birds have equal probability within the common pool, all uncommon birds within the uncommon pool, etc.

**Per-Bird Probability:**

| Rarity | Tier Probability | Pool Size | Per-Bird Probability |
|--------|-----------------|-----------|---------------------|
| Common | 60% | ~236 | ~0.25% |
| Uncommon | 25% | ~98 | ~0.26% |
| Rare | 12% | ~48 | ~0.25% |
| Legendary | 3% | ~11 | ~0.27% |

### 11.5 Achievement System

**Source:** `aviquest/lib/main.dart`:4465-4475

Nine achievements are defined as a constant map of `(emoji, title, description)` records:

| Key | Emoji | Title | Requirement |
|-----|-------|-------|-------------|
| `first_bird` | `🐦` | First Feather | Identify 1 bird |
| `five_species` | `🌿` | Nature Curious | Collect 5 species |
| `ten_species` | `🏆` | Avid Birder | Collect 10 species |
| `twenty_species` | `🦅` | Wing Watcher | Collect 20 species |
| `rare_find` | `💎` | Rare Encounter | Identify a rare or legendary bird |
| `legendary_find` | `✨` | Legend Spotter | Identify a legendary bird |
| `level_5` | `⭐` | Rising Birder | Reach level 5 |
| `level_10` | `🌟` | Expert Nester | Reach level 10 |
| `level_20` | `🌠` | Sky Master | Reach level 20 |

**Achievement Check Logic** (`main.dart`:4762-4803):

Achievements are evaluated after every bird addition. The check is idempotent — already-unlocked achievements are skipped. Newly unlocked achievements trigger a delayed SnackBar notification (500ms delay for staggering multiple simultaneous unlocks).

---

## 12. Camera & Hardware Integration

### Camera Initialization

**Source:** `aviquest/lib/main.dart`:4576-4589

```dart
Future<void> _initCamera() async {
  try {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;  // FIX 5
    _cam = CameraController(cameras[0], ResolutionPreset.high);
    await _cam!.initialize();
    if (!mounted) return;  // FIX 7
    setState(() => _camReady = true);
  } catch (_) {
    // Camera unavailable — silently degrade
  }
}
```

**Key Design Decisions:**
- **First camera used**: `cameras[0]` is typically the back-facing camera
- **High resolution**: `ResolutionPreset.high` for detailed bird photos
- **Graceful degradation**: If no camera exists or initialization fails, the app continues with a placeholder UI
- **Empty camera guard** (FIX 5): Prevents index-out-of-bounds on devices without cameras (e.g., emulators)
- **Mounted check** (FIX 7): Prevents `setState` after widget disposal if initialization completes after navigation away

### Photo Capture

**Source:** `aviquest/lib/main.dart`:4591-4598

```dart
Future<void> _takePhoto() async {
  await Permission.camera.request();
  if (_cam == null || !_camReady) return;
  try {
    final file = await _cam!.takePicture();
    if (!mounted) return;
    await _simulateIdentify(File(file.path));
  } catch (_) {}
}
```

Permission is requested each time (the system handles showing the prompt only once). The captured file is passed to `_simulateIdentify`, though the file content is not actually analyzed — the parameter is ignored and a weighted random bird is selected instead.

### Camera Lifecycle

The camera controller is properly disposed in `dispose()` (`main.dart`:4562-4567):

```dart
@override
void dispose() {
  _cam?.dispose();
  _player.dispose();
  super.dispose();
}
```

---

## 13. Audio System

### Audio Player Setup

**Library:** `just_audio` ^0.9.36

A single `AudioPlayer` instance is created in `_HomeScreenState` and reused for all bird call playback:

```dart
final _player = AudioPlayer();
```

### Playback Triggers

Audio is played in two contexts:

1. **When adding a bird to aviary** (`main.dart`:4729-4731):
```dart
if (bird.audioUrl.isNotEmpty) {
  _player.setUrl(bird.audioUrl).then((_) => _player.play()).catchError((_) {});
}
```

2. **In the bird detail sheet** (`main.dart`:4878-4884):
```dart
ElevatedButton.icon(
  onPressed: () {
    _player.setUrl(bird.audioUrl).then((_) => _player.play()).catchError((_) {});
  },
  icon: const Icon(Icons.volume_up),
  label: const Text('Play Bird Call'),
),
```

**Audio Sources:** Bird calls are loaded from Xeno-Canto via direct MP3 URLs. Not all birds have audio — the playback button only appears when `audioUrl.isNotEmpty`.

**Error Handling:** Both playback triggers use `.catchError((_) {})` to silently swallow network or decoding errors. This prevents crashes from broken URLs or network issues, though it provides no user feedback on failure.

---

## 14. UI/UX Design System

### Color Palette

**Source:** `aviquest/lib/main.dart`:15-24

| Constant | Hex | Usage |
|----------|-----|-------|
| `_bgDeep` | `#0A1F0F` | Scaffold background, deepest green |
| `_bgCard` | `#1A2F1F` | Card backgrounds, input fields |
| `_bgNav` | `#0F2A1F` | Bottom navigation bar |

### Rarity Colors

| Rarity | Color | Hex/Value |
|--------|-------|-----------|
| Common | White70 | `rgba(255,255,255,0.7)` |
| Uncommon | Green | `#4CAF50` |
| Rare | Blue | `#2196F3` |
| Legendary | Amber | Material amber |
| Unknown | Purple | `#CE93D8` |

### Design Language

The app follows a cohesive **dark forest theme**:

- **Dark backgrounds** with subtle green tinting evoke a nighttime forest atmosphere
- **Amber accents** (primary color) draw attention to interactive elements and rewards
- **Green secondary** reinforces the nature/birding theme
- **Rarity colors** create visual hierarchy in bird displays
- **16px border radius** used consistently on cards, buttons, and containers
- **Shimmer loading** provides visual feedback during image loads

### Animation Strategy

All animations use the `flutter_animate` library with a consistent pattern:

```dart
.animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.95, 0.95))
```

**Common patterns:**
- `fadeIn()` — Smooth opacity transition on appearance
- `slideY(begin: -0.3)` — Subtle vertical entrance
- `scale()` — Pop-in effect for discovery moments
- Staggered delays (`100.ms`, `200.ms`, `300.ms`) — Sequential reveal of UI elements

### Typography

Uses the default Material dark theme typography with key overrides:
- Bird names: Bold, 13-26px depending on context
- Scientific names: Italic, `Colors.white54`
- Section headers: 20-32px, bold, amber
- Body text: Default, `Colors.white70`
- Secondary text: `Colors.white54` or `Colors.white38`

---

## 15. Image Loading & Caching

### Implementation

**Source:** `aviquest/lib/main.dart`:4907-4924

```dart
Widget _buildNetworkImage(String url, double height) {
  return CachedNetworkImage(
    imageUrl: url,
    height: height,
    width: double.infinity,
    fit: BoxFit.cover,
    placeholder: (_, __) => Shimmer.fromColors(
      baseColor: _bgCard,
      highlightColor: const Color(0xFF2A3F2F),
      child: Container(height: height, color: _bgCard),
    ),
    errorWidget: (_, __, ___) => Container(
      height: height,
      color: _bgCard,
      child: const Center(
        child: Icon(Icons.broken_image, color: Colors.white24, size: 48)),
    ),
  );
}
```

### Loading States

1. **Loading**: Shimmer animation with green-tinted pulsing
2. **Success**: Image displayed with `BoxFit.cover` (fills container, may crop)
3. **Error**: Dark container with broken image icon

### Caching Strategy

The `cached_network_image` package provides:
- Automatic disk caching of downloaded images
- In-memory cache for recently viewed images
- Cache invalidation based on URL
- Stale-while-revalidate pattern

Since the bird database uses Wikimedia Commons URLs (which are stable and CDN-backed), cache hit rates should be very high after initial viewing.

---

## 16. Android Platform Configuration

### AndroidManifest.xml

**Source:** `aviquest/android/app/src/main/AndroidManifest.xml`

**Permissions:**
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-feature android:name="android.hardware.camera" android:required="false"/>
```

- `INTERNET`: Required for loading bird images and audio from external servers
- `CAMERA`: Required for the photo identification feature
- `RECORD_AUDIO`: Required for the audio identification feature
- Camera hardware feature is marked `required="false"` — the app can be installed on devices without cameras

**Activity Configuration:**
- Launch mode: `singleTop` (prevents duplicate instances)
- Hardware acceleration: `true`
- Orientation handling: Managed by Flutter, not Android

### Build Configuration

**Application ID:** `com.example.aviquest`

> **Note:** The `com.example` namespace should be changed before publishing to a production app store.

**Gradle JVM Settings** (`gradle.properties`):
```properties
org.gradle.jvmargs=-Xmx4G
```

The 4GB heap size is generous and prevents out-of-memory errors during builds with large resource files.

---

## 17. Error Handling & Resilience

### Defensive Patterns Used

1. **Mounted checks after async operations** (`main.dart`:4572, 4584, 4596, 4621):
```dart
if (!mounted) return;
```
Prevents `setState` calls after widget disposal, which would throw a framework exception.

2. **Camera graceful degradation** (`main.dart`:4576-4589):
Empty camera list guard and try-catch around initialization.

3. **Null-safe box reads** (`main.dart`:5029):
```dart
final birdName = box.getAt(i);
if (birdName == null) return const SizedBox.shrink();
```

4. **Unknown bird fallback** (`main.dart`:5030-5033):
```dart
final bird = birds.firstWhere(
  (b) => b.name == birdName,
  orElse: () => unknownBird(birdName),
);
```

5. **Audio error swallowing** (`main.dart`:4730):
```dart
.catchError((_) {})
```

6. **Image error widgets** (`main.dart`:4918-4922):
Broken image icon shown instead of crash.

### Areas Without Error Handling

- Network connectivity: No offline detection or retry logic
- Hive box corruption: No recovery mechanism
- XP overflow: No upper bound on level or XP values (though overflow is practically impossible)

---

## 18. Known Issues & Bug Fix History

The codebase contains inline `// FIX` comments documenting bugs that were discovered and fixed:

| FIX # | Line | Description | Root Cause |
|-------|------|-------------|------------|
| FIX 1 | 1 | Added `dart:io` import | `File` class usage without import |
| FIX 2 | 28-33 | Added `audioUrl` field to `Bird` class | Field was missing, causing crashes when accessed |
| FIX 3 | 4482, 4540, 4570 | Changed `Box<Bird>` to `Box<String>` | Hive TypeAdapter for `Bird` wasn't registered, causing serialization crashes |
| FIX 4 | 4999-5000 | Corrected `ValueListenableBuilder` type parameter | Generic type mismatch after Box type change |
| FIX 5 | 4580, 5029 | Added empty camera list guard and null box read guard | Index out of bounds on emulators/devices without camera |
| FIX 6 | 4562-4567 | Added `dispose()` for camera and audio player | Resource leaks (camera stays active, audio keeps playing) |
| FIX 7 | 4572, 4584 | Added `mounted` checks after `await` | `setState` called on disposed widget |

---

## 19. Performance Characteristics

### Memory Profile

| Component | Estimated Memory |
|-----------|-----------------|
| Bird list (393 objects) | ~200 KB (strings + references) |
| Hive box (names only) | ~10-50 KB |
| Camera preview | ~10-30 MB (live frame buffer) |
| Cached images | Varies (disk-backed) |
| Audio player | ~1-5 MB per loaded track |
| Widget tree (5 tabs) | ~5-10 MB |

### Potential Bottlenecks

1. **Bird list filtering** (`_buildFieldGuideTab`): Iterates all 393 birds on every keystroke in the search field. For the current dataset this is negligible, but could become an issue with thousands of birds.

2. **IndexedStack**: All five tabs are built simultaneously on first render, even if the user never visits some tabs. The camera preview is particularly expensive.

3. **Image loading**: First launch loads images from Wikimedia Commons over the network. Subsequent launches benefit from the `cached_network_image` disk cache.

4. **Aviary grid**: Uses `ValueListenableBuilder` which rebuilds the entire grid on any box change. For large collections (100+ birds), this could cause frame drops during the rebuild.

### Optimization Opportunities

- Replace `IndexedStack` with lazy tab loading
- Paginate the aviary grid for large collections
- Debounce the Field Guide search input
- Precompute rarity-filtered bird lists (avoid `where().toList()` on each call)
- Extract the bird database to a JSON file loaded at startup

---

## 20. Security Considerations

### Current Security Posture

AviQuest has a minimal attack surface due to its offline, single-player nature:

| Concern | Status | Notes |
|---------|--------|-------|
| Authentication | N/A | No user accounts |
| Data encryption | Not used | Hive supports AES-256, not enabled |
| Network security | HTTPS only | Wikimedia and Xeno-Canto serve over HTTPS |
| Input validation | Minimal | No user-generated text sent anywhere |
| Secrets management | N/A | No API keys or secrets |
| Code obfuscation | Not configured | Default Flutter build |

### Recommendations for Future Security

If user accounts or cloud sync are added:
- Enable Hive encryption for stored user data
- Use secure storage (e.g., `flutter_secure_storage`) for tokens
- Implement certificate pinning for API calls
- Add input validation on any user-submitted text
- Review the `com.example` namespace for production

---

## 21. Future Roadmap

Based on the current codebase analysis, the following enhancements are recommended:

### High Priority

1. **Persist player progress**: Level, XP, streak, and achievements are lost on app restart. Store these in Hive (or a dedicated Hive box) alongside the aviary data.

2. **Extract bird database**: Move the 4,300+ lines of bird data to a JSON or SQLite file. This reduces `main.dart` to ~1,100 lines and allows database updates without code changes.

3. **Modularize the codebase**: Split `main.dart` into separate files:
   ```
   lib/
   ├── main.dart                 # Entry point
   ├── models/bird.dart          # Bird data model
   ├── data/bird_database.dart   # Bird list (or JSON loader)
   ├── services/storage.dart     # Hive persistence
   ├── services/audio.dart       # Audio player wrapper
   ├── screens/home_screen.dart  # Main shell
   ├── tabs/identify_tab.dart    # Camera & identification
   ├── tabs/aviary_tab.dart      # Collection grid
   ├── tabs/field_guide_tab.dart # Searchable reference
   ├── tabs/profile_tab.dart     # Player stats
   ├── tabs/map_tab.dart         # Future map feature
   ├── widgets/bird_card.dart    # Reusable bird card
   ├── widgets/bird_detail.dart  # Detail bottom sheet
   ├── theme/colors.dart         # Color constants
   └── game/progression.dart     # XP, levels, achievements
   ```

### Medium Priority

4. **Real bird identification**: Integrate an ML model (TFLite or cloud API) for actual image-based bird recognition.

5. **State management upgrade**: Adopt Riverpod or Provider for testable, scalable state management.

6. **Add unit and widget tests**: The `flutter_test` dependency exists but no tests have been written. Priority test targets:
   - XP calculation and level-up logic
   - Weighted random distribution
   - Achievement unlock conditions
   - Bird lookup and unknown bird fallback

7. **Interactive map**: Implement the Map tab with a mapping library (e.g., `flutter_map` or Google Maps) showing bird sighting locations.

### Low Priority

8. **iOS support**: Add `ios/` directory and configuration for Apple platforms.

9. **Accessibility**: Add semantic labels, larger touch targets, and screen reader support.

10. **Internationalization**: Support multiple languages for bird names and UI strings.

---

## 22. Developer Onboarding Guide

### Prerequisites

- Flutter SDK (3.x or later)
- Android Studio or VS Code with Flutter extensions
- An Android device or emulator (API 21+)
- Git

### Getting Started

```bash
# Clone the repository
git clone https://github.com/TheCryptoCanuck/AviQuest-.git
cd AviQuest-/aviquest

# Install dependencies
flutter pub get

# Run on connected device or emulator
flutter run
```

### Key File to Understand

All application code lives in `aviquest/lib/main.dart`. Read it in this order:

1. **Lines 13-24**: Color constants — understand the visual language
2. **Lines 26-62**: `Bird` class — the only data model
3. **Lines 4417-4475**: Helpers — game logic (levels, XP, achievements)
4. **Lines 4479-4521**: App entry and theme
5. **Lines 4526-4589**: State initialization
6. **Lines 4591-4747**: Core game flow (photo → identify → add → XP)
7. **Lines 4928-5208**: UI tabs (Identify, Aviary, Field Guide)
8. **Lines 5240-5397**: Profile tab and build method

### Development Tips

- The camera will not work on most emulators. Test identification flow by tapping "By Call" which bypasses the camera.
- Bird database changes require modifying the `birds` list starting at line 68.
- To add a new achievement, update both `_achievements` (line 4465) and `_checkAchievements()` (line 4762).
- The app forces portrait orientation. Remove the `SystemChrome.setPreferredOrientations` call (line 4483) to test landscape.

---

## Appendix A: Complete Bird Rarity Distribution

### Common Birds (60% Selection Pool)

Base XP range: 20-50. These are widespread species found globally in common habitats — parks, gardens, forests, and urban areas. Examples include:

- Black-capped Chickadee (50 XP)
- American Robin (40 XP)
- House Sparrow (30 XP)
- European Starling (25 XP)
- Rock Pigeon (20 XP)

### Uncommon Birds (25% Selection Pool)

Base XP range: 65-115 (effective: 97-172 after 1.5x multiplier). Regional specialists and less frequently encountered species:

- Northern Cardinal (75 XP base → 112 effective)
- Blue Jay (80 XP base → 120 effective)
- Red-tailed Hawk (100 XP base → 150 effective)

### Rare Birds (12% Selection Pool)

Base XP range: 150-295 (effective: 300-590 after 2.0x multiplier). Specialized habitat dwellers and uncommon regional species:

- Snowy Owl (150 XP base → 300 effective)
- Pileated Woodpecker (200 XP base → 400 effective)
- Peregrine Falcon (250 XP base → 500 effective)

### Legendary Birds (3% Selection Pool)

Base XP range: 500-900 (effective: 2,500-4,500 after 5.0x multiplier). Iconic, rare, and endangered species:

- Resplendent Quetzal (500 XP base → 2,500 effective)
- Shoebill (600 XP base → 3,000 effective)
- Kakapo (800 XP base → 4,000 effective)

---

## Appendix B: Achievement Catalogue

| # | Key | Icon | Name | Description | Trigger Condition |
|---|-----|------|------|-------------|-------------------|
| 1 | `first_bird` | 🐦 | First Feather | Identify your first bird | `aviaryBox.length >= 1` |
| 2 | `five_species` | 🌿 | Nature Curious | Collect 5 different species | `aviaryBox.length >= 5` |
| 3 | `ten_species` | 🏆 | Avid Birder | Collect 10 different species | `aviaryBox.length >= 10` |
| 4 | `twenty_species` | 🦅 | Wing Watcher | Collect 20 different species | `aviaryBox.length >= 20` |
| 5 | `rare_find` | 💎 | Rare Encounter | Identify a rare bird | `bird.rarity == 'rare' \|\| 'legendary'` |
| 6 | `legendary_find` | ✨ | Legend Spotter | Identify a legendary bird | `bird.rarity == 'legendary'` |
| 7 | `level_5` | ⭐ | Rising Birder | Reach level 5 | `level >= 5` |
| 8 | `level_10` | 🌟 | Expert Nester | Reach level 10 | `level >= 10` |
| 9 | `level_20` | 🌠 | Sky Master | Reach level 20 | `level >= 20` |

> **Note:** The species collection achievements count total additions (including duplicates), not unique species. This is because Hive stores each bird name independently without deduplication.

---

## Appendix C: Level Progression Table

| Level | Title | XP to Next Level | Cumulative XP | Common Birds Needed* |
|-------|-------|-----------------|---------------|---------------------|
| 1 | Fledgling | 1,000 | 1,000 | ~25 |
| 2 | Fledgling | 2,639 | 3,639 | ~66 |
| 3 | Nestling | 4,656 | 8,295 | ~116 |
| 4 | Nestling | 6,964 | 15,259 | ~174 |
| 5 | Nestling | 9,518 | 24,777 | ~238 |
| 6 | Sparrow | 12,286 | 37,063 | ~307 |
| 7 | Sparrow | 15,247 | 52,310 | ~381 |
| 8 | Sparrow | 18,384 | 70,694 | ~460 |
| 9 | Sparrow | 21,685 | 92,379 | ~542 |
| 10 | Warbler | 25,119 | 117,498 | ~628 |
| 15 | Warbler | 44,306 | 289,320 | ~1,107 |
| 20 | Songweaver | 66,287 | 571,113 | ~1,657 |
| 30 | Falconer | 117,072 | 1,464,540 | ~2,926 |
| 40 | Eagle Scout | 175,075 | 2,894,460 | ~4,378 |

*\*Approximate, assuming average 40 XP per common bird.*

---

## Appendix D: Glossary

| Term | Definition |
|------|-----------|
| **Aviary** | The player's collection of identified birds, persisted in Hive storage |
| **Base XP** | The raw experience point value assigned to a bird before rarity multipliers |
| **Bird Call** | An audio recording of a bird's vocalization, sourced from Xeno-Canto |
| **Effective XP** | Base XP multiplied by the rarity modifier (the actual XP awarded) |
| **Field Guide** | The searchable reference tab listing all 393 birds in the database |
| **Hive** | A lightweight Dart-native key-value database used for local persistence |
| **Hive Box** | A named collection within Hive; AviQuest uses `aviary_v2` |
| **IndexedStack** | A Flutter widget that shows one child from a list while keeping all alive |
| **Mounted** | A Flutter widget state that indicates whether the widget is still in the tree |
| **Rarity** | A classification tier (common/uncommon/rare/legendary) that affects XP and visual presentation |
| **Shimmer** | A loading animation that shows a glowing wave effect as a placeholder |
| **Unknown Bird** | A fallback `Bird` object created when a stored name doesn't match the database |
| **ValueListenableBuilder** | A Flutter widget that rebuilds when a `ValueListenable` changes, used for reactive Hive updates |
| **Weighted Random** | A selection algorithm where outcomes have different probabilities based on assigned weights |
| **Xeno-Canto** | An open-access archive of bird sound recordings from around the world |

---

*This document was generated through comprehensive static analysis of the AviQuest codebase. All line numbers reference `aviquest/lib/main.dart` unless otherwise specified.*
