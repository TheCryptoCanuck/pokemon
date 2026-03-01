# AviQuest - Discover, Identify, Collect

**The gamified birding experience that turns every walk into a wildlife adventure.**

AviQuest is a mobile app built with Flutter that combines bird identification with collection-based gameplay. Point your camera, identify species, build your aviary, and progress from Fledgling to Master Birder.

## Why AviQuest?

Birding apps identify birds. AviQuest makes it a game. Every species you find earns XP, unlocks achievements, and grows your personal collection. With 393 species across four rarity tiers, there's always something new to discover.

## Core Features

### Bird Identification & Collection
- **393 bird species** from every continent, each with scientific data, habitat info, conservation status, and unique lore
- **Camera integration** for real-time bird "capture" and identification
- **Personal aviary** that tracks every species you've collected
- **Bird calls** powered by Xeno-Canto audio recordings

### Rarity System
| Tier | Spawn Rate | XP Multiplier |
|------|-----------|---------------|
| Common | 60% | 1x |
| Uncommon | 25% | 1.5x |
| Rare | 12% | 2x |
| Legendary | 3% | 5x |

Legendary species include the Resplendent Quetzal, Shoebill, Kakapo, Harpy Eagle, Superb Lyrebird, and Spix's Macaw.

### Progression System
- **20+ levels** with escalating XP requirements
- **8 rank titles**: Fledgling, Nestling, Sparrow, Warbler, Songweaver, Falconer, Eagle Scout, Master Birder
- **Daily streaks** to encourage consistent birding habits

### Achievements
- First Feather - Identify your first bird
- Nature Curious - Collect 5 different species
- Avid Birder - Collect 10 different species
- Wing Watcher - Collect 20 different species
- Rare Encounter - Identify a rare bird
- Legend Spotter - Identify a legendary bird
- Rising Birder, Expert Nester, Sky Master - Level milestones

### Bird Guide & Encyclopedia
- Browse all 393 species with search and rarity filtering
- Detailed species cards with images from Wikimedia Commons
- Conservation status indicators
- Habitat and scientific classification data

## Tech Stack

- **Framework**: Flutter/Dart
- **Platform**: Android (iOS-ready architecture)
- **Local Storage**: Hive (lightweight, fast key-value database)
- **Camera**: Flutter Camera plugin with permission handling
- **Audio**: just_audio for bird call playback
- **Images**: cached_network_image with shimmer loading states
- **Animations**: flutter_animate for polished UI transitions

## Getting Started

### Prerequisites
- Flutter SDK 3.x or higher
- Android Studio or VS Code with Flutter extension
- An Android device or emulator

### Setup

1. Clone the repository:
```bash
git clone https://github.com/TheCryptoCanuck/AviQuest-.git
cd AviQuest-/aviquest
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## Project Structure

```
AviQuest-/
├── README.md
├── docs/
│   ├── CONTENT_MARKETING_STRATEGY.md
│   ├── APP_STORE_LISTING.md
│   ├── SOCIAL_MEDIA_CONTENT.md
│   └── BLOG_CONTENT_PLAN.md
└── aviquest/
    ├── pubspec.yaml
    ├── lib/
    │   └── main.dart           # Complete app implementation
    └── android/                # Android platform files
```

## Data Sources & Attribution

- **Bird Images**: [Wikimedia Commons](https://commons.wikimedia.org/) (Creative Commons licensed)
- **Bird Audio**: [Xeno-Canto](https://xeno-canto.org/) (bird call recordings from contributors worldwide)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support, please open an issue on the [GitHub Issues](https://github.com/TheCryptoCanuck/AviQuest-/issues) page.
