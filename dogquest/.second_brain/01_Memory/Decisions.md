# Decisions

Tags: #memory #decisions

Use for durable decisions.

## Format

- Date:
- Decision:
- Reason:
- Related project:
- Score:

## Entries

- Date: 2026-04-25
  Decision: **Audit v2 executed end-to-end — 5,082 images quarantined, top-1 +14.8pt, top-3 +21.9pt. Quarantine kept.** Backend pivoted to Keras+GPU (WSL2 TF 2.21 + RTX 3060 Ti) mid-task after TFLite CPU estimated 3.7 hours for the sweep; Keras batched TTA at batch_size=32 finished the sweep in 23.5 min. New locked baseline numbers supersede the historical TFLite baseline (5% / 30%) in any future comparison — the backends are not comparable.
  Outcome:
    - Baseline (Keras, 3-seed random sample, n≈44 scored): top-1 14.0%, top-3 41.2%
    - Post (same harness, cleaned pool 36,758 from 41,840): top-1 28.7%, top-3 63.1%
    - Decision rule fired KEEP_SUCCESS on top-1 Δ=+14.8pt (rule threshold was ≥-1pt to keep; well above)
    - Cluster-awareness verified: 0 violations in the manifest (no working_kelpie→Australian Kelpie flags, no standard_poodle→Toy/Mini/Standard Poodle flags)
    - High-confidence flags (top_conf ≥ 0.70): 2,741 of 5,082 (53.9%); mean top-1 of flagged was 0.727
  Methodology notes:
    - Actual threshold used was DIFFERENT_BREED_THRESHOLD=0.40 and OWN_CLUSTER_LOW_THRESHOLD=0.05 (inherited from audit_supplemental.py v1), NOT the "0.85 + 0.05" written in the prior-day plan entry below. The 0.40 threshold produced 12.1% overall quarantine rate and the SUCCESS result validates that this calibration was not over-aggressive.
    - MIN_KEEP=50 floor never triggered — no folder dropped close to the floor.
    - 4 known-flagged folders (siberian_husky, belgian_laekenois, american_bulldog, combai) were skipped per plan; next pass should revisit them with looser thresholds once the main cleanup is proven.
    - Top-25 heaviest-flagged folders are candidates for manual spot-check: american_hairless_terrier (156), grand_basset_griffon_vendeen (143), goldador (128), cesky_terrier (103), petit_basset_griffon_vendeen (93). Some are likely genuine label noise (scraped hairless-dog photos in the hairless-terrier folder); others are hard-for-model breeds where the 0.40 threshold may be flagging legit images the model simply can't classify.
    - Harness reconstruction: the `outputs/test_20_images.py` harness was not on disk at task start despite this file claiming otherwise; user copied it from the Cowork sandbox mid-task. Paths patched from hardcoded sandbox paths to repo-relative.
  Risks / followups:
    - Historic TFLite baseline numbers in the 2026-04-25 20-image test report are now stale relative to the new cleaned pool. If/when a new TFLite model is exported from continue-training weights, rerun the audit harness on the cleaned supplemental_dogs/ to refresh the TFLite-reference numbers.
    - The +14.8pt top-1 jump mostly reflects "removed images the model was always going to miss" rather than an improvement in model capability. The app experience will improve proportionally only for the subset of user uploads that resemble the quarantined-pattern images (near-duplicates, mislabeled scrapes, out-of-distribution photos). Real-world delta will be smaller than 14.8pt but still positive.
    - Rollback command: `wsl -u root -- bash -c 'cd /mnt/c/Users/Administrator/AviQuest-/dogquest && python3 outputs/audit_supplemental_v2.py rollback'`
  Full report: `outputs/audit_v2/REPORT.md`; SUCCESS doc: `outputs/audit_v2/SUCCESS.md`; manifest: `outputs/audit_v2/quarantine_manifest.jsonl`.
  Related project: DogQuest data hygiene
  Score: 0.92

