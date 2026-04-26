# Phase 3B — Documentation Findings

**Review date**: 2026-04-25 (spanning code snapshot post 13-commit landing)  
**Mode**: Quality-first, strict, security-focus  
**Scope**: Repo-root docs, CLAUDE.md accuracy, inline code docs, API contracts, architecture docs, operational runbooks, vault organization

## Posture

DogQuest has **solid project intelligence** (CLAUDE.md is comprehensive and up-to-date post DOC-001 reconciliation). Inline docs are **unevenly distributed**: security-critical paths (SightingSyncService sec-C2, dog_found_dialog telemetry) are excellently documented, while model preprocessing rationale and API contracts exist only in code or offline. Documentation gaps are **not blockers for closed beta** but will create friction when scaling beyond solo dev — especially the missing Supabase API contract (if a second engineer joins the sync layer) and the absent ADR backlog (architectural decisions live in the vault and commit messages, not durable records). The vault (`.second_brain/`) is a **knowledge asset** but lacks a discoverable index. No critical security or correctness issues — all findings are hygiene + velocity improvements.

## Findings by severity

### Critical

**DOC-C-Privacy**: Standalone privacy policy document missing (per Phase 2A SEC-C-Lost-2)

- **What's missing**: A published privacy policy at `docs/PRIVACY_POLICY.md` or equivalent, suitable for public-facing documentation (Play Store listing, website). An in-app privacy-policy screen exists (`lib/screens/privacy_policy_screen.dart`) but serves closed-beta users, not Play Store compliance.
- **Risk**: Google Play Policy 5.2 requires a privacy policy URL at app-listing time. Without this, public launch is blocked. Pre-closed-beta, the risk is onboarding friction if external testers ask "where's your privacy policy?" The in-app policy partially addresses this but is not a substitute for a durable, web-accessible document.
- **Recommendation**: Create `docs/PRIVACY_POLICY.md` at repo root (or derive from in-app screen's content) with sections: Information Collection, Use of Data, Retention, User Rights (GDPR), Contact. Tag it as "Last updated: [date]". Link from README.md in the "Documentation" section. For Play Store, the URL is `https://github.com/user/dogquest/blob/main/docs/PRIVACY_POLICY.md` (or hosted on dogquest.app once registered).
- **Effort**: 1-2 hr (extract + enrich from in-app screen, add web metadata).

### High

**DOC-H-API**: Supabase API contract undocumented

- **What's missing**: The app syncs sightings to Supabase via a `sync_sightings` RPC. The wire format is defined in `lib/services/sighting_sync_service.dart` (_formatSightingPayload, lines 85-105), but there is no schema document for the RPC parameters, return type, or auth contract. The actual Supabase function definition exists only in Jesse's dashboard, not in the repo.
- **Risk**: If a second engineer joins the project and needs to extend sync (e.g., add a new field to sightings), they will reverse-engineer the contract from code or ask Jesse. Schema changes risk silent failures if the Dart client is not updated in sync with the server. For a Critical-security-context feature (sighting ownership is server-inferred per sec-C1), this is a dangerous gap.
- **Recommendation**: Create `docs/SUPABASE_API.md` with: **sync_sightings RPC** signature, payload schema (JSON example), auth contract (RLS policy enforces `auth.uid() = sightings.user_id`), return type. List other RPCs if they exist (get_active_lost_dogs, get_friendships, etc.). Note that this is post-sync-dormancy; BackendSyncService is the live integration point.
- **Effort**: 1-2 hr.

**DOC-H-ML-TTA**: TFLite preprocessing and TTA strategy underdocumented

- **What's missing**: `lib/services/tflite_identification_service.dart` has excellent class-level dartdoc but the `_preprocessImage()` method and TTA strategy lack explanation. A comment at line 20 reads "v5 TTA: 5-crop (center + 4 corners) x flip = 10 variants averaged" — this is the **old** approach, not the current 3-variant one. New implementers will be confused by the stale comment.
- **Risk**: When v7 model training begins or float16 export is pursued, engineers will re-invent these choices or miss the latency-accuracy trade-off rationale.
- **Recommendation**: Expand class dartdoc to include: TTA strategy ("v5.1 uses 3 center-crop variants: tight, tight-flipped, loose-context — chosen for <1.5s latency on Pixel 5 while recovering ~1–2pp from tighter crop"), Uint8List rationale (600KB vs 30–40MB for 3 variants), preprocessing stages (EXIF bake, scale, 3 variants, flatten). Update the stale comment at line 20 to reference the current approach.
- **Effort**: 30 min.

**DOC-H-Synonym-Clusters**: Synonym clustering not formally documented

- **What's missing**: 6 synonym clusters hardcoded in `lib/services/tflite_identification_service.dart` (e.g., cavalier_king_charles_spaniel ↔ blenheim_spaniel) have no justification. Why are these clusters present? How were they validated? Future contributors extending the clusters will have no guidance.
- **Risk**: Clusters may drift from the model's training data or user feedback over time. The Active_Tasks mentions "Define rules for downgrading 'Very confident' when top-3 includes the same breed cluster twice" — this rule does not exist in code, only in the task description.
- **Recommendation**: Create `docs/SYNONYM_CLUSTERS.md` with: cluster definitions (JSON or table), justification per cluster (e.g., "Cavalier + Blenheim: 95% visual similarity, model confusion on coat-color-dominant photos"), validation checklist (confmat reciprocal confusion, accuracy gain measurement, unit test), sync with Python audit script.
- **Effort**: 1 hr.

**DOC-H-Auth-SM**: Offline auth state machine not documented

- **What's missing**: Auth system supports both online (Supabase JWT) and offline (local Hive flag `offline_mode`). State transitions are scattered across LoginScreen, router.dart, SightingSyncService, and never formally defined. sec-C1 fix lives in code comments and task checklists, not in a durable state-machine spec.
- **Risk**: A new engineer implementing account-switching or session-recovery features will not understand the state transitions, introducing regressions. The test suite documents the happy path but not edge cases.
- **Recommendation**: Create `docs/AUTH_STATE_MACHINE.md` with: states (online, offline, transitioning), transitions (offline → online on login, online → offline on logout, online + offline_mode=true → safety-net clear), sync behavior (SightingSyncService dormant; BackendSyncService is live path), test matrix outline.
- **Effort**: 1-2 hr.

**DOC-H-ADR-Backlog**: No Architecture Decision Records

- **What's missing**: `docs/adr/` is empty. Decisions like "use Riverpod over BLoC", "Hive encryption key management", "lost-dog UUID fix approach (full migration vs. reduced scope)", "Sentry → Crashlytics swap" are documented in commit messages, task checklists, and the vault—not in durable ADRs.
- **Risk**: Future engineers (or AI code-review agents) cannot quickly understand why key choices were made. Decisions will be re-litigated or reinvented.
- **Recommendation**: Write ~5-8 ADRs capturing: (1) State Management (Riverpod chosen over BLoC + plain ChangeNotifier), (2) Lost Dog UUID architecture (reduced-scope dormancy of SightingSyncService), (3) Hive encryption (FlutterSecureStorage-backed AES for sightings), (4) Backend posture (local-first + Supabase planned), (5) Synonym clusters (Option B: hardcoded mapping vs. Option A: dynamic from model). ADR-0001 template: Title, Date, Status, Context, Decision, Rationale, Consequences, Alternatives. ~30 min per ADR.
- **Effort**: 3-4 hr total.

### Medium

**DOC-M-Quiz-Engine**: Quiz engine question types not documented

- **What's missing**: `lib/services/quiz_engine.dart` defines 13 question types (nameFromPhoto, photoFromName, etc.) with hardcoded XP values and difficulty labels. Semantics of each type and the design rationale are missing. Future engineers extending the quiz will have to reverse-engineer the implementation.
- **Risk**: Adding a new question type requires reading 30-50 lines of code. Task T2 (quiz redesign) is active, but the engine's design space is undocumented.
- **Recommendation**: Create `docs/QUIZ_ENGINE.md` with: table mapping type → prompt → difficulty → why → XP, design rationale ("Easy questions cluster at 15–20 XP; expert at 30–35 XP"), extending the engine (step-by-step guide to add a new type).
- **Effort**: 1-2 hr.

**DOC-M-Vault-Index**: Vault organization lacks master index

- **What's missing**: `.second_brain/` is well-organized (System, Memory, Context, Projects, Knowledge, etc.) and has a Retrieval_Map.md, but there is no master index listing all 40+ markdown files with one-line summaries. Searching for a concept (e.g., "quantization", "embedding", "conflict resolution") requires grepping or guessing the file name. New contributors don't know if `Decisions.md` is fresh or stale (edit dates are not visible without checking).
- **Risk**: Vault is a knowledge asset but feels like a private note system. A second engineer would benefit from a single entry point: "Start here → read Strategy → read Active_Tasks → explore by topic."
- **Recommendation**: Create `.second_brain/README.md` or `.second_brain/00_System/INDEX.md` with: critical reading order (this file → Strategy → Active_Tasks → Decisions), by-topic index (ML / Model Training, Security, Architecture, Testing, Performance, etc.), timestamps on status sections. Schedule end-of-session updates to `.second_brain/03_Projects/DogQuest.md` in Memory_Maintenance_Protocol.md.
- **Effort**: 1-2 hr.

**DOC-M-CLAUDE-Model-Drift**: CLAUDE.md drifted on model preprocessing specs

- **What's missing**: CLAUDE.md line 93 states "Image preprocessing: EXIF bakeOrientation + scale + 5-crop + resize (260x260 for v5, 300x300 for v6)". But the deployed v5.1 uses **3-crop** (center tight, center flipped, center zoomed-out), not 5-crop. Line 94 ("v5 TTA: 5-crop (center + 4 corners) x flip = 10 variants averaged") is the old approach. This is corrected in tflite_identification_service.dart comment at line 20, but CLAUDE.md is now inconsistent with the code.
- **Risk**: New contributors reading CLAUDE.md will misunderstand the preprocessing pipeline. The spec is marked "Critical Technical Notes" — the gap undermines trust in that section.
- **Recommendation**: Update CLAUDE.md lines 93-94 to: "Image preprocessing: EXIF bakeOrientation + scale + center-crop (3 variants: tight, tight-flipped, loose-context) + resize (260x260 for v5, 300x300 for v6). v5.1 TTA: 3-variant average (chosen for <1.5s latency on Pixel 5; prior v5 used 10-variant for +2–3pp)."
- **Effort**: 15 min.

**DOC-M-Makefile-Setup**: Makefile targets and environment variables not documented

- **What's missing**: Makefile has 30+ targets (run `make help` to see them), but environment variables (`--dart-define=SUPABASE_URL=...`, `SENTRY_DSN`, etc.) are not documented. Prerequisites (ADB, Flutter, Python) are implicit. No `make doctor` target exists to validate the build environment.
- **Risk**: New developer runs `make deploy` without ADB set up, gets a cryptic error. Five-minute troubleshooting guide would save time.
- **Recommendation**: (1) Add `make doctor` target to Makefile to validate flutter, adb, python3, connected devices. (2) Create `docs/SETUP.md` with prerequisites (Flutter 3.16+, Dart 3+, Android SDK, Python 3.9+), required env vars, troubleshooting (ADB not found, device not detected, build fails), pointer to Makefile targets.
- **Effort**: 1-2 hr.

**DOC-M-Quantization-Impl**: Quantization headroom research incomplete for implementation

- **What's missing**: `docs/session_2026-04-26/quantization_headroom_research.md` provides excellent research and a recommendation (float16 TFLite export, 3–5 hours, +8–9pp expected accuracy recovery). However, the **implementation plan** is sketched but not step-by-step (which flags for export_tflite.py, how to validate float16 on device, fallback strategy if float16 is slower than uint8).
- **Risk**: When T3 task activates and float16 export begins, the implementer will need to cross-reference CLAUDE.md and infer the process. A checklist in the research doc would reduce friction.
- **Recommendation**: Append to quantization_headroom_research.md: Implementation Checklist (T3) with step-by-step tasks: export TFLite with `--quantization_type=float16`, file size validation (~20 MB), latency test on Pixel 5 class device, accuracy gate (≥+8pp recovery from -9.4pp headroom), fallback if latency > uint8 + 50ms, "Dalmatian canary" test, commit + code comment.
- **Effort**: 30 min.

### Low

**DOC-L-README-GDPR**: README mentions privacy policy but link is missing

- **What's missing**: README.md line 73–79 (Documentation section) does not mention the privacy policy or link to the GDPR pre-launch checklist (Phase 2A). For a game handling location data and user-generated content (Lost Dog reports), this is conspicuous by absence.
- **Risk**: Low — README is complete for engineering onboarding. But for compliance tracking, a link to the privacy policy (once published) or a "Security & Privacy" section would help external reviewers.
- **Recommendation**: Add to README.md Documentation section: "- **`docs/PRIVACY_POLICY.md`** — privacy policy covering data collection, retention, user rights (GDPR). Required for Play Store listing."
- **Effort**: 5 min.

**DOC-L-SEC-C3-Comment**: .gitignore sec-C3 comment references offline Active_Tasks

- **What's missing**: .gitignore line 35-39 has the backend/ block with a comment "Vestigial FastAPI backend (sec-C3) — Supabase is the live backend." But the comment does not reference the full security fix (commit `aaebc5d`). A future contributor removing the block might not understand the security rationale.
- **Risk**: Low — the comment exists and is reasonably clear. Phase 3B Phase 3A found this acceptable and DOC-004 is already closed. Remark: this was DOC-004 in the archived review; status: closed.
- **Recommendation**: No change needed; the existing comment is sufficient.
- **Effort**: 0 hr (closed).

## ADR Backlog

The following architectural decisions should be captured as ADRs in `docs/adr/`:

1. **ADR-0001: State Management Architecture** — Why Riverpod (code-gen, lazy-init, testing) over BLoC (boilerplate) or plain ChangeNotifier (limited scope). Date: ~2026-03-01 (app fork). Status: Accepted.

2. **ADR-0002: Lost Dog Sync UUID Architecture** — Reduced-scope dormancy of SightingSyncService (init() throws) pending full migration of localId field onto Sighting model. Decision rationale: avoid data loss during cross-device sync. Date: 2026-04-25. Status: Accepted (pending follow-up).

3. **ADR-0003: Hive Encryption Strategy** — FlutterSecureStorage-backed AES key for `dogquest_sightings_v1` box. Why not encrypt all Hive boxes? Risk/effort trade-off for beta scale. Date: ~2026-03-01. Status: Accepted.

4. **ADR-0004: Backend-First Posture** — Local-first Hive storage as primary; Supabase planned for real-time social + auth. Decision: ship locally-functional MVP before backend lock-in. Date: ~2026-03-01. Status: Proposed (Supabase migration phase pending).

5. **ADR-0005: Synonym Clusters (Option B)** — Hardcoded breed-name mapping over dynamic extraction from model confmat. Why: predictability + offline-first. Caveat: requires manual maintenance. Date: 2026-04-25. Status: Accepted.

6. **ADR-0006: Image Preprocessing (3-Crop TTA)** — Test-time augmentation with 3 center-crop variants (vs. prior 10-crop). Trade-off: <1.5s latency on mid-range devices vs. 2–3pp accuracy. Date: ~2026-04-20. Status: Accepted.

7. **ADR-0007: Sentry → Crashlytics Migration** — Dependency swap from Sentry to Firebase Crashlytics for observability. Rationale: Firebase ecosystem alignment (Analytics already present), simpler DSN management. Date: 2026-04-25. Status: In Progress (DSN wiring is T1).

8. **ADR-0008: Model Float16 Export (T3)** — Future decision gate: float16 TFLite quantization for +8–9pp accuracy recovery pending latency validation on device. Affects v6 deployment readiness. Date: 2026-04-26 (planned). Status: Pending.

## Pre-public-launch doc deliverables

From Phase 2A SEC-C-Lost-2, these are hard gates for public Play Store launch:

| Deliverable | Status | Effort | Hard gate? |
|---|---|---|---|
| Published privacy policy | ✗ (in-app only) | 1-2 hr | **YES** |
| ADR backlog (architecture decisions durable) | ✗ | 3-4 hr | NO (hygiene) |
| Supabase API contract documented | ✗ | 1-2 hr | NO (internal) |
| Setup/onboarding guide (SETUP.md) | ✗ | 1-2 hr | NO (nice-to-have) |

## What's well-documented

**Credit**: CLAUDE.md is unusually strong for a solo-dev project — comprehensive tech stack, feature breakdown, 294-breed ML pipeline, known issues, code conventions, all up-to-date post-reconciliation. The vault (`.second_brain/`) is exceptionally well-organized: Active_Tasks is the live runbook, Decisions.md is coherent, Failure_Patterns is a knowledge asset. Inline docs on security-critical paths (SightingSyncService sec-C2, dog_found_dialog telemetry) are excellent. The 22-test suite is well-named and self-documenting. README.md (DOC-002, closed 2026-04-25) is solid and captures the project quickly. Session-dated docs in `docs/session_2026-04-25/`, `docs/session_2026-04-26/` are detailed and specific (lost_dog_improvements_spec.md, quiz_redesign_spec.md, quantization_headroom_research.md).

## Confidence audit

- **DOC-C-Privacy, DOC-H-API, DOC-H-ADR-Backlog**: Solid (verified against Phase 2A, repo structure, active task tracking).
- **DOC-H-ML-TTA, DOC-H-Synonym-Clusters**: Solid (verified against tflite_identification_service.dart code and CLAUDE.md drift).
- **DOC-M-Vault-Index**: Solid (vault structure confirmed; lack of index verified via no `INDEX.md` or similar).
- **DOC-M-CLAUDE-Model-Drift**: Solid (line-by-line verification of CLAUDE.md vs. code).
- **DOC-M-Makefile-Setup**: Solid (Makefile confirmed to have no doctor target; prerequisites implicit).

All findings are **verified against source**, not inferred.

---

**Total estimated effort to close all findings**: ~15-20 hr.  
**Blockers for closed beta**: DOC-C-Privacy (if external testers ask). All others are internal velocity improvements.  
**Blockers for public launch**: DOC-C-Privacy (Play Store policy requirement).
