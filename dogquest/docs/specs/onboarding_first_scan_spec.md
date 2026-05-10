# Spec: First-Run Onboarding — First Scan Funnel
**Status:** Draft  
**Date:** 2026-05-10  
**Goal:** Every new user reaches first scan result within 60 seconds of install.

---

## Problem

No onboarding flow exists. User installs → lands on Discover tab (empty for new users) → has to discover Identify tab independently → may never scan. Aha moment (breed result) never triggers → churn before seeing core product value.

Camera permission currently not optimized: if requested on launch, industry data shows ~55-65% accept rate vs ~75-85% when requested in-context after user takes deliberate action.

---

## Success Metrics

- **Primary:** % of new installs that complete first scan within 60 seconds (target: >60%)
- **Secondary:** Camera permission accept rate (target: >75%)
- **Secondary:** % of users who create account post first scan (target: >30%)
- **Guardrail:** No regression to D1 retention

---

## User Flow

```
App launch (first time, no account)
  │
  ▼
HomeShell — default tab index = 1 (Identify), NOT 0 (Discover)
  │
  ├─ First-launch overlay on Identify tab:
  │   "Point at a dog. Tap to identify."
  │   [Single full-width CTA button → taps camera icon]
  │   Dismissed permanently after first tap.
  │
  ▼
User taps camera button
  │
  ├─ Camera permission NOT yet granted:
  │   → Request permission in-context (rationale: "Hound needs camera to identify breeds")
  │   → Granted → open camera viewfinder
  │   → Denied → show "Camera access needed" bottom sheet with "Open Settings" link
  │
  ├─ Camera permission already granted:
  │   → Open camera viewfinder immediately
  │
  ▼
Scan → breed result screen (DogFoundDialog / result flow)
  │
  ├─ Result shown: breed name, confidence, top-3 alternatives, kennel add prompt
  │
  └─ Post-result account CTA (ONLY if not logged in):
      Bottom sheet: "Save [BreedName] to your Kennel"
      [Create account]  [Maybe later]
      → "Create account" → magic-link auth flow
      → "Maybe later" → dismiss, result stays, scan is NOT saved to Supabase
```

---

## Screen Specs

### 1. HomeShell — Default Tab on First Launch

**Current behavior:** `_currentIndex = 0` (Discover).  
**New behavior:** `_currentIndex = 1` (Identify) if `!hasCompletedFirstScan`.

```dart
// In HomeShell initState or via Riverpod provider:
final hasCompletedFirstScan = Hive.box('hound_prefs').get('hasCompletedFirstScan', defaultValue: false);
final initialIndex = hasCompletedFirstScan ? 0 : 1;
```

Hive box: `hound_prefs` (existing or new). Key: `hasCompletedFirstScan` (bool).  
Set to `true` when first scan result is received (in `SharedTfliteService` callback or result screen init).

---

### 2. First-Launch Identify Overlay

Shown once, on top of Identify tab, dismissed on first tap of camera button.

**Condition:** `!hasCompletedFirstScan && _currentIndex == 1`

**Layout:**
```
┌─────────────────────────────────────────┐
│                                         │
│          [dog silhouette icon]          │
│                                         │
│       Point at a dog.                   │
│       Tap to identify.                  │
│                                         │
│   ┌─────────────────────────────────┐   │
│   │      Identify a Breed  →        │   │  ← taps camera, dismisses overlay
│   └─────────────────────────────────┘   │
│                                         │
│   [Skip]  ← sets hasCompletedFirstScan  │
│            = true, stays on Identify    │
└─────────────────────────────────────────┘
```

Implementation: `AnimatedSwitcher` or `Stack` over the Identify tab content. Store dismissed state in same `hound_prefs` Hive box: key `hasSeenIdentifyPrompt`.

---

### 3. Camera Permission — In-Context Request

Do NOT call `Geolocator` / camera permission in `initState`. Call only when user taps the scan/camera button.

```dart
// In IdentifyScreen or camera init:
final status = await Permission.camera.status;
if (status.isDenied) {
  final result = await Permission.camera.request();
  if (result.isPermanentlyDenied) {
    // show bottom sheet: "Open Settings"
    return;
  }
}
// proceed to open camera
```

