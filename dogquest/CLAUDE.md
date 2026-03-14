# DogQuest — Project Intelligence

## Project Overview

DogQuest is a Flutter-based dog breed identification app forked from AviQuest. It features 150 dog breeds, TFLite visual ML identification (87.2% accuracy, EfficientNetB2 v5.1), gamification mechanics (XP, leveling, achievements, combos, streaks, mastery, daily challenges), Pack (family co-ownership), Dog Friendships with a Neighborhood Map, and shareable Dog Passport cards. No audio identification. No backend (local-first with Hive).

## Tech Stack

- **Framework**: Flutter (Dart)
- **Platform**: Android (iOS untested)
- **Storage**: Hive (local NoSQL), boxes prefixed `dogquest_`
- **ML Model**: EfficientNetB2 (v5.1), uint8 quantized, 260x260 input, 150-class output, 10.3 MB, **87.2% test accuracy**
- **Previous Model**: EfficientNetB0 (v3), 224x224, 5.0 MB, 82.6% accuracy
- **Key Libraries**: flutter_animate, camera, cached_network_image, tflite_flutter, image_picker, permission_handler, geolocator

## Project Structure

```
dogquest/
├── CLAUDE.md                  ← You are here
├── lib/
│   ├── main.dart              ← App entry, provider init, model loading
│   ├── constants.dart         ← Rarity enum, color constants, achievements
│   ├── router.dart            ← go_router with auth gate & StatefulShellRoute
│   ├── models/                ← Data classes (Dog, Sighting, Player, Pack, DogFriendship)
│   ├── screens/               ← UI screens (identify, kennel, profile, quiz, map, pack, passport)
│   ├── services/              ← Business logic (player, dog, kennel, sighting, ML, pack, friendship)
│   ├── helpers/               ← Utility functions
│   └── widgets/               ← Shared widgets (dog_detail_sheet, dog_found_dialog, dog_passport_card)
├── assets/
│   ├── dogs.json              ← 151 breed database
│   ├── dog_labels.txt         ← 151 breed labels (matches model output)
│   └── dog_model.tflite       ← 5.0 MB quantized EfficientNetB0
├── supplemental_dogs/         ← 31 breed folders, 100 images each (3,100 total)
├── train_model_v5.py          ← v5 training (EfficientNetB2, RandAug, progressive resize, 90%+ target)
├── train_model_v4.py          ← FGVC training (bbox crop, CutMix, bilinear head)
├── train_model_v3.py          ← Previous production training (EfficientNetB0, 82.6%)
├── train_model_v2.py          ← Previous training script (MobileNetV2, 73.8%)
├── audit_supplemental.py      ← TFLite image quality auditor
├── download_more_images.py    ← Multi-query breed image downloader
└── *.py                       ← Other utility scripts (mostly one-time use)
```

## Critical Technical Notes

- TFLite model expects **uint8 input** (0-255), NOT float32
- TFLite uint8 output must be divided by 255.0 for confidence
- Image preprocessing: EXIF bakeOrientation + scale + 5-crop + resize 260x260 (v5)
- v5 TTA: 5-crop (center + 4 corners) × flip = 10 variants averaged
- Camera: must fully dispose + reinitialize after takePicture()
- **tflite_flutter 0.11.0**: output buffers MUST use `List.filled(n, 0.0).reshape()`, NOT `Float32List`
- **LocationFilterService DISABLED** — dog breeds are globally distributed
- Name aliases in `dog_service.dart` map model labels to breed names in `dogs.json`
- Dog images: use `thumb.php` Wikimedia API (CDN `/thumb/` URLs return 429)
- App ID: `com.dogquest.app`
- Hive boxes prefixed `dogquest_` to avoid collision with AviQuest

## Build Commands

```bash
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.dogquest.app/.MainActivity
adb logcat -d | grep -iE "flutter|tflite|identify|entropy"
```

## Key Differences from AviQuest

- No audio identification (BirdNET removed)
- No backend sync (all methods return null/void)
- No Firebase/Google Services (commented out in build.gradle)
- 7 AKC breed groups replace 14 bird families
- Routes: `/aviary` → `/kennel`
- Dog-themed achievements, player titles, avatars
- Additional features: Pack, Dog Friendships, Neighborhood Map, Dog Passport Card
