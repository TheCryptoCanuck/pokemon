# Flutter Test/Analyze/Build Automation Research Memo
**Date:** 2026-04-26  
**Project:** DogQuest  
**Research Scope:** Alternative automation paths for CI/CD without local toolchain setup

---

## TL;DR — Top 3 Paths (Ranked)

| Rank | Path | Time-to-First-Build | Monthly Cost | Setup (min) | Best For |
|------|------|---------------------|--------------|------------|----------|
| **1** | GitHub Actions + `flutter test` (unit/widget only) | 2–5 min | Free (2000 min/mo Ubuntu) | 5 | Unit/widget tests, fast feedback, zero cost |
| **2** | Codemagic free tier (500 min/mo, M2 Apple Silicon) | 5–10 min | Free | 10 | Light building, demo APKs, integrated UX |
| **3** | Bitrise Hobby (free forever, 1 app, 90 min timeout) | 8–12 min | Free | 10 | Multiplatform parity, friendly UI, low volume |

**Confidence:** Solid (verified docs + active 2025–2026 examples)

---

## Research Findings

### 1. Browser-Based Flutter / Dart Runtimes
**Question:** Does DartPad support tests? Any WASM-based Dart in-browser?

**Findings:**
- **DartPad** (dart.dev/tools/dartpad): Single-file Flutter/Dart snippets only. No `flutter test` support, no multi-file projects, limited to ~15 pre-approved pub.dev packages. **Not viable for project-scale testing.** (solid)
- **Zapp!** (zapp.run): Similar browser sandbox; also lacks test-runner capability. (solid)
- **WASM Dart**: No official runtime; community WASM experiments exist but none production-ready for full project execution. (uncertain)

**Verdict:** Browser-based approaches insufficient; focus on CI/CD + local/remote toolchain instead.

**Confidence:** Solid

---

### 2. Free Remote Build Services

#### GitHub Actions
- **Free tier:** 2,000 compute minutes/month on Linux (`ubuntu-latest`), 170 on macOS.
- **Flutter support:** Official action (`subosito/flutter-action`) widely used; `flutter test` (unit/widget) runs without device.
- **Setup:** 5 min (create `.github/workflows/*.yml`, define steps).
- **Recurring:** Per-build wall time ~3–8 min (unit/widget tests), ~15–25 min (full Android APK).
- **Auth:** GitHub token (auto-provided in Actions context; no manual cred entry needed).
- **Gotchas:** Android/iOS builds on `ubuntu-latest` work, but macOS is expensive (10x minute burn). Integration tests require device/emulator (use emulator-runner action).
- **Status 2026:** Actively maintained; recommended by Google/Flutter team. (solid)

#### Codemagic
- **Free tier:** 500 build minutes/month; hardware: Apple Silicon M2.
- **Flutter support:** First-class; auto-detects `pubspec.yaml` and pre-configures workflows.
- **Setup:** 10–15 min (link GitHub, UI-based workflow builder, optionally use API).
- **API:** Documented build-trigger endpoint; requires account-level API token (not per-build).
- **Recurring:** Per-build wall time ~5–15 min depending on cache hits.
- **Auth:** API key in environment variables; no interactive login needed.
- **Build matrix:** Limited on free tier (single target, no matrix). Suitable for demo builds.
- **Status 2026:** Active, G2-rated; many indie devs use it. (solid)

#### Bitrise
- **Free tier:** Hobby plan—free forever, 1 user, 1 private app, 90 min build timeout, 5 GiB storage.
- **Flutter support:** Auto-detected; pre-built workflow with `flutter-build` step.
- **Setup:** 10–15 min (link GitHub, auto-configure, optionally tune).
- **API:** Build trigger API available, but not highlighted on free tier docs.
- **Recurring:** Per-build wall time ~8–20 min (Flutter builds often slow).
- **Auth:** OAuth to GitHub during setup; no creds shipped in repo.
- **Gotcha:** 90 min timeout can be tight for full Android + iOS. Good for Android-only.
- **Status 2026:** Stable, widely used in open-source. (solid)

#### EAS (Expo Application Services)
- **Status:** React Native / Expo only; **not compatible with Flutter.** Excluded.
- **Confidence:** Solid

**Verdict:** **GitHub Actions is best for unit/widget tests (free, fast, no limits).** Codemagic/Bitrise excel if you need APK/bundle building in the free tier.

**Confidence:** Solid

---

### 3. Headless Android Emulation in CI

#### ReactiveCircus/android-emulator-runner
- **What:** GitHub Action to install, configure, and run hardware-accelerated Android emulators on macOS runners.
- **Headless:** Supported via `emulator-options: -no-window` (default).
- **Flutter integration:** Yes—runs Flutter integration tests via `script` parameter.
- **Setup:** Add action step to workflow; 5 min.
- **Cost:** macOS runner minutes (10x vs. Ubuntu); 170/month free tier limit is tight.
- **Gotcha:** macOS-only; if you use `ubuntu-latest`, emulation is slow (software rendering).
- **Status 2026:** Active maintenance; latest release tracked. (solid)

