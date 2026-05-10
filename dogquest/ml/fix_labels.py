#!/usr/bin/env python3
"""
Fix dog_labels.txt to match v6 model output order.

The v6 model was trained with this class ordering:
  1. Stanford Dogs TFDS labels (cleaned, minus 3 wild canids) → indices 0-116
  2. New supplemental breeds (sorted alphabetically by folder name) → indices 117-295

generate_dogs.py overwrote dog_labels.txt with dogs.json popularity order,
breaking the mapping between model output indices and breed names.

This script regenerates the correct dog_labels.txt by replicating the
exact label-building logic from train_model_v6.py.

Usage:
    # RECOMMENDED: On the machine with tensorflow-datasets installed (e.g., WSL2):
    python3 fix_labels.py

    # If TFDS is not available, use --no-tfds (may need manual verification):
    python3 fix_labels.py --no-tfds
"""
import os
import sys
import argparse

OUTPUT_DIR = "assets"
SUPPLEMENTAL_DIR = "supplemental_dogs"
LABELS_PATH = os.path.join(OUTPUT_DIR, "dog_labels.txt")


# ── Stanford Dogs name mapping (exact copy from train_model_v6.py) ────────
# NOTE: The original train_model_v6.py MAP uses lowercase keys and the lookup
# is case-sensitive via .get(informal). TFDS returns mixed-case names, so some
# names pass through uncleaned. This function replicates that EXACT behavior.

