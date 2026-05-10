"""
Safe cleanup of supplemental training data.

Key safety rules:
  1. NEVER delete a breed folder — move bad images to a review folder
  2. NEVER drop a breed below MIN_KEEP images
  3. Prioritize removing the WORST images first (lowest own-breed confidence)
  4. Report exactly what was moved for full traceability

Reads audit_flagged.json and moves the worst mislabeled images to
supplemental_dogs_removed/ (preserving breed subfolder structure).

Usage:
  python safe_clean_supplemental.py              # dry run (report only)
  python safe_clean_supplemental.py --execute    # actually move files
"""
import json
import os
import shutil
import sys
from collections import Counter, defaultdict

FLAGGED_FILE = "audit_flagged.json"
SUPPLEMENTAL_DIR = "supplemental_dogs"
REMOVED_DIR = "supplemental_dogs_removed"

# Safety floor: never drop a breed below this many images
MIN_KEEP = 50

# Only remove images where the model is genuinely confident it's wrong
OWN_CONF_CEILING = 0.02     # own breed confidence < 2%
WRONG_BREED_FLOOR = 0.30    # AND wrong breed confidence >= 30%


def count_breed_images(supplemental_dir):
    """Count total images per breed folder."""
    counts = {}
    for d in sorted(os.listdir(supplemental_dir)):
        dp = os.path.join(supplemental_dir, d)
        if os.path.isdir(dp):
            n = len([f for f in os.listdir(dp)
                     if f.lower().endswith((".jpg", ".jpeg", ".png", ".webp"))])
            counts[d] = n
    return counts


def score_for_removal(entry):
    """Lower score = worse image = remove first. Sorts ascending."""
    own_conf = entry.get("own_confidence", 1.0)
    # Images with 0 own confidence and high wrong-breed confidence are worst
    return own_conf