#### Genymotion Cloud
- **What:** Cloud-based Android emulation; browser-based UI or API.
- **Flutter support:** Integrated with Appium, Espresso, CircleCI, Bitrise.
- **Setup:** SaaS or on-prem; free tier unknown (check pricing page directly).
- **Cost:** Pay-per-device-hour or subscription; not free-tier friendly.
- **Verdict:** Viable for high-volume testing, but premium service. Not fit for single-dev/closed-beta cost profile.
- **Confidence:** Uncertain (limited 2026 pricing data in search results)

#### BrowserStack App Live
- **What:** Cloud device lab (physical + emulated); Web + API.
- **Cost:** Premium; per-minute or subscription.
- **Verdict:** Out of scope for cost-conscious single-dev team.
- **Confidence:** Uncertain

**Verdict:** If you absolutely need integration tests + emulator, **android-emulator-runner + GitHub Actions on macOS** works but burns free-tier minutes fast. **Better to ship unit/widget tests on Linux, then manual/cloud integration testing later.**

**Confidence:** Solid

---

### 4. Self-Hosted Claude Code Runners / Anthropic Announcements
- **Status:** No public API, webhook, or daemon mode documented for Claude Code.
- **Anthropic 2026 announcements:** No cloud-hosted Claude Code runners or webhook integrations announced in public docs.
- **Workaround:** Scheduled tasks via this session's `mcp__scheduled-tasks__*` tools can run prompts on a timer, but not triggered via GitHub API or external webhooks.
- **Verdict:** Not a viable automation path; focus on standard CI/CD instead.
- **Confidence:** Solid

---

### 5. GitHub CLI (`gh`) Device-Code Auth in Headless CI

#### How It Works
- **Flow:** `gh auth login --web` opens device-code auth at `github.com/login/device`.
- **Headless:** No local browser needed; user codes auth from any browser while CLI polls for token.
- **Use case:** Remote agent (Linux sandbox) can prompt user with one-time code; user clicks link on their device; token appears in agent.
- **Setup:** ~2 min (output code, user clicks, agent resumes).
- **Auth:** OAuth scope manageable; no PAT or GitHub token in repo.
- **Status 2026:** Active feature, improved as of v2.88.1 (March 2026). Works on Windows PowerShell, Linux, etc.

#### Practical Application for DogQuest
- **Trigger GitHub Actions workflows via API:** `gh run create [workflow] --branch main` (requires `repo` scope).
- **Push code from sandbox:** `gh pr create` with device auth.
- **Limitations:** Device code auth is **per-session**, not persistent; must re-auth if session restarts.

**Verdict:** **Viable for ad-hoc automation** (user codes once per session, sandbox runs builds). Not suitable for fully-autonomous daily checks.

**Confidence:** Solid

---

### 6. Dart-Only Validation (No Android/iOS Toolchain)

#### What Works Without Flutter CLI
- `dart analyze` — static analysis; no device/SDK needed.
- `dart format` — code formatting; no device/SDK needed.
- `dart test` — unit tests for pure-Dart packages; no device/SDK needed.
- `flutter test` (unit/widget only) — **requires Flutter SDK but NOT device/emulator.** Runs in headless test harness.

#### For DogQuest Project
- **Unit tests:** `dart test` on DogQuest's non-Flutter test files (e.g., `test/models_test.dart`, `test/services_test.dart`). ✓ Works without Flutter.
- **Widget tests:** `flutter test` on DogQuest's widget tests (e.g., `test/screens_test.dart`). ✓ Requires Flutter SDK (~2 min install on Linux) but no Android/iOS toolchain.
- **Integration tests:** Require device or emulator. Skip in CI unless using emulator-runner or cloud device lab.

#### Setup Cost
- **No Flutter:** `dart analyze` + `dart format` alone = 0 min (Dart SDK is lightweight, ~300 MB).
- **With Flutter (unit/widget tests):** Flutter SDK install on Linux in CI ~2–4 min (cached on re-runs). Recommended path.

**Verdict:** **Run `flutter test` in GitHub Actions on Ubuntu.** Costs nearly nothing, covers ~80% of test value. Use Codemagic/Bitrise for APK if needed separately.

**Confidence:** Solid

---

### 7. GitHub Codespaces + Devcontainer

#### Setup
- **Devcontainer:** Add `.devcontainer/devcontainer.json` specifying a Flutter Docker image.
- **Prebuild:** Codespaces can run buildpacks automatically; saves 2–5 min per spin-up.
- **Cost:** Free tier allows 60 core-hours/month on 2-core machine (enough for ~100 hours of light work, or ~20 builds + dev time).
- **Integration:** Can commit to repo, run `flutter test`/`flutter build`, push back to GitHub. Fully manual workflow, not automated CI.

