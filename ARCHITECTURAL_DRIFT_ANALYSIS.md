# AviQuest — Architectural Drift Analysis

**Date:** 2026-02-28
**Scope:** Detect patterns actually in use, identify drift-caused bugs, propose stabilization
**Constraint:** No code changes. Micro-refactors only in the plan.

---

## Part 1: Current Patterns Actually Used (Not Ideal Patterns)

This section documents what the code *does*, not what it should do. Every
claim is traced to a line number in `aviquest/lib/main.dart`.

### Pattern 1: "God State Widget"

All application state lives in `_HomeScreenState` (line 4533). This single
class owns:

| Concern | Variables | Lines |
|---------|-----------|-------|
| Player progression | `level`, `xp`, `streak`, `unlockedAchievements` | 4535–4538 |
| Persistence handle | `aviaryBox`, `hiveReady` | 4541–4542 |
| Hardware controllers | `_player`, `_cam`, `_camReady` | 4545–4548 |
| Tab navigation | `_tab` | 4550 |
| Field guide filtering | `_guideSearch`, `_guideRarityFilter` | 4551–4552 |
| RNG | `_rng` | 4546 |

**Pattern summary:** Every responsibility shares one `setState()` call surface.
Changing the search filter rebuilds the camera preview. Adding a bird rebuilds
the map placeholder. There is no scoping.

### Pattern 2: Hybrid State Observation (Two Incompatible Models)

The app uses two different state observation mechanisms simultaneously:

| Mechanism | Where | What it watches |
|-----------|-------|-----------------|
| `setState()` | 9 call sites | XP, level, tab index, search, filter, camera readiness, Hive readiness |
| `ValueListenableBuilder<Box<String>>` | Aviary tab (line 5000) | Hive box contents for bird grid |

These two mechanisms can desync. `_addBird()` (line 4727) calls
`aviaryBox.add()` *inside* `setState()`. The `setState()` triggers a rebuild
of the entire scaffold. The `ValueListenableBuilder` in the aviary tab *also*
triggers a rebuild because the Hive box changed. Result: the aviary tab
rebuilds twice per bird addition — once from `setState()` propagating through
`IndexedStack`, once from the Hive listener.

The profile tab reads `aviaryBox.length` directly (line 5243) inside its
build method — a third observation pattern (synchronous pull). This only
updates when `setState()` fires for *any* reason, not when the Hive box
changes.

### Pattern 3: Business Logic Inside setState Callbacks

`_addBird()` (line 4727) is the critical mutation path. Inside one
`setState()` block:

```
setState(() {
  aviaryBox.add(bird.name);        // persistence write
  xp += bird.xp;                   // progression math
  while (...) {                    // level-up loop
    level++;
    _showLevelUp();                // ← SIDE EFFECT: shows SnackBar
  }
  _checkAchievements(bird);        // ← SIDE EFFECT: schedules Future.delayed SnackBars
});
```

`_showLevelUp()` (line 4749) calls `ScaffoldMessenger.of(context).showSnackBar()`
synchronously inside the `setState()` callback — before the framework has
processed the state change. `_checkAchievements()` (line 4762) schedules
`Future.delayed` SnackBars, also from within `setState()`.

**This is the actual pattern:** mutation, persistence, side effects, and UI
notifications are interleaved in a single synchronous block. There is no
command/event separation.

### Pattern 4: Services Called Directly from UI Methods

No service layer exists. Platform APIs are called from widget methods:

| API | Called from | Line |
|-----|------------|------|
| `Hive.openBox()` | `_initHive()` | 4570 |
| `aviaryBox.add()` | `_addBird()` inside `setState()` | 4735 |
| `availableCameras()` | `_initCamera()` | 4578 |
| `_cam!.takePicture()` | `_takePhoto()` | 4595 |
| `_cam!.initialize()` | `_initCamera()` | 4582 |
| `Permission.camera.request()` | `_takePhoto()` | 4592 |
| `_player.setUrl().then(play)` | `_addBird()` | 4730 |
| `_player.setUrl().then(play)` | `_showBirdDetail()` | 4880 |

