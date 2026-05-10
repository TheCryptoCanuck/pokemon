# DogQuest Improvement Plan
_Generated April 2026 from competitive brief + codebase audit_

---

## TL;DR

Three parallel codebase audits surfaced two critical build-breaking bugs hiding in plain sight, confirmed the
v6 model (296 breeds) is trained but undeployed, and mapped exactly what's needed to execute the
competitive brief's recommended sequence: **float16 model → subscription tier → iOS launch → daily care content**.

---

## Critical Bugs (Fix Before Anything Else)

### 1. `google_mobile_ads` missing from pubspec.yaml — app won't compile
`lib/services/ad_service.dart` and `lib/widgets/dogquest_banner_ad.dart` import `google_mobile_ads`,
but the package is not in `pubspec.yaml`. Every build that includes ad code will fail.

**Fix:** Add to pubspec.yaml under dependencies:
```yaml
google_mobile_ads: ^5.0.0
```
Then run `flutter pub get`. Inject AdMob IDs via `--dart-define=ADMOB_INTERSTITIAL_ID=...` and
`--dart-define=ADMOB_BANNER_ID=...` at build time (wiring already exists in `ad_service.dart:48`).

**Effort:** 1 hour. Revenue unlock: ad revenue on 100% of current Android users.

---

### 2. Default API URL is Android-emulator localhost — will break iOS
`lib/services/api_client.dart:16` defaults to `https://10.0.2.2:8000/api/v1`. iOS cannot reach
Android emulator localhost. Any API call on iOS silently fails.

**Fix:** Never default to localhost. Either crash-early with a config error or inject via dart-define:
```bash
--dart-define=API_BASE_URL=https://api.dogquest.io/v1
```

**Effort:** 30 minutes.

---

## Quick Wins (This Week)

### 3. Deploy v6 model — go from 150 to 296 breeds
The v6 training pipeline (`train_model_v6.py`) is complete and includes a float16 export path
(`export_tflite.py:170–175`). The app is still shipping v5.1 with only 150 breeds.

**Steps:**
1. If v6 training checkpoint exists, run: `python export_tflite.py` → generates `dog_model_v6.tflite`
2. Copy to `assets/dog_model.tflite`
3. Edit `lib/services/tflite_identification_service.dart`: change input size constant from `260` to `300`
4. Swap `assets/dog_labels.txt` with `v6_training_package/dog_labels.txt` (296 labels prepared)
5. Run `flutter build apk --debug` and smoke-test on 5–10 supplemental breeds

**Float16 note:** The export script falls back to float16 if uint8 calibration fails. Float16 is the
preferred path for iOS (smaller binary, +8–9% accuracy per brief). Test uint8 first; if accuracy
doesn't meet bar, re-export float16.

**Effort:** 2–4 hours (assuming training checkpoint exists). **This is the highest-impact single change.**

---

### 4. Rewrite Google Play description — "dog life companion" not "breed scanner"
"Breed scanner" is Dog Scanner's territory. "Dog life companion" is unclaimed. Update the listing to lead
with Pack, Neighborhood Map, Lost Dog, and Playdate Matcher — features no competitor has.

**One-line pitch:** "The app that knows every dog breed — and actually helps you live with yours."

**Effort:** 1 hour. No code.

---

### 5. Refresh screenshot set — lead with social screens
Screenshots showing ID results look identical to Dog Scanner. Screenshots showing the Neighborhood
Map with dog pins, the Pack family view, and the Dog Passport card are differentiated and uncontested.

**Priority order:** (1) Neighborhood Map, (2) Pack family view, (3) Dog Passport, (4) Lost Dog alert,
(5) Breed ID results.

**Effort:** 2 hours (capture + upload). No code.

---

## Strategic (Next 30–90 Days)

Sequence matters. The brief's recommended order: **model accuracy → subscription tier → iOS launch → content layer**.

---

### 6. Dog Care Content Layer — the Picture This gap
Picture This ($5M/month revenue) drives retention via daily care touchpoints beyond identification:
watering reminders, plant disease tips, care calendars. DogQuest has zero equivalent.

The notification infrastructure already exists (`smart_notification_service.dart`, 5 reminder types,
timezone-aware scheduling). What's missing is the content.

**Phase A — Expand MyDogProfile** (`lib/models/my_dog_profile.dart:131`):
Add fields: `weightKg`, `feedingTimesPerDay`, `feedingNotes`, `exerciseMinutesDaily`,
`nextVetDate`, `medications`, `vaccinationDueDate`.

**Phase B — Create `dog_care_service.dart`** (~300 lines):
Generates daily touchpoints from profile data + breed info from `dogs.json`:
- Morning: breed-specific exercise prompt ("Golden Retrievers need 60+ min. Walk scheduled?")
- Midday: feeding reminder if `feedingTimesPerDay >= 2`
- Evening: vet/vaccination countdown if `nextVetDate` within 30 days