def clean_stanford_name(raw_name: str):
    """Convert Stanford Dogs label format to proper breed name (or None to exclude).

    IMPORTANT: This is an EXACT copy of the function from train_model_v6.py.
    The MAP keys are lowercase and .get() is case-sensitive, matching the
    training script's behavior exactly.
    """
    if "-" in raw_name:
        raw_name = raw_name.split("-", 1)[1]
    informal = raw_name.replace("_", " ")

    _STANFORD_NAME_MAP = {
        "chihuahua": "Chihuahua",
        "japanese spaniel": "Japanese Chin",
        "maltese dog": "Maltese",
        "pekinese": "Pekingese",
        "shih-tzu": "Shih Tzu",
        "blenheim spaniel": "Blenheim Spaniel",
        "papillon": "Papillon",
        "toy terrier": "Toy Terrier",
        "rhodesian ridgeback": "Rhodesian Ridgeback",
        "afghan hound": "Afghan Hound",
        "basset": "Basset Hound",
        "beagle": "Beagle",
        "bloodhound": "Bloodhound",
        "bluetick": "Bluetick Coonhound",
        "black-and-tan coonhound": "Black and Tan Coonhound",
        "walker hound": "Walker Hound",
        "english foxhound": "English Foxhound",
        "redbone": "Redbone Coonhound",
        "borzoi": "Borzoi",
        "irish wolfhound": "Irish Wolfhound",
        "italian greyhound": "Italian Greyhound",
        "whippet": "Whippet",
        "ibizan hound": "Ibizan Hound",
        "norwegian elkhound": "Norwegian Elkhound",
        "otterhound": "Otterhound",
        "saluki": "Saluki",
        "scottish deerhound": "Scottish Deerhound",
        "weimaraner": "Weimaraner",
        "staffordshire bullterrier": "Staffordshire Bull Terrier",
        "american staffordshire terrier": "American Staffordshire Terrier",
        "bedlington terrier": "Bedlington Terrier",
        "border terrier": "Border Terrier",
        "kerry blue terrier": "Kerry Blue Terrier",
        "irish terrier": "Irish Terrier",
        "norfolk terrier": "Norfolk Terrier",
        "norwich terrier": "Norwich Terrier",
        "yorkshire terrier": "Yorkshire Terrier",
        "wire-haired fox terrier": "Wire Fox Terrier",
        "lakeland terrier": "Lakeland Terrier",
        "sealyham terrier": "Sealyham Terrier",
        "airedale": "Airedale Terrier",
        "cairn": "Cairn Terrier",
        "australian terrier": "Australian Terrier",
        "dandie dinmont": "Dandie Dinmont Terrier",
        "boston bull": "Boston Terrier",
        "miniature schnauzer": "Miniature Schnauzer",
        "giant schnauzer": "Giant Schnauzer",
        "standard schnauzer": "Standard Schnauzer",
        "scotch terrier": "Scottish Terrier",
        "tibetan terrier": "Tibetan Terrier",
        "silky terrier": "Silky Terrier",
        "soft-coated wheaten terrier": "Soft-Coated Wheaten Terrier",
        "west highland white terrier": "West Highland White Terrier",
        "lhasa": "Lhasa Apso",
        "flat-coated retriever": "Flat-Coated Retriever",
        "curly-coated retriever": "Curly-Coated Retriever",
        "golden retriever": "Golden Retriever",
        "labrador retriever": "Labrador Retriever",
        "chesapeake bay retriever": "Chesapeake Bay Retriever",
        "german short-haired pointer": "German Shorthaired Pointer",
        "vizsla": "Vizsla",
        "english setter": "English Setter",
        "irish setter": "Irish Setter",
        "gordon setter": "Gordon Setter",
        "brittany spaniel": "Brittany",
        "clumber": "Clumber Spaniel",
        "english springer": "English Springer Spaniel",
        "welsh springer spaniel": "Welsh Springer Spaniel",
        "cocker spaniel": "Cocker Spaniel",
        "sussex spaniel": "Sussex Spaniel",
        "irish water spaniel": "Irish Water Spaniel",
        "kuvasz": "Kuvasz",
        "schipperke": "Schipperke",
        "groenendael": "Belgian Sheepdog",
        "malinois": "Belgian Malinois",
        "briard": "Briard",
        "kelpie": "Australian Kelpie",
        "komondor": "Komondor",
        "old english sheepdog": "Old English Sheepdog",
        "shetland sheepdog": "Shetland Sheepdog",
        "collie": "Collie",
        "border collie": "Border Collie",
        "bouvier des flandres": "Bouvier des Flandres",
        "rottweiler": "Rottweiler",
        "german shepherd": "German Shepherd",
        "doberman": "Doberman Pinscher",
        "miniature pinscher": "Miniature Pinscher",
        "greater swiss mountain dog": "Greater Swiss Mountain Dog",
        "bernese mountain dog": "Bernese Mountain Dog",
        "appenzeller": "Appenzeller Sennenhund",
        "entlebucher": "Entlebucher Mountain Dog",
        "boxer": "Boxer",
        "bull mastiff": "Bullmastiff",
        "tibetan mastiff": "Tibetan Mastiff",
        "french bulldog": "French Bulldog",
        "great dane": "Great Dane",
        "saint bernard": "Saint Bernard",
        "eskimo dog": "American Eskimo Dog",
        "malamute": "Alaskan Malamute",
        "siberian husky": "Siberian Husky",
        "affenpinscher": "Affenpinscher",
        "basenji": "Basenji",
        "pug": "Pug",
        "leonberg": "Leonberger",
        "newfoundland": "Newfoundland",
        "great pyrenees": "Great Pyrenees",
        "samoyed": "Samoyed",
        "pomeranian": "Pomeranian",
        "chow": "Chow Chow",
        "keeshond": "Keeshond",
        "brabancon griffon": "Brussels Griffon",
        "pembroke": "Pembroke Welsh Corgi",
        "cardigan": "Cardigan Welsh Corgi",
        "toy poodle": "Toy Poodle",
        "miniature poodle": "Miniature Poodle",
        "standard poodle": "Standard Poodle",
        "mexican hairless": "Xoloitzcuintli",
        # Wild canids -- exclude
        "dingo": None,
        "dhole": None,
        "african hunting dog": None,
    }

    return _STANFORD_NAME_MAP.get(informal, informal)


