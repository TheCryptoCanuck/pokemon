#!/usr/bin/env python3
"""Extract and save the exact class label order from train_model_v6.py's logic.
Run once to generate tf_cache/class_labels.json for use by continue_training_v6.py.

Usage: python3 save_class_labels.py
"""
import os, sys, json, glob

# Import the name functions directly from train_model_v6
# We need: clean_stanford_name, clean_supplemental_name, stanford_class_names

# Must set up TF minimally for tensorflow_datasets
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "3"
import tensorflow_datasets as tfds

SUPPLEMENTAL_DIR = "supplemental_dogs"

# Load Stanford Dogs metadata only
_, ds_info = tfds.load("stanford_dogs", split="train", with_info=True, as_supervised=False)
stanford_class_names = ds_info.features["label"].names

# ── Replicate train_model_v6.py's name functions exactly ──────────────────

def clean_stanford_name(raw_name):
    if "-" in raw_name:
        raw_name = raw_name.split("-", 1)[1]
    informal = raw_name.replace("_", " ")
    _STANFORD_NAME_MAP = {
        "chihuahua": "Chihuahua", "japanese spaniel": "Japanese Chin",
        "maltese dog": "Maltese", "pekinese": "Pekingese",
        "shih-tzu": "Shih Tzu", "blenheim spaniel": "Blenheim Spaniel",
        "papillon": "Papillon", "toy terrier": "Toy Terrier",
        "rhodesian ridgeback": "Rhodesian Ridgeback", "afghan hound": "Afghan Hound",
        "basset": "Basset Hound", "beagle": "Beagle", "bloodhound": "Bloodhound",
        "bluetick": "Bluetick Coonhound", "black-and-tan coonhound": "Black and Tan Coonhound",
        "walker hound": "Walker Hound", "english foxhound": "English Foxhound",
        "redbone": "Redbone Coonhound", "borzoi": "Borzoi",
        "irish wolfhound": "Irish Wolfhound", "italian greyhound": "Italian Greyhound",
        "whippet": "Whippet", "ibizan hound": "Ibizan Hound",
        "norwegian elkhound": "Norwegian Elkhound", "otterhound": "Otterhound",
        "saluki": "Saluki", "scottish deerhound": "Scottish Deerhound",
        "weimaraner": "Weimaraner", "staffordshire bullterrier": "Staffordshire Bull Terrier",
        "american staffordshire terrier": "American Staffordshire Terrier",
        "bedlington terrier": "Bedlington Terrier", "border terrier": "Border Terrier",
        "kerry blue terrier": "Kerry Blue Terrier", "irish terrier": "Irish Terrier",
        "norfolk terrier": "Norfolk Terrier", "norwich terrier": "Norwich Terrier",
        "yorkshire terrier": "Yorkshire Terrier", "wire-haired fox terrier": "Wire Fox Terrier",
        "lakeland terrier": "Lakeland Terrier", "sealyham terrier": "Sealyham Terrier",
        "airedale": "Airedale Terrier", "cairn": "Cairn Terrier",
        "australian terrier": "Australian Terrier", "dandie dinmont": "Dandie Dinmont Terrier",
        "boston bull": "Boston Terrier", "miniature schnauzer": "Miniature Schnauzer",
        "giant schnauzer": "Giant Schnauzer", "standard schnauzer": "Standard Schnauzer",
        "scotch terrier": "Scottish Terrier", "tibetan terrier": "Tibetan Terrier",
        "silky terrier": "Silky Terrier",
        "soft-coated wheaten terrier": "Soft-Coated Wheaten Terrier",
        "west highland white terrier": "West Highland White Terrier",
        "lhasa": "Lhasa Apso", "flat-coated retriever": "Flat-Coated Retriever",
        "curly-coated retriever": "Curly-Coated Retriever",
        "golden retriever": "Golden Retriever", "labrador retriever": "Labrador Retriever",
        "chesapeake bay retriever": "Chesapeake Bay Retriever",
        "german short-haired pointer": "German Shorthaired Pointer",
        "vizsla": "Vizsla", "english setter": "English Setter",
        "irish setter": "Irish Setter", "gordon setter": "Gordon Setter",
        "brittany spaniel": "Brittany", "clumber": "Clumber Spaniel",
        "english springer": "English Springer Spaniel",
        "welsh springer spaniel": "Welsh Springer Spaniel",
        "cocker spaniel": "Cocker Spaniel", "sussex spaniel": "Sussex Spaniel",
        "irish water spaniel": "Irish Water Spaniel", "kuvasz": "Kuvasz",
        "schipperke": "Schipperke", "groenendael": "Belgian Sheepdog",
        "malinois": "Belgian Malinois", "briard": "Briard",
        "kelpie": "Australian Kelpie", "komondor": "Komondor",
        "old english sheepdog": "Old English Sheepdog",
        "shetland sheepdog": "Shetland Sheepdog", "collie": "Collie",
        "border collie": "Border Collie", "bouvier des flandres": "Bouvier des Flandres",
        "rottweiler": "Rottweiler", "german shepherd": "German Shepherd",
        "doberman": "Doberman Pinscher", "miniature pinscher": "Miniature Pinscher",
        "greater swiss mountain dog": "Greater Swiss Mountain Dog",
        "bernese mountain dog": "Bernese Mountain Dog",
        "appenzeller": "Appenzeller Sennenhund",
        "entlebucher": "Entlebucher Mountain Dog", "boxer": "Boxer",
        "bull mastiff": "Bullmastiff", "tibetan mastiff": "Tibetan Mastiff",
        "french bulldog": "French Bulldog", "great dane": "Great Dane",
        "saint bernard": "Saint Bernard", "eskimo dog": "American Eskimo Dog",
        "malamute": "Alaskan Malamute", "siberian husky": "Siberian Husky",
        "affenpinscher": "Affenpinscher", "basenji": "Basenji", "pug": "Pug",
        "leonberg": "Leonberger", "newfoundland": "Newfoundland",
        "great pyrenees": "Great Pyrenees", "samoyed": "Samoyed",
        "pomeranian": "Pomeranian", "chow": "Chow Chow", "keeshond": "Keeshond",
        "brabancon griffon": "Brussels Griffon",
        "pembroke": "Pembroke Welsh Corgi", "cardigan": "Cardigan Welsh Corgi",
        "toy poodle": "Toy Poodle", "miniature poodle": "Miniature Poodle",
        "standard poodle": "Standard Poodle", "mexican hairless": "Xoloitzcuintli",
        "dingo": None, "dhole": None, "african hunting dog": None,
    }
    return _STANFORD_NAME_MAP.get(informal, informal)