**Pattern summary:** The widget is both the controller and the service layer.
There is zero indirection between UI and platform APIs.

### Pattern 5: String-Typed Domain Modeling

Rarity is a `String` field (line 37) with a comment documenting the allowed
values: `'common' | 'uncommon' | 'rare' | 'legendary'`. A fifth value
`'unknown'` was added later (line 23, 4444) without updating the comment.
Rarity is checked via string comparison in 7 locations:

- `Bird.xp` getter (line 55–59): switch on rarity
- `Bird.rarityColor` getter (line 52): map lookup
- `_weightedRandomBird()` (line 4461): filter by rarity
- `_showFoundDialog()` (line 4627): `== 'unknown'`
- `_showBirdDetail()` (line 4849): `== 'unknown'`
- `_checkAchievements()` (line 4777–4778): `== 'rare'`, `== 'legendary'`
- Field guide filter (line 5089): string comparison

A typo in any of these locations (e.g., `'Legendary'` vs `'legendary'`)
would silently produce wrong behavior. There is no compiler help.

Achievement keys follow the same pattern — bare strings (`'first_bird'`,
`'five_species'`) compared against a `Set<String>` and a `const Map`. A
misspelling silently creates a phantom achievement.

### Pattern 6: Duplicated UI Snippets with Subtle Variations

Three distinct implementations of the rarity badge:

| Location | Opacity | Font size | Border radius |
|----------|---------|-----------|---------------|
| `_showFoundDialog()` (line 4639) | 0.2 | 12 | 20 |
| `_showBirdDetail()` (line 4829) | 0.15 | default (14) | 20 |
| `_buildFieldGuideTab()` (line 5184) | 0.15 | 10 | 10 |

Three distinct implementations of network image + shimmer placeholder:

| Location | Uses `_buildNetworkImage()`? | Height | Error widget |
|----------|-----------------------------|--------|--------------|
| Dialogs/detail (line 4907) | Yes (helper) | param | Container with Icon |
| Aviary grid (line 5046) | **No — inline** | fit:expand | bare Icon |
| Field guide list (line 5165) | **No — inline** | 60x60 | bare Icon |

The aviary and field guide implementations are copy-pasted with small tweaks,
bypassing the helper that exists for exactly this purpose.

### Pattern 7: Top-Level Functions as Pseudo-Service Layer

Business logic that doesn't fit in the widget was placed at file scope:

| Function | Line | Purpose |
|----------|------|---------|
| `levelTitle(int)` | 4419 | Map level to rank name |
| `xpForNextLevel(int)` | 4430 | Progression curve formula |
| `unknownBird(String)` | 4435 | Fallback factory for missing birds |
| `_weightedRandomBird(Random)` | 4449 | Gacha-style random selection |

These are not methods on any class. They access the global `birds` list
directly (line 4461). They cannot be mocked, injected, or tested in isolation
without importing the entire file (and all 393 bird entries with it).

---

## Part 2: Top 5 Drift Problems Causing Bugs

Ranked by severity (impact x likelihood of manifesting in production).

### Drift Bug #1: Player Progress Evaporates on Every App Restart

**Severity: Critical — Affects every user, every session**

| State | Storage | Persisted? |
|-------|---------|------------|
| Collected birds | Hive `Box<String>` | Yes |
| Level | `int level = 1` (line 4535) | **No** |
| XP | `int xp = 0` (line 4536) | **No** |
| Streak | `int streak = 1` (line 4537) | **No** |
| Achievements | `Set<String>` (line 4538) | **No** |

When the user closes and reopens the app, they still see their collected birds
(Hive persists), but they are back to Level 1, 0 XP, 0 achievements, streak 1.
The profile tab shows incorrect data. Achievements that were unlocked are locked
again. The user must re-earn every badge — but the collection thresholds
(`collected >= 5`) would immediately re-trigger on next bird add, creating
duplicate "Achievement Unlocked!" notifications.

