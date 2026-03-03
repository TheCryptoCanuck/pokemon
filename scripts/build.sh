#!/usr/bin/env bash
# =============================================================================
# AviQuest APK Builder
#
# Builds a release APK using Docker.
#
# Usage:
#   ./scripts/build.sh
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/build-output"

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

echo ""
echo -e "${CYAN}=== AviQuest APK Builder ===${NC}"
echo ""

# Check Docker is available
if ! command -v docker &> /dev/null; then
    error "Docker is not installed."
    echo "  Install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! docker info &> /dev/null 2>&1; then
    error "Docker daemon is not running. Start Docker Desktop and try again."
    exit 1
fi

info "Docker detected."
info "Building APK... (first run takes 10-20 min to download SDKs)"
echo ""

cd "$PROJECT_ROOT"
mkdir -p "$OUTPUT_DIR"

# Build using docker compose (try v2 plugin first, then standalone)
if docker compose version &> /dev/null 2>&1; then
    docker compose up --build
elif command -v docker-compose &> /dev/null; then
    docker-compose up --build
else
    info "docker compose not found, using plain docker build..."
    docker build -t aviquest-builder .
    docker run --rm -v "$OUTPUT_DIR:/output-host" aviquest-builder \
        sh -c "cp /output/aviquest-release.apk /output-host/aviquest-release.apk"
fi

if [ -f "$OUTPUT_DIR/aviquest-release.apk" ]; then
    echo ""
    ok "APK built successfully!"
    ok "Location: $OUTPUT_DIR/aviquest-release.apk"
    ok "Size: $(du -h "$OUTPUT_DIR/aviquest-release.apk" | cut -f1)"
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  Install on your Android device${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""
    echo "  1. Enable Developer Options on your phone:"
    echo "     Settings > About Phone > tap 'Build Number' 7 times"
    echo ""
    echo "  2. Enable USB Debugging:"
    echo "     Settings > Developer Options > USB Debugging > ON"
    echo ""
    echo "  3. Connect phone via USB, authorize the PC, then run:"
    echo ""
    echo -e "     ${GREEN}adb install $OUTPUT_DIR/aviquest-release.apk${NC}"
    echo ""
    echo "  Or copy the APK to your phone and open it to install"
    echo "  (enable 'Install from Unknown Sources' in Settings first)."
    echo ""
else
    error "Build failed — APK not found."
    error "Check the Docker output above for errors."
    exit 1
fi
