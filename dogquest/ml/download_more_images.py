"""
Download additional training images for supplemental breeds.

Uses multiple targeted search queries per breed to get cleaner, more diverse
images. Downloads to a minimum target count, skipping breeds that already
have enough images.

Usage:
    python download_more_images.py                          # all breeds, target 100
    python download_more_images.py --target 120             # custom target
    python download_more_images.py --breeds "Akita,Poodle"  # specific breeds
"""

import argparse
import os
import shutil
import sys
import time
from pathlib import Path

try:
    from icrawler.builtin import BingImageCrawler
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "icrawler", "Pillow", "-q"])
    from icrawler.builtin import BingImageCrawler

from PIL import Image
import hashlib

# --- Config ---
SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR / "supplemental_dogs"
IMG_SIZE = 224
MIN_SRC = 100
DEFAULT_TARGET = 250

BREEDS = [
    "Akita", "American Eskimo Dog", "Australian Shepherd", "Azawakh",
    "Bergamasco Sheepdog", "Bichon Frise", "Bull Terrier", "Bulldog",
    "Canaan Dog", "Cane Corso", "Carolina Dog", "Catalburun",
    "Cavalier King Charles Spaniel", "Chinese Crested", "Chinook",
    "Dachshund", "Dalmatian", "Fila Brasileiro", "Jack Russell Terrier",
    "Kai Ken", "Kooikerhondje", "Lagotto Romagnolo", "Mudi",
    "New Guinea Singing Dog", "Norwegian Lundehund", "Peruvian Inca Orchid",
    "Pharaoh Hound", "Poodle", "Stabyhoun", "Telomian", "Thai Ridgeback",
]

# Multiple queries per breed for diversity and accuracy
def get_search_queries(breed):
    """Return a list of search queries that are likely to return correct, diverse images."""
    queries = [
        f"{breed} dog breed AKC",
        f"{breed} dog show champion",
        f"{breed} dog breed profile portrait",
        f"{breed} purebred dog photo",
    ]
    # Add breed-specific queries for commonly confused breeds
    extras = {
        "Bergamasco Sheepdog": [f"Bergamasco Sheepdog matted coat breed"],
        "Poodle": [f"Standard Poodle full body", f"Poodle dog breed not doodle"],
        "Carolina Dog": [f"Carolina Dog American Dingo breed"],
        "New Guinea Singing Dog": [f"New Guinea Singing Dog rare breed"],
        "Norwegian Lundehund": [f"Norwegian Lundehund six toes breed"],
        "Peruvian Inca Orchid": [f"Peruvian Inca Orchid hairless dog"],
        "Telomian": [f"Telomian Malaysian dog breed"],
        "Mudi": [f"Mudi Hungarian herding dog"],
        "Chinook": [f"Chinook sled dog breed New Hampshire"],
        "Kooikerhondje": [f"Kooikerhondje Dutch spaniel breed"],
        "Lagotto Romagnolo": [f"Lagotto Romagnolo truffle dog Italy"],
        "Fila Brasileiro": [f"Fila Brasileiro Brazilian Mastiff"],
        "Kai Ken": [f"Kai Ken Japanese brindle dog"],
        "Azawakh": [f"Azawakh African sighthound breed"],
        "Catalburun": [f"Catalburun Turkish pointer split nose"],
        "Stabyhoun": [f"Stabyhoun Frisian pointing dog"],
        "Thai Ridgeback": [f"Thai Ridgeback blue coat breed"],
        "Akita": [f"Akita Inu Japanese breed", f"American Akita dog"],
        "Canaan Dog": [f"Canaan Dog Israel national breed"],
        "Pharaoh Hound": [f"Pharaoh Hound Kelb tal-Fenek"],
        "Jack Russell Terrier": [f"Jack Russell Terrier small white"],
        "Dachshund": [f"Dachshund wiener dog breed"],
    }
    if breed in extras:
        queries.extend(extras[breed])
    return queries


def image_hash(filepath):
    """Compute perceptual hash to detect duplicates (simple MD5 of resized thumbnail)."""
    try:
        img = Image.open(filepath).convert("RGB").resize((32, 32))
        return hashlib.md5(img.tobytes()).hexdigest()
    except Exception:
        return None


