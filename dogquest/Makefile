# Hound CLI — Unified Build & Deploy
# Usage: make <target>

SHELL := /bin/bash
ADB := C:/Users/Administrator/AppData/Local/Android/Sdk/platform-tools/adb.exe
APP_ID := com.hound.app
APK := build/app/outputs/flutter-apk/app-debug.apk
RELEASE_APK := build/app/outputs/flutter-apk/app-release.apk

.PHONY: help build run deploy install launch logs clean analyze test \
        build-release deploy-release restart kill \
        train audit benchmark benchmark-v3 verify screenshot \
        lint format check menu verify-deploy model-info hooks-install \
        migrate

# ── Help ──────────────────────────────────────────────────────────────
help: ## Show all available commands
	@echo "Hound CLI"
	@echo "============"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ── Build ─────────────────────────────────────────────────────────────
build: ## Build debug APK
	flutter build apk --debug

build-release: ## Build release APK (requires SUPABASE_URL, SUPABASE_ANON_KEY)
	flutter build apk --release \
		--dart-define=ENV=production \
		--dart-define=SUPABASE_URL=$${SUPABASE_URL:?SUPABASE_URL must be set} \
		--dart-define=SUPABASE_ANON_KEY=$${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY must be set} \
		--dart-define=API_BASE_URL=$${API_BASE_URL:-https://placeholder.example.com} \
		--dart-define=SENTRY_DSN=$${SENTRY_DSN:-}

build-aab: ## Build release AAB for Play Store (requires SUPABASE_URL, SUPABASE_ANON_KEY)
	flutter build appbundle --release \
		--dart-define=ENV=production \
		--dart-define=SUPABASE_URL=$${SUPABASE_URL:?SUPABASE_URL must be set} \
		--dart-define=SUPABASE_ANON_KEY=$${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY must be set} \
		--dart-define=API_BASE_URL=$${API_BASE_URL:-https://placeholder.example.com} \
		--dart-define=SENTRY_DSN=$${SENTRY_DSN:-}

analyze: ## Run Flutter static analysis
	flutter analyze

test: ## Run all tests
	flutter test

clean: ## Clean build artifacts
	flutter clean && flutter pub get

# ── Deploy ────────────────────────────────────────────────────────────
install: build ## Build and install debug APK to device
	$(ADB) install -r $(APK)

launch: ## Launch app on device
	$(ADB) shell am start -n $(APP_ID)/.MainActivity

deploy: install launch ## Build, install, and launch (full deploy)
	@echo "✓ Deployed and launched"

deploy-release: build-release ## Build and install release APK (reads SUPABASE_URL, SUPABASE_ANON_KEY, SENTRY_DSN from env)
	$(ADB) install -r $(RELEASE_APK)
	$(ADB) shell am start -n $(APP_ID)/.MainActivity

restart: ## Force stop and relaunch app
	$(ADB) shell am force-stop $(APP_ID)
	@sleep 1
	$(ADB) shell am start -n $(APP_ID)/.MainActivity

kill: ## Force stop app
	$(ADB) shell am force-stop $(APP_ID)

# ── Logging ───────────────────────────────────────────────────────────
logs: ## Show recent Flutter logs (last 100 lines)
	$(ADB) logcat -d -t 100 | grep -iE "flutter|hound|tflite|error|exception" | \
		grep -v "chromium\|InputMethod\|ViewRoot\|Bluetooth\|EglImage\|userfaultfd\|ManagedChannel"

logs-live: ## Stream live Flutter logs
	$(ADB) logcat | grep -iE "flutter|hound"

logs-id: ## Show identification/ML logs
	$(ADB) logcat -d -t 200 | grep -iE "HOUND_ID\|entropy\|identify\|tflite"

logs-clear: ## Clear device logcat
	$(ADB) logcat -c

# ── Screenshots ───────────────────────────────────────────────────────
screenshot: ## Take device screenshot and save locally
	@mkdir -p screenshots
	$(ADB) shell screencap -p /sdcard/screenshot.png
	$(ADB) pull /sdcard/screenshot.png screenshots/screenshot-$$(date +%Y%m%d-%H%M%S).png
	$(ADB) shell rm /sdcard/screenshot.png
	@echo "✓ Screenshot saved to screenshots/"

# ── ML Model ──────────────────────────────────────────────────────────
train: ## Train model (v5.1 EfficientNetB2)
	python train_model_v5_1.py

audit: ## Audit supplemental training images
	python audit_supplemental.py

benchmark: ## Benchmark TFLite model performance
	python benchmark_tflite.py

benchmark-v3: ## Run V3 infrastructure performance benchmarks
	node .claude-flow/benchmark-v3.mjs

verify: ## Verify TFLite model quantization
	python verify_tflite.py

# ── Device Info ───────────────────────────────────────────────────────
devices: ## List connected ADB devices
	$(ADB) devices -l

device-info: ## Show device model and Android version
	@echo "Model: $$($(ADB) shell getprop ro.product.model)"
	@echo "Android: $$($(ADB) shell getprop ro.build.version.release)"
	@echo "SDK: $$($(ADB) shell getprop ro.build.version.sdk)"

# ── Swarm ─────────────────────────────────────────────────────────────
swarm-init: ## Initialize ruflo hive-mind swarm
	npx -y ruflo@latest hive-mind init -t hierarchical-mesh

swarm-status: ## Show hive-mind status
	npx -y ruflo@latest hive-mind status

swarm-spawn: ## Spawn 3 hive-mind workers
	npx -y ruflo@latest hive-mind spawn -n 3

# ── Quick Combos ──────────────────────────────────────────────────────
quick: build install launch logs ## Build, deploy, launch, show logs
	@echo "✓ Quick deploy complete"

fresh: clean build install launch ## Clean build + full deploy
	@echo "✓ Fresh deploy complete"

# ── Pre-build Validation ────────────────────────────────────────────
lint: ## Check formatting (fails if unformatted)
	dart format --set-exit-if-changed .

format: ## Auto-format all Dart files
	dart format .

check: lint analyze test ## Gate: format check + analyze + test
	@echo "✓ All checks passed"

# ── Interactive Menu ─────────────────────────────────────────────────
menu: ## Interactive workflow menu
	@echo ""
	@echo "Hound — Choose a workflow:"
	@echo "─────────────────────────────"
	@echo "  1) Build debug APK"
	@echo "  2) Build release APK"
	@echo "  3) Deploy to device (build + install + launch)"
	@echo "  4) Run all checks (lint + analyze + test)"
	@echo "  5) Clean rebuild + deploy"
	@echo "  6) Show logs"
	@echo "  7) Model info"
	@echo "  8) Verify deployment"
	@echo "  9) Take screenshot"
	@echo "  0) Exit"
	@echo ""
	@read -r -p "Select [0-9]: " choice; \
	case "$$choice" in \
		1) $(MAKE) build ;; \
		2) $(MAKE) build-release ;; \
		3) $(MAKE) deploy ;; \
		4) $(MAKE) check ;; \
		5) $(MAKE) fresh ;; \
		6) $(MAKE) logs ;; \
		7) $(MAKE) model-info ;; \
		8) $(MAKE) verify-deploy ;; \
		9) $(MAKE) screenshot ;; \
		0) echo "Bye." ;; \
		*) echo "Invalid selection: $$choice" >&2; exit 1 ;; \
	esac