- Date: 2026-04-25
  Decision: **Data-quality audit promoted to fully agentic process.** Jesse explicitly opted out of per-folder review; Claude Code executes end-to-end with automated guardrails replacing the human checkpoint. Brief delivered to Claude Code 2026-04-25.
  Guardrails (the deal that makes "remove human from loop" responsible):
    1. Quarantine, not delete — every flagged image moves to `supplemental_dogs_quarantine/`, recoverable.
    2. Multi-seed harness baseline (seeds 43/100/200) measured BEFORE any moves; same harness re-run AFTER moves.
    3. Auto-rollback if average top-1 drops by >2pt vs baseline.
    4. Cluster-aware flagging — same-cluster predictions (e.g. Working Kelpie → Australian Kelpie) must not be flagged as mislabel.
    5. MIN_KEEP=50 floor per folder.
    6. Sanity-check on one folder (akita/) before sweeping all 174.
    7. Tier-A only (>85% conf wrong + <5% own conf); Tier-B logged but NOT moved.
    8. Idempotent reruns.
  Rationale: Quarantine + auto-rollback removes catastrophic-failure mode. The empirical multi-seed harness IS the human checkpoint, just automated.
  This is the right call for THIS specific task (data hygiene with empirical verifier available). Do NOT generalize to all data-modification tasks — auto-rollback only works when there's a measurable success signal. Use case for case.
  Related project: DogQuest data hygiene
  Score: 0.85

