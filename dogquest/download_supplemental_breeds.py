#!/usr/bin/env python3
"""
download_supplemental_breeds.py
-------------------------------
Downloads training images for the 31 dog breeds missing from the Stanford Dogs
dataset (120 breeds) so we can fine-tune/retrain the DogQuest model to cover
all 147 breeds.

Uses icrawler (primary) or bing_image_downloader (fallback) to fetch ~150
images per breed from the web, then resizes to 224x224 and applies basic
quality filtering.

Usage:
    python download_supplemental_breeds.py                  # full download
    python download_supplemental_breeds.py --dry-run        # preview only
    python download_supplemental_breeds.py --max-per-breed 50  # fewer images
    python download_supplemental_breeds.py --breeds "Akita,Poodle"  # subset
"""

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

# ---------------------------------------------------------------------------
# Auto-install dependencies
# ---------------------------------------------------------------------------

def ensure_packages():
    """Install required packages if missing."""
    required = {
        "icrawler": "icrawler",
        "PIL": "Pillow",
    }
    for import_name, pip_name in required.items():
        try:
            __import__(import_name)
        except ImportError:
            print(f"[setup] Installing {pip_name} ...")
            subprocess.check_call(
                [sys.executable, "-m", "pip", "install", pip_name, "-q"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            print(f"[setup] {pip_name} installed.")


ensure_packages()

from icrawler.builtin import BingImageCrawler, GoogleImageCrawler
from PIL import Image

# ---------------------------------------------------------------------------
# Missing breeds (31 total)
# ---------------------------------------------------------------------------

MISSING_BREEDS = [
    "Akita",
    "American Eskimo Dog",
    "Australian Shepherd",
    "Azawakh",
    "Bergamasco Sheepdog",
    "Bichon Frise",
    "Bull Terrier",
    "Bulldog",
    "Canaan Dog",
    "Cane Corso",
    "Carolina Dog",
    "Catalburun",
    "Cavalier King Charles Spaniel",
    "Chinese Crested",
    "Chinook",
    "Dachshund",
    "Dalmatian",
    "Fila Brasileiro",
    "Jack Russell Terrier",
    "Kai Ken",
    "Kooikerhondje",
    "Lagotto Romagnolo",
    "Mudi",
    "New Guinea Singing Dog",
    "Norwegian Lundehund",
    "Peruvian Inca Orchid",
    "Pharaoh Hound",
    "Poodle",
    "Stabyhoun",
    "Telomian",
    "Thai Ridgeback",
]

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR / "supplemental_dogs"
MANIFEST_PATH = OUTPUT_DIR / "manifest.json"
TARGET_SIZE = (224, 224)
MIN_SOURCE_SIZE = (100, 100)  # skip images smaller than this before resize
# Request more than we need because some will be filtered out
DOWNLOAD_HEADROOM = 1.4


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def breed_to_folder(breed: str) -> str:
    """Convert breed name to a filesystem-safe folder name."""
    return breed.lower().replace(" ", "_")


def breed_search_query(breed: str) -> str:
    """Build a search query likely to return good training photos."""
    return f"{breed} dog breed photo"


def download_images_icrawler(breed: str, dest: Path, max_num: int) -> bool:
    """
    Download images using icrawler's Bing crawler.
    Falls back to Google crawler if Bing fails.
    Returns True if any images were downloaded.
    """
    query = breed_search_query(breed)
    request_num = int(max_num * DOWNLOAD_HEADROOM)

    # Try Bing first (tends to give more results)
    try:
        crawler = BingImageCrawler(
            storage={"root_dir": str(dest)},
            log_level="WARNING",
        )
        crawler.crawl(
            keyword=query,
            max_num=request_num,
            min_size=MIN_SOURCE_SIZE,
        )
        if any(dest.iterdir()):
            return True
    except Exception as e:
        print(f"  [warn] Bing crawler failed for '{breed}': {e}")

    # Fallback to Google
    try:
        crawler = GoogleImageCrawler(
            storage={"root_dir": str(dest)},
            log_level="WARNING",
        )
        crawler.crawl(
            keyword=query,
            max_num=request_num,
            min_size=MIN_SOURCE_SIZE,
        )
        if any(dest.iterdir()):
            return True
    except Exception as e:
        print(f"  [warn] Google crawler also failed for '{breed}': {e}")

    return False


def process_and_rename(breed: str, folder: Path, max_keep: int) -> int:
    """
    Post-process downloaded images:
      - Convert to RGB
      - Skip images smaller than MIN_SOURCE_SIZE
      - Resize to TARGET_SIZE (224x224)
      - Rename to {breed}_{001}.jpg, {breed}_{002}.jpg, ...
      - Delete originals that don't pass quality checks
    Returns the count of images kept.
    """
    prefix = breed_to_folder(breed)
    raw_files = sorted(folder.iterdir())
    kept = 0

    for fpath in raw_files:
        if not fpath.is_file():
            continue
        try:
            img = Image.open(fpath)

            # Quality filter: skip tiny images
            w, h = img.size
            if w < MIN_SOURCE_SIZE[0] or h < MIN_SOURCE_SIZE[1]:
                fpath.unlink(missing_ok=True)
                continue

            # Convert to RGB (drop alpha, handle grayscale, palette, etc.)
            if img.mode != "RGB":
                try:
                    img = img.convert("RGB")
                except Exception:
                    fpath.unlink(missing_ok=True)
                    continue

            # Resize to target
            img = img.resize(TARGET_SIZE, Image.LANCZOS)

            kept += 1
            if kept > max_keep:
                # We have enough
                fpath.unlink(missing_ok=True)
                kept -= 1
                continue

            new_name = f"{prefix}_{kept:03d}.jpg"
            new_path = folder / new_name

            img.save(new_path, "JPEG", quality=90)

            # Remove original if it has a different name
            if fpath.name != new_name:
                fpath.unlink(missing_ok=True)

        except Exception:
            # Corrupt / unreadable file
            fpath.unlink(missing_ok=True)

    return kept


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Download supplemental training images for missing dog breeds."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be downloaded without actually downloading.",
    )
    parser.add_argument(
        "--max-per-breed",
        type=int,
        default=150,
        help="Target number of images per breed (default: 150).",
    )
    parser.add_argument(
        "--breeds",
        type=str,
        default=None,
        help='Comma-separated subset of breeds to download (e.g. "Akita,Poodle").',
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        default=None,
        help="Override output directory (default: supplemental_dogs/ next to script).",
    )
    args = parser.parse_args()

    out_dir = Path(args.output_dir) if args.output_dir else OUTPUT_DIR
    max_per = args.max_per_breed

    # Determine which breeds to process
    if args.breeds:
        requested = [b.strip() for b in args.breeds.split(",")]
        breeds = [b for b in MISSING_BREEDS if b in requested]
        unknown = [b for b in requested if b not in MISSING_BREEDS]
        if unknown:
            print(f"[warn] Unknown breeds ignored: {unknown}")
    else:
        breeds = MISSING_BREEDS

    print("=" * 65)
    print("DogQuest -- Supplemental Breed Image Downloader")
    print("=" * 65)
    print(f"  Breeds to process : {len(breeds)}")
    print(f"  Target per breed  : {max_per}")
    print(f"  Output directory  : {out_dir}")
    print(f"  Image size        : {TARGET_SIZE[0]}x{TARGET_SIZE[1]}")
    print(f"  Min source size   : {MIN_SOURCE_SIZE[0]}x{MIN_SOURCE_SIZE[1]}")
    print(f"  Dry run           : {args.dry_run}")
    print("=" * 65)

    if args.dry_run:
        print("\n[DRY RUN] The following breeds would be downloaded:\n")
        for i, breed in enumerate(breeds, 1):
            folder = breed_to_folder(breed)
            query = breed_search_query(breed)
            print(f"  {i:2d}. {breed:<35s}  folder: {folder}/")
            print(f"      search: \"{query}\"")
        print(f"\nTotal: {len(breeds)} breeds x ~{max_per} images = ~{len(breeds) * max_per} images")
        print("Run without --dry-run to start downloading.")
        return

    # Create output directory
    out_dir.mkdir(parents=True, exist_ok=True)

    results = {}  # breed -> count
    failed = []
    start_time = time.time()

    for i, breed in enumerate(breeds, 1):
        folder_name = breed_to_folder(breed)
        breed_dir = out_dir / folder_name
        breed_dir.mkdir(parents=True, exist_ok=True)

        # Skip if already has enough images
        existing = list(breed_dir.glob("*.jpg"))
        if len(existing) >= max_per:
            print(f"[{i:2d}/{len(breeds)}] {breed:<35s} -- SKIP (already {len(existing)} images)")
            results[breed] = len(existing)
            continue

        print(f"[{i:2d}/{len(breeds)}] {breed:<35s} -- downloading ...", end="", flush=True)

        try:
            ok = download_images_icrawler(breed, breed_dir, max_per)
            if not ok:
                print(" FAILED (no images)")
                failed.append(breed)
                results[breed] = 0
                continue

            count = process_and_rename(breed, breed_dir, max_per)
            results[breed] = count
            print(f" {count} images")

        except Exception as e:
            print(f" ERROR: {e}")
            failed.append(breed)
            results[breed] = 0

        # Brief pause between breeds to be polite to image sources
        time.sleep(1)

    elapsed = time.time() - start_time

    # ------------------------------------------------------------------
    # Write manifest
    # ------------------------------------------------------------------
    manifest = {
        "description": "Supplemental training images for DogQuest missing breeds",
        "target_size": list(TARGET_SIZE),
        "min_source_size": list(MIN_SOURCE_SIZE),
        "total_breeds": len(breeds),
        "total_images": sum(results.values()),
        "breeds": {
            breed: {
                "folder": breed_to_folder(breed),
                "count": results.get(breed, 0),
                "status": "ok" if results.get(breed, 0) > 0 else "failed",
            }
            for breed in breeds
        },
    }
    manifest_path = out_dir / "manifest.json"
    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2)

    # ------------------------------------------------------------------
    # Summary
    # ------------------------------------------------------------------
    print("\n" + "=" * 65)
    print("DOWNLOAD SUMMARY")
    print("=" * 65)
    total_imgs = 0
    for breed in breeds:
        count = results.get(breed, 0)
        total_imgs += count
        status = "OK" if count > 0 else "FAILED"
        bar = "#" * min(count // 3, 50)
        print(f"  {breed:<35s} {count:4d} images  [{status}]  {bar}")

    print("-" * 65)
    print(f"  Total images downloaded : {total_imgs}")
    print(f"  Successful breeds       : {len([b for b in breeds if results.get(b, 0) > 0])}/{len(breeds)}")
    if failed:
        print(f"  Failed breeds           : {', '.join(failed)}")
    print(f"  Elapsed time            : {elapsed:.0f}s ({elapsed/60:.1f} min)")
    print(f"  Manifest written to     : {manifest_path}")
    print(f"  Output directory        : {out_dir}")
    print("=" * 65)


if __name__ == "__main__":
    main()
