"""Validate all imageUrl entries in dogs.json and report failures."""
import json
import urllib.request
import urllib.error
import sys

with open("assets/dogs.json", "r", encoding="utf-8") as f:
    dogs = json.load(f)

print(f"Checking {len(dogs)} breed image URLs...\n")

failed = []
passed = 0

for i, dog in enumerate(dogs):
    name = dog["name"]
    url = dog.get("imageUrl", "")
    if not url:
        failed.append((name, url, "empty URL"))
        continue
    try:
        req = urllib.request.Request(url, method="HEAD")
        req.add_header("User-Agent", "DogQuest-Validator/1.0")
        resp = urllib.request.urlopen(req, timeout=10)
        code = resp.getcode()
        ctype = resp.headers.get("Content-Type", "")
        if code == 200 and ("image" in ctype or "octet" in ctype):
            passed += 1
        else:
            failed.append((name, url, f"status={code} content-type={ctype}"))
    except Exception as e:
        failed.append((name, url, str(e)[:100]))

    if (i + 1) % 20 == 0:
        print(f"  checked {i+1}/{len(dogs)}...")

print(f"\n{'='*60}")
print(f"Results: {passed} passed, {len(failed)} failed out of {len(dogs)}")
print(f"{'='*60}\n")

if failed:
    print("FAILED URLs:")
    for name, url, reason in failed:
        print(f"  [{name}]")
        print(f"    URL: {url}")
        print(f"    Reason: {reason}\n")
