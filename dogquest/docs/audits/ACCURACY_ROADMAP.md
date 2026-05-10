# DogQuest — Roadmap to 90% Accuracy (296 breeds)

**Current**: 48.86% val_accuracy (v6, EfficientNetV2-S, 300x300)
**Target**: 90% val_accuracy, all 296 breeds
**Hardware**: RTX 3060 Ti 8GB, i9-9900KF, WSL2

## Overview

| Phase | What | Expected Accuracy | Time |
|-------|------|-------------------|------|
| 0 | Current v6 baseline | 49% | done |
| 1 | Data cleaning (audit + remove bad images) | 58-65% | 1-2 days |
| 2 | More data (500 images/breed) | 68-75% | 2-3 days |
| 3 | Training improvements (384px, gradient accum) | 75-82% | 1-2 days |
| 4 | Second cleaning pass + more data (750/breed) | 80-87% | 2-3 days |
| 5 | Final push (1000/breed, longer training, TTA) | 85-90% | 1 week |

---

## Phase 1: Data Cleaning (BIGGEST IMPACT)

Web-scraped images from Bing have ~10-20% noise (wrong breed, stock photos,
watermarked images, multiple dogs, non-dog images). Removing these gives the
single biggest accuracy boost because you're eliminating training signal that
actively teaches the model wrong things.

```bash
# Step 1: Run the audit (report only, ~30 min for 42K images)
cd /mnt/c/Users/Administrator/AviQuest-/dogquest
python3 audit_and_clean.py

# Step 2: Review the report
# - audit_report.txt: text summary with per-breed flag rates
# - audit_breed_stats.json: machine-readable per-breed stats
# - audit_flagged.json: every flagged image with reasons
# Look at the "WORST BREEDS" section — breeds with >30% flag rate
# have serious data quality problems.

# Step 3: Auto-clean (moves flagged images to supplemental_dogs_removed/)
python3 audit_and_clean.py --clean

# Step 4: Retrain with cleaned data
python3 train_model_v6.py

# Step 5: Export TFLite
python3 export_tflite.py
```

**Why this works**: Even at 49% accuracy, when the model says an image in the
"golden_retriever" folder is actually a "labrador_retriever" with 60%+ confidence,
it's almost always right. Those are the images that confuse training the most.

---

## Phase 2: More Data (500 images/breed)

After cleaning, download more images to reach 500 per supplemental breed.
More data = more examples of each breed's visual variation = better generalization.

```bash
# Download to 500/breed target (images saved at 384px for future use)
python3 download_more_images.py --target 500

# Audit the NEW images (they're web-scraped too, so clean them)
python3 audit_and_clean.py --clean

# Retrain
python3 train_model_v6.py
python3 export_tflite.py
```

**Note**: The download script now saves at 384x384 (EfficientNetV2-S native
resolution). Existing 224px images from earlier downloads are fine — the training
pipeline resizes everything anyway — but new images will be higher quality.

---

## Phase 3: Training Improvements

Once data is clean and plentiful, squeeze more accuracy from the training itself.

### 3a. Train at 384x384 (native resolution)

EfficientNetV2-S was designed for 384x384. Training at 300x300 leaves accuracy
on the table, especially for fine-grained breed distinctions (coat texture,
ear shape, facial markings).

Requires smaller batch size on 8GB VRAM:
- Phase 1 (head only, 224px): batch_size=64 ✓
- Phase 2.1 (fine-tune, 224px): batch_size=32 ✓
- Phase 2.2 (fine-tune, 384px): batch_size=6-8, top 100 layers

Changes needed in `train_model_v6.py`:
```python
IMG_SIZES = [224, 384]           # was [224, 300]
FINAL_IMG_SIZE = 384             # was 300
BATCH_SIZES_PER_STAGE = [64, 6]  # smaller batch at 384
FINE_TUNE_LAYERS_STAGE = [60, 100]  # fewer layers to fit in VRAM
```

Also update `export_tflite.py` and `dog_embedding_service.dart`:
```python
FINAL_IMG_SIZE = 384  # in export_tflite.py
```
```dart
static const int _inputSize = 384;  // in dog_embedding_service.dart
```

### 3b. Gradient Accumulation

Simulate larger effective batch size while fitting in 8GB.
Add to training script:

```python
ACCUMULATION_STEPS = 4  # effective batch = 6 * 4 = 24

# Custom training step
@tf.function
def train_step(model, optimizer, loss_fn, x_batch, y_batch, step):
    with tf.GradientTape() as tape:
        preds = model(x_batch, training=True)
        loss = loss_fn(y_batch, preds) / ACCUMULATION_STEPS

    grads = tape.gradient(loss, model.trainable_variables)
    if step % ACCUMULATION_STEPS == 0:
        optimizer.apply_gradients(zip(grads, model.trainable_variables))
```

