# Train DogQuest v6 Model on Your GPU Machine

## Quick Start (5 minutes)

### 1. Copy these files to your GPU machine

You need the entire `dogquest/` project folder, but specifically:

```
dogquest/
  train_model_v6.py          # Training script (auto-detects GPU)
  supplemental_dogs/          # 180 breed folders, 42,543 images
  assets/dog_labels.txt       # 296 breed labels
  tf_cache/                   # IMPORTANT: has saved checkpoints!
    best_weights_head.weights.h5       # Head training complete
    best_weights_ft_stage0.weights.h5  # Best fine-tune weights (epoch 6, val_acc 47%)
```

### 2. Install dependencies

**IMPORTANT**: TensorFlow dropped native Windows GPU support after v2.10. You MUST use WSL2.

#### WSL2 Setup (Windows with NVIDIA GPU)

```bash
# Open PowerShell as Administrator, then:
wsl -u root

# Install Python and pip
apt update && apt install -y python3-pip python3-dev

# Install TensorFlow with CUDA + all dependencies
pip install --ignore-installed typing_extensions tensorflow[and-cuda] tensorflow-datasets Pillow numpy scipy importlib_resources --break-system-packages

# Set CUDA library path (REQUIRED every session)
NVIDIA_PATH=$(python3 -c "import nvidia; print(nvidia.__path__[0])")
export LD_LIBRARY_PATH=$(find $NVIDIA_PATH -name "*.so*" -exec dirname {} \; | sort -u | tr '\n' ':')

# Verify GPU is detected
python3 -c "import tensorflow as tf; print(tf.config.list_physical_devices('GPU'))"
# Should print: [PhysicalDevice(name='/physical_device:GPU:0', device_type='GPU')]
```

**Known issues solved**:
- `typing_extensions` conflict: use `--ignore-installed` flag
- `sudo` password unknown in WSL: use `wsl -u root` instead
- `nvidia-nccl-cu12` is Linux-only: that's why WSL2 is required (not native Windows)
- Missing `importlib_resources` and `scipy`: not auto-installed by tensorflow-datasets

#### Linux / macOS with GPU

```bash
pip install tensorflow[and-cuda] tensorflow-datasets Pillow numpy scipy importlib_resources
```

### 3. Run training

```bash
cd /mnt/c/Users/Administrator/AviQuest-/dogquest   # WSL2 path to project
python3 train_model_v6.py
```

The script auto-detects GPU and enables mixed precision (fp16) for ~2x speedup. It will:
- Load Stanford Dogs dataset via tensorflow-datasets
- Load 180 supplemental breed folders
- Train head (Phase 1), then fine-tune progressively (Phase 2.1 at 224x224, Phase 2.2 at 300x300)
- Save checkpoints to `tf_cache/` after each epoch
- Export final model as `assets/dog_model_v6.tflite` (uint8 quantized)

#### Resuming After a Crash

If training gets OOM-killed mid-run, you can skip completed phases:

```bash
# Clear stale cache locks from the killed process
rm -f tf_cache/*.lockfile

# Resume from Phase 2.2 (skips Phase 1 + Phase 2.1, loads saved weights)
RESUME_STAGE=2 python3 train_model_v6.py

# RESUME_STAGE values:
#   0 = train from scratch (default)
#   1 = skip Phase 1 (head), load head weights
#   2 = skip Phase 1 + Phase 2.1, load Stage 0 fine-tune weights
```

**Important**: Optimizer state is NOT saved with weight checkpoints. On resume, AdamW starts fresh — accuracy will be low initially (~12%) but climbs as the optimizer warms up over 2-3 epochs.

### Expected Training Times

| Hardware | Estimated Time |
|----------|---------------|
| RTX 3060 Ti 8GB | ~80-100 min total (batch_size=16 for 300x300 stage) |
| RTX 3080/3090 | ~30-45 min |
| RTX 4070+ | ~20-30 min |
| A100/H100 | ~15-20 min |
| CPU only (i9-9900KF) | ~8-12 hours |

### 4. What to look for

**Actual results from RTX 3060 Ti training** (296 breeds):
- **Head training (Phase 1)**: val_acc 45.5% in 5 epochs, 13.5 min ✅
- **Fine-tune stage 0 (Phase 2.1, 224x224)**: val_acc 47.0%, 26.4 min, early stopped at epoch 15 ✅
- **Fine-tune stage 1 (Phase 2.2, 300x300)**: val_acc 48.86%, early stopped at epoch 26 ✅
- **TFLite export**: 23.8 MB, uint8 I/O, int8 with float fallback ✅

48.9% across 296 breeds = 144x better than random chance (0.34%). The top-3 predictions typically contain the correct breed, making it very usable in practice.

