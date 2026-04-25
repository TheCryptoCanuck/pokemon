# Phase 1: Code Quality & Architecture Review

**Status**: complete. 0 Critical findings. 5 High, 11 Medium, 2 Low.
**Strict-mode trigger**: not fired (no Critical). Proceed to Phase 2.

Detailed findings live in:
- `.full-review/01a-code-quality-findings.md` (code-reviewer)
- `.full-review/01b-architecture-findings.md` (architect-review)

This file consolidates and routes findings to downstream phases.

## Code Quality Findings

### High (3)

- **H1 — Late var injection pattern.** Several services use manual `setDogService()` calls in `main.dart` rather than Provider-based construction → fragile ordering dependencies. Effort: medium. Defer to post-beta.
- **H2 — Five service files remain >800 LOC.** `breed_collection_service.dart`, `dog_group_service.dart`, `daily_challenge_service.dart`, `dog_mastery_service.dart`, `dog_social_service.dart`. Pattern from `quiz_screen` / `map_tab` decomposition applies. Defer to post-beta.
- **H3 — Cluster table drift risk** between Dart `dogQuestSynonymClusters` and Python `SYNONYM_CLUSTERS`. Already documented in `Failure_Patterns.md`. Mitigation: add a checklist item to verify sync at launch.

### Medium (6)

- M1 — Identification error handling lacks error-type categorization (rolls up under broad `catch`).
- M2 — Ad-hoc logging mixed with structured `_log` patterns; lose composability for downstream log routing.
- M3 — `DogEmbeddingService` undocumented (embedding space, similarity threshold justification).
- M4 — Label cache lookups don't assert target exists; silent null-return path.
- M5 — `DogService` alias map (347 entries) lacks startup validation against `dog_labels.txt`.
- M6 — Test harnesses originally landed in Cowork sandbox; **fixed this session** (now in `outputs/` in repo) but pattern worth a note for future tooling.

### Positive findings

- ✓ Synonym clustering Option B is well-architected with 95-test coverage
- ✓ TFLite pipeline correct (uint8 handling, TTA, entropy gating)
- ✓ Counter dissonance fix at `dog_found_dialog.dart:280` is correct
- ✓ 95-test suite uses logic-mirror pattern (excellent for testing private methods)
- ✓ Consistent Riverpod patterns and naming throughout

## Architecture Findings

### High (2)

- **FINDING-001 — `backend/` FastAPI is vestigial.** 2,173 LOC of unused FastAPI exists alongside the live Supabase backend. Recommended: archive to a separate branch or delete. Effort: 30 min. **Defer to post-beta** (no harm in carrying it during beta but clean before public launch).
- **FINDING-002 — `SightingSyncService` uses fragile index-based local ID mapping.** Local IDs are array indices (0, 1, 2…) not stable UUIDs. If sightings reorder due to deletion/reimport, sync generates duplicate entries. **Actionable BEFORE closed beta** — closed-beta users trigger this exact code path. Fix: add `localId` field to `Sighting` model, assign UUIDs at creation. Effort: 2–3 hours.

### Medium (5)

- FINDING-003 — Synonym clustering has no formal validation that cluster[0] preferred names exist in dogs.json. Runtime fallback exists with warning log, but compile-time / startup-time assertion would be cleaner. Effort: 45 min.
- FINDING-004 — `TfliteIdentificationService` has implicit dependency on `DogService` load order. Add assertion. Effort: 15 min.
- FINDING-005 — Five god-class screens >800 LOC (`identify_screen.dart` 1,242, `profile_screen.dart` 1,454, etc.). Known. Defer to post-beta.
- FINDING-006 — `ConflictStrategy` enum has semantically redundant `serverSourceOfTruth` vs `serverWins`. Rename. Effort: 10 min.
- FINDING-007 — `IdentificationOrchestrator` couples 20+ services. Acceptable for orchestrator pattern; well-tested.

### Low (2)

- FINDING-008 — Router auth gate checks both Supabase session and Hive offline flag (works, slightly redundant).
- FINDING-009 — TTA is compile-time constant; runtime toggle would help debugging.

## Critical Issues for Phase 2 Context

Findings to feed into Phase 2 (security + performance) reviewers:

1. **FINDING-002 (SightingSync index-based local IDs)** — security reviewer should check if this causes data integrity issues across user accounts; performance reviewer should check how the sync queue handles the duplicate scenario at scale.
2. **M1 (error categorization)** — relevant to security: are auth/network errors leaking info? Relevant to performance: are caught-and-ignored errors hiding bottlenecks?
3. **M3 (DogEmbeddingService undocumented)** — performance: is the embedding similarity loop O(n) or O(n²)?
4. **FINDING-001 (vestigial backend/)** — security: if `backend/` happens to be reachable from any deployment artifact, that's a real exposure. Verify it's not packaged into the APK or bundled anywhere.
5. **M5 (alias map drift)** — performance impact of 347 misses on identification path?

## Recommendation for Checkpoint 1

**Strict-mode is enabled. No Critical findings → no auto-halt.** However:

- **One pre-beta blocker surfaced**: FINDING-002 (SightingSync local IDs) should be fixed before closed-beta distribution. 2–3 hours.
- Recommend Continue to Phase 2 — security + performance findings may add more pre-beta items, and a single consolidated triage at the final report is cleaner than mid-flight halts.

If Phase 2 surfaces additional Critical findings, the post-Phase-2 checkpoint will have full strict-mode authority to halt.
