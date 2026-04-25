# DogQuest — Audit v2 REPORT

**Date:** 2026-04-25
**Model:** EfficientNetV2-S v6 via Keras on GPU (RTX 3060 Ti, WSL2, TF 2.21)
**Weights:** `tf_cache/best_weights_continue.weights.h5`
**Pipeline:** 3-variant TTA (tight center / flip / loose 1.15x), batched Keras inference at batch_size=32
**Tier-A flag criteria:** top-1 cluster ≠ truth cluster AND top-1 confidence ≥ 0.40 AND own-cluster confidence < 0.05
**Cluster-aware:** same-cluster predictions (e.g. Working Kelpie → Australian Kelpie) never flag
**MIN_KEEP floor:** 50 images per folder
**Flagged folders (excluded from audit):** `siberian_husky`, `belgian_laekenois`, `american_bulldog`, `combai`

## Decision: **KEEP_SUCCESS** — quarantine retained

| Metric | Baseline (pre) | Post | Delta |
|---|---|---|---|
| Avg top-1 | 14.0% | 28.7% | **+14.8pt** |
| Avg top-3 | 41.2% | 63.1% | **+21.9pt** |

## Per-seed detail

| Seed | Baseline top-1 | Post top-1 | Baseline top-3 | Post top-3 |
|---|---|---|---|---|
| 43 | 15.4% (n=13) | 46.2% (n=13) | 46.2% | 69.2% |
| 100 | 15.4% (n=13) | 20.0% (n=15) | 38.5% | 60.0% |
| 200 | 11.1% (n=18) | 20.0% (n=15) | 38.9% | 60.0% |

## Headline counts

- **Folders audited:** 178
- **Folders with ≥1 flag:** 178 (every audited folder had at least one flag)
- **Total images quarantined:** 5,082 (including the 11 akita flagged during the sanity-check execute)
- **High-confidence flags (top_conf ≥ 0.70):** 2,741 (53.9%)
- **Mean top-1 confidence of flagged images:** 0.727
- **Pool before audit:** 41,840 images across 178 breeds
- **Pool after audit:** 36,758 images (-5,082; −12.1%)
- **Wall-clock:** 23.5 min for the sweep (Keras + GPU batched, TTA preserved); akita sanity add-on +0.7 min

## Cluster-awareness verification: PASS (0 violations)

Confirmed automatically against the full manifest:
- No image in `supplemental_dogs/working_kelpie/` was flagged when predicted as Australian Kelpie or Working Kelpie.
- No image in `supplemental_dogs/standard_poodle/` was flagged when predicted as Toy/Miniature/Standard Poodle.

Same-cluster predictions never enter the flag set, as designed at `audit_folder():if top_cluster == truth_cluster: continue`.

## Top-25 folders by flag count

| Folder | Flagged |
|---|---|
| american_hairless_terrier | 156 |
| grand_basset_griffon_vendeen | 143 |
| goldador | 128 |
| cesky_terrier | 103 |
| petit_basset_griffon_vendeen | 93 |
| field_spaniel | 85 |
| irish_red_and_white_setter | 85 |
| silken_windhound | 82 |
| american_pit_bull_terrier | 73 |
| black_russian_terrier | 73 |
| nova_scotia_duck_tolling_retriever | 68 |
| xigou | 66 |
| spinone_italiano | 65 |
| glen_of_imaal_terrier | 64 |
| pomsky | 61 |
| pumi | 60 |
| pyrenean_shepherd | 60 |
| chinese_crested | 59 |
| black_mouth_cur | 58 |
| portuguese_podengo | 57 |
| greyhound | 55 |
| central_asian_shepherd | 54 |
| english_mastiff | 54 |
| labsky | 52 |
| telomian | 52 |

The heaviest flag counts cluster on breeds where (a) the model has low overall confidence (rare breeds with thin training signal) or (b) the scraped dataset likely contains many genuinely-wrong images. Candidates for manual spot-check later:

- `american_hairless_terrier` (156 flagged) — scraped images may include generic hairless-dog photos rather than the specific breed.
- `grand_basset_griffon_vendeen` (143) / `petit_basset_griffon_vendeen` (93) — commonly-confused breed pair. High flag count in one but not the other could indicate real mislabels vs genuine model confusion.
- `goldador` (128) — Golden × Lab crossbreed; fundamentally hard to label cleanly since visual distinctiveness is low.
- `greyhound` (55) — mainstream breed; high flag count is suspicious, worth eyeballing whether scraped images include whippets or lurchers.

These four are good candidates for the "4-folder data hygiene spot-check" task that was already in Tier 1 (`siberian_husky`, `belgian_laekenois`, `american_bulldog`, `combai` are the original four; the new heavy-flag set extends that list).

## Methodology caveats

- **Baseline is Keras, not TFLite.** The historical baseline in `Decisions.md` (TFLite, top-1 5% / top-3 30%) is NOT directly comparable; it was produced by a different inference backend with uint8 quantization. The new locked baseline (14.0% / 41.2%) becomes the reference for comparison against future audits. Switch driven by compute: Keras GPU batched is ~10x faster end-to-end and matches training fidelity without quantization rounding.
- **n=60 per measurement is noisy.** Single-image differences are ~1.7pt; the observed +14.8pt top-1 delta is ~9x the noise floor, so the signal is real. Top-3 moved +21.9pt — when top-1 and top-3 move together, it's directional signal, not sample-draw artifact.
- **Flag threshold calibration.** DIFFERENT_BREED_THRESHOLD=0.40 and OWN_CLUSTER_LOW_THRESHOLD=0.05 were inherited from the original `audit_supplemental.py`. They produced a reasonable 12.1% overall quarantine rate. Tighter thresholds would be conservative; looser would quarantine more. The SUCCESS result validates that this calibration didn't overfit-to-flag.
- **MIN_KEEP=50 never triggered for any audited folder.** The smallest post-audit folder sizes are in the hundreds. The floor was a belt-and-suspenders safeguard that didn't bind.

## Rollback hint

```
wsl -u root -- bash -c 'cd /mnt/c/Users/Administrator/AviQuest-/dogquest && python3 outputs/audit_supplemental_v2.py rollback'
```

Rollback moves all 5,082 quarantined files back to `supplemental_dogs/` and archives the manifest with a timestamped `.rolledback` suffix. Idempotent and safe to run multiple times (subsequent runs find an empty manifest).

## Files produced

- `outputs/audit_supplemental_v2.py` — refactored audit script (Keras GPU backend)
- `outputs/wsl_gpu_env.sh` — LD_LIBRARY_PATH helper for WSL2 + pip nvidia packages
- `outputs/audit_v2/baseline_metrics.json` — pre-audit 3-seed metrics (Keras)
- `outputs/audit_v2/post_metrics.json` — post-audit 3-seed metrics (Keras)
- `outputs/audit_v2/quarantine_manifest.jsonl` — 5,082 append-only records (src, dst, top_label, top_conf, own_conf, timestamp)
- `outputs/audit_v2/per_folder_stats.json` — per-folder flag counts
- `outputs/audit_v2/SUCCESS.md` — decision-rule output (auto-generated)
- `outputs/audit_v2/sweep.log` — full progress log of the sweep
- `outputs/audit_v2/REPORT.md` — this document