def clean_supplemental_name(folder_name: str) -> str:
    """Convert folder name to proper breed name (exact copy from train_model_v6.py)."""
    _overrides = {
        "mcnab_dog": "McNab Dog",
        "cirneco_dell'etna": "Cirneco dell'Etna",
        "danish-swedish_farmdog": "Danish-Swedish Farmdog",
        "pont-audemer_spaniel": "Pont-Audemer Spaniel",
    }
    if folder_name in _overrides:
        return _overrides[folder_name]

    _lowercase_words = {"de", "do", "da", "of", "and", "the", "del", "des", "von"}

    words = folder_name.replace("_", " ").split()
    result = []
    for i, w in enumerate(words):
        if i > 0 and w.lower() in _lowercase_words:
            result.append(w.lower())
        else:
            result.append(w.capitalize())
    return " ".join(result)


# ── Stanford Dogs TFDS label order (120 classes, by synset ID) ────────────
# This is the stable, deterministic order from tensorflow_datasets stanford_dogs.
# Source: https://www.tensorflow.org/datasets/catalog/stanford_dogs

STANFORD_TFDS_RAW_NAMES = [
    "n02085620-Chihuahua",
    "n02085782-Japanese_spaniel",
    "n02085936-Maltese_dog",
    "n02086079-Pekinese",
    "n02086240-Shih-Tzu",
    "n02086646-Blenheim_spaniel",
    "n02086910-papillon",
    "n02087046-toy_terrier",
    "n02087394-Rhodesian_ridgeback",
    "n02088094-Afghan_hound",
    "n02088238-basset",
    "n02088364-beagle",
    "n02088466-bloodhound",
    "n02088632-bluetick",
    "n02089078-black-and-tan_coonhound",
    "n02089867-Walker_hound",
    "n02089973-English_foxhound",
    "n02090379-redbone",
    "n02090622-borzoi",
    "n02090721-Irish_wolfhound",
    "n02091032-Italian_greyhound",
    "n02091134-whippet",
    "n02091244-Ibizan_hound",
    "n02091467-Norwegian_elkhound",
    "n02091635-otterhound",
    "n02091831-Saluki",
    "n02092002-Scottish_deerhound",
    "n02092339-Weimaraner",
    "n02093256-Staffordshire_bullterrier",
    "n02093428-American_Staffordshire_terrier",
    "n02093647-Bedlington_terrier",
    "n02093754-Border_terrier",
    "n02093859-Kerry_blue_terrier",
    "n02093991-Irish_terrier",
    "n02094114-Norfolk_terrier",
    "n02094258-Norwich_terrier",
    "n02094433-Yorkshire_terrier",
    "n02095314-wire-haired_fox_terrier",
    "n02095570-Lakeland_terrier",
    "n02095889-Sealyham_terrier",
    "n02096051-Airedale",
    "n02096177-cairn",
    "n02096294-Australian_terrier",
    "n02096437-Dandie_Dinmont",
    "n02096585-Boston_bull",
    "n02097047-miniature_schnauzer",
    "n02097130-giant_schnauzer",
    "n02097209-standard_schnauzer",
    "n02097298-Scotch_terrier",
    "n02097474-Tibetan_terrier",
    "n02097658-silky_terrier",
    "n02098105-soft-coated_wheaten_terrier",
    "n02098286-West_Highland_white_terrier",
    "n02098413-Lhasa",
    "n02099267-flat-coated_retriever",
    "n02099429-curly-coated_retriever",
    "n02099601-golden_retriever",
    "n02099712-Labrador_retriever",
    "n02099849-Chesapeake_Bay_retriever",
    "n02100236-German_short-haired_pointer",
    "n02100583-vizsla",
    "n02100735-English_setter",
    "n02100877-Irish_setter",
    "n02101006-Gordon_setter",
    "n02101388-Brittany_spaniel",
    "n02101556-clumber",
    "n02102040-English_springer",
    "n02102177-Welsh_springer_spaniel",
    "n02102318-cocker_spaniel",
    "n02102480-Sussex_spaniel",
    "n02102973-Irish_water_spaniel",
    "n02104029-kuvasz",
    "n02104365-schipperke",
    "n02105056-groenendael",
    "n02105162-malinois",
    "n02105251-briard",
    "n02105412-kelpie",
    "n02105505-komondor",
    "n02105641-Old_English_sheepdog",
    "n02105855-Shetland_sheepdog",
    "n02106030-collie",
    "n02106166-Border_collie",
    "n02106382-Bouvier_des_Flandres",
    "n02106550-Rottweiler",
    "n02106662-German_shepherd",
    "n02107142-Doberman",
    "n02107312-miniature_pinscher",
    "n02107574-Greater_Swiss_Mountain_dog",
    "n02107683-Bernese_mountain_dog",
    "n02107908-Appenzeller",
    "n02108000-EntleBucher",
    "n02108089-boxer",
    "n02108422-bull_mastiff",
    "n02108551-Tibetan_mastiff",
    "n02108915-French_bulldog",
    "n02109047-Great_Dane",
    "n02109525-Saint_Bernard",
    "n02109961-Eskimo_dog",
    "n02110063-malamute",
    "n02110185-Siberian_husky",
    "n02110627-affenpinscher",
    "n02110806-basenji",
    "n02110958-pug",
    "n02111129-Leonberg",
    "n02111277-Newfoundland",
    "n02111500-Great_Pyrenees",
    "n02111889-Samoyed",
    "n02112018-Pomeranian",
    "n02112137-chow",
    "n02112350-keeshond",
    "n02112706-Brabancon_griffon",
    "n02113023-Pembroke",
    "n02113186-Cardigan",
    "n02113624-toy_poodle",
    "n02113712-miniature_poodle",
    "n02113799-standard_poodle",
    "n02113978-Mexican_hairless",
    "n02115641-dingo",
    "n02115913-dhole",
    "n02116738-African_hunting_dog",
]