# ── Post-deploy Verification ────────────────────────────────────────
verify-deploy: ## Verify app is running on device
	@echo "── Deploy Verification ──"
	@PID=$$($(ADB) shell pidof $(APP_ID) 2>/dev/null); \
	if [ -n "$$PID" ]; then \
		echo "✓ App is running (PID $$PID)"; \
	else \
		echo "✗ App is NOT running" >&2; \
	fi
	@echo ""
	@echo "── Version Info ──"
	@$(ADB) shell dumpsys package $(APP_ID) 2>/dev/null | grep -E "versionName|versionCode|firstInstall|lastUpdate" || true
	@echo ""
	@echo "── Recent Logs (last 20) ──"
	@$(ADB) logcat -d -t 20 | grep -iE "flutter|hound" | \
		grep -v "chromium\|InputMethod\|ViewRoot" || echo "(no matching log lines)"

# ── Model Lifecycle ──────────────────────────────────────────────────
MODEL_FILE := assets/dog_model.tflite
LABELS_FILE := assets/dog_labels.txt

model-info: ## Show ML model file size, date, and label count
	@echo "── ML Model Info ──"
	@if [ -f "$(MODEL_FILE)" ]; then \
		SIZE=$$(stat --printf='%s' "$(MODEL_FILE)" 2>/dev/null || stat -f '%z' "$(MODEL_FILE)" 2>/dev/null); \
		SIZE_MB=$$(awk "BEGIN {printf \"%.1f\", $$SIZE / 1048576}"); \
		echo "Model:   $(MODEL_FILE)"; \
		echo "Size:    $$SIZE_MB MB ($$SIZE bytes)"; \
		MOD=$$(stat --printf='%y' "$(MODEL_FILE)" 2>/dev/null || stat -f '%Sm' "$(MODEL_FILE)" 2>/dev/null); \
		echo "Modified: $$MOD"; \
	else \
		echo "✗ Model file not found: $(MODEL_FILE)" >&2; exit 1; \
	fi
	@echo ""
	@if [ -f "$(LABELS_FILE)" ]; then \
		COUNT=$$(wc -l < "$(LABELS_FILE)" | tr -d ' '); \
		echo "Labels:  $(LABELS_FILE)"; \
		echo "Count:   $$COUNT breeds"; \
		echo ""; \
		echo "── First 10 labels ──"; \
		head -10 "$(LABELS_FILE)"; \
	else \
		echo "✗ Labels file not found: $(LABELS_FILE)" >&2; exit 1; \
	fi

# ── Memory Migration ────────────────────────────────────────────────
migrate: ## Migrate memory systems to unified AgentDB
	node .claude-flow/migrate-memory.mjs

