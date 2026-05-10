"""
Clean supplemental training data by removing flagged images.

Reads audit_flagged.json and removes images that are:
  1. WRONG_BREED flagged (model confidently predicts different breed ≥30%)
  2. Very low own-breed confidence (<2%) — likely mislabeled or wrong breed

Moves removed images to supplemental_dogs_removed/ for review.
Reports per-breed cleanup stats.

Usage:
  python clean_supplemental.py              # dry run (report only)
  python clean_supplemental.py --execute    # actually move files
"""
import json
import os
import shutil
import sys

FLAGGED_FILE = "audit_flagged.json"
SUPPLEMENTAL_DIR = "supplemental_dogs"
REMOVED_DIR = "supplemental_dogs_removed"

# Thresholds for removal
OWN_CONF_REMOVE_THRESHOLD = 0.02    # remove if own confidence < 2%
WRONG_BREED_CONF_THRESHOLD = 0.30   # AND model predicts wrong breed ≥30%

def main():
    execute = "--execute" in sys.argv

    if not os.path.exists(FLAGGED_FILE):
        print(f"ERROR: {FLAGGED_FILE} not found. Run audit_supplemental.py first.")
        return

    with open(FLAGGED_FILE, "r") as f:
        flagged = json.load(f)

    print(f"Loaded {len(flagged)} flagged entries from {FLAGGED_FILE}")

    # Determine which images to remove
    to_remove = []
    for entry in flagged:
        if not entry.get("flagged", False):
            continue

        own_conf = entry.get("own_confidence", 1.0)
        reason = entry.get("flag_reason", "")
        top3 = entry.get("top3", [])

        # Get highest confidence for a DIFFERENT breed
        wrong_breed_conf = 0.0
        for breed_name, conf_str in top3:
            conf = float(conf_str.strip("%")) / 100.0
            if breed_name.lower() != entry["breed"].lower():
                wrong_breed_conf = max(wrong_breed_conf, conf)

        # Remove if: very low own confidence AND model is somewhat confident about wrong breed
        # OR if explicitly flagged as WRONG_BREED
        should_remove = False

        if own_conf < OWN_CONF_REMOVE_THRESHOLD and wrong_breed_conf >= WRONG_BREED_CONF_THRESHOLD:
            should_remove = True

        if "WRONG_BREED" in reason:
            should_remove = True

        # Also remove extremely low confidence (< 1%) regardless
        if own_conf < 0.01:
            should_remove = True

        if should_remove:
            to_remove.append(entry)

    # Stats per breed
    breed_stats = {}
    for entry in to_remove:
        breed = entry["breed"]
        if breed not in breed_stats:
            breed_stats[breed] = {"remove": 0, "total_flagged": 0}
        breed_stats[breed]["remove"] += 1

    for entry in flagged:
        if entry.get("flagged"):
            breed = entry["breed"]
            if breed not in breed_stats:
                breed_stats[breed] = {"remove": 0, "total_flagged": 0}
            breed_stats[breed]["total_flagged"] += 1

    # Count total images per breed
    breed_total = {}
    if os.path.isdir(SUPPLEMENTAL_DIR):
        for d in os.listdir(SUPPLEMENTAL_DIR):
            dp = os.path.join(SUPPLEMENTAL_DIR, d)
            if os.path.isdir(dp):
                count = len([f for f in os.listdir(dp)
                           if f.lower().endswith((".jpg", ".jpeg", ".png"))])
                breed_total[d] = count

    print(f"\n{'='*70}")
    print(f"CLEANUP SUMMARY")
    print(f"{'='*70}")
    print(f"Total flagged images:    {len([e for e in flagged if e.get('flagged')])}")
    print(f"Images to remove:        {len(to_remove)}")
    print(f"Images to keep (flagged but acceptable): "
          f"{len([e for e in flagged if e.get('flagged')]) - len(to_remove)}")

    print(f"\n{'Breed':<30} {'Total':>6} {'Flagged':>8} {'Remove':>7} {'Keep':>6}")
    print("-" * 60)
    for breed in sorted(breed_stats.keys()):
        total = breed_total.get(breed, 0)
        flagged_count = breed_stats[breed]["total_flagged"]
        remove_count = breed_stats[breed]["remove"]
        keep = total - remove_count
        pct = f"({remove_count*100//max(total,1)}%)"
        print(f"  {breed:<28} {total:>6} {flagged_count:>8} {remove_count:>7} {keep:>6} {pct}")

    if not execute:
        print(f"\n  DRY RUN — no files moved. Use --execute to apply.")
        return

    # Move files
    print(f"\nMoving {len(to_remove)} files to {REMOVED_DIR}/...")
    moved = 0
    for entry in to_remove:
        src = entry["file"]
        if not os.path.exists(src):
            continue

        breed = entry["breed"]
        dst_dir = os.path.join(REMOVED_DIR, breed)
        os.makedirs(dst_dir, exist_ok=True)

        dst = os.path.join(dst_dir, entry["filename"])
        shutil.move(src, dst)
        moved += 1

    print(f"  Moved {moved} files")
    print(f"\n  Re-run audit_supplemental.py after cleanup to verify improvement.")
    print(f"  Then run train_model_v6.py for v6 training.")


if __name__ == "__main__":
    main()