def get_stanford_clean_names_hardcoded():
    """Get Stanford Dogs clean names in TFDS order, excluding wild canids."""
    all_clean = [clean_stanford_name(n) for n in STANFORD_TFDS_RAW_NAMES]
    return [n for n in all_clean if n is not None]


def get_stanford_clean_names_tfds():
    """Get Stanford Dogs clean names from actual TFDS dataset."""
    try:
        import tensorflow_datasets as tfds
        _, info = tfds.load("stanford_dogs", split=["train"], with_info=True)
        raw_names = info.features["label"].names
        all_clean = [clean_stanford_name(n) for n in raw_names]
        return [n for n in all_clean if n is not None]
    except Exception as e:
        print(f"  TFDS not available ({e}), falling back to hardcoded order")
        return get_stanford_clean_names_hardcoded()


def get_supplemental_new_breeds(stanford_clean_lower):
    """Get new supplemental breeds (not in Stanford), sorted alphabetically."""
    import glob as globmod

    new_supplemental = []
    for entry in sorted(os.listdir(SUPPLEMENTAL_DIR)):
        folder_path = os.path.join(SUPPLEMENTAL_DIR, entry)
        if not os.path.isdir(folder_path):
            continue
        imgs = set()
        for ext in ("*.jpg", "*.jpeg", "*.png", "*.JPG", "*.JPEG", "*.PNG"):
            imgs.update(globmod.glob(os.path.join(folder_path, ext)))
        if len(imgs) == 0:
            continue
        clean = clean_supplemental_name(entry)
        if clean.lower() not in stanford_clean_lower:
            new_supplemental.append(clean)

    return new_supplemental


def validate_against_model(num_labels):
    """Check if label count matches model output shape."""
    model_path = os.path.join(OUTPUT_DIR, "dog_model.tflite")
    if not os.path.exists(model_path):
        return None
    try:
        import tensorflow as tf
        interp = tf.lite.Interpreter(model_path=model_path)
        interp.allocate_tensors()
        out = interp.get_output_details()
        model_classes = out[0]['shape'][-1]
        return model_classes
    except Exception:
        return None


