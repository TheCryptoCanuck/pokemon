# AviQuest

A gamified bird identification and collection app built with Flutter. Snap photos of birds, build your aviary collection, earn XP, level up, and unlock achievements.

## Features

- **Bird Identification** — Point your camera at a bird and identify it (simulated identification with weighted rarity system)
- **Aviary Collection** — Build your personal collection of identified species, stored locally via Hive
- **Field Guide** — Browse and search 393 bird species across 4 rarity tiers (common, uncommon, rare, legendary)
- **Player Progression** — Earn XP, level up through 8 ranks (Fledgling to Master Birder), and track day streaks
- **Achievements** — Unlock 9 badges for milestones like first bird, rare encounters, and level thresholds
- **Bird Calls** — Listen to real bird calls sourced from Xeno-Canto
- **Interactive Map** — Community sightings and hotspot mapping (coming soon)

## Tech Stack

- **Flutter 3.x** with Dart 3.x (null-safe)
- **Hive** — Local persistence for aviary and player stats
- **CachedNetworkImage** — Efficient image loading with shimmer placeholders
- **just_audio** — Bird call playback
- **camera** — Live camera preview for photo identification
- **flutter_animate** — Smooth UI transitions and animations

## Project Structure

```
aviquest/
├── assets/data/
│   └── birds.json              # 393 species database
├── lib/
│   ├── main.dart               # App entry point & theme
│   ├── constants.dart           # Colors, achievements, helpers
│   ├── models/
│   │   └── bird.dart           # Bird data model with JSON parsing
│   ├── services/
│   │   ├── bird_service.dart   # Bird data loading & lookup
│   │   └── player_service.dart # Player stats persistence
│   ├── screens/
│   │   ├── home_screen.dart    # Tab controller & game logic
│   │   ├── identify_tab.dart   # Camera & identification UI
│   │   ├── aviary_tab.dart     # Collection grid
│   │   ├── field_guide_tab.dart# Searchable species browser
│   │   ├── map_tab.dart        # Map placeholder
│   │   └── profile_tab.dart    # Player stats & achievements
│   └── widgets/
│       ├── bird_network_image.dart # Cached image with shimmer
│       └── bird_detail_sheet.dart  # Species detail bottom sheet
└── pubspec.yaml
```

## Getting Started

### Prerequisites

- Flutter SDK 3.x+
- Dart SDK 3.x+

### Setup

```bash
git clone https://github.com/TheCryptoCanuck/AviQuest-.git
cd AviQuest-/aviquest
flutter pub get
flutter run
```

## License

This project is licensed under the MIT License — see the LICENSE file for details.
