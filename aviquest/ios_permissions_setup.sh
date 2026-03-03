#!/usr/bin/env bash
# ios_permissions_setup.sh — Run after `flutter create --platforms=ios .`
# Adds required NSUsageDescription keys to ios/Runner/Info.plist

set -euo pipefail

PLIST="ios/Runner/Info.plist"

if [ ! -f "$PLIST" ]; then
  echo "Error: $PLIST not found. Run 'flutter create --platforms=ios .' first."
  exit 1
fi

# Insert permission keys before the closing </dict>
/usr/libexec/PlistBuddy -c "Add :NSCameraUsageDescription string 'AviQuest needs camera access to identify birds.'" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :NSMicrophoneUsageDescription string 'AviQuest needs microphone access to identify birds by their calls.'" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :NSPhotoLibraryUsageDescription string 'AviQuest needs photo library access to save bird photos.'" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :NSLocationWhenInUseUsageDescription string 'AviQuest uses your location to show nearby bird sightings on the map.'" "$PLIST" 2>/dev/null || true

echo "iOS permissions configured in $PLIST"
