# Hound — Play Store Screenshot Pipeline

End-to-end pipeline for producing the six marketing screenshots required for the Google Play listing, framed in three device shells (Pixel 7, Galaxy S24, 10" tablet) = **18 final assets**.

## Output directories

```
screenshots/
  raw/                       <- direct device captures (PNG)
    pixel7/
    galaxy_s24/
    tablet_10/
  mock/                      <- Figma exports for screens 1 + 5
  final/                     <- Canva-framed assets with copy overlay
    pixel7/
    galaxy_s24/
    tablet_10/
```

## Capture pipeline

### 0. Prerequisites

- Android Studio AVD running (or physical device) — see device matrix below.
- Hound debug build installed: `cd dogquest; .\build_debug.ps1 -Install`
- ADB on PATH (or at `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`)

### 1. Seed deterministic state

Open the app → **Profile tab → Settings → Developer → Seed screenshot state**.

This seeds (`lib/dev/screenshot_seed.dart`, gated by `kDebugMode`):

- Kennel: first 47 breeds from `assets/dogs.json` (showing **47 / 150** in the grid).
- Player: Level 4 "Good Boy", 1850 XP, 12-day streak, 4 unlocked achievements, 53 total sightings.

To revert: same menu → **Reset screenshot state**.

### 2. Capture screens 2, 3, 4, 6 from the device

```powershell
cd dogquest
.\scripts\capture_screenshots.ps1                          # default: pixel7
.\scripts\capture_screenshots.ps1 -DeviceLabel galaxy_s24
.\scripts\capture_screenshots.ps1 -DeviceLabel tablet_10
.\scripts\capture_screenshots.ps1 -OnlyScreen 3            # re-shoot one
```

The script prompts you to stage each screen, then runs `adb shell screencap` + `adb pull`. Output lands in `screenshots/raw/<DeviceLabel>/S{N}_<slug>.png`.

### 3. Mock screens 1 + 5 (built as Flutter widgets in the app)

These screens couldn't be captured from the shipping flow as-is — Hound's camera viewfinder doesn't render live predictions, and the production share UI is the OS-native sheet rather than a branded card. So we built dedicated mock widgets in `lib/dev/mock_screen_1.dart` and `lib/dev/mock_screen_5.dart`, accessible from **Settings → Developer**. The capture script already includes them in the rotation, so no separate Figma export is needed.

(Originally planned in Figma — pivoted to Flutter for visual consistency with the rest of the app, faster turnaround, and no MCP dependency. The Figma path remains an option if you want to iterate on these later.)

### 4. Frame + add copy in Canva

For each of the 6 screens × 3 device shells, wrap the raw/mock PNG in a device frame and add the chosen marketing copy. Final output dimensions per Google Play spec:

| Slot | Source | Dimensions | Frames |
|---|---|---|---|
| Phone | `raw/pixel7/`, `raw/galaxy_s24/` | min 1080×1920, 16:9 or 9:16 portrait | Pixel 7, Galaxy S24 |
| Tablet 7" | `raw/tablet_7/` | 1024×600 or 1024×768 | Generic 7" tablet |
| Tablet 10" | `raw/tablet_10/` | 1280×800 or 2560×1800 | Generic 10" tablet |

Export to `screenshots/final/<deviceLabel>/S{N}_{slug}_with_copy.png`.

## Click-path per screen

| # | Screen | How to stage |
|---|---|---|
| 1 | Camera + live prediction overlay | Settings → Developer → **Open mock screen 1** (`lib/dev/mock_screen_1.dart`) |
| 2 | Breed result dialog (`DogFoundDialog`) | Identify tab → "Search manually" → pick **Golden Retriever** (the chips row added in `widgets/dog_found_dialog.dart` shows Large / Scotland / Friendly) |
| 3 | Kennel grid with 47 / 150 progress | Seed state first → tap Kennel tab → scroll to top so the progress bar is visible |
| 4 | Profile XP / Level / Achievements | Seed state first → tap Profile tab → scroll to show XP bar and achievements row |
| 5 | Branded share UI | Settings → Developer → **Open mock screen 5** (`lib/dev/mock_screen_5.dart`) |
| 6 | Offline banner | Enable airplane mode → orange "Offline — local mode" banner appears at top |

## Device frame matrix

| Label | Source device | Resolution | Notes |
|---|---|---|---|
| `pixel7` | Pixel 7 AVD, API 34 | 1080×2400 | Primary phone shot |
| `galaxy_s24` | Galaxy S24 AVD, API 34 | 1080×2340 | Alternate phone shot |
| `tablet_10` | Pixel Tablet AVD, API 34 | 1600×2560 | Required for Play tablet listing |

Tablet 7" is not required by Play but improves the listing — capture if time permits.

## Copy slots

The chosen marketing headline for each screen (from `screenshots/copy.md`) is overlaid in Canva, top or bottom of the frame depending on visual weight. Maintain consistent typography across the set. See `copy.md` for the picked variants.

## Why no `integration_test` automation

Considered and dropped. The screens require seeding Hive boxes for Player + Kennel state plus overrides for several Riverpod providers (`kennelServiceProvider` and `playerProvider` both throw `UnimplementedError` until injected after Hive init). Building that test harness costs ~3 h for marginal benefit on a one-time launch deliverable. Manual `adb screencap` from a seeded debug build produces identical output in ~30 min, and the seed function (`lib/dev/screenshot_seed.dart`) gives the same determinism guarantee.

If we later need golden-image regression on these specific screens, revisit and add `integration_test/` + a `test_driver/` that exfiltrates PNG bytes.
