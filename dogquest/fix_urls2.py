"""Search Wikimedia Commons API for real image filenames, then update dogs.json."""
import json
import urllib.request
import urllib.parse
import time

# Breeds that got real 404s (not rate-limited)
BREEDS_TO_FIX = [
    "French Bulldog", "Bulldog", "Great Dane", "Bernese Mountain Dog",
    "Whippet", "Irish Setter", "Bull Terrier", "Vizsla",
    "Belgian Malinois", "Papillon", "Saint Bernard", "Komondor",
    "Tibetan Mastiff", "Azawakh", "Bergamasco Sheepdog", "Mudi",
    "Catalburun", "New Guinea Singing Dog", "Chinook", "Kooikerhondje",
    "Pekingese", "Toy Terrier", "Redbone Coonhound", "Norfolk Terrier",
    "Sealyham Terrier", "Australian Terrier", "Gordon Setter",
    "Sussex Spaniel", "Keeshond", "Miniature Poodle",
    "Boston Terrier", "Soft-Coated Wheaten Terrier",
]

def search_commons(query):
    """Search Wikimedia Commons for an image file."""
    params = urllib.parse.urlencode({
        'action': 'query',
        'list': 'search',
        'srsearch': f'{query} dog breed',
        'srnamespace': '6',  # File namespace
        'srlimit': '5',
        'format': 'json',
    })
    url = f'https://commons.wikimedia.org/w/api.php?{params}'
    req = urllib.request.Request(url)
    req.add_header('User-Agent', 'DogQuest-Validator/1.0 (jesse@dogquest.app)')
    try:
        resp = urllib.request.urlopen(req, timeout=10)
        data = json.loads(resp.read())
        results = data.get('query', {}).get('search', [])
        for r in results:
            title = r['title']
            if title.startswith('File:'):
                fname = title[5:]  # Remove "File:" prefix
                # Skip SVGs, PDFs, etc.
                if any(fname.lower().endswith(ext) for ext in ['.jpg', '.jpeg', '.png']):
                    return fname
    except Exception as e:
        print(f"    API error: {e}")
    return None

with open("assets/dogs.json", "r", encoding="utf-8") as f:
    dogs = json.load(f)

fixed = 0
not_found = []

for breed in BREEDS_TO_FIX:
    print(f"Searching: {breed}...", end=" ")
    fname = search_commons(breed)
    time.sleep(0.5)  # Rate limit

    if fname:
        encoded = urllib.parse.quote(fname, safe='')
        new_url = f"https://commons.wikimedia.org/w/thumb.php?f={encoded}&w=400"
        # Find and update in dogs list
        for dog in dogs:
            if dog["name"] == breed:
                dog["imageUrl"] = new_url
                fixed += 1
                print(f"-> {fname}")
                break
    else:
        not_found.append(breed)
        print("NOT FOUND")

with open("assets/dogs.json", "w", encoding="utf-8") as f:
    json.dump(dogs, f, indent=2, ensure_ascii=False)

print(f"\nFixed {fixed}/{len(BREEDS_TO_FIX)} URLs")
if not_found:
    print(f"Still missing: {not_found}")