**Root cause:** An AI iteration added Hive for birds but never extended
persistence to the rest of the player state. The `FIX 3` comment trail shows
the original attempt used `Box<Bird>` (which crashed because Bird lacks a Hive
adapter), so it was downgraded to `Box<String>`. The other state was likely
planned for persistence but never implemented.

### Drift Bug #2: Aviary Allows Unlimited Duplicates, Achievements Count Wrong

**Severity: High — Silently corrupts game progression**

`_addBird()` (line 4735) calls `aviaryBox.add(bird.name)` — `add()` appends
unconditionally. If a user identifies the same bird 20 times, it appears 20
times in the aviary grid and `aviaryBox.length` returns 20.

The achievement system checks `aviaryBox.length` (line 4763) against
thresholds that say "Collect 5 different species" (line 4467), "Collect 10
different species" (line 4468). But `aviaryBox.length` counts *total entries
including duplicates*, not unique species.

A user can earn "Collect 20 different species" by identifying 20 of the same
common sparrow.

**Root cause:** Hive's `Box.add()` was used because it's the simplest API.
Deduplication logic was never added. The achievement descriptions were written
separately from the code that checks them.

### Drift Bug #3: Side Effects Inside setState() Create Race Conditions

**Severity: High — Causes visual glitches, potential framework violations**

Inside `_addBird()` (line 4733–4746):

```dart
setState(() {
  aviaryBox.add(bird.name);
  xp += bird.xp;
  while (xp >= xpForNextLevel(level)) {
    xp -= xpForNextLevel(level);
    level++;
    _showLevelUp();          // ScaffoldMessenger.showSnackBar() DURING setState
  }
  _checkAchievements(bird);  // Future.delayed + showSnackBar() DURING setState
});
```

`_showLevelUp()` calls `ScaffoldMessenger.of(context).showSnackBar()`
synchronously inside `setState()`. The Flutter framework is in the middle of
marking the element as dirty. The SnackBar requests its own animation frame.
If the user levels up multiple times at once (possible at high XP gains),
multiple SnackBars queue up with `_showLevelUp()` calling into Scaffold
overlay state before the previous `setState()` has finished.

`_checkAchievements()` uses `Future.delayed(500ms)` to stagger SnackBars,
but this delay is scheduled from *inside* `setState()`. The futures capture
the current `context` which may be mid-rebuild.

**Observed symptoms:**
- Multiple SnackBars stacking/overlapping on multi-level jumps
- Potential "setState() called during build" warnings in debug mode
- Achievement SnackBars appearing *after* the user has navigated away

**Root cause:** AI iterations added features (level-up notification,
achievement notification) by inserting code into the existing `setState()`
block rather than separating mutation from notification.

### Drift Bug #4: `streak` Is Displayed But Never Updated — Dead Feature

**Severity: Medium — Misleading UI, user confusion**

`streak` is initialized to `1` (line 4537) and displayed in the profile tab
(line 5289: `_statCard('🔥', '$streak', 'Day Streak')`). It is never modified
anywhere in the codebase.

Every user always sees "Day Streak: 1". The feature was started (variable
declared, UI rendered) but the logic to increment/reset the streak on daily
usage was never implemented. No date tracking exists.

**Root cause:** Classic AI drift — a variable was scaffolded, the UI was built
to display it, but the connecting logic was never written. A subsequent AI
iteration likely focused on other bugs (the 7 FIX comments) and didn't notice
the incomplete feature.

### Drift Bug #5: `_simulateIdentify()` Accepts a Photo But Ignores It

**Severity: Medium — Core feature is deceptive**

The identification flow:

1. `_takePhoto()` (line 4591) takes a real photo via `CameraController`
2. Passes `File(file.path)` to `_simulateIdentify()` (line 4597)
3. `_simulateIdentify(File _)` (line 4601) — the parameter is named `_`, meaning explicitly unused
4. The method calls `_weightedRandomBird(_rng)` — a pure random selection
5. Shows an "Analysing..." dialog with a spinner for 1800ms
6. Displays the random bird as if it was identified from the photo

The "By Call" button (line 4978) passes `File('')` — an empty path — to the
same function, confirming the photo is never used.