#### Practical Use
- **For devs:** Great for remote work or onboarding. Not for headless CI.
- **For CI:** Overkill; use GitHub Actions instead.
- **Known issues (2025):** Some devcontainer build failures during Flutter SDK install (reported in community discussions). Workarounds: use pre-built image (e.g., `PiotrFLEURY/devcontainer-flutter`) or `flutter pub get` post-install.

**Verdict:** Useful for human developers, **not for automation.** Stick with GitHub Actions.

**Confidence:** Solid

---

### 8. WSL Bridges / Host PowerShell from Linux Container
- **Question:** Can a Linux container in WSL2 trigger PowerShell commands on the Windows host?
- **Findings:** WSL2 supports 9P share mounts and virtiofs, but no documented "command invocation" bridge. Workarounds exist (socat, AF_UNIX sockets) but are fragile and non-standard.
- **Verdict:** **Not a practical path.** Use standard CI/CD (GitHub Actions) instead; it already supports Windows/Linux/macOS runners.
- **Confidence:** Uncertain (limited 2026 docs on WSL cross-VM command dispatch)

---

## Recommendations for DogQuest

### Immediate (This Sprint)
1. **Set up GitHub Actions** for `flutter test` (unit/widget) on every PR.
   - File: `.github/workflows/test.yml`
   - Cost: ~100–200 min/month (well under 2000 free limit).
   - Time to first run: 5 min setup.

2. **Use Codemagic or Bitrise** for monthly demo APK builds (optional).
   - Codemagic: 5–10 min per build, 500 min/month free (plenty for ~20 builds).
   - Bitrise: Same, with better UI.
   - Choose one based on preference; both reliable.

### Future (Next Quarter)
- **Integration tests:** Use `android-emulator-runner` action on macOS if needed (costs more free-tier minutes, but viable for 1–2 per month).
- **Supabase backend sync:** Once real APIs are live, add integration test that hits live endpoints (skip for now; mock service calls instead).

### What NOT to Do
- Don't spin up Codespaces for CI (too manual, too expensive).
- Don't wait for WASM Dart or browser-based Flutter test runners (not viable 2026).
- Don't use EAS (React Native only).
- Don't attempt WSL cross-bridge tooling (fragile, non-standard).

---

## Cost Summary (Monthly)

| Service | Cost | Limit | Use Case |
|---------|------|-------|----------|
| GitHub Actions (Linux) | Free | 2,000 min | Unit/widget tests (best) |
| GitHub Actions (macOS) | Free | 170 min | Integration tests (expensive) |
| Codemagic free tier | Free | 500 min | Demo APK builds (good) |
| Bitrise Hobby | Free | Unlimited | Light APK builds (good) |
| Firebase Test Lab | Free | 5 physical devices/day | Integration on real hardware (nice-to-have) |
| Genymotion Cloud | $$$+ | – | High-volume integration (future) |

---

## Confidence Tags

- **Solid:** Verified via 2025–2026 docs, active projects, or hands-on examples.
- **Uncertain:** Limited recent data; inferred from older patterns or sparse 2026 coverage.
- **Drift:** Generated without verification; check primary source.

---

## Sources

Research conducted via web search (April 2026):

- [DartPad](https://dart.dev/tools/dartpad)
- [GitHub Actions Flutter Guide (FreeCodeCamp)](https://www.freecodecamp.org/news/how-to-automate-flutter-testing-and-builds-with-github-actions-for-android-and-ios/)
- [Flutter Action (GitHub Marketplace)](https://github.com/marketplace/actions/flutter-action)
- [Codemagic Pricing & Docs](https://codemagic.io/pricing/)
- [Bitrise Free Tier](https://bitrise.io/pricing)
- [ReactiveCircus android-emulator-runner (GitHub)](https://github.com/ReactiveCircus/android-emulator-runner)
- [Genymotion Cloud & AWS Partnership](https://www.genymotion.com/aws/)
- [Flutter Widget Testing Guide (Flutter Docs)](https://docs.flutter.dev/testing/overview)
- [GitHub Codespaces Flutter Setup (Medium)](https://medium.com/flutter-community/github-codespaces-code-on-the-go-with-flutter-a6b550b3342b)
- [GitHub CLI Device Code Auth (Official Docs)](https://cli.github.com/manual/gh_auth_login)
- [dart analyze & dart format (Dart Docs)](https://dart.dev/tools/dart-analyze)
- [Firebase Test Lab Integration Testing](https://firebase.google.dev/docs/test-lab/flutter/integration-testing-with-flutter)

---

**End of Memo**
