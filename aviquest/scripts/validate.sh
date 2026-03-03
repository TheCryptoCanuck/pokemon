#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
# AviQuest Validation Script
# Run from the aviquest/ directory:  ./scripts/validate.sh
# ─────────────────────────────────────────────────────────────────────
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

step() { echo -e "\n${YELLOW}▸ $1${NC}"; }
pass() { echo -e "${GREEN}  ✓ $1${NC}"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}  ✗ $1${NC}"; FAIL=$((FAIL + 1)); }

# ── 1. Deps ──────────────────────────────────────────────────────────
step "Installing dependencies"
if flutter pub get --no-example > /dev/null 2>&1; then
  pass "flutter pub get"
else
  fail "flutter pub get"
fi

# ── 2. Static analysis ──────────────────────────────────────────────
step "Running dart analyze"
ANALYZE_OUTPUT=$(dart analyze lib/ 2>&1) || true
ERRORS=$(echo "$ANALYZE_OUTPUT" | grep -c " error " || true)
WARNINGS=$(echo "$ANALYZE_OUTPUT" | grep -c " warning " || true)
INFOS=$(echo "$ANALYZE_OUTPUT" | grep -c " info " || true)

if [ "$ERRORS" -eq 0 ]; then
  pass "No analysis errors (warnings: $WARNINGS, infos: $INFOS)"
else
  fail "$ERRORS analysis errors found"
  echo "$ANALYZE_OUTPUT" | grep " error "
fi

# ── 3. Unit tests ───────────────────────────────────────────────────
step "Running unit tests"
if flutter test --no-pub 2>&1; then
  pass "All tests passed"
else
  fail "Some tests failed"
fi

# ── 4. Android debug build ──────────────────────────────────────────
step "Building Android debug APK"
if flutter build apk --debug 2>&1 | tail -5; then
  pass "Debug APK built"
else
  fail "Debug APK build failed"
fi

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${GREEN}Passed: $PASS${NC}  ${RED}Failed: $FAIL${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