Rationale string shown to Android users (add to `AndroidManifest.xml` `uses-permission` comment):  
> "Hound uses your camera to identify dog breeds."

---

### 4. Post-Result Account CTA

Shown at bottom of result screen when `supabase.auth.currentUser == null`.

```
┌─────────────────────────────────────────┐
│  💾  Save Golden Retriever to Kennel    │
│                                         │
│  [Create account]    [Maybe later]      │
└─────────────────────────────────────────┘
```

- "Create account" → triggers magic-link flow (existing auth flow)
- "Maybe later" → dismisses sheet, breed result displayed but NOT written to Supabase
- Local scan result can be stored in `hound_prefs` Hive box (key: `pendingBreedResult`) for recovery if user creates account later in same session

---

### 5. Discover Tab — New User State

**Condition:** `sightings == 0` (check against local scan count from Hive, not Supabase, so unauthenticated users qualify)

**Show:** Curated breed cards — "Featured Breeds" — static list seeded manually for beta.

**Graduation trigger:** `sightings >= 1` → show social feed (existing Discover behavior)

**Data source for featured breeds:** Hardcoded list in `constants.dart` or a small JSON asset (`assets/data/featured_breeds.json`). Not a backend call. 10-20 entries. Format:

```json
[
  { "breedId": "golden_retriever", "displayName": "Golden Retriever", "funFact": "One of the most popular breeds in the US.", "imageAsset": "assets/breeds/golden_retriever.jpg" },
  ...
]
```

Images: either bundled assets (small set, ~50-100KB each) or Wikimedia thumb URLs (already used in Field Guide).

**Widget:** Reuse existing `BreedGhostCard` or create a `FeaturedBreedCard` — simpler, no ghost overlay, just breed photo + name + fun fact. Tap → navigate to Field Guide entry for that breed.

---

## State Management

All new state lives in `hound_prefs` Hive box (not Supabase — user may not be authenticated).

| Key | Type | Default | Set when |
|---|---|---|---|
| `hasCompletedFirstScan` | bool | false | First scan result received |
| `hasSeenIdentifyPrompt` | bool | false | Overlay dismissed or skipped |
| `localSightingsCount` | int | 0 | Each scan result (authenticated or not) |
| `pendingBreedResult` | String? | null | Post-scan, user not logged in |

`localSightingsCount` is the source of truth for Discover tab graduation (not Supabase `sightings` — that requires auth).

---

## go_router Considerations

Current auth gate blocks unauthenticated users from certain routes. Ensure:
- Identify tab / camera / scan result screens are accessible WITHOUT authentication
- Kennel "save breed" action checks auth and redirects to magic-link flow if not authenticated
- No route redirect on app open forces login before scan

If auth gate currently redirects unauthenticated root `/` → `/login`, add exception for first-launch path or make login optional on initial navigation.

---

## Implementation Order

1. `hound_prefs` Hive box + `hasCompletedFirstScan` key (30 min)
2. HomeShell default tab override on first launch (15 min)
3. First-launch identify overlay widget (1 hr)
4. Camera permission in-context refactor (30 min)
5. Post-result account CTA bottom sheet (1 hr)
6. Discover tab new-user state + featured breeds JSON asset (2 hr)
7. `localSightingsCount` increment on scan (15 min)

**Total estimated: ~6 hours**

---

## Open Questions

1. **Graduation threshold** — `sightings >= 1` or higher? Test with beta: ask testers when Discover felt useful vs. empty.
2. **Pending breed result recovery** — if user creates account 1 hr later, do we restore the pending scan? Probably not worth the complexity for beta. Log and drop.
3. **go_router auth gate scope** — confirm which routes currently require auth. May need audit before implementing.
4. **Featured breeds image source** — bundled assets (APK size hit) vs. Wikimedia URLs (requires network). For offline-first consistency: bundle a small set (10 breeds, low-res thumbnails).
5. **Skip vs. dismiss overlay** — does "Skip" on the identify prompt need a separate analytics event? Useful for beta instrumentation.

---

## Out of Scope (This Sprint)

- Full account creation onboarding flow (name, dog, photo)
- Push notification permission request
- Lost-dog recovery onboarding
- A/B testing infrastructure
