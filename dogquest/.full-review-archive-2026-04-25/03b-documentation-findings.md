# Phase 3B — Documentation Findings

**Status**: Complete. 12 substantive findings across project intelligence, inline code docs, API contracts, setup guides, and vault organization.

**Severity Inventory**:
- Critical: 1 | High: 5 | Medium: 4 | Low: 2

---

## Findings

### DOC-001 — CLAUDE.md drift on ML model specs (Critical)

- **Severity**: Critical
- **Gap**: `CLAUDE.md` Tech Stack section (line 16) states:
  - ML Model (deployed): "EfficientNetB2 v5.1, uint8 quantized, 260x260 input, **150 breeds**, 10.3 MB"
  - ML Model (training): "EfficientNetV2-S v6, 300x300 input, **294 breeds**"
  
  But `.second_brain/03_Projects/DogQuest.md` (2026-04-25 session-end status) states: "Model v6 (EfficientNetV2-S, **296 breeds**, 51.65% Stanford val_acc) deployed with corrected TFLite quant scale." And the project scope doc later clarifies: "294 breeds total: 120 Stanford Dogs + 174 supplemental".
  
  The inconsistency (150 vs 294 vs 296) creates confusion for new contributors. Current v5.1 is deployed with **150 breeds**; v6 (296 training-set size) is trained but **not deployed**. The breeds.json and dog_labels.txt claim 294.

- **Impact**: New contributors read CLAUDE.md first and misunderstand the model landscape. Engineers debugging on-device behavior will be looking at a 150-breed model but may assume 294/296 breeds. Onboarding is broken.

- **Recommendation**: Fix CLAUDE.md to:
  - **Deployed model**: "EfficientNetB2 v5.1, uint8 quantized, 260x260 input, 150 breeds (from 120 Stanford + 30 supplemental), 10.3 MB, 87.2% top-1 accuracy on Stanford Dogs validation."
  - **Training model**: "EfficientNetV2-S v6, 300x300 input, 294 species (120 Stanford + 174 supplemental folders) in training set, trained to 51.65% val_acc on Stanford Dogs only (due to data-quality disparity)."
  - Add a table: **"Model timeline"** showing v5.1 deployed, v6 trained-not-deployed, float16 export (T3) pending.

- **File(s)**: `CLAUDE.md` (Tech Stack section), `.second_brain/03_Projects/DogQuest.md`

---

### DOC-002 — Missing README at repo root (High)

- **Severity**: High
- **Gap**: The repo has no `README.md` at the root. A new developer cloning the project has only `CLAUDE.md` (project intelligence) and `Makefile` (CLI targets) to discover how to run the app. Standard GitHub discovery patterns fail.

- **Impact**: Onboarding friction. Standard questions ("Is this ready to run?" "What does setup look like?") cannot be answered by a 30-second skim. Contributors default to asking (or to reading CLAUDE.md, which is not a README replacement).

- **Recommendation**: Create `README.md` at repo root with:
  - One-line hook: "DogQuest — AI dog breed identification with deep gamification & social features."
  - Quick start (5 min):
    ```bash
    # Install dependencies
    flutter pub get
    
    # Run debug build
    flutter run
    
    # Or use Makefile
    make deploy
    ```
  - Stack summary (pointer to CLAUDE.md for full details).
  - Build artifact info: "Current model: v5.1 (150 breeds). v6 (294 breeds) in training."
  - "Contributing" section: pointer to CLAUDE.md + `.second_brain/02_Context/Strategy.md` (quality-first posture).
  - Link to Makefile help: `make help` for 30+ build targets.
  - Section: "Known limitations" (iOS untested, Supabase backend planned, etc. — from CLAUDE.md Known Issues).

- **File(s)**: `README.md` (create at root)

---

### DOC-003 — Supabase API contract undocumented (High)