**Phase C — Wire to SmartNotificationService**:
Add 3 new notification types: `feeding_reminder`, `exercise_prompt`, `vet_countdown`.

**Effort:** ~15 hours. **Estimated DAU impact: +30–40%** (creates 2–4 daily return moments vs.
current 1–2 gamification-only).

---

### 7. Soft Subscription Tier — $2.99/month
Dog Scanner's hard paywall is DogQuest's best acquisition argument, but only if DogQuest has a
credible paid tier. The key is gating access **expansion**, not the core ID feature.

**Recommended tier unlocks:**
- +50% combo XP bonus (free: standard; premium: 1.5×)
- Flash challenges (free: 1/day; premium: unlimited)
- Dog Passport PNG export (currently free — move to premium; shareable link stays free)
- Extended identification history (free: last 50; premium: unlimited)

**Implementation steps:**
1. Add `in_app_purchase: ^3.0.0` to pubspec.yaml
2. Create `lib/services/subscription_service.dart` (~400 lines): state machine for
   active/expired/trial/canceled; restore on app launch; Supabase sync for cross-device
3. Create `lib/screens/paywall_sheet.dart` (~200 lines): benefits, price, trial offer
4. Gate Dog Passport PNG export in `lib/screens/dog_passport_screen.dart:134`
5. Modify combo multiplier in player service to check subscription state
6. Set up StoreKit 2 product (iOS) + Google Play Billing product (Android) in app consoles

**Effort:** ~50 hours total. **Revenue model:** 7% of 10K MAU × $2.99 × 0.70 payout = ~$1.5K MRR.
Scales to ~$50K MRR at 500K MAU (post iOS launch).

---

### 8. iOS Launch Prep
DogQuest is missing ~50% of the English-speaking market. iOS users have higher ARPPU (better ad
CPMs, higher subscription conversion). This is the single biggest distribution unlock.

**Checklist — all confirmed missing from codebase:**

| Item | Fix |
|---|---|
| iOS project folder | `flutter create --platforms=ios .` |
| App icon (iOS) | Set `ios: true` in pubspec.yaml flutter_launcher_icons config, re-run |
| Splash screen (iOS) | Set `ios: true` in flutter_native_splash config, re-run |
| Supabase URL/key | Move from hardcoded `main.dart:98–99` to `--dart-define` injection |
| Info.plist permissions | `NSLocationWhenInUseUsageDescription`, `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSUserNotificationsUsageDescription` |
| Float16 model | Required before iOS to minimize binary size (see item 3) |
| AdMob iOS adapter | Additional setup in ios/Runner/AppDelegate.swift |

**Effort:** ~40 hours. **Prerequisites:** items 3 (model), 6 (subscription design), and both critical bugs fixed.

---

### 9. Real-Time Camera Scanning
Seek offers live confidence scoring as you point the camera. DogQuest does static photo-only.
This is a material UX gap once iOS launches and users compare directly.

**Implementation sketch:**
- Wrap existing `tflite_identification_service.identify()` in a frame loop (debounced to 3 FPS)
- Overlay: top breed name + confidence bar, updates live
- "Tap to confirm" gesture freezes the result and triggers normal flow
- Roughly 200 additional lines in `identify_screen.dart`

**Effort:** ~16 hours. Ship after iOS launch (Android first, then iOS parity).

---

### 10. Pack Shared Challenges + Leaderboards
Pack exists (`pack_service.dart`) but only tracks weekly aggregate XP — no shared goals, no
competition between members. This underutilizes the most differentiated social feature DogQuest has.

**Add:**
- Weekly family challenge: "Find 50 breeds together this week"
- Per-member mini-leaderboard: XP, breed count, streak
- Push notification when pack goal is close: "Your pack needs 3 more breeds to hit the weekly goal!"

**Effort:** ~8 hours. Pairs well with the daily care content layer (item 6).

---

## Sequence Summary

| # | Item | Effort | When |
|---|---|---|---|
| 1 | Fix `google_mobile_ads` in pubspec | 1 hr | Today |
| 2 | Fix localhost API URL default | 30 min | Today |
| 3 | Deploy v6 model (296 breeds, float16) | 2–4 hrs | This week |
| 4 | Rewrite Play Store description | 1 hr | This week |
| 5 | Refresh screenshot set | 2 hrs | This week |
| 6 | Dog care content layer | ~15 hrs | Next 30 days |
| 7 | Soft subscription tier | ~50 hrs | Next 30–60 days |
| 8 | iOS launch prep | ~40 hrs | Next 60–90 days |
| 9 | Real-time camera scanning | ~16 hrs | Post iOS launch |
| 10 | Pack shared challenges | ~8 hrs | Next 30 days |

**Total strategic work:** ~130 hours  
**Critical bug fixes:** 1.5 hours — unblock immediately.
