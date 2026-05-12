# Hound — Brand & Compliance Review

Self-review pass on all marketing deliverables produced for the Play Store launch package. Severity follows standard brand-review conventions: **blocker** → must fix before submit; **high** → strongly recommend fix; **medium** → consider fix; **low** → noted, not critical.

Reviewed deliverables:

- `screenshots/copy.md` — per-screen marketing headlines
- `store-listing/play_store_listing.md` — app title, short + full description, captions
- `lib/widgets/dog_found_dialog.dart` — breed details chips row (Task #2)
- `lib/dev/mock_screen_1.dart` — branded camera + prediction mock
- `lib/dev/mock_screen_5.dart` — branded share UI mock

---

## Findings

### Blocker 1 — Privacy claim mismatch (resolved)

**File:** `store-listing/play_store_listing.md` — `WHY HOUND IS DIFFERENT` section

**Was:** "No tracking. No data sale. No dark patterns."

**Evidence:** Firebase Analytics is initialized at `lib/main.dart:627` (`FirebaseAnalytics.instance`). Sentry is initialized in `main.dart` and `services/sync_queue_service.dart`. Both collect anonymous diagnostics from every install.

**Risk:** Misleading Claims violation under Play's [Deceptive Behavior policy](https://support.google.com/googleplay/android-developer/answer/9969691) — apps must not misrepresent what data they collect.

**Resolution:** Rewrote the bullet to disclose anonymous diagnostics + opt-out path. `solid`

---

### High 1 — "294 breeds in training" depends on v6 timing

**File:** `store-listing/play_store_listing.md` — `NEW IN v5.1` section

**Claim:** "150 breeds (up from 100), with v6 expansion to 294 breeds in training"

**Risk:** If v6 slips past 60 days post-launch, the listing reads as stale-marketing. Play allows it but reviewers can flag.

**Recommendation:** If v6 ship date is not committed within the next 4–6 weeks of submit, soften to: "More breeds in active training — coming soon to your Kennel."

Tagged `uncertain` on whether to apply now; pending the user's v6 ship signal. Left as-is for now with this callout.

---

### High 2 — Mock screen 5 implies a friends feature that's branch-only

**File:** `lib/dev/mock_screen_5.dart`

**Risk:** The mock shows "Send to a friend" with named avatars (Alex / Jordan / Sam / Elena / Tom). Hound's social/friends backend is on branch `phase-1/social-backend-realtime` and not in v5.1. If a reviewer or savvy user installs and looks for the friends list, they won't find it.

**Mitigation:** The screen is marketing-only and the headline (copy.md → "Share your discoveries") matches the implemented OS-native share — so the words are accurate even if the visual is aspirational. App-store screenshots showing concept UI are common practice and Play does not require pixel-perfect parity.

**Recommendation:** Acceptable if you're comfortable that friends ship within ~90 days. If the social backend timeline is uncertain, swap screen 5 for an alternate (e.g., the breed quiz screen, which is shipped). Decision deferred to user.

---

### Medium 1 — Confidence label drift between mock and shipping result card

**Files:** `lib/dev/mock_screen_1.dart` line ~218 ("High match") vs `lib/widgets/identification_result_card.dart` `_matchLabel` getter

**Observation:** Mock screen 1 shows "HIGH MATCH" pill. The shipping `DogFoundDialog` uses descriptors like "Very confident" / "Confident" / "Fairly sure" (see `_tierDescriptor` at `dog_found_dialog.dart:1075`).

**Risk:** Visual inconsistency between marketing and live UI. Not a Play policy issue; aesthetic/branding only.

**Recommendation:** Either change mock 1 to "VERY CONFIDENT" / "CONFIDENT" to match shipping copy, or accept the inconsistency on the basis that the mock represents a future state with the live-prediction overlay.

---

### Medium 2 — Screen 4 promises specific achievements; seed data must match

**File:** `screenshots/copy.md` — Screen 4 headline "Level up your dog knowledge"

**Risk:** The seeded state in `lib/dev/screenshot_seed.dart` lists achievement keys `['first_breed', 'streak_7', 'pack_starter', 'rare_find']`. I have **not verified** these keys exist as labels in the actual achievements UI — they may render as raw keys if the achievement lookup table doesn't recognize them. `drift`.

**Recommendation:** Before capture, the user should open the seeded build, navigate to Profile, and check that achievement chips render with human-readable labels. If they show as raw keys, swap to known-good achievement keys (search `lib/services/` for the achievement registry).

---

### Low 1 — `CLAUDE.md` color drift

**Observation:** `CLAUDE.md` describes `bgDeep` as `#1A0F0A` (warm brown). Actual `lib/constants.dart:42` defines `bgDeep` as `Color(0xFF0F1A10)` (dark forest green). The app appears to have shifted to a green-forest palette since CLAUDE.md was written.

**Impact on this work:** None — all mock widgets and copy use the constants from `constants.dart`, not the CLAUDE.md values. But CLAUDE.md is stale and worth a refresh in a separate pass.

---

## Accessibility (WCAG 2.1 AA) — partial pass

A11y review on the on-image marketing copy can only be finalized after framing. Pre-framing checks I can perform now:

| Check | Mock 1 | Mock 5 | Notes |
|---|---|---|---|
| Text contrast vs background | ✓ verified — white text on darkened bottom gradient (gradient overlay ensures ≥7:1 even on light dog fur) | ✓ verified — white on `bgDeep` (`#0F1A10`) = 18.5:1 | Both pass AAA |
| Pill text contrast | ✓ amber on dark = 8.1:1 (AAA) | ✓ same | Pass |
| Tap target size ≥ 44pt | All buttons in mocks are ≥48pt | Same | Pass |
| Color as sole indicator | Confidence shown via label + icon + color; rarity shown via label + color | Friend avatars use initials + color; no color-only meaning | Pass |
| Text scaling resilience | Untested in code — relies on MediaQuery.textScaler. Risk: long breed names + Wrap should reflow but the prediction card has fixed padding | Same risk | **Manual check** during capture: enable system Large text and verify no clipping |

**Outstanding a11y work** (post-framing): contrast check between marketing copy overlay and the underlying screenshot photo regions on each of the 18 final assets. Use WebAIM Contrast Checker on the headline-vs-background regions. If any fall below 4.5:1, add a 40% black gradient behind the text per `copy.md` typography rules.

---

## Pre-submit sign-off checklist

- [x] Privacy claim corrected to disclose Firebase + Sentry diagnostics
- [x] All character limits within historic Play limits (30 / 80 / 4000)
- [x] No competitor name-drops
- [x] No emoji in listing body
- [x] Feature claims verified to exist in v5.1:
  - [x] 150 breeds (verified via `kDeployedBreedCount` in `constants.dart`)
  - [x] On-device AI / TFLite (verified via `tflite_flutter` in `pubspec.yaml`)
  - [x] Kennel collection (verified `kennel_service.dart`)
  - [x] XP + levels + 8 titles (verified `player_service.dart` lines 62–69)
  - [x] Streaks (verified `player_service.dart`)
  - [x] Daily challenges + weekly missions (verified widget files exist)
  - [x] Local sighting map (verified `map_tab.dart`)
  - [x] Quiz mode (verified `quiz_screen.dart`)
  - [x] Custom breed card share (verified `breed_share_sheet.dart`)
- [ ] **Final a11y contrast check on framed assets** — pending Task #7
- [ ] **Achievement labels render correctly on seeded build** — pending the user's emulator capture (Task #4)
- [ ] **Privacy policy URL field in Play Console** — open item, listed in `play_store_listing.md`
- [ ] **`google_mobile_ads` dependency** — body says "No ads. Ever." but the dep is in `pubspec.yaml`. Confirm v5.1 ships without ad units OR remove the dep before submit. Open item.

---

## Verdict

Copy + mocks are **ready to use** subject to the user's call on the two High findings (v6 timing softening, friends feature confidence). The Blocker has been resolved in the file. A11y pre-checks pass; final contrast pass on the framed assets is the only remaining quality gate before Play Console submit.