def clean_supplemental_name(folder_name):
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


# ── Build label list ──────────────────────────────────────────────────────

stanford_all_clean = [clean_stanford_name(n) for n in stanford_class_names]
stanford_clean = [n for n in stanford_all_clean if n is not None]
stanford_lower = {n.lower() for n in stanford_clean}

print(f"Stanford breeds: {len(stanford_clean)} (excl. 3 wild canids)")

# Discover supplemental breeds
overlaps = []
new_breeds = []
for entry in sorted(os.listdir(SUPPLEMENTAL_DIR)):
    path = os.path.join(SUPPLEMENTAL_DIR, entry)
    if not os.path.isdir(path):
        continue
    imgs = [f for f in os.listdir(path) if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
    if not imgs:
        continue
    clean = clean_supplemental_name(entry)
    if clean.lower() in stanford_lower:
        overlaps.append((entry, clean))
    else:
        new_breeds.append((entry, clean))

all_labels = list(stanford_clean)
for _, clean in new_breeds:
    all_labels.append(clean)

print(f"Overlaps: {len(overlaps)} — {[f for f, _ in overlaps]}")
print(f"New supplemental: {len(new_breeds)}")
print(f"TOTAL classes: {len(all_labels)}")

# Save
out_path = os.path.join("tf_cache", "class_labels.json")
os.makedirs("tf_cache", exist_ok=True)
with open(out_path, "w") as f:
    json.dump({"labels": all_labels, "num_classes": len(all_labels)}, f, indent=2)

print(f"\nSaved to {out_path}")
print(f"First 5: {all_labels[:5]}")
print(f"Last 5: {all_labels[-5:]}")