def download_breed(breed, target_count):
    """Download images for a single breed up to target_count."""
    folder_name = breed.lower().replace(" ", "_")
    breed_dir = OUTPUT_DIR / folder_name
    breed_dir.mkdir(parents=True, exist_ok=True)

    # Count existing images
    existing = list(breed_dir.glob("*.jpg"))
    current_count = len(existing)

    if current_count >= target_count:
        print(f"  SKIP {breed}: already has {current_count} images (target: {target_count})")
        return current_count

    needed = target_count - current_count
    print(f"  {breed}: has {current_count}, needs {needed} more (target: {target_count})")

    # Collect hashes of existing images to avoid duplicates
    existing_hashes = set()
    for f in existing:
        h = image_hash(f)
        if h:
            existing_hashes.add(h)

    # Download using multiple queries
    raw_dir = breed_dir / "_raw"
    queries = get_search_queries(breed)
    total_new = 0

    # Find the next available index for naming
    existing_nums = []
    for f in existing:
        try:
            num = int(f.stem.split("_")[-1])
            existing_nums.append(num)
        except ValueError:
            pass
    next_idx = max(existing_nums) + 1 if existing_nums else current_count + 1

    for qi, query in enumerate(queries):
        if total_new >= needed:
            break

        # Clean raw dir for each query
        if raw_dir.exists():
            shutil.rmtree(raw_dir, ignore_errors=True)
        raw_dir.mkdir(parents=True, exist_ok=True)

        # Request more than needed (many will be filtered)
        request_num = min(needed - total_new + 30, 80)

        print(f"    Query {qi+1}/{len(queries)}: \"{query}\" (requesting {request_num})")

        try:
            crawler = BingImageCrawler(
                storage={"root_dir": str(raw_dir)},
                log_level=40,  # ERROR only
            )
            crawler.crawl(keyword=query, max_num=request_num, min_size=(MIN_SRC, MIN_SRC))
        except Exception as e:
            print(f"    Crawler error: {e}")
            continue

        # Process downloaded images
        query_new = 0
        for f in sorted(raw_dir.iterdir()):
            if total_new >= needed:
                break
            if f.suffix.lower() not in ('.jpg', '.jpeg', '.png', '.webp', '.bmp'):
                continue
            try:
                img = Image.open(f)
                if img.width < MIN_SRC or img.height < MIN_SRC:
                    continue
                img = img.convert("RGB")

                # Check for duplicate
                thumb = img.resize((32, 32))
                h = hashlib.md5(thumb.tobytes()).hexdigest()
                if h in existing_hashes:
                    continue
                existing_hashes.add(h)

                # Center crop to square
                w, h_px = img.size
                crop_size = min(w, h_px)
                left = (w - crop_size) // 2
                top = (h_px - crop_size) // 2
                img = img.crop((left, top, left + crop_size, top + crop_size))

                # Resize
                img = img.resize((IMG_SIZE, IMG_SIZE), Image.LANCZOS)

                out = breed_dir / f"{folder_name}_{next_idx:03d}.jpg"
                img.save(out, "JPEG", quality=90)
                next_idx += 1
                total_new += 1
                query_new += 1

            except Exception:
                continue

        print(f"    -> {query_new} new images from this query")

        # Brief pause between queries
        time.sleep(0.5)

    # Cleanup
    if raw_dir.exists():
        shutil.rmtree(raw_dir, ignore_errors=True)

    final_count = len(list(breed_dir.glob("*.jpg")))
    print(f"  {breed}: DONE - {final_count} total images ({total_new} new)")
    return final_count


def main():
    parser = argparse.ArgumentParser(description="Download more supplemental breed images")
    parser.add_argument("--target", type=int, default=DEFAULT_TARGET,
                        help=f"Target images per breed (default: {DEFAULT_TARGET})")
    parser.add_argument("--breeds", type=str, default=None,
                        help='Comma-separated breeds (e.g. "Akita,Poodle")')
    args = parser.parse_args()

    breeds = BREEDS
    if args.breeds:
        requested = [b.strip() for b in args.breeds.split(",")]
        breeds = [b for b in BREEDS if b in requested]
        if not breeds:
            print(f"No matching breeds found. Available: {BREEDS}")
            sys.exit(1)

    print("=" * 65)
    print("DogQuest -- Supplemental Image Downloader v2")
    print("=" * 65)
    print(f"  Breeds: {len(breeds)}")
    print(f"  Target per breed: {args.target}")
    print(f"  Output: {OUTPUT_DIR}")
    print(f"  Multiple queries per breed for diversity")
    print("=" * 65)

    results = {}
    start = time.time()

    for i, breed in enumerate(breeds, 1):
        print(f"\n[{i:2d}/{len(breeds)}] {breed}")
        try:
            count = download_breed(breed, args.target)
            results[breed] = count
        except Exception as e:
            print(f"  ERROR: {e}")
            results[breed] = 0
        time.sleep(1)

    elapsed = time.time() - start

    print(f"\n{'=' * 65}")
    print("SUMMARY")
    print(f"{'=' * 65}")
    for breed in breeds:
        count = results.get(breed, 0)
        status = "OK" if count >= args.target else f"LOW ({count})"
        print(f"  {breed:<35s} {count:4d} images  [{status}]")

    total = sum(results.values())
    low = [b for b, c in results.items() if c < args.target]
    print(f"\n  Total images: {total}")
    print(f"  At target: {len(breeds) - len(low)}/{len(breeds)}")
    if low:
        print(f"  Below target: {', '.join(low)}")
    print(f"  Elapsed: {elapsed:.0f}s ({elapsed/60:.1f} min)")
    print("=" * 65)


if __name__ == "__main__":
    main()