def main():
    execute = "--execute" in sys.argv
    os.chdir(os.path.dirname(os.path.abspath(__file__)) or ".")

    if not os.path.exists(FLAGGED_FILE):
        print(f"ERROR: {FLAGGED_FILE} not found. Run audit_supplemental.py first.")
        return

    with open(FLAGGED_FILE, "r") as f:
        flagged = json.load(f)

    print(f"Loaded {len(flagged)} flagged entries from {FLAGGED_FILE}")

    # Current image counts
    breed_total = count_breed_images(SUPPLEMENTAL_DIR)
    print(f"Found {len(breed_total)} breed folders, {sum(breed_total.values())} total images\n")

    # --- Identify candidates for removal ---
    candidates_by_breed = defaultdict(list)

    for entry in flagged:
        if not entry.get("flagged"):
            continue

        own_conf = entry.get("own_confidence", 1.0)
        reason = entry.get("flag_reason", "")
        top3 = entry.get("top3", [])

        # Compute wrong-breed confidence
        wrong_breed_conf = 0.0
        for breed_name, conf_str in top3:
            conf = float(conf_str.strip("%")) / 100.0
            if breed_name.lower().replace(" ", "_") != entry["breed"].lower():
                wrong_breed_conf = max(wrong_breed_conf, conf)

        # Strict removal criteria
        should_consider = False

        if "WRONG_BREED" in reason and own_conf < OWN_CONF_CEILING:
            should_consider = True
        elif own_conf < 0.01 and wrong_breed_conf >= WRONG_BREED_FLOOR:
            should_consider = True
        elif "LOW_ENTROPY" in reason:
            should_consider = True  # corrupt/blank images always go

        if should_consider:
            candidates_by_breed[entry["breed"]].append(entry)

    # --- Apply safety floor: cap removals per breed ---
    to_remove = []
    skipped_for_safety = 0

    for breed in sorted(candidates_by_breed):
        total = breed_total.get(breed, 0)
        candidates = candidates_by_breed[breed]

        # Sort by quality score (worst first)
        candidates.sort(key=score_for_removal)

        # How many can we safely remove?
        max_removable = max(0, total - MIN_KEEP)

        if len(candidates) <= max_removable:
            to_remove.extend(candidates)
        else:
            # Only take the worst ones up to the safety limit
            to_remove.extend(candidates[:max_removable])
            skipped_for_safety += len(candidates) - max_removable

    # --- Report ---
    remove_counts = Counter(e["breed"] for e in to_remove)

    print(f"{'=' * 70}")
    print(f"SAFE CLEANUP SUMMARY")
    print(f"{'=' * 70}")
    print(f"Total flagged images:      {len([e for e in flagged if e.get('flagged')])}")
    print(f"Candidates for removal:    {sum(len(v) for v in candidates_by_breed.values())}")
    print(f"Actually removing:         {len(to_remove)}")
    print(f"Skipped (safety floor):    {skipped_for_safety}")
    print(f"Safety floor:              {MIN_KEEP} images/breed minimum")

    print(f"\n{'Breed':<30} {'Before':>7} {'Remove':>7} {'After':>7} {'Status'}")
    print("-" * 75)

    all_breeds = sorted(set(list(remove_counts.keys()) + list(candidates_by_breed.keys())))
    for breed in all_breeds:
        total = breed_total.get(breed, 0)
        removing = remove_counts.get(breed, 0)
        after = total - removing
        capped = len(candidates_by_breed.get(breed, [])) > removing
        status = "CAPPED (safety floor)" if capped else "OK"
        print(f"  {breed:<28} {total:>7} {removing:>7} {after:>7}   {status}")

    # Verify no breed is destroyed
    print(f"\n{'=' * 70}")
    print("SAFETY CHECK")
    print(f"{'=' * 70}")
    all_ok = True
    for breed in breed_total:
        after = breed_total[breed] - remove_counts.get(breed, 0)
        if after < MIN_KEEP and remove_counts.get(breed, 0) > 0:
            print(f"  BLOCKED: {breed} would have {after} images (below {MIN_KEEP})")
            all_ok = False
    if all_ok:
        print(f"  ALL BREEDS SAFE — every breed keeps >= {MIN_KEEP} images")
    else:
        print(f"\n  ERROR: Safety check failed. Aborting.")
        return

    # Check no breed folder will be empty
    for breed in breed_total:
        if breed_total[breed] - remove_counts.get(breed, 0) <= 0:
            print(f"  CRITICAL: {breed} would be EMPTY. Aborting.")
            return

    if not execute:
        print(f"\n  DRY RUN — no files moved. Use --execute to apply.")
        return

    # --- Execute: move files ---
    print(f"\nMoving {len(to_remove)} files to {REMOVED_DIR}/...")
    moved = 0
    errors = 0

    for entry in to_remove:
        src = entry["file"]
        if not os.path.exists(src):
            errors += 1
            continue

        breed = entry["breed"]
        dst_dir = os.path.join(REMOVED_DIR, breed)
        os.makedirs(dst_dir, exist_ok=True)

        dst = os.path.join(dst_dir, entry["filename"])
        try:
            shutil.move(src, dst)
            moved += 1
        except Exception as e:
            print(f"  ERROR moving {src}: {e}")
            errors += 1

    print(f"  Moved: {moved}")
    if errors:
        print(f"  Errors: {errors}")

    # Final verification
    print(f"\nPost-cleanup verification:")
    post_counts = count_breed_images(SUPPLEMENTAL_DIR)
    all_safe = True
    for breed in sorted(post_counts):
        if post_counts[breed] < MIN_KEEP:
            print(f"  WARNING: {breed} has only {post_counts[breed]} images!")
            all_safe = False

    if all_safe:
        print(f"  ALL {len(post_counts)} breed folders intact with >= {MIN_KEEP} images each")
    print(f"  Total images remaining: {sum(post_counts.values())}")
    print(f"\n  Removed images saved in: {REMOVED_DIR}/")
    print(f"  To undo: move files back from {REMOVED_DIR}/ to {SUPPLEMENTAL_DIR}/")


if __name__ == "__main__":
    main()
