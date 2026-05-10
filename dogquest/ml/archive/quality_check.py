"""Quick image quality check: corruption, size, duplicates, solid colors."""
import os, hashlib
from pathlib import Path
from PIL import Image
from collections import defaultdict, Counter

sup = Path("supplemental_dogs")
small_imgs = []
corrupt_imgs = []
dim_dist = Counter()
dup_hashes = defaultdict(list)
total = 0
solid_color = []

for d in sorted(sup.iterdir()):
    if not d.is_dir():
        continue
    for f in sorted(d.iterdir()):
        if f.suffix.lower() not in (".jpg", ".jpeg", ".png", ".webp"):
            continue
        total += 1
        try:
            img = Image.open(str(f))
            w, h = img.size
            dim_dist[str(w) + "x" + str(h)] += 1
            if w < 100 or h < 100:
                small_imgs.append((str(f), w, h))
            extrema = img.convert("RGB").getextrema()
            if all(mx - mn < 10 for mn, mx in extrema):
                solid_color.append((str(f), extrema))
            thumb = img.resize((32, 32)).convert("RGB")
            h_val = hashlib.md5(thumb.tobytes()).hexdigest()
            dup_hashes[h_val].append(str(f))
        except Exception as e:
            corrupt_imgs.append((str(f), str(e)))

print("TOTAL IMAGES:", total)
print("CORRUPT (cannot open):", len(corrupt_imgs))
for p, e in corrupt_imgs[:10]:
    print("  ", p, ":", e)

print("TOO SMALL (<100x100):", len(small_imgs))
for p, w, h in small_imgs[:10]:
    print("  ", p, ":", w, "x", h)

print("SOLID/NEAR-SOLID COLOR:", len(solid_color))
for p, ex in solid_color[:10]:
    print("  ", p)

dups = {k: v for k, v in dup_hashes.items() if len(v) > 1}
dup_count = sum(len(v) - 1 for v in dups.values())
print("DUPLICATE GROUPS:", len(dups), "groups,", dup_count, "extra copies")

cross_breed = 0
for h_val, paths in sorted(dups.items(), key=lambda x: -len(x[1]))[:20]:
    breeds = set(Path(p).parent.name for p in paths)
    if len(breeds) > 1:
        cross_breed += 1
        print("  CROSS-BREED DUP (" + str(len(paths)) + " copies):")
        for p in paths[:3]:
            print("    ", p)
    elif len(paths) > 2:
        b = list(breeds)[0]
        print("  WITHIN-BREED DUP (" + str(len(paths)) + " copies in " + b + ")")

print("Cross-breed duplicate groups:", cross_breed)

print("TOP 10 IMAGE DIMENSIONS:")
for dim, cnt in dim_dist.most_common(10):
    print("  ", dim, ":", cnt)
