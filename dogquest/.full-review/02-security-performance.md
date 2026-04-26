# Phase 2 — Security & Performance (Consolidated)

**Review date**: 2026-04-25 evening (post 13-commit landing)
**Mode**: strict, security-focus
**Method**: 2A security-auditor + 2B performance-engineer in parallel; both consumed Phase 1 carry-forward context

## Executive read

DogQuest's security baseline is **solid** for a pre-closed-beta game with local-first architecture; the C1/C2/C3 fixes hold; Hive encryption is sound; EXIF/GPS stripping works. But **2 GDPR Criticals block public Play Store launch** (plaintext contact_info broadcast, zero consent/policy plumbing) and **2 performance Criticals** are quick wins (dual TFLite load, stream leak race). Performance posture is otherwise healthy — TFLite isolate offload is correct, cold start is in the predictable 5-7s range, no battery drain hot spots, frame budget largely respected.

The 2A and 2B agents converged on the same stream-leak finding from different angles (security/observability vs. heap/CPU), confirming Phase 1 Q1 at higher severity.

## Critical findings (5 distinct)

### S1 / SEC-C-Lost-1 — Contact info plaintext broadcast in `get_active_lost_dogs` RPC
**Source**: 2A. **CWE-200 + CVSS 7.5 + GDPR Article 5/6/32.**
- `lib/services/supabase_lost_dog_service.dart:220-240` returns full `contact_info` (phone + email) to anyone in radius. Stalking + scraping + GDPR exposure.
- **Hard gate for public Play Store**. Closed-beta-with-friends defensible only if you send explicit consent email beforehand.
- Fix paths in lost_dog spec; 2-5 hr.

### S2 / SEC-C-Lost-2 — No lawful basis, consent dialog, DPA, or privacy policy
**Source**: 2A. **GDPR Article 6/7/13/14/28/30. Up to €10M / 4% revenue admin fine ceiling (realistic exposure for solo-dev closed beta is much smaller).**
- No published privacy policy, no on-screen consent dialog, no DPA with Supabase signed, no retention policy.
- **Hard gate for public Play Store** (Google Play Policy 5.2 requires a privacy policy at listing time).
- 8-12 hr including DPA paperwork (~1 week wall time for Supabase counter-sign).

### Q1+Q2 / SEC merged — Stream subscription leaks + race condition
**Sources**: 1A C1 + 2B FW-002 + 2A FW-002 — three angles on the same finding.
- `lib/screens/lost_dog_map_screen.dart:41, 52, 83, 87, 934` — `_sightingSub` race-condition on dispose if subscription assigned during dispose window.
- 3 more leaks in `lost_dog_hub_screen.dart`, `widgets/lost_dog/help_find_tab.dart`, +1 binary-grep match.
- Heap pressure ~1-2 MB cumulative per long session; CPU wake-ups firing on disposed subscribers.
- Fix: convert to `ref.watch(supabaseLostDogServiceProvider...watchSightings(...))` so Riverpod owns lifecycle. ~30 min.

### P1 / FW-001 — Dual TFLite model load on cold start
**Source**: 2B FW-001. **+800-1200ms cold start** (estimated; would need DevTools to verify exact ms).
- `lib/main.dart:596` (TfliteIdentificationService) + `lib/main.dart:668` (DogEmbeddingService) both call `Interpreter.fromAsset('assets/dog_model.tflite')` independently.
- Fix: shared singleton interpreter or shared service; both consume `await SharedTfliteService.getInterpreter()`. ~1 hr.

### Q2 / SEC-O — Swallowed geolocator exceptions  
**Source**: 1A C2 + 2B FW-006. Already in Phase 1 carry-forward; 2A treats as observability/security gap.
- `lib/widgets/lost_dog/help_find_tab.dart:57-62` (generic `catch (e)`).
- `lib/screens/lost_dog_map_screen.dart:77` (`catch (_)` — discards entirely).
- ~10 more spots with broad catches.
- Fix: `_log.warning('Geolocator failed', e, st)` + Crashlytics + user-visible toast/snackbar. ~30 min.

## High findings (10)