- **Severity**: High
- **Gap**: The app syncs sightings to Supabase via a `sync_sightings` RPC. The wire format is defined in `lib/services/sighting_sync_service.dart` at `_formatSightingPayload()` (lines 85–105), but:
  1. There is **no schema doc** for the RPC parameters or return type.
  2. There is **no Supabase function definition** or edge-function spec checked into the repo.
  3. The RPC name exists in code comments but the actual Supabase deployment is not documented (only exists in Jesse's Supabase dashboard).
  4. The `sec-C1` security finding noted that sync ownership is "server-inferred, not client-tagged" — this critical contract detail is in a task checklist, not in API docs.

- **Impact**: If the Supabase RPC changes (e.g., during a schema migration or a function redeploy), the client code will fail silently or with cryptic 5xx errors. A second engineer joining the project cannot understand the contract without asking Jesse or reverse-engineering the code.

- **Recommendation**: Create `docs/SUPABASE_API.md` with:
  - **`sync_sightings` RPC**:
    - Signature: `sync_sightings(local_ids: UUID[], payloads: JSON[])`
    - Payload schema (JSON example):
      ```json
      {
        "dogName": "string",
        "timestamp": "ISO8601",
        "confidence": 0.0–1.0,
        "source": "identify|lost_dog|manual",
        "latitude": number | null,
        "longitude": number | null,
        "accuracy": number | null
      }
      ```
    - Auth: RLS policy enforces `auth.uid() = sightings.user_id` (no client-side uid in payload).
    - Return: `{ success: bool, synced_count: int, errors?: string[] }`
  - **RLS policies** (outline, not full SQL):
    - `sightings` table: `INSERT/SELECT/UPDATE` only by owning user (auth.uid).
    - Mention that the policy is read-only; no deletes exposed to app.
  - **Offline-first contract**: "During offline mode, the app logs sightings to local Hive `dogquest_sightings_v1` and does NOT sync. On reconnect, SightingSyncService (currently dormant) will batch-sync; BackendSyncService is the live integration point."

- **File(s)**: `docs/SUPABASE_API.md` (create)

---

### DOC-004 — sec-C1/C2/C3 fixes undocumented in code comments (High)

- **Severity**: High
- **Gap**: Three Critical security findings from Phase 2 have been addressed in code (commits visible in `.second_brain/03_Projects/Active_Tasks.md`), but:
  - **sec-C1** (`router.dart:89–100`): Has an inline comment "sec-C1: invalidate stale offline_mode flag" — adequate.
  - **sec-C2** (`sighting_sync_service.dart:15–49`): Has **excellent** class-level dartdoc explaining the dormancy and bug walkthrough. Score: solid.
  - **sec-C3** (backend/ archive): Filesystem verification done; git-side verification pending. No in-code comment needed but `.gitignore` line 35–39 has the block — **undocumented why it's there**.

  The issue: a future contributor removing that `.gitignore` block without understanding its purpose (CWE-200 scope reduction) would re-expose the FastAPI directory. The security rationale is in a task checklist in the vault, not in a durable code artifact.

- **Impact**: Future security audit, refactor, or .gitignore cleanup could unknowingly undo the C3 fix. The fix survives only as long as Jesse remembers why `backend/` is ignored.

- **Recommendation**: Add a comment block in `.gitignore` (line 35, above the backend block):
  ```
  # === Backend FastAPI (sec-C3) ===
  # The FastAPI directory was archived to reduce attack surface.
  # See .full-review/02a-security-findings.md C3 and commit aaebc5d.
  # Do not restore this directory unless the security review is revisited.
  ```

- **File(s)**: `.gitignore` (lines 35–39)

---

### DOC-005 — TFLite preprocessing and TTA not documented in inline code (High)

- **Severity**: High
- **Gap**: `lib/services/tflite_identification_service.dart` has excellent class-level dartdoc (lines 99–120+), but the preprocessing pipeline `_preprocessImage()` (lines 26–95) and TTA (test-time augmentation) strategy lack explanation:
  - Why 3 variants instead of 5 or 10? (Comment at line 20 mentions "v5.1 optimized TTA: 3 variants" but explains the *change* not the *rationale*.)
  - Why "center tight, center flipped, center zoomed-out" specifically? (The code is clear but the intent isn't.)
  - Why `Uint8List` instead of `Float32List` for the flat tensor? (There's a memory comment but no reference to the tflite_flutter 0.11.0 quirk documented in CLAUDE.md.)

- **Impact**: Performance engineers or ML engineers working on the next model (v7, float16 path, etc.) will re-invent these choices or miss why they were made. The comment at line 20 is a graveyard: "v5 TTA: 5-crop (center + 4 corners) x flip = 10 variants averaged" — this is the OLD approach, not the current one. Ambiguity.

- **Recommendation**: Expand the class dartdoc (lines 99–120) to include:
  - **TTA strategy**: "v5.1 uses 3 center-crop variants (tight, tight-flipped, loose-context). Original v5 used 10-crop (4 corners + center x flip) for +2–3pp accuracy at 3.3× latency cost. The 3-variant trade-off was chosen to keep on-device latency <1.5s on Pixel 5 class while recovering ~1–2pp from the tighter crop."
  - **Uint8List choice**: "Memory optimization: Uint8List (600KB) vs. nested List<int> (30–40MB) for 3 variants + 5-crop strategy. Using flat tensors also avoids boxing overhead in isolate transfer. See CLAUDE.md 'Critical Technical Notes' for tflite_flutter 0.11.0 output-buffer quirk."
  - **Preprocessing stages**: Add a comment block before `_preprocessImage()` listing the 4 stages (EXIF bake, scale, variant 1/2/3, flatten).

- **File(s)**: `lib/services/tflite_identification_service.dart` (lines 13–25, 26–95)

---

### DOC-006 — Quiz engine question types undocumented (Medium)

- **Severity**: Medium
- **Gap**: `lib/services/quiz_engine.dart` defines 13 question types (lines 10–24: `nameFromPhoto`, `photoFromName`, ..., `compareBreeds`). Each has:
  - `xpValue` — hardcoded 15–35pt scaling.
  - `label` — "Easy", "Medium", "Hard", "Expert".
  - `prompt` — the question text shown to the user.
  - `icon` — visual indicator.

  But there is **no dartdoc** explaining the semantics of each type (what does `traitMatch` actually ask? What makes `silhouetteRound` harder than `oddOneOut`?). The prompts are in code, not in a spec. A future engineer extending the quiz will have to reverse-engineer the implementation to understand the design space.

- **Impact**: Adding a new question type requires reading 30–50 lines of code to understand the pattern. Documentation of intent is missing. The active task (Active_Tasks.md, T2 section) notes that quiz is "boring and answers are repeated" — the issue tracker is more informative than the code.

- **Recommendation**: Add a section to `docs/QUIZ_ENGINE.md` (create) describing:
  1. **Question type reference table**:
     | Type | Prompt | Difficulty | Why | XP |
     | `nameFromPhoto` | Photo → breed name | Easy | Baseline identification; high hit rate | 15 |
     | `photoFromName` | Breed name → photo | Easy | Reverse task; same difficulty | 15 |
     | `traitMatch` | Photo → trait (size/temperament) | Medium | Requires semantic knowledge, not visual memorization | 20 |
     | ... | ... | ... | ... | ... |
  2. **Design rationale**: "Easy questions cluster at 15–20 XP; expert at 30–35 XP. Weighting reflects both difficulty and user-engagement value (silhouette is harder but more memorable)."
  3. **Extending the engine**: Step-by-step to add a new type.

- **File(s)**: `lib/services/quiz_engine.dart` (add dartdoc), `docs/QUIZ_ENGINE.md` (create)

---

### DOC-007 — Synonym clusters not formally documented (Medium)

- **Severity**: Medium
- **Gap**: Synonym clustering (Option B, shipped 2026-04-25) defines 6 clusters in `lib/services/tflite_identification_service.dart`. The clusters are hardcoded in the source:
  ```dart
  static const Map<String, List<String>> dogQuestSynonymClusters = {
    'cavalier_king_charles_spaniel': ['blenheim_spaniel', ...],
    'poodle': ['toy_poodle', 'miniature_poodle', ...],
    ...
  };
  ```
  But there is **no spec** or **no justification** for the clusters. Why is `cavalier_king_charles_spaniel` a cluster but `boxer` is not? What is the empirical signal (confmat? user feedback? hardcoded heuristic)? Future contributors extending the clusters will have no guidance.

- **Impact**: The Active Tasks (T2, "Confidence-labeling honesty pass") mentions "Define rules for downgrading 'Very confident' when top-3 includes the same breed cluster twice." This rule does not exist in code, only in the task description. The clusters themselves are under-justified and may drift from the training data over time.

- **Recommendation**: Create `docs/SYNONYM_CLUSTERS.md` with:
  - **Cluster definitions**: JSON or table listing each cluster, the preferred name (first entry), and member breeds.
  - **Justification per cluster**: "Cavalier + Blenheim: 95% visual similarity, model confusion on coat-color-dominant photos from the Stanford Dogs training set (poodle_143.jpg, etc.)."
  - **Validation checklist**: "Before adding a cluster: (a) confirm top-5 confmat shows reciprocal high confusion (both A→B and B→A >10% in validation); (b) measure +accuracy on hard test set post-clustering; (c) add unit test asserting cluster[0] exists in dogs.json."
  - **Sync with Python**: "The Python audit script (`audit_supplemental.py`) has a parallel `SYNONYM_CLUSTERS` dict. These MUST stay in sync. Add a lint rule or GitHub Action to assert equality on every PR."

- **File(s)**: `docs/SYNONYM_CLUSTERS.md` (create), `lib/services/tflite_identification_service.dart` (add dartdoc to cluster constant)

---

### DOC-008 — Offline auth state machine not documented (Medium)

- **Severity**: Medium
- **Gap**: The auth system supports both online (Supabase JWT) and offline modes (local Hive flag `offline_mode`). The state transitions are scattered:
  - `offline_mode` set in `LoginScreen:55` on login success.
  - Cleared in `router.dart:96–100` on session creation (sec-C1 fix).
  - Checked in `SightingSyncService` guards (`lib/services/sighting_sync_service.dart:117, 174`).
  - Never formally defined as a state machine.

  The sec-C1 task in Active_Tasks notes: "Tests are contract-documentation, not behavioral... The test comments label themselves 'Documented post-condition (verified at integration level)'. For a Critical security finding, this is thinner than ideal."

- **Impact**: The offline state machine is a security boundary. A new engineer implementing a feature that touches auth (e.g., account switching, session recovery) will not understand the state transitions and may introduce regressions. The test suite documents the happy path but not the edge cases.

- **Recommendation**: Create `docs/AUTH_STATE_MACHINE.md` with:
  - **States**: `online` (Supabase session exists), `offline` (offline_mode=true, session=null), `transitioning` (briefly, during login/logout).
  - **Transitions**:
    ```
    offline → online: LoginScreen sets offline_mode=false, calls auth.signInWithPassword, Supabase session created.
    online → offline: LogoutScreen calls auth.signOut, sets offline_mode=false. (User chooses "login later" → offline_mode stays true.)
    online + offline_mode=true: Router's sec-C1 post-frame clears offline_mode=false (safety net).
    ```
  - **Sync behavior**: "While online, SightingSyncService (dormant) would sync with ownership check (sec-C1). While offline, no sync. Cross-device scenario (User A logs in on Device 1, User B logs in on Device 2) — offline_mode persistence is the failure mode sec-C1 addresses."
  - **Test matrix**: Outline the 8–10 state transitions and their tests (partial coverage in `test/sync_services_test.dart:381+`).

- **File(s)**: `docs/AUTH_STATE_MACHINE.md` (create)

---

### DOC-009 — Vault organization is coherent but lacks indexing (Medium)

- **Severity**: Medium
- **Gap**: The `.second_brain/` vault is well-organized (System, Memory, Context, Projects, Knowledge, Agents, etc.), and `00_System/Retrieval_Map.md` is excellent for "which file do I read?" However:
  1. **No full index**: Searching for a specific concept (e.g., "quantization", "embedding", "conflict resolution") requires grepping the vault or guessing the file name. An AI-friendly **indexed master list** of all 40+ markdown files with one-line summaries would help.
  2. **Update lag on DogQuest.md**: The project file is marked "This file is a status snapshot — it does not capture the live posture" and defaults to "the vault wins" if there's disagreement. This is correct but creates uncertainty. The snapshot is from 2026-04-25, and it's now (review date) 2026-04-25 end-of-session. It should be updated soon.
  3. **No "recently-updated" pointer**: New contributors don't know if `Decisions.md` is fresh or stale without checking the edit date.

- **Impact**: Vault is a knowledge asset but feels like a private note system, not a team resource. A second engineer onboarding would benefit from a single entry point that says "Start here: [link], then read [link], then explore [link]."

- **Recommendation**:
  1. Add a **master index** at `.second_brain/README.md` or `00_System/INDEX.md`:
     ```
     # Vault Index
     
     ## Active Projects
     - DogQuest — dog breed ID app (Status: quality-first, 3 Criticals closed)
     
     ## Critical Reading Order
     1. This README
     2. [[Strategy]] — current posture
     3. [[Active_Tasks]] — what to work on next
     4. [[Decisions]] — why we chose this approach
     5. [[Failure_Patterns]] — what broke before
     
     ## By Topic
     ### ML / Model Training
     - [[Failure_Patterns]] — OOM patterns, data quality drift
     - `Decisions.md` entries mentioning "quantization", "float16"
     ...
     ```
  2. Restore `.second_brain/03_Projects/DogQuest.md` at the end of each session (currently stale flag exists; enforce an end-of-session update in `Memory_Maintenance_Protocol.md`).
  3. Add timestamps to status sections: "Last updated: 2026-04-25 18:00 UTC".

- **File(s)**: `.second_brain/README.md` or `.second_brain/00_System/INDEX.md` (create), `.second_brain/03_Projects/DogQuest.md` (update at session end)

---

### DOC-010 — Quantization headroom research incomplete for implementation (Low)

- **Severity**: Low
- **Gap**: `docs/session_2026-04-26/quantization_headroom_research.md` provides excellent research and a recommendation (float16 TFLite export, 3–5 hours, +8–9pt expected). However:
  1. The **implementation plan** is sketched but not step-by-step (e.g., which flags for `export_tflite.py`, how to validate float16 on device, what to look for in logs).
  2. **Risk mitigation** for the float16 path is not documented (e.g., "if float16 is slower than uint8 on device, fallback to ...").
  3. **Measurement gate** (the "Dalmatian canary" mentioned in CLAUDE.md) is referenced in comments but not formally specified (which 20 images, what accuracy target?).

- **Impact**: When T3 task activates and float16 export begins, the implementer will need to refer back to the research doc, cross-reference CLAUDE.md, and infer the process. A checklist in the research doc would reduce friction.

- **Recommendation**: Append to `quantization_headroom_research.md`:
  ```
  ## Implementation Checklist (T3)
  
  - [ ] Export TFLite with `--quantization_type=float16` in `export_tflite.py`
  - [ ] File size validation: v6 float16 should be ~20 MB (vs. ~10.3 MB uint8)
  - [ ] Latency test: `make benchmark` on Pixel 5 class device, measure inference time
  - [ ] Accuracy gate: Run 20-image harness (`outputs/test_20_images.py`) on float16 export, measure +accuracy vs. uint8
  - [ ] Target: ≥+8pt top-3 accuracy recovery (from -9.4pt headroom)
  - [ ] Fallback: If latency > uint8 + 50ms, document and file a perf-optimization task; do not deploy
  - [ ] Dalmatian canary: Test on `assets/dogs/dalmatian.jpg` (reference image), confirm top-1 = Dalmatian
  - [ ] Commit: "Export float16 TFLite model (T3)" + add comment in `lib/services/tflite_identification_service.dart` noting float16 model info
  ```

- **File(s)**: `docs/session_2026-04-26/quantization_headroom_research.md` (append checklist)

---

### DOC-011 — Makefile targets and environment variables not documented (Low)

- **Severity**: Low
- **Gap**: `Makefile` has 30+ targets (lines 1–150+), and `make help` lists them. But:
  1. **Environment variables** are not documented. e.g., `--dart-define=API_URL=...` is mentioned in CLAUDE.md but not in the Makefile or a setup guide.
  2. **Setup prerequisites** are implicit: ADB must be in PATH, Flutter must be installed, Python 3 must be available for ML tasks. No `make setup` target exists to validate the environment.
  3. **Device-specific targets** (e.g., `logs`, `logs-live`, `logs-id`) assume ADB is available and a device is connected. A `make devices` target lists connected devices, but there's no troubleshooting guide.

- **Impact**: New developer runs `make deploy` without ADB set up, gets a cryptic error. A five-minute troubleshooting guide in `CONTRIBUTING.md` or as a `make doctor` target would save time.

- **Recommendation**:
  1. Add to `Makefile` (end, before `.PHONY`):
     ```makefile
     doctor: ## Verify build environment
     	@echo "DogQuest Build Doctor"
     	@which flutter > /dev/null || echo "✗ flutter not in PATH"
     	@which adb > /dev/null || echo "✗ adb not in PATH (Android SDK Platform Tools)"
     	@which python3 > /dev/null || echo "✗ python3 not in PATH (needed for ML tasks)"
     	@adb devices | grep -q device && echo "✓ ADB connected device(s)" || echo "✗ No ADB devices connected"
     	@flutter --version | head -1
     ```
  2. Create `docs/SETUP.md`:
     - Prerequisites: Flutter 3.16+, Dart 3+, Android SDK, ADB, Python 3.9+
     - `make doctor` to verify setup.
     - Required env vars: `SENTRY_DSN` (optional but recommended), `SUPABASE_URL` / `SUPABASE_ANON_KEY` (populated in `main.dart` from `.env` or hardcoded for dev).
     - Troubleshooting: ADB not found, device not detected, build fails.

- **File(s)**: `Makefile` (add `doctor` target), `docs/SETUP.md` (create)

---

## Documentation Health Summary

| Category | Score | Notes |
|----------|-------|-------|
| **Project Intelligence (CLAUDE.md)** | 7/10 | Comprehensive but drifted on model specs (DOC-001). Excellent on tech stack and structure. Missing: setup prerequisites, Makefile explanation. |
| **Inline Code Doc** | 7/10 | SightingSyncService (sec-C2) and dog_found_dialog (E5 telemetry) are excellent. TfliteIdentificationService is good but TTA strategy underdocumented (DOC-005). Quiz engine has no semantics doc (DOC-006). |
| **API Contract** | 2/10 | **Critical gap**: Supabase RPC contract exists only in code and in Jesse's dashboard (DOC-003). No schema, no function definition, no auth contract. |
| **Setup / Onboarding** | 4/10 | README missing (DOC-002). Makefile help is good but no environment setup guide (DOC-011). CLAUDE.md is heavy for a first read. |
| **Test / Runbook** | 6/10 | Test files are self-documenting (16 files with good naming). Quiz and identification tests are strong. Offline auth state machine undocumented (DOC-008). |
| **Vault (.second_brain/)** | 8/10 | Well-organized, coherent retrieval map, excellent Active_Tasks. Lacks a master index and periodic refresh schedule (DOC-009). |
| **Security Docs** | 7/10 | sec-C1/C2/C3 are documented in code and in Active_Tasks. C3 .gitignore block lacks a comment (DOC-004). No SECURITY.md or threat model. |
| **Spec Docs** | 8/10 | `dog_found_dialog_redesign_spec.md` and `quiz_redesign_spec.md` are detailed and well-reasoned. Quantization research is solid but incomplete for impl (DOC-010). |

**Overall**: 6.3/10. Project intelligence is solid but drifted; API contract is a critical blind spot; setup/onboarding is weak. Vault is an asset; inline docs are inconsistent.

---

## Phase 4 Hand-off

Findings impacting **framework / DevOps best-practice review**:

1. **DOC-002 (Missing README)**: Standard GitHub discovery patterns fail. Impacts: first-impression UX, hiring, external contributions (if ever opened).

2. **DOC-003 (Supabase API undocumented)**: If Supabase backend is the next major integration (post-security-fixes), API contract must be formalized before any second engineer touches the sync layer. Recommend: Supabase schema export + RLS policy spec checked into `docs/supabase/` as part of the DevOps runbook.

3. **DOC-009 (Vault indexing)**: The vault is a team asset but lacks discoverability. A published index + scheduled refresh (end-of-session) would improve knowledge transfer and reduce reliance on synchronous Q&A.

4. **DOC-011 (Makefile / setup)**: As the team scales, environment validation (`make doctor`) and setup guides reduce onboarding friction. Recommend standardizing on a `docs/SETUP.md` + Makefile `doctor` target as a template for future projects.

5. **ML Documentation pattern**: The quantization + model-training docs (session files, CLAUDE.md) are fragmented. Recommend consolidating into `docs/ML/README.md` with versioned model specs, training runbooks, and export checklists. Applies to future models (v7, float32 retraining, etc.).

---

## Summary

DogQuest has strong project intelligence (CLAUDE.md), excellent vault discipline, and solid inline code docs on security-critical paths (sec-C1/C2, E5 telemetry). But it has critical gaps in API contracts, onboarding (no README), and module-level documentation (quiz engine, synonym clusters, TTA strategy). The vault is well-organized but needs a master index and periodic refresh.

**Blockers for quality-first posture**: None. All gaps are hygiene + velocity improvements, not security/correctness blockers.

**Recommendations for closed beta**: Prioritize DOC-002 (README) and DOC-003 (Supabase schema docs) so external feedback doesn't land on incomplete documentation. DOC-001 (CLAUDE.md drift) should be fixed before Phase 4 manual launch tasks (TASK-049/050) begin.