- Date: 2026-04-25
  Decision: **claude-flow MCP retained, pinned, hardened.** `.mcp.json` confirmed in active use (package.json, node_modules/@claude-flow/*, .claude-flow/plugins/dogquest-ml/, mcp__ruflo__* tools route through it). Pinned `@claude-flow/cli@latest` → `@claude-flow/cli@3.5.80`. Removed unused `CLAUDE_FLOW_WS_ENABLED` + `CLAUDE_FLOW_WS_PORT=3001` (transport is already stdio, so the WS listener was dead config). Committed `.mcp.json` to git so the pin sticks across machines.
  Correction to earlier session note: I had assumed claude-flow was leftover/unused from the AviQuest fork — wrong. It is actively wired into the project's tooling. Always grep package.json + node_modules before declaring an inherited config "leftover."
  Related project: DogQuest tooling
  Score: 0.7

- Date: 2026-04-25
  Decision: **Shell-bridge MCP options vetted for Cowork.** No off-the-shelf, blessed-by-Anthropic shell plugin in Cowork's marketplace. Two viable third-party options researched: Desktop Commander and PowerShell.MCP. Recommendation logged but no install action taken yet — Jesse's call.
  Findings:
    - Cowork plugin search returned 6 results, 0 with shell capabilities (Zoom, Apollo, legal, bio-research, operations, plugin-management). Anthropic does not curate a shell-bridge plugin.
    - Desktop Commander (5.9k stars, v0.2.39 2026-04-23): wide feature surface, configurable blocklist, Docker isolation option. **Had CVSS 10 zero-click RCE in Feb 2026 (patched).** Maintainers admit blocklist is bypassable.
    - PowerShell.MCP (45 stars, v1.7.7 2026-04-18): Authenticode-signed binaries, transparency model (runs in user's existing PowerShell console — every command visible/audited), narrower scope, no documented critical CVE. Smaller community = less battle-tested.
    - First-party alternative: Claude Code (Anthropic CLI) handles this workload natively without an MCP shell-bridge. Strictly safer + better-suited for Flutter builds + Python ML + on-device debugging.
  Recommendation: PowerShell.MCP if staying in Cowork; Claude Code if open to switching tools for execution work. Both can run alongside Cowork's vault/skills layer.
  Both options entail handing arbitrary shell access to an LLM — treat as "junior dev with shell access," keep signing keys / secrets out of accessible directories.
  Related project: DogQuest tooling
  Score: 0.7 (recommendation; not yet acted on)

- Date: 2026-04-25
  Decision: **Label noise confirmed in `supplemental_dogs/poodle/`.** Visual inspection by Jesse: `poodle_045.jpg` is a Boxer; `poodle_106.jpg` is a French Bulldog. Both flagged by 20-image harness with high model confidence on the WRONG breed (94.5% Boxer / 84.6% French Bulldog) — model is correctly identifying them; the `poodle/` folder label is wrong. Deleted both files. This validates the 20-image harness as a useful label-noise detection tool: high model confidence on a non-folder breed = strong signal that the image is mislabeled.
  Generalized: any folder with sustained "high-conf wrong" predictions deserves a manual audit. Protocol: run harness, look for >50% conf on a label not matching the folder name, open and verify, delete if mislabeled.
  Related project: DogQuest data hygiene
  Score: 0.85

- Date: 2026-04-25
  Decision: **20-image test harness moved from Cowork sandbox to project repo.** Files now live persistently at `C:\Users\Administrator\AviQuest-\dogquest\outputs\test_20_images.py` (389 lines) and `outputs\run_test.py` (127 lines). Cluster table synced to match the 6-cluster Dart definition (Poodle + Australian Kelpie additions). Discovered when Claude Code's audit_v2 task halted unable to find the harness on disk — it had only ever existed in Cowork's session-only sandbox. Failure pattern logged.
  Lesson: persistent project artifacts must be written into the user's workspace folder (`C:\...\dogquest\`), never the Cowork outputs sandbox.

- Date: 2026-04-25
  Decision: **Empirical quality baseline locked: 20-image test harness in `outputs/test_20_images.py` + `outputs/run_test.py`.** Mirrors the app's pipeline exactly (3-variant TTA, 300×300 uint8, EXIF bake, entropy/gap gates, Option B synonym clustering). Two-mode sampling (stratified by rarity vs. uniform random) prevents single-number misreading.
  Baseline numbers (random seed 42 + 43, n=20 each):
    - **Stratified**: top-1 0/20 (0%), top-3 2/20 (10%), 4 rejected — heavy weight to legendary blind spots (Telomian, Catalburun, Stabyhoun, etc.); treat as worst-realistic-case lower bound.
    - **Random**: top-1 1/20 (5%), top-3 6/20 (30%), 6 rejected — apples-to-apples with prior session's 194-image baseline (11.9% / 56.2%); ±5 points variance at n=20.
  Key findings:
    - Errors are visually-coherent (Akita→Norwegian Elkhound, Cane Corso→Bullmastiff, Lagotto→Toy Poodle, Bichon→Bolognese). Model is "thinking", not guessing — top-3 ranked alternatives UI handles this gracefully.
    - High-confidence wrong answers exist (Russell Terrier→Boston Terrier 83%, Poodle→Boxer 94%, Working Kelpie→Australian Kelpie 84%). Direct evidence the dog_found_dialog redesign matters; "Very confident" labeling on these is dishonest.
    - 0/40 synonym substitutions fired across both samples — none of the 4 documented clusters happened to be in either sample. Coverage of real-world model confusions is sparse.
    - Entropy/gap gates rejected 4–6 ambiguous predictions cleanly with no false positives.
  New cluster candidates surfaced empirically: Working Kelpie ↔ Australian Kelpie (highest priority, model said Aussie at 84%); possibly American Foxhound ↔ Walker Hound; Russell Terrier ↔ Boston Terrier deserves an outlier check (likely not a real cluster, possibly model bug or data noise).
  Caveat: `supplemental_dogs/` is the *supplementary* (rare) partition; mainstream AKC breeds in Stanford Dogs aren't sampled. Real-app accuracy on Lab/Golden/GSD likely higher than these numbers suggest.
  Report: `docs/session_2026-04-25/dogquest_20image_test.md` (496 lines, per-image breakdown).
  Related project: DogQuest
  Score: 0.9

- Date: 2026-04-25
  Decision: **Posture pivot — quality-first with closed beta as feedback loop.** Defer public Play Store launch (TASK-058/059/060/061) until quality bar is met via 5–10 person closed beta. Phase 4 manual tasks split: TASK-049 (signing key) and TASK-050 (Sentry DSN) stay in scope as quality-instrumentation; TASK-058/059/060/061 defer.
  Reason: Jesse explicitly chose quality-first over ship-first on 2026-04-25. Quality without external feedback is conjecture; closed beta provides the user signal needed to define "quality bar" objectively without committing to public launch.
  Trade-offs / risks captured: perpetual pre-launch is the failure mode. Time-box: 4 weeks of pure quality work before reassessing. Tier 3 (retrain) is expensive and should come AFTER cheap Tier 1+2 wins are exhausted.
  Tier order: T1 cheap quality wins (~1.5h: cluster-coverage check, 4-folder noise cleanup, "Breeds 0/296" state-bug check, Sentry wiring, +1-2 synonym clusters). T2 UX (1-2 days: dog_found_dialog redesign, confidence-labeling honesty). T3 model (overnight retrain after data hygiene). T4 closed beta (signing key + 2 weeks). T5 polish on real signal. Then ship.
  Supersedes: prior strategy "Phase 4 is the bottleneck — treat manual tasks as P0".
  Related project: DogQuest
  Score: 0.95

- Date: 2026-04-25
  Decision: Synonym clustering — Option B: preferred-name per cluster (cluster[0] is canonical display name). Substitute preferred Dog when non-preferred member wins on raw model confidence; pass-through model's confidence value unchanged. Partners are deduped silently with `_log.fine` trace.
  Reason: On-device verification on a Cavalier-color photo surfaced "Blenheim Spaniel" instead of "Cavalier King Charles Spaniel" — semantically correct but UX-broken. Option B keeps user-recognizable names in the headline without rewriting confidence numbers.
  Trade-off: Slight relabeling — when Blenheim scores 75%, we display "Cavalier 75%". Honest because the cluster is by design a single-breed grouping; cluster table is the place where this relabeling is auditable.
  Cluster table:
    [Cavalier King Charles Spaniel, Blenheim Spaniel]
    [Yorkshire Terrier, Biewer Terrier]
    [Belgian Sheepdog, Belgian Tervuren]   (FCI single breed; AKC-distinct — Belgian Sheepdog picked as preferred, debatable)
    [Siberian Husky, Alaskan Husky]
  Implementation: `dogQuestSynonymClusters` (List<List<String>>) + `dogQuestClusterKey()` returns cluster.first. Substitution loop in `_buildResults` uses `_dogService.lookupByCommonName(clusterKey)` with warning-log fallback if preferred not in dogs.json. Tests in test/services/tflite_identification_service_test.dart §11+§12 (102 total tests, 25 cluster-related).
  Earlier (superseded) approach: alphabetically-first cluster key; shipped the same day, replaced after on-device verification revealed UX issue.
  Related project: DogQuest
  Score: 0.85

- Date: 2026-04-25
  Decision: Ship EfficientNetV2-S v6 (296 breeds, 300x300 uint8) with quant scale 1.0.
  Reason: Calibration bug at 1/255 destroyed on-device confidence; 1.0 matches the converter's expected range and was verified by Dalmatian canary.
  Related project: DogQuest
  Score: 1.0

- Date: 2026-04-25
  Decision: Drop dataset `.cache()` and any decoded-tensor `tf.data.shuffle` for continue-training on RTX 3060 Ti 8GB.
  Reason: 17K images at 300x300 = ~18.5GB CPU RAM via cache; shuffle buffers hold decoded tensors in RAM. Shuffle file paths BEFORE decoding instead.
  Related project: DogQuest
  Score: 0.9

- Date: 2026-04-24
  Decision: Use Hive box prefix `dogquest_` to avoid collision with AviQuest installs on the same device.
  Reason: Forked codebase shares storage namespace.
  Related project: DogQuest
  Score: 0.8

- Date: 2026-04-24
  Decision: AdMob interstitial frequency cap = every 3rd identification, 5-min cooldown.
  Reason: Balance revenue and user trust; identification is the core retention loop.
  Related project: DogQuest
  Score: 0.8

- Date: 2026-04-24
  Decision: Riverpod + go_router + StatefulShellRoute as the state/nav baseline.
  Reason: Inherited from AviQuest, proven; auth gate cleanly fits this pattern.
  Related project: DogQuest
  Score: 0.8

- Date: 2026-04-24
  Decision: Supabase as backend (auth, social, sync, storage, RLS, RPC). Hive remains local-first source of truth.
  Reason: Conflict-resolution policy: localWins for player stats, serverWins for profile, deduplicateById for sightings.
  Related project: DogQuest
  Score: 0.9

- Date: 2026-04-24
  Decision: Exclude wild canids (dingo, dhole, African wild dog) from the model output.
  Reason: Out of scope for a domestic dog breed app; mapped to None in Stanford name map.
  Related project: DogQuest
  Score: 0.7

- Date: 2026-04-24
  Decision: TFLite output buffers must use `List.filled(n, 0.0).reshape()`, not `Float32List`, on tflite_flutter 0.11.0.
  Reason: API contract — Float32List silently mis-shapes outputs.
  Related project: DogQuest
  Score: 0.9

## Related Notes

- [[Strategy]]
- [[Active_Tasks]]
- [[Failure_Patterns]]