### 3c. Better representative dataset for TFLite quantization

Currently using random noise for calibration. Use actual training images:

```python
def representative_data_gen():
    for img_path in random.sample(all_image_paths, 200):
        img = Image.open(img_path).convert("RGB").resize((384, 384))
        data = np.array(img, dtype=np.float32)[np.newaxis]
        yield [data]
```

### 3d. Cosine annealing with warm restarts

Already implemented in continue_training_v6.py. Make sure train_model_v6.py
uses the same schedule for all stages.

---

## Phase 4: Second Cleaning Pass

After Phase 3, the model will be much better (~75-80%). Use it to do a
tighter cleaning pass:

```bash
# Re-audit with aggressive thresholds (the model is now accurate enough)
python3 audit_and_clean.py --clean --aggressive

# Download more images to replace removed ones (target 750)
python3 download_more_images.py --target 750
python3 audit_and_clean.py --clean

# Retrain
python3 train_model_v6.py
python3 export_tflite.py
```

---

## Phase 5: Final Push to 90%

### 5a. 1000+ images per breed

```bash
# Increase to 1000/breed
python3 download_more_images.py --target 1000
python3 audit_and_clean.py --clean
```

Consider adding Google Images as a second source (icrawler supports
GoogleImageCrawler). More sources = more diversity.

### 5b. Extended training

```bash
# Longer training with lower LR
EPOCHS=80 LR=1e-6 PATIENCE=10 BATCH_SIZE=6 python3 continue_training_v6.py
```

### 5c. Test-Time Augmentation (in the app)

The v5 TTA (5-crop x flip = 10 variants averaged) should be active for v6 too.
Verify in `tflite_identification_service.dart` that TTA is enabled.

### 5d. Knowledge Distillation (optional, if plateau)

If you plateau at ~85%, train a larger teacher model (EfficientNetV2-L) on a
cloud GPU (Colab Pro, Lambda, etc.), then use soft labels to train the student
(V2-S) on your local GPU. Soft labels from the teacher encode inter-breed
similarity (e.g., "this is 70% Golden Retriever, 20% Goldendoodle, 10% Labrador")
which gives the student richer training signal than hard one-hot labels.

---

## Problematic Breeds to Watch

These categories will be hardest to get to 90%:

**Designer breeds** (high visual variance, overlap with parents):
- Goldendoodle, Labradoodle, Cockapoo, Bernedoodle, Aussiedoodle
- Maltipoo, Pomsky, Morkie, Yorkipoo, Sheepadoodle
- Goldador, Labsky, Shorkie, Havapoo, Corgipoo, Schnoodle, Puggle, Cavapoo

**Near-duplicate entries** (should verify they're truly distinct):
- Jindo vs Korean Jindo Dog vs Jindo Gae
- Kangal vs Kangal Shepherd Dog
- Catahoula Leopard Dog vs Catahoula Cur

**Rare breeds with few quality images online**:
- Toy Terrier (52 images), Tibetan Kyi Apso (87 images)
- Xigou, Hmong Bobtail Dog, Jonangi, Chippiparai, Gaddi Kutta

**Easily confused breed pairs**:
- Golden Retriever ↔ Labrador Retriever
- Alaskan Malamute ↔ Siberian Husky
- Belgian Malinois ↔ German Shepherd
- Collie ↔ Shetland Sheepdog

After Phase 1, check `audit_breed_stats.json` for which breeds have the
lowest per-breed accuracy. Focus data collection efforts on those breeds.

---

## Files Reference

| Script | Purpose |
|--------|---------|
| `audit_and_clean.py` | Audit + auto-clean supplemental images |
| `download_more_images.py` | Download more images (now targets 500/breed at 384px) |
| `train_model_v6.py` | Main training script |
| `continue_training_v6.py` | Extended fine-tuning from checkpoint |
| `export_tflite.py` | Standalone TFLite export |
| `safe_clean_supplemental.py` | Legacy cleanup script (use audit_and_clean.py instead) |

## Quick Start

```bash
# SSH into WSL2
wsl -u root
cd /mnt/c/Users/Administrator/AviQuest-/dogquest

# Phase 1: Clean existing data
python3 audit_and_clean.py            # see the damage
python3 audit_and_clean.py --clean    # fix it

# Phase 2: Get more data
python3 download_more_images.py --target 500
python3 audit_and_clean.py --clean    # clean new downloads

# Retrain
NVIDIA_PATH=$(python3 -c "import nvidia; print(nvidia.__path__[0])")
export LD_LIBRARY_PATH=$(find $NVIDIA_PATH -name "*.so*" -exec dirname {} \; | sort -u | tr '\n' ':')
python3 train_model_v6.py
python3 export_tflite.py

# Build & deploy
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```
