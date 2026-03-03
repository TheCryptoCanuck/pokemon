#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
# Download the AIY Vision Bird Classifier V1 TFLite model
# Run from the aviquest/ directory:  ./scripts/download_model.sh
#
# Model: Google AIY Vision Classifier — Birds V1
# Input: 224×224 RGB, normalized [0,1]
# Output: 964 bird species (scientific names)
# Size: ~3.4 MB
# Source: TensorFlow Hub
# ─────────────────────────────────────────────────────────────────────
set -euo pipefail

DEST="assets/bird_model.tflite"
URL="https://tfhub.dev/google/lite-model/aiy/vision/classifier/birds_V1/3?lite-format=tflite"

if [ -f "$DEST" ]; then
  SIZE=$(stat -f%z "$DEST" 2>/dev/null || stat -c%s "$DEST" 2>/dev/null || echo "0")
  if [ "$SIZE" -gt 1000000 ]; then
    echo "Model already exists: $DEST ($SIZE bytes)"
    echo "Delete it first to re-download."
    exit 0
  fi
fi

echo "Downloading AIY Vision Bird Classifier V1..."
echo "  From: $URL"
echo "  To:   $DEST"

if command -v curl &> /dev/null; then
  curl -L -o "$DEST" "$URL"
elif command -v wget &> /dev/null; then
  wget -O "$DEST" "$URL"
else
  echo "Error: curl or wget required"
  exit 1
fi

SIZE=$(stat -f%z "$DEST" 2>/dev/null || stat -c%s "$DEST" 2>/dev/null || echo "0")
echo ""
echo "Downloaded: $SIZE bytes ($(echo "scale=1; $SIZE / 1048576" | bc) MB)"
echo "Ready to build: flutter run"