def main():
    parser = argparse.ArgumentParser(description="Fix dog_labels.txt to match v6 model output order")
    parser.add_argument("--no-tfds", action="store_true",
                        help="Use hardcoded Stanford order instead of loading TFDS (less reliable)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print labels but don't write file")
    args = parser.parse_args()

    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    # Step 1: Get Stanford Dogs labels in TFDS order
    print("Step 1: Getting Stanford Dogs labels in model output order...")
    if args.no_tfds:
        stanford_clean = get_stanford_clean_names_hardcoded()
        print(f"  Using hardcoded TFDS order ({len(stanford_clean)} breeds)")
        print(f"  ⚠️  NOTE: --no-tfds may have slight casing differences from actual training.")
        print(f"  For exact results, run without --no-tfds where TFDS is installed.")
    else:
        stanford_clean = get_stanford_clean_names_tfds()
        print(f"  Got {len(stanford_clean)} Stanford breeds")

    stanford_clean_lower = {n.lower() for n in stanford_clean}

    # Step 2: Get new supplemental breeds
    print("\nStep 2: Getting supplemental breeds...")
    if not os.path.isdir(SUPPLEMENTAL_DIR):
        print(f"  ERROR: {SUPPLEMENTAL_DIR}/ not found")
        sys.exit(1)

    new_supplemental = get_supplemental_new_breeds(stanford_clean_lower)
    print(f"  Found {len(new_supplemental)} new supplemental breeds")

    # Step 3: Build complete label list
    all_labels = list(stanford_clean) + new_supplemental
    print(f"\nTotal labels: {len(all_labels)} (should be 296)")

    # Validate against model
    model_classes = validate_against_model(len(all_labels))
    if model_classes:
        print(f"  Model output classes: {model_classes}")
        if len(all_labels) != model_classes:
            print(f"  ⚠️  MISMATCH: {len(all_labels)} labels vs {model_classes} model outputs")
            if args.no_tfds:
                print(f"  This is likely due to --no-tfds casing differences.")
                print(f"  Run without --no-tfds for exact results.")
        else:
            print(f"  ✅ Label count matches model output!")
    elif len(all_labels) != 296:
        print(f"  WARNING: Expected 296 labels, got {len(all_labels)}")

    # Step 4: Compare with current file
    if os.path.exists(LABELS_PATH):
        with open(LABELS_PATH, "r") as f:
            current = [line.strip() for line in f if line.strip()]
        # Check for differences
        if current == all_labels:
            print(f"\n✅ {LABELS_PATH} is already correct! No changes needed.")
            return
        else:
            n_diff = sum(1 for a, b in zip(current, all_labels) if a != b)
            print(f"\n  Current file has {len(current)} labels, {n_diff} differ from correct order")
            # Show first few differences
            print(f"\n  First differences:")
            shown = 0
            for i, (cur, correct) in enumerate(zip(current, all_labels)):
                if cur != correct and shown < 10:
                    print(f"    [{i:3d}] current: {cur:<35s} → correct: {correct}")
                    shown += 1

    # Step 5: Write corrected file
    if args.dry_run:
        print(f"\n  DRY RUN — would write {len(all_labels)} labels to {LABELS_PATH}")
        print(f"\n  First 10 labels:")
        for i, name in enumerate(all_labels[:10]):
            print(f"    [{i:3d}] {name}")
        print(f"  ...")
        print(f"  Last 5 labels:")
        for i, name in enumerate(all_labels[-5:], len(all_labels) - 5):
            print(f"    [{i:3d}] {name}")
    else:
        # Backup current file
        if os.path.exists(LABELS_PATH):
            backup_path = LABELS_PATH + ".bak"
            import shutil
            shutil.copy2(LABELS_PATH, backup_path)
            print(f"\n  Backed up current file to {backup_path}")

        with open(LABELS_PATH, "w", encoding="utf-8") as f:
            for name in all_labels:
                f.write(name + "\n")
        print(f"\n✅ Fixed! Wrote {len(all_labels)} labels to {LABELS_PATH}")

    print(f"\nLabel order:")
    print(f"  [  0-{len(stanford_clean)-1:3d}] Stanford Dogs ({len(stanford_clean)} breeds, TFDS synset order)")
    print(f"  [{len(stanford_clean):3d}-{len(all_labels)-1:3d}] Supplemental ({len(new_supplemental)} breeds, alphabetical)")
    print(f"\nNext steps:")
    print(f"  1. Re-run: python3 audit_and_clean.py")
    print(f"  2. Rebuild APK: flutter build apk --debug")


if __name__ == "__main__":
    main()
