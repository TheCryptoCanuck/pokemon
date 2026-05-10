"""Use Wikipedia article images to get reliable breed photos."""
import json
import urllib.request
import urllib.parse
import time
import sys
import os

os.environ['PYTHONIOENCODING'] = 'utf-8'

# Map breed names to their Wikipedia article titles
WIKI_ARTICLES = {
    "French Bulldog": "French_Bulldog",
    "Bulldog": "Bulldog",
    "Great Dane": "Great_Dane",
    "Bernese Mountain Dog": "Bernese_Mountain_Dog",
    "Whippet": "Whippet",
    "Irish Setter": "Irish_Setter",
    "Bull Terrier": "Bull_Terrier",
    "Vizsla": "Vizsla",
    "Belgian Malinois": "Belgian_Shepherd",
    "Papillon": "Papillon_(dog)",
    "Saint Bernard": "St._Bernard_(dog)",
    "Komondor": "Komondor",
    "Tibetan Mastiff": "Tibetan_Mastiff",
    "Azawakh": "Azawakh",
    "Bergamasco Sheepdog": "Bergamasco_Shepherd",
    "Mudi": "Mudi",
    "Catalburun": "Catalburun",
    "New Guinea Singing Dog": "New_Guinea_singing_dog",
    "Chinook": "Chinook_(dog)",
    "Kooikerhondje": "Kooikerhondje",
    "Pekingese": "Pekingese",
    "Toy Terrier": "English_Toy_Terrier_(Black_%26_Tan)",
    "Redbone Coonhound": "Redbone_Coonhound",
    "Norfolk Terrier": "Norfolk_Terrier",
    "Sealyham Terrier": "Sealyham_Terrier",
    "Australian Terrier": "Australian_Terrier",
    "Gordon Setter": "Gordon_Setter",
    "Sussex Spaniel": "Sussex_Spaniel",
    "Keeshond": "Keeshond",
    "Miniature Poodle": "Poodle",
    "Boston Terrier": "Boston_Terrier",
    "Soft-Coated Wheaten Terrier": "Soft-coated_Wheaten_Terrier",
}

def get_wiki_image(article_title):
    """Get the main image filename from a Wikipedia article."""
    params = urllib.parse.urlencode({
        'action': 'query',
        'titles': article_title,
        'prop': 'pageimages',
        'piprop': 'original',
        'format': 'json',
    })
    url = f'https://en.wikipedia.org/w/api.php?{params}'
    req = urllib.request.Request(url)
    req.add_header('User-Agent', 'DogQuest-Validator/1.0')
    try:
        resp = urllib.request.urlopen(req, timeout=10)
        data = json.loads(resp.read())
        pages = data.get('query', {}).get('pages', {})
        for page in pages.values():
            orig = page.get('original', {})
            source = orig.get('source', '')
            if source:
                # Extract filename from the full URL
                # e.g., https://upload.wikimedia.org/wikipedia/commons/2/26/French_Bulldog.jpg
                parts = source.split('/')
                filename = parts[-1]
                return filename
    except Exception as e:
        pass
    return None

with open("assets/dogs.json", "r", encoding="utf-8") as f:
    dogs = json.load(f)

fixed = 0
failed = []

for breed, article in WIKI_ARTICLES.items():
    fname = get_wiki_image(article)
    time.sleep(0.3)

    if fname:
        encoded = urllib.parse.quote(fname, safe='')
        new_url = f"https://commons.wikimedia.org/w/thumb.php?f={encoded}&w=400"
        for dog in dogs:
            if dog["name"] == breed:
                dog["imageUrl"] = new_url
                fixed += 1
                break
        sys.stdout.buffer.write(f"  OK: {breed}\n".encode('utf-8'))
    else:
        failed.append(breed)
        sys.stdout.buffer.write(f"  FAIL: {breed}\n".encode('utf-8'))

sys.stdout.flush()

with open("assets/dogs.json", "w", encoding="utf-8") as f:
    json.dump(dogs, f, indent=2, ensure_ascii=False)

sys.stdout.buffer.write(f"\nFixed {fixed}/{len(WIKI_ARTICLES)} URLs\n".encode('utf-8'))
if failed:
    sys.stdout.buffer.write(f"Still missing: {failed}\n".encode('utf-8'))