### Security
- **SEC-H-Lost-1** — Permanent public photo URLs (`getPublicUrl()` at `supabase_lost_dog_service.dart:152-155`) never expire, never deleted on `markFound`/`cancelReport`. GDPR Article 17 right-to-erasure violation. ~1-2 hr.
- **SEC-H-1** — Hardcoded Supabase URL + anon key in `lib/main.dart:100-103` (Phase 1 Q5 elevated to High in 2A; Supabase anon key is intentionally public, but project URL discloses your instance). Fix: empty defaults + startup assert. 15 min.
- **SEC-H-2** — PII in auth logs at `lib/services/supabase_auth_service.dart:49, 67, 90` (emails plaintext via `_log.info('Signed in: $email')`). Sentry/Crashlytics exposure. Fix: redact helper. 1 hr.
- **SEC-H-3** — Non-secure `Random()` in `lib/services/lost_dog_service.dart:187-191` `_generateId()` — timestamp + 16-bit suffix predictable, enables enumeration. Fix: `Uuid().v4()`. 30 min. Hooks the lost-dog spec sync architecture (Agent B's Phase 1 UUID hygiene).
- **SEC-H-4** — Network security config not verified — `android/app/src/main/AndroidManifest.xml:16-18` references `@xml/network_security_config` but content unverified. Fix: verify file exists and disallows cleartext. 30 min.

### Performance
- **FW-003** — TFLite preprocessing memory spike — 3-variant TTA creates ~1 MB heap spike per identify (3 Uint8List tensors held simultaneously during averaging). Drop to 1-crop center (no expected accuracy loss per v5.1 baselines) or pool isolates. 30 min for crop simplification, 2 hr for isolate pool. Risk on mid-range 2GB devices under bulk scan.
- **FW-004** — God-class `lost_dog_map_screen.dart` rebuild thrash — 1390 lines + missing `const` (because `analysis_options.yaml:5-6` disables `prefer_const_constructors` and `prefer_const_literals_to_create_immutables`). Frame drops 60→30 fps under marker updates likely. Fix: re-enable lints + `dart fix --apply` + per-line ignores for true positives. 1 hr.
- **FW-005** — Read-modify-write JSON-blob services (LostDog, Pack, DogFriendship, DogSocial) — O(N) per write. 50-200 ms main-thread block at 5000+ items. Acceptable for beta; **architectural ceiling, not blocker**.

### Cross-cutting
- **Q3** — 81 widget-returning helper functions (Phase 1 H1) — blocks `const` and testability; pattern is endemic. Ongoing during feature work.
- **Q4** — Test coverage at 0.04% on 52.9K lines (Phase 1 H3) — security-sensitive paths (auth, Supabase services, lost_dog) unguarded. 10-15 hr phased.

## Medium findings (12)

### Security (5)
- **SEC-M-1** — Lost dog ID collision risk (subset of SEC-H-3, same fix).
- **SEC-M-2** — Sighting GPS at full ~11 cm precision exposed to all radius users. Fuzz to ~500 m on public display. 1-2 hr.
- **SEC-M-3** — Supabase RLS policies on `lost_dog_reports`, `lost_dog_sightings`, `friendships`, `packs` not yet audited. Phase 1 trusted existence; Phase 2A needs correctness check. **Required pre-public-launch** ~30 min Jesse-side via dashboard.
- **SEC-M-4** — Dio missing certificate pinning at `lib/services/api_client.dart:29-35`. Cafe-WiFi MITM risk. 2-3 hr to wire pinning. Optional for beta.
- **SEC-M-5** — No input validation on text fields (dog name, breed, notes, contact_info). Length limits + charset check. 1-2 hr.

### Performance (4)
- **FW-006** — Geolocator exception swallowing UX decay → users retry → multiple concurrent `getCurrentPosition()` calls. Bundled with Q2/critical fix.
- **FW-007** — Camera dispose+reinit pattern fragile in `identify_screen.dart` (1002 lines). CLAUDE.md flags this. Verify `_cameraController?.dispose()` in `dispose()`, `_cameraReady` flag against double-init. 30 min verify.
- **FW-008** — flutter_map marker redraw on every sighting stream update without clustering. 30-100 ms rebuild estimated per update at 50+ markers. Add `flutter_map_marker_cluster` + tile cache config. 2-3 hr.
- **FW-009** — `cached_network_image` no explicit cache cap (defaults 100 MB). Long-session GC stalls 20-50 ms possible. Configure `CacheManager` with `maxNrOfCacheObjects: 200`. 1 hr.

### Quality (3)
- **Q7** — God-class screens >1000 lines (lost_dog_map_screen, profile_screen, pack_screen, dog_found_dialog, quiz_screen, map_tab, identify_screen). T2 spec exists for dog_found_dialog and quiz; remaining 5 are ~6 hr each.
- **Q8** — 464 null assertions, 34 missing `context.mounted` guards, 12-15 generic catches. Sweep ~3-4 hr.
- **Q9** — KennelService implicit setter dependency `lib/services/kennel_service.dart:22-29` — silent `[]` fallback if setter not called. Fix: assert. 5 min.
- **Q10** — JSON-blob services (subset of FW-005, post-launch refactor 4-8 hr).
- **Q11** — Re-enable `prefer_const_*` linter rules (subset of FW-004).

### Other (1)
- **FW-010** — 26 providers eager-init at cold start. ~50 ms cumulative. Lazy-init opportunity, but correctness-risky. 2-3 hr if pursued.

## Low findings (5)

- **SEC-L-1** — `offline_mode` flag in unencrypted Hive — rooted-device read risk. Move to FlutterSecureStorage. Post-beta. 1-2 hr.
- **SEC-L-2** — No `dart pub audit` in CI/CD. Add to GitHub Actions security workflow. 30 min.
- **Q-L1** — 0 `unawaited()` calls; fire-and-forget at `identify_screen.dart:73`. Wrap. 5 min.
- **Q-L2** — 1 `print()` in committed code. Replace with `_log.info`. 5 min.
- **Q-L3** — Dart 3 sealed classes underutilized. Refactor opportunistically.

## GDPR pre-public-launch checklist

| Item | Status | Effort | Hard gate? |
|------|--------|--------|------------|
| Privacy policy published | ✗ | 2-3 hr | **YES** |
| Consent dialog wired (Lost Dog) | ✗ | 1-2 hr | **YES** |
| DPA with Supabase signed | ✗ | 1 wk wall time | **YES** |
| Data retention (90-day expiry RPC) | ✗ | 1 hr | YES |
| Contact-info "Request" flow / strip from RPC | ✗ | 2-5 hr | **YES** |
| Photo cleanup on `markFound`/`cancelReport` | ✗ | 1-2 hr | YES |
| Sighting GPS fuzzing (~500m) | ✗ | 1-2 hr | NO (nice-to-have) |
| RLS policy audit | ✗ | 30 min Jesse | **YES** |
| PII redaction in logs | ✗ | 1 hr | NO (pre-Sentry) |

**Total pre-public-launch GDPR work: 12-20 hr.**

## What's secure / fast (credit)

**Security**: Auth gate fix (sec-C1) intact; SightingSyncService dormant via `init()` throw (sec-C2); FastAPI backend gone (sec-C3); Hive sightings AES-256 encrypted with secure-storage-backed key; photo EXIF/GPS stripping via `image` package re-encode is implemented; FlutterSecureStorage for JWT (Keychain/Keystore-backed); dependencies modern and CVE-clean as of audit date.

**Performance**: TFLite inference offloaded to compute isolate; Hive boxes opened in parallel batches at startup (`main.dart:615-621`); 26-provider Riverpod graph dependency-clean and circular-free; resource lifecycle disciplined (81 dispose calls); splash crossfade smooth; geolocator only on user action (no background polling); analytics calls async non-blocking. Smart choice: lost-dog embedding extracted once at report time, not on every scan.

## Open questions for Jesse

These need your input before some findings can move from Open → Closed:
1. **`network_security_config.xml` content** — does the file exist? does it disallow cleartext? (SEC-H-4)
2. **Supabase RLS dashboard audit on `lost_dog_reports` / `lost_dog_sightings` / `friendships` / `packs`** (SEC-M-3, ~30 min). The C1 work covered `sightings` only.
3. **Lost Dog ship timeline** — closed-beta or defer? Drives whether SEC-C-Lost-1/2 are immediate or gated to pre-public-launch.
4. **Privacy policy** — does `dogquest.app` exist yet? Drafted? (SEC-C-Lost-2)
5. **Supabase DPA** — already signed? (SEC-C-Lost-2)

## Carry-forward to Phase 3 (testing & docs)

For Phase 3A (tests):
- Auth, lost_dog_*, photo_upload, embedding extraction have ZERO unit tests. Critical paths.
- Stream-leak fix (Q1) needs a regression test pattern (subscription cancel verified before super.dispose()).
- TFLite inference pipeline has limited test surface; isolate code is hard to test.
- `test/supabase_social_test.dart` has 30 broken mocks pending T5 rewire — known.
- `test/sync_services_test.dart` has 13 runtime failures pending T5 Ref-cast fix — known.

For Phase 3B (docs):
- Privacy policy is a Critical artifact (SEC-C-Lost-2) but it's a documentation deliverable.
- ADR backlog — none exist yet (`docs/adr/` empty). The lost-dog Decision 1/2/3 are ADR-shaped.
- README.md is now present (DOC-002 closed) but doesn't yet mention the GDPR posture / privacy policy URL placeholder.
