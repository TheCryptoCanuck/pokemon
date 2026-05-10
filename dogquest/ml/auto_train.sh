#!/bin/bash
# Auto-training pipeline: waits for v5 to finish, evaluates, then launches v5.1
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "================================================="
echo "DogQuest Auto-Training Pipeline"
echo "================================================="

# Wait for v5 to finish
echo "Waiting for v5 training (PID 3116) to complete..."
while kill -0 3116 2>/dev/null; do
    echo "  [$(date +%H:%M)] v5 still running..."
    sleep 60
done
echo "  v5 training process ended."
sleep 5

# Evaluate v5
echo ""
echo "================================================="
echo "Evaluating v5..."
echo "================================================="
if [ -f "train_v5_report.json" ]; then
    python -c "
import json
r = json.load(open('train_v5_report.json'))
acc = r['test_accuracy']
print(f'  v5 accuracy: {acc*100:.1f}%')
print(f'  Model size: {r[\"model_size_mb\"]:.1f} MB')
if acc >= 0.90:
    print('  TARGET REACHED!')
else:
    print(f'  Below target (need 90%, got {acc*100:.1f}%)')
low = r.get('low_accuracy_breeds', [])
if low:
    print(f'  Low-accuracy breeds: {len(low)}')
    for b in low[:5]:
        if isinstance(b, (list, tuple)):
            print(f'    {b[0]}: {b[1]*100:.1f}%')
        elif isinstance(b, dict):
            print(f'    {b[\"breed\"]}: {b[\"accuracy\"]*100:.1f}%')
"
    ACC=$(python -c "import json; print(json.load(open('train_v5_report.json'))['test_accuracy'])")
    if python -c "exit(0 if $ACC >= 0.90 else 1)"; then
        echo "TARGET REACHED with v5! Deploying."
        cp assets/dog_model_v5.tflite assets/dog_model.tflite 2>/dev/null
        exit 0
    fi
else
    echo "  No v5 report found. Model may have crashed."
fi

# Launch v5.1
echo ""
echo "================================================="
echo "Launching v5.1 training with all fixes..."
echo "================================================="
echo "Fixes applied:"
echo "  - class_weight bug fix (CutMix/Mixup compatible)"
echo "  - Cache-before-augmentation fix"
echo "  - Poodle 4-way split removed"
echo "  - Dead labels remapped (dingo/dhole/african hunting dog)"
echo "  - CutMix alpha 1.0, label smoothing 0.1"
echo "  - RandAugment magnitude 7, AdamW optimizer"
echo "  - 3x supplemental oversampling"
echo "  - Better quantization (100 batches representative data)"
echo ""

python train_model_v5_1.py 2>&1 | tee train_v5_1_output.log

echo ""
echo "================================================="
echo "v5.1 complete!"
echo "================================================="
if [ -f "train_v5_1_report.json" ]; then
    python -c "
import json
r = json.load(open('train_v5_1_report.json'))
acc = r['test_accuracy']
print(f'  v5.1 accuracy: {acc*100:.1f}%')
print(f'  Model size: {r[\"model_size_mb\"]:.1f} MB')
if acc >= 0.90:
    print('  TARGET REACHED!')
else:
    print(f'  Gap to target: {(0.90-acc)*100:.1f}%')
"
fi