# ── T1 Closure Automation ───────────────────────────────────────────
verify-c3: ## Phase 1: verify backend/ archive state (sec-C3)
	@echo "── C3: filesystem ──"
	@if [ -d backend ]; then \
		echo "FAIL: backend/ directory still present on disk"; exit 1; \
	else \
		echo "✓ backend/ absent from working tree"; \
	fi
	@echo "── C3: git index ──"
	@tracked=$$(git ls-files backend/ | wc -l); \
	if [ "$$tracked" -gt 0 ]; then \
		echo "STALE: $$tracked file(s) still tracked under backend/. Running git rm -rf backend/..."; \
		git rm -rf backend/; \
		echo "Next: git commit -m 'Archive vestigial FastAPI backend (sec-C3)'"; \
	else \
		echo "✓ backend/ absent from git index"; \
	fi
	@echo "── C3: history ──"
	@archive_commits=$$(git log --all --oneline -- backend/ | wc -l); \
	echo "  $$archive_commits historical commits touch backend/"
	@echo "── C3: gitignore ──"
	@if grep -q "^backend/" .gitignore; then \
		echo "✓ backend/ ignored in .gitignore"; \
	else \
		echo "WARN: .gitignore does not ignore backend/"; \
	fi

c2-verify: ## Phase 2: dart format + analyze + test the C2 dormant-marker edit
	dart format lib/services/sighting_sync_service.dart
	dart analyze lib/services/sighting_sync_service.dart
	flutter test test/sync_services_test.dart

c2-commit: c2-verify ## Phase 2: commit the C2 dormant-marker (after c2-verify passes)
	git add lib/services/sighting_sync_service.dart
	git commit -m "Mark SightingSyncService dormant pending sec-C2 (sec-C2-defer)"

wire-sentry: ## Phase 4: build + install with Sentry DSN — usage: make wire-sentry SENTRY_DSN=https://...
	@if [ -z "$(SENTRY_DSN)" ]; then \
		echo "ERROR: SENTRY_DSN is required."; \
		echo "  Usage: make wire-sentry SENTRY_DSN=https://<key>@<org>.ingest.sentry.io/<project>"; \
		exit 1; \
	fi
	flutter build apk --debug --dart-define=SENTRY_DSN=$(SENTRY_DSN)
	adb install -r build/app/outputs/flutter-apk/app-debug.apk
	adb shell am start -n com.hound.app/.MainActivity
	@echo ""
	@echo "Next: trigger any error path in the debug build, watch Sentry dashboard for the event."

t1-status: ## Show T1 close progress from the vault
	@echo "── T1 Critical ──"
	@awk '/^## Tier 1 — Critical/,/^## Tier 1 — Other/' .second_brain/03_Projects/Active_Tasks.md \
		| grep -E "^- Task:|^  Status:" | head -20
	@echo ""
	@echo "── T1 Other ──"
	@awk '/^## Tier 1 — Other/,/^## Tier 2/' .second_brain/03_Projects/Active_Tasks.md \
		| grep -E "^- Task:|^  Status:" | head -20

close-t1: verify-c3 c2-verify ## Phase 1+2: run the auto-verifiable T1 closes
	@echo ""
	@echo "── Manual / external steps remaining ──"
	@echo "  Jesse-side:"
	@echo "    a. C1 Supabase RLS: dashboard → Functions → sync_sightings (uses auth.uid()?), Tables → sightings → Policies (auth.uid() = user_id?)"
	@echo "    b. On-device cluster verify: photograph Yorkie/Poodle/Husky in Hound, confirm cluster preferred names + no warnings in 'make logs-id'"
	@echo "    c. Sentry signup at sentry.io, copy DSN, then: make wire-sentry SENTRY_DSN=<dsn>"
	@echo "  Claude Code:"
	@echo "    d. Read scripts/close_t1.md, execute Phase 4 + 5 + 6 + 7"
	@echo "    e. After all the above: /comprehensive-review:full-review → Resume"

# ── Git Hooks ────────────────────────────────────────────────────────
GIT_DIR := $(shell git rev-parse --git-dir 2>/dev/null || echo ".git")

hooks-install: ## Install pre-commit hook (format + analyze)
	@mkdir -p "$(GIT_DIR)/hooks"
	@printf '%s\n' \
		'#!/usr/bin/env bash' \
		'set -euo pipefail' \
		'' \
		'echo "── pre-commit: checking formatting ──"' \
		'dart format --set-exit-if-changed . || {' \
		'  echo "ERROR: Dart formatting issues found. Run: dart format ." >&2' \
		'  exit 1' \
		'}' \
		'' \
		'echo "── pre-commit: running analysis ──"' \
		'flutter analyze --no-fatal-infos || {' \
		'  echo "ERROR: Flutter analysis failed." >&2' \
		'  exit 1' \
		'}' \
		'' \
		'echo "✓ pre-commit checks passed"' \
		> "$(GIT_DIR)/hooks/pre-commit"
	@chmod +x "$(GIT_DIR)/hooks/pre-commit"
	@echo "✓ Pre-commit hook installed at $(GIT_DIR)/hooks/pre-commit"
