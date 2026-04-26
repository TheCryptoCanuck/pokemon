# Phase 2: Security & Performance Review

**Status**: complete. **3 Critical security findings**, 6 High security, 4 High performance, plus mediums.
**Strict-mode trigger**: **FIRED** — strict-mode requires halt at Checkpoint 1 with Critical findings.

Detailed findings:
- `.full-review/02a-security-findings.md` (security-auditor)
- `.full-review/02b-performance-findings.md` (performance-engineer)

## Security Findings

### Critical (3) — closed-beta blockers

- **C1 — Offline auth gate bypassable** (CWE-287). The `offline_mode` flag persists across sessions. An attacker (or an honest user in an unintended state) can log sightings while unauthenticated, which then sync to the wrong user. Earlier session work (TASK-043) hardened offline login but left the persistence path. Fix: invalidate the flag on auth success + verify ownership at sync time. **1–2 hours.**
- **C2 — SightingSync index-based local IDs** (CWE-434). Sync keys are array indices, not stable UUIDs. Reorders (deletion, reimport, box compaction) generate new UUIDs for existing rows → duplicates on Supabase, and worst case cross-user attribution. Fix: add immutable `localId` UUID to `Sighting` model, migrate existing entries, update sync logic. **2–3 hours.** *(Phase 1 architect-review independently identified this as FINDING-002.)*
- **C3 — Vestigial FastAPI backend partially exposed** (CWE-200). 2,173 LOC of unused FastAPI in `backend/`, with placeholder secrets and weak example auth, ships in the repo. Not deployed but increases surface area; if any deployment script accidentally picks it up, real exposure. Fix: delete or archive to a separate branch. **5–30 min.**

### High (6)

- H1 — Supabase anon key visible in source. Per Supabase design this is **not actually a vulnerability** (anon key is meant to be public; RLS enforces protection). Documentation gap, not a security gap. Action: add a comment in code explaining why this is intentional.
- H2 — `flutter_secure_storage` iOS implementation unverified (iOS untested per CLAUDE.md). Pre-iOS-launch checklist item.
- H3 — AdMob consent not validated at SDK init (GDPR compliance gap if EU-targeted).
- H4 — Sentry DSN unwired (TASK-050 still open). No crash visibility for closed beta.
- H5 — Offline sighting ownership not tracked (audit trail gap; relates to C1).
- H6 — No rate limiting on sync endpoints (Supabase-side; DoS risk pre-launch low).

### Medium (5)

- TFLite model integrity not verified at runtime (could be swapped); PII leakage risk in verbose logs; session expiry not actively validated; key rotation absent; dependency CVE scan not in CI.

### Low (3)

- Misc tech debt items.

## Performance Findings

### High (4)

- **P-H1 — TTA inference latency** estimated 1.2–1.5s per ID on-device (3-variant TTA on top of ~319ms base). Justified for accuracy headroom but **needs on-device validation** before beta — frame rate drops during inference would feel janky. Action: instrument `identify_screen.dart` capture flow with a frame-time check on a Pixel 5-class device.
- **P-H2 — SightingSync local ID bug** (same as security C2). Performance impact: duplicate sightings = redundant Supabase writes + bloated local Hive box. **Pre-beta blocker.**
- **P-H3 — Hive read caching** absent. Kennel grid + profile screen do 10–50 uncoordinated reads per frame; cumulative 10–250ms latency on screen open. Recommend instrumentation first to measure actual vs theoretical impact before refactoring.
- **P-H4 — Dual TFLite model loads at startup**. Both `tflite_identification_service` and `dog_embedding_service` load the same 23.8 MB model independently. Embedding is only used for lost-dog matching (low-traffic). Lazy-load embedding to save 0.5–1.0s startup. **30 min fix.**

### Medium (6)

- Pull sync queries lack `updated_at` indexes (5–10s first pull if Supabase tables grow).
- Kennel grid renders 200+ items without frame-time optimization.
- Conflict resolution complexity unanalyzed.
- Camera reinit pattern may leak memory under rapid captures (50-photo stress test recommended).
- AdMob interstitial load lacks timeout (5–10s delay on slow networks).
- Sync queue backoff lacks jitter (thundering herd risk).

### Low (3)

- Image preprocessing nested loop not vectorized (~15–30ms, low ROI).
- Embedding cosine similarity not SIMD-accelerated (acceptable).
- Cluster lookup is O(k) linear (k ≤ 6, sub-millisecond).

## Critical Issues for Phase 3 Context

To feed into testing + documentation reviewers:

1. **C1 + H5 (offline auth)** — testing must cover the offline → online → offline state-transition matrix; documentation must explain the auth gate's intended state machine.
2. **C2 / P-H2 (SightingSync)** — testing must include sighting deletion + reordering + sync; documentation must specify the local-ID contract.
3. **P-H1 (TTA latency)** — performance testing must include on-device frame-time benchmarks; documentation must note expected inference latency range.
4. **C3 (vestigial backend)** — documentation must clarify backend status (or delete).
5. **H4 (Sentry unwired)** — documentation should note operational observability gap.

## Recommendation for Checkpoint 1

**STRICT-MODE TRIGGER FIRED.** Three Critical security findings (C1, C2, C3). Per the skill protocol with `--strict-mode`, the recommendation is **option 2 (fix critical issues first before proceeding)**. The Phase 1 + 2 surfaces are the highest-density findings in the review; closing the Criticals before Phase 3+4 protects the rest of the review from being structured around dead code (vestigial backend) and broken assumptions (auth gate, sighting IDs).

Note: while this review ran, the agentic data-hygiene audit completed successfully (top-1 +14.8pt, top-3 +21.9pt, 5,082 quarantined, KEEP_SUCCESS). The Critical security findings are independent of that work — closing them is still required.

Estimated total effort to close all 3 Criticals: **3–5 hours.**