### 5. After training completes

The script outputs:
- `assets/dog_model_v6.tflite` — The deployable model (uint8 quantized, 23.8 MB)
- `assets/dog_model.tflite` — Copy for the app
- `assets/dog_labels.txt` — Updated labels file
- `train_v6_report.json` — Training metrics and per-breed accuracy

If TFLite conversion fails but training succeeded, use the standalone export:
```bash
python3 export_tflite.py   # loads best checkpoint, converts with float fallback
```

### 6. Deploy to app (DONE)

All code changes have been applied (7 files updated):

1. `dog_embedding_service.dart`: input size 260 → 300
2. `demo_service.dart`: embedding dim 294 → 296
3. `player_service.dart`: all_breeds threshold 294 → 296
4. `game_helpers.dart`: achievement text "294 breeds" → "296 breeds"
5. `tflite_identification_service.dart`: comments updated to 296
6. `dog_service.dart`: comments updated to 296
7. `breed_collection_service.dart`: comments updated to 296

The model file `assets/dog_model.tflite` has been replaced with v6 (23.8 MB).

To rebuild after any future changes:
```powershell
flutter build apk --debug
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" install -r build\app\outputs\flutter-apk\app-debug.apk
```

### 7. Improve accuracy with continued training

If accuracy isn't good enough, run extended fine-tuning:

```bash
# In WSL2 (must set up GPU env first — see Section 2)
rm -f tf_cache/*.lockfile
python3 continue_training_v6.py
```

**Status**: Script is ready to run. All bugs fixed (296-class match, name functions, TF 2.21 fill_value).

What to look for when it starts:
- `Stanford breeds: 117` / `Overlap (extra data): 2` / `New supplemental: 179` / `Total classes: 296`
- Checkpoint loads successfully (no shape mismatch)
- Pre-training eval should show ~48.9% accuracy (matching v6 deployment)

Key differences from initial training:
- **All layers unfrozen** (vs top 150) — full model optimization
- **batch_size=8** (safe for 8GB VRAM with all layers)
- **LR=3e-6** (vs 1e-5) — finer adjustments
- **Patience=6** (vs 3) — lets cosine restarts escape local minima
- **40 max epochs** (vs 12) — more time to converge

All settings are tunable via environment variables:
```bash
BATCH_SIZE=12 EPOCHS=60 LR=1e-6 PATIENCE=8 python3 continue_training_v6.py
```

If accuracy improves, the script automatically exports a new TFLite model. Rebuild the APK to deploy.

## Data Quality Notes

Data cleanup has been performed using `safe_clean_supplemental.py`:
- **1,988 bad images** moved to `supplemental_dogs_removed/` (not deleted, can be reviewed)
- **MIN_KEEP=50** safety floor ensures no breed loses all images
- **Toy Terrier**: 52 images downloaded via icrawler (was missing before)
- **9 breeds with <150 images** (Tibetan Kyi Apso has only 87) — may have lower accuracy
- Final training set: **46,013 images** across 296 breeds

## Troubleshooting

**OOM (Out of Memory)**: The script uses per-stage batch sizes (`BATCH_SIZES_PER_STAGE` on line 76). The 300x300 stage is the bottleneck — on an 8GB GPU:
- batch_size=64 + all layers = instant GPU OOM
- batch_size=24 + all layers = OOM at epoch boundary (validation memory spike)
- batch_size=16 + all layers + `.cache()` on test = CPU RAM OOM (18.5GB for 17K images at 300x300)
- batch_size=16 + top 150 layers + no test cache = **works on RTX 3060 Ti 8GB** ✅
- If still OOMs: try batch_size=12, or reduce `FINE_TUNE_LAYERS_STAGE[1]` from 150 to 120
- Key insights: AdamW stores 2 momentum buffers per trainable param (fewer unfrozen layers = less VRAM); `.cache()` on large high-res datasets can exhaust CPU RAM

**Stale lockfiles after crash**: TensorFlow cache lockfiles persist after OOM kills. Delete them before resuming:
```bash
rm -f tf_cache/*.lockfile
```

**Stanford Dogs download fails**: The script uses `tensorflow_datasets` to auto-download Stanford Dogs. If it fails, manually download from http://vision.stanford.edu/aditya86/ImageNetDogs/ and place in `~/tensorflow_datasets/`.

**Training gets stuck**: Check `tf_cache/` for checkpoint files. Delete `tf_cache/` to start completely fresh (you'll lose cached head weights).

**PowerShell vs WSL**: All training commands must run inside WSL (`wsl -u root`), NOT in PowerShell. If you see errors about `$()` or `export`, you're in the wrong shell.
