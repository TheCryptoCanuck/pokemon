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

```bash
pip install tensorflow tensorflow-datasets Pillow numpy
# For GPU: pip install tensorflow[and-cuda]  (or use conda install tensorflow-gpu)
```

### 3. Run training

```bash
cd dogquest
python train_model_v6.py
```

The script auto-detects GPU and enables mixed precision (fp16) for ~2x speedup. It will:
- Load Stanford Dogs dataset via tensorflow-datasets
- Load 180 supplemental breed folders
- Resume head training (will redo this quickly since weights are cached)
- Run 2-stage progressive fine-tuning: 224x224 -> 300x300
- Save checkpoints to `tf_cache/` after each epoch
- Export final model as `assets/dog_model_v6.tflite` (uint8 quantized)

### Expected Training Times

| Hardware | Estimated Time |
|----------|---------------|
| RTX 3060/3070 | ~45-60 min |
| RTX 3080/3090 | ~30-45 min |
| RTX 4070+ | ~20-30 min |
| A100/H100 | ~15-20 min |
| CPU only (your i9-9900KF) | ~8-12 hours |

### 4. What to look for

Training is going well if:
- **Head training** reaches 50-60% val_accuracy in 5 epochs
- **Fine-tune stage 0** (224x224) reaches 75-80% val_accuracy
- **Fine-tune stage 1** (300x300) reaches 85-90% val_accuracy
- Loss decreases steadily (val_loss < 1.0 is good)

### 5. After training completes

The script outputs:
- `assets/dog_model_v6.tflite` — The deployable model (uint8 quantized)
- `assets/dog_model.tflite` — Copy for the app
- `assets/dog_labels.txt` — Updated labels file
- `train_v6_report.json` — Training metrics and per-breed accuracy

Copy these back to your DogQuest project folder.

### 6. Deploy to app (5 minutes)

Only **3 code lines** need changing:

1. **`lib/services/dog_embedding_service.dart` line 13**: Change `260` to `300`
2. **`lib/services/demo_service.dart`**: Update breed count comment from 294 to 296
3. **`lib/services/player_service.dart`**: Update breed count comment from 294 to 296

The main identification service (`tflite_identification_service.dart`) already uses dynamic output sizing — no changes needed there.

Then rebuild:
```bash
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

## Data Quality Notes

The data audit found:
- **9 breeds with <150 images** (Tibetan Kyi Apso has only 87) — may have lower accuracy
- **~30% of supplemental images** flagged as potentially mislabeled in previous audit
- **Toy Terrier** is in dog_labels.txt but missing from supplemental_dogs/ (no training images)

For best results, consider cleaning the most-flagged breeds before training:
- Akita (62% flagged), Alaskan Husky (40%), Belgian Laekenois (38%), Thai Ridgeback (36%)

## Troubleshooting

**OOM (Out of Memory)**: Reduce BATCH_SIZE in the script (line 74). Try 32 for 8GB GPU, 16 for 6GB.

**Stanford Dogs download fails**: The script uses `tensorflow_datasets` to auto-download Stanford Dogs. If it fails, manually download from http://vision.stanford.edu/aditya86/ImageNetDogs/ and place in `~/tensorflow_datasets/`.

**Training gets stuck**: Check `tf_cache/` for checkpoint files. Delete `tf_cache/` to start completely fresh (you'll lose cached head weights).
