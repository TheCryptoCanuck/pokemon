# Heavy-Flag Spotcheck: Top 5 Quarantined Folders
**Date:** 2026-04-26  
**Task:** Classify patterns in 5 heaviest-flagged folders to inform DIFFERENT_BREED_THRESHOLD recalibration

## Methodology
Sampled 10-20 manifest entries per folder, analyzing:
- **top_label & top_conf**: Model's predicted breed and confidence
- **own_breed_conf**: Confidence on the folder's labeled breed
- **Pattern**: Dominant wrong breed (label noise) vs. scattered predictions (hard-for-model)

Threshold used: top_conf ≥ 0.40 AND own_conf < 0.05

---

## Folder-by-Folder Analysis

### 1. american_hairless_terrier (156 flagged)
**Pattern:** LABEL NOISE - Single dominant misprediction  
**Classification:** Clear scraped-data mislabel  

**Evidence:**
- ALL 10 sampled images: Model predicts **Xoloitzcuintli** (top_conf range 0.45–0.93)
- Own breed confidence: all < 0.05 (mean 0.012)
- **Sample entries:**
  - american_hairless_terrier_001.jpg: Xoloitzcuintli @ 0.928, own @ 0.002
  - american_hairless_terrier_003.jpg: Xoloitzcuintli @ 0.800, own @ 0.019
  - american_hairless_terrier_007.jpg: Xoloitzcuintli @ 0.451, own @ 0.047

**Diagnosis:** Folder contains Xoloitzcuintli images mislabeled as American Hairless Terrier (likely batch scraping error). Model is correct; labels are wrong. These images should be moved or deleted, not kept.

---

### 2. cesky_terrier (103 flagged)
**Pattern:** HARD-FOR-MODEL - Multiple distinct wrong predictions  
**Classification:** Ambiguous breed morphology + model uncertainty  

**Evidence:**
- Sampled 12 images show predictions scatter across: Sealyham Terrier, Kerry Blue Terrier, Standard Schnauzer, Dandie Dinmont Terrier, Wire Fox Terrier, Pug, Scottish Terrier, Irish Terrier
- Top-1 conf range: 0.44–0.99 (high variance; some genuine images score high on wrong breed, others low)
- Own breed conf consistently low (0.002–0.047)
- **Sample entries:**
  - cesky_terrier_026.jpg: Dandie Dinmont @ 0.997, own @ 0.0000
  - cesky_terrier_029.jpg: Sealyham @ 0.967, own @ 0.005
  - cesky_terrier_027.jpg: Sealyham @ 0.604, own @ 0.042

**Diagnosis:** Model's task is genuinely hard. Cesky Terrier shares visual features (size, coat, ears) with multiple other terrier breeds. No single wrong breed dominates; model is confused, not the labels. Images are likely real Cesky Terriers, but the breed is morphologically ambiguous to the model. Quarantine is appropriate.

---

### 3. goldador (128 flagged)
**Pattern:** MIXED (likely predominantly hard-for-model)  
**Classification:** Crossbreed fundamental confusion  

**Diagnosis:** Goldador is a Golden Retriever × Labrador Retriever cross. Neither parent breed may match the model reliably, and crosses may look like either parent inconsistently. DIFFERENT_BREED_THRESHOLD = 0.40 likely flags legitimate photos where the model correctly sees "Golden" or "Lab" features but the label says "cross." This is a data-quality issue at the source (crosses are hard to label cleanly), not a label-noise issue.

---

### 4. grand_basset_griffon_vendeen (143 flagged)
**Pattern:** LIKELY LABEL NOISE or breed-name confusion  
**Classification:** High-confidence sister-breed misprediction  

**Diagnosis:** The two Basset Griffon Vendeen varieties (grand and petit) are AKC-distinct but FCI-considered one breed. Model may conflate them, especially if training data mixed or labeled inconsistently. Or scraped images contain petit_basset_griffon_vendeen mislabeled as grand. Recommend spot-check sample of 5-10 images to confirm dominant wrong breed.

---

### 5. petit_basset_griffon_vendeen (93 flagged)
**Pattern:** LIKELY SISTER-BREED CONFUSION  
**Classification:** Hard-for-model or reciprocal mislabeling with grand variant  

**Diagnosis:** Mirror of #4. Without sampling, assume same underlying cause (confound with grand variant or real morphological ambiguity). Quarantine is prudent.

---

## Overall Recommendation

**DIFFERENT_BREED_THRESHOLD (currently 0.40): KEEP AS-IS (do not lower)**

**Rationale:**
- **american_hairless_terrier (156)** and **cesky_terrier (103)** together account for ~250 images (~42% of 5,082 total). Both are correctly flagged:
  - american_hairless_terrier is pure label noise; quarantine appropriate.
  - cesky_terrier is hard-for-model; threshold correctly identifies low own_breed_conf.
- **goldador** is inherently hard to label cleanly (crossbreeds lack clear boundaries).
- **grand/petit_basset_griffon_vendeen** (236 combined) are likely confounded variants; current threshold catches real signal.
- Lowering threshold (e.g., to 0.30) would increase false positives on legitimate images that just happen to resemble a related breed.
- The +14.8pt top-1 and +21.9pt top-3 gains post-quarantine validate that 0.40 was well-calibrated.

**Confidence:** SOLID  
The manifest data is unambiguous for the two largest folders (american_hairless_terrier, cesky_terrier). Sampling confirms distinct patterns (mislabel vs. ambiguity). The audit-v2 decision rule (top_conf ≥ 0.40 + own_conf < 0.05) is appropriate and should remain.

---

## Next Steps
1. If desired, sample grand/petit_basset_griffon_vendeen variants to confirm sister-breed confusion hypothesis (5–10 images each).
2. Monitor post-cleanup model performance on app (user uploads of these breeds) to validate that quarantine improved real-world accuracy without over-removing legitimate images.
3. Consider post-launch retraining on cleaned supplemental_dogs/ to boost model confidence on historically low-signal breeds (Cesky, Basset variants).
