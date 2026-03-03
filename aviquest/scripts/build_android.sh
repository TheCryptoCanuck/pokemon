#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
# AviQuest Android Build Script
# Run from the aviquest/ directory:  ./scripts/build_android.sh [mode]
#
# Modes:
#   debug    - Fast build, installs to connected device (default)
#   release  - Optimised APK for manual install
#   bundle   - AAB for Play Store upload
#   run      - Build + launch on connected device
# ─────────────────────────────────────────────────────────────────────
set -euo pipefail

MODE="${1:-debug}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

step() { echo -e "\n${YELLOW}▸ $1${NC}"; }

# ── Pre-flight checks ───────────────────────────────────────────────
step "Pre-flight checks"
flutter doctor --android 2>&1 | head -20

step "Resolving dependencies"
flutter pub get --no-example

step "Running tests"
flutter test --no-pub || {
  echo -e "${RED}Tests failed — fix before building${NC}"
  exit 1
}

# ── Build ────────────────────────────────────────────────────────────
case "$MODE" in
  debug)
    step "Building debug APK"
    flutter build apk --debug
    echo -e "\n${GREEN}APK: build/app/outputs/flutter-apk/app-debug.apk${NC}"
    echo "Install:  flutter install --debug"
    ;;
  release)
    step "Building release APK"
    flutter build apk --release
    echo -e "\n${GREEN}APK: build/app/outputs/flutter-apk/app-release.apk${NC}"
    echo "Install:  adb install build/app/outputs/flutter-apk/app-release.apk"
    ;;
  bundle)
    step "Building AAB (App Bundle)"
    flutter build appbundle --release
    echo -e "\n${GREEN}AAB: build/app/outputs/bundle/release/app-release.aab${NC}"
    ;;
  run)
    step "Building and launching on device"
    flutter run --release
    ;;
  *)
    echo -e "${RED}Unknown mode: $MODE${NC}"
    echo "Usage: ./scripts/build_android.sh [debug|release|bundle|run]"
    exit 1
    ;;
esac
