"""Download images for a specific list of dog breeds. Called by parallel agents."""
import sys
import os
import time
from pathlib import Path

# Auto-install icrawler if needed
try:
    from icrawler.builtin import BingImageCrawler
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "icrawler", "Pillow", "-q"])
    from icrawler.builtin import BingImageCrawler

from PIL import Image

IMG_SIZE = 224
MIN_SRC = 100
TARGET = 200  # Request more since Bing DNS can be flaky
BASE_DIR = Path(__file__).parent / "supplemental_dogs"

def download_breed(breed_name: str):
    folder_name = breed_name.lower().replace(" ", "_")
    breed_dir = BASE_DIR / folder_name
    raw_dir = breed_dir / "_raw"
    raw_dir.mkdir(parents=True, exist_ok=True)

    # Check if already done
    existing = list(breed_dir.glob("*.jpg"))
    if len(existing) >= 20:
        print(f"  SKIP {breed_name}: already has {len(existing)} images", flush=True)
        return len(existing)

    # Download raw images using Bing crawler (Google parser is broken)
    query = f"{breed_name} dog breed photo"
    print(f"  Downloading: {query}", flush=True)
    crawler = BingImageCrawler(
        storage={"root_dir": str(raw_dir)},
        log_level=40,  # ERROR only
    )
    crawler.crawl(keyword=query, max_num=TARGET, min_size=(MIN_SRC, MIN_SRC))

    # Process: resize, filter, rename
    count = 0
    for f in sorted(raw_dir.iterdir()):
        if f.suffix.lower() not in ('.jpg', '.jpeg', '.png', '.webp', '.bmp'):
            continue
        try:
            im = Image.open(f)
            if im.width < MIN_SRC or im.height < MIN_SRC:
                continue
            im = im.convert("RGB")
            im = im.resize((IMG_SIZE, IMG_SIZE), Image.LANCZOS)
            count += 1
            out = breed_dir / f"{folder_name}_{count:03d}.jpg"
            im.save(out, "JPEG", quality=90)
        except Exception:
            continue

    # Cleanup raw
    import shutil
    shutil.rmtree(raw_dir, ignore_errors=True)

    print(f"  {breed_name}: {count} images saved", flush=True)
    return count


if __name__ == "__main__":
    breeds = sys.argv[1:]
    if not breeds:
        print("Usage: python download_batch.py 'Breed1' 'Breed2' ...")
        sys.exit(1)

    print(f"\n=== Batch download: {len(breeds)} breeds ===", flush=True)
    BASE_DIR.mkdir(parents=True, exist_ok=True)

    results = {}
    for b in breeds:
        try:
            n = download_breed(b)
            results[b] = n
        except Exception as e:
            print(f"  FAILED {b}: {e}", flush=True)
            results[b] = 0
        time.sleep(1)

    print(f"\n=== Summary ===", flush=True)
    for b, n in results.items():
        status = "OK" if n >= 20 else "LOW"
        print(f"  {b}: {n} images [{status}]")
