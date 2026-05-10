# DogQuest — 20-image accuracy harness

**Date:** 2026-04-25  
**Model:** `assets/dog_model.tflite` (EfficientNetV2-S v6, post-calibration-fix, 300×300 uint8)  
**Pipeline:** 3-variant TTA + entropy/gap gates + synonym clustering w/ preferred-name (Option B)  
**Random seed:** 42 (re-runs are reproducible)  
**Sample:** 20 images, stratified 5 per rarity, drawn from `supplemental_dogs/` excluding ['american_bulldog', 'belgian_laekenois', 'combai', 'siberian_husky']  

## Headline

- **Top-1 (displayed):** 1/20 (5%)
- **Top-3 (displayed contains truth-cluster):** 6/20 (30%)
- **Rejected (entropy/gap):** 6
- **Synonym substitutions fired:** 0

Top-1 / top-3 both compare against the *cluster* of the truth breed, so a Blenheim image whose model output is Blenheim-then-Cavalier scores top-1 ✓ (displayed: Cavalier King Charles Spaniel — preferred). This matches user-perceived behavior.

## Per-image

### Common

**Aussiedoodle** — `aussiedoodle_027.jpg`  
**Irish Red and White Setter** — `irish_red_and_white_setter_005.jpg`  
**Cavapoo** — `cavapoo_072.jpg`  
- 🚫 Rejected (gap); norm_entropy=0.875, top1=2.5%, gap=0.8%