The user experience is: take a real photo of a bird, watch a fake analysis
animation, receive a random bird with no relation to what was photographed.
There is no indication to the user that identification is simulated.

**Root cause:** The camera infrastructure was built by one AI iteration. The
identification logic was implemented as a placeholder by another. The two were
never connected. The `_simulateIdentify` parameter signature preserves the
*intention* of future real identification but the unused `_` signals the
implementation was knowingly deferred.

---

## Part 3: Phased Stabilization Plan (Micro-Refactors Only)

Each phase is a small, isolated change. No architecture overhaul. Each phase
must leave the app compiling and running before the next begins.

### Phase 1: Persist Player Progress

**Risk: LOW** — Additive change. Existing code untouched except adding save/load calls.

**What to change:**
- Open a second Hive box in `_initHive()`: `Box('player_progress_v1')`
- On `_initHive()`, load `level`, `xp`, `streak`, `unlockedAchievements` from the box (with defaults for first-time users)
- In `_addBird()`, after the existing `setState()` block, save the updated values to the progress box
- Do NOT change `setState()` internals or the aviary box

**Lines affected:** ~4569–4574 (init), ~4727–4747 (save after mutation)
**New code:** ~20 lines
**What could break:** Nothing — strictly additive. If the new box fails to open, fall back to current behavior (in-memory defaults).
**Validates by:** Close app, reopen, verify level/XP/achievements survive.

### Phase 2: Extract Side Effects from setState()

**Risk: LOW** — Reorders existing code without changing behavior.

**What to change:**
In `_addBird()`, separate mutation from notification:

```
// BEFORE (current):
setState(() {
  aviaryBox.add(...);
  xp += ...;
  while (...) { level++; _showLevelUp(); }   // side effect in setState
  _checkAchievements(bird);                    // side effect in setState
});

// AFTER (stable):
setState(() {
  aviaryBox.add(...);
  xp += ...;
  levelsGained = 0;
  while (...) { level++; levelsGained++; }
});
// Side effects AFTER setState completes:
for (var i = 0; i < levelsGained; i++) _showLevelUp();
_checkAchievements(bird);
```

**Lines affected:** ~4727–4747
**New code:** ~5 lines changed, 0 new lines net
**What could break:** Notification timing changes slightly (SnackBars appear after rebuild instead of during). Visually identical or improved.
**Validates by:** Add a bird, verify level-up and achievement SnackBars still appear correctly.

### Phase 3: Deduplicate Aviary Entries

**Risk: LOW-MEDIUM** — Changes existing write behavior. Requires migration thought for existing users.

**What to change:**
In `_addBird()`, before `aviaryBox.add()`, check if the bird name already exists:

```dart
final alreadyCollected = List.generate(aviaryBox.length, (i) => aviaryBox.getAt(i))
    .contains(bird.name);
if (alreadyCollected) {
  // Still award XP (reward for re-sighting) but don't add duplicate entry
} else {
  aviaryBox.add(bird.name);
}
```

Update `_checkAchievements()` to count unique species (which is now
`aviaryBox.length` since duplicates are no longer added).

**Lines affected:** ~4735, ~4763
**New code:** ~6 lines
**What could break:** Users with existing duplicate entries in their Hive box retain them (no migration needed — we just stop adding new duplicates). Achievement thresholds become harder to hit (correctly).
**Validates by:** Identify the same bird twice, verify aviary shows it once. Check achievement unlock still works on unique count.

### Phase 4: Remove Dead `streak` Display or Wire It Up

**Risk: VERY LOW** — Either remove 1 line of UI or add ~10 lines of logic.

**Option A (remove):**
Replace `_statCard('🔥', '$streak', 'Day Streak')` with a different stat
(e.g., total XP earned all-time) or remove the card entirely.

**Option B (wire up):**
- Store `lastActiveDate` in the progress Hive box (Phase 1 must be done first)
- On app open, compare `lastActiveDate` to today
- If same day: no change. If next day: `streak++`. If gap: `streak = 1`.
- Save updated streak and date.

**Lines affected:** ~4537 (variable), ~5289 (display), ~4570 (load)
**What could break:** Nothing — either removes dead code or adds isolated logic.
**Validates by:** Option A: visually verify card removed. Option B: change device date, reopen app, verify streak increments/resets.

### Phase 5: Consolidate Rarity Badge Widget

**Risk: VERY LOW** — Pure UI extraction. No logic changes.

**What to change:**
Create a single builder function in `_HomeScreenState`:

```dart
Widget _rarityBadge(Bird bird, {double opacity = 0.15, double fontSize = 12, double radius = 20}) {
  ...
}
```

Replace the 3 inline implementations (lines 4639–4650, 4829–4841, 5184–5194)
with calls to this function.

**Lines affected:** 3 locations, ~15 lines each → 1 function + 3 one-line calls
**Net code change:** ~35 lines removed, ~15 lines added
**What could break:** Visual appearance. Must verify opacity/font size params match each callsite's current values.
**Validates by:** Visual comparison of all three locations before and after.

### Phase 6: Consolidate Network Image Loading

**Risk: VERY LOW** — Pure UI extraction. The helper already exists.

**What to change:**
The aviary grid (line 5046) and field guide list (line 5165) have inline
`CachedNetworkImage` + `Shimmer` code that duplicates `_buildNetworkImage()`
(line 4907). Replace the inline versions with calls to the existing helper.

Adjust `_buildNetworkImage()` to accept optional width and fit parameters to
cover the grid/list sizing needs.

**Lines affected:** ~5046–5056, ~5165–5175, ~4907–4924
**Net code change:** ~20 lines removed, ~5 lines added to helper signature
**What could break:** Image sizing in grid/list. Must verify visual appearance.
**Validates by:** Scroll through aviary grid and field guide list, verify images render identically.

### Phase 7: Add Compile-Time Safety to Rarity and Achievement Keys

**Risk: LOW** — Mechanical replacement of strings with enum/constants.

**What to change:**

```dart
enum Rarity { common, uncommon, rare, legendary, unknown }
```

Change `Bird.rarity` from `String` to `Rarity`. Update the 7 string comparison
sites to use enum values. The compiler then catches typos.

For achievements, create a similar enum or a class with `static const` keys.
Replace the `Set<String>` with `Set<AchievementKey>`.

**Lines affected:** ~30 (Bird model), ~37 (rarity comparisons), ~4465–4475 (achievement map), ~4762–4781 (achievement checks)
**New code:** ~10 lines (enum definition). ~30 lines changed (string → enum).
**What could break:** Bird data list — all 393 entries reference `rarity: 'common'` etc. and would need `rarity: Rarity.common`. This is mechanical but high line-count. Use find-and-replace.
**Validates by:** App compiles (compiler catches any missed conversion). Run app, verify all rarity colors and XP multipliers work.

---

### Stabilization Summary

| Phase | Description | Risk | Bug Fixed | Lines Changed |
|-------|-------------|------|-----------|---------------|
| 1 | Persist player progress | Low | **Drift Bug #1** (critical) | ~20 added |
| 2 | Extract side effects from setState | Low | **Drift Bug #3** (high) | ~5 changed |
| 3 | Deduplicate aviary entries | Low-Med | **Drift Bug #2** (high) | ~6 added |
| 4 | Fix or remove dead streak | Very Low | **Drift Bug #4** (medium) | ~1–10 |
| 5 | Consolidate rarity badge | Very Low | UI drift | ~20 net removed |
| 6 | Consolidate network image | Very Low | UI drift | ~15 net removed |
| 7 | Enum rarity + achievement keys | Low | **Drift Bug #5** (medium, partial) | ~40 changed |

**Total net code change:** ~50 lines added, ~35 removed, ~75 lines mechanically changed.
**No new files. No new dependencies. No architecture change.**

Each phase is independent (except Phase 4 Option B depends on Phase 1).
The order above is recommended: highest-value bug fixes first, lowest-risk
cosmetic fixes last.
