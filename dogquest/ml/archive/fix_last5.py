import json, urllib.parse

fixes = {
    "Papillon": "Papillon_-_PortoGaribaldi.jpg",
    "Saint Bernard": "Bernardyn.jpg",
    "Catalburun": "Pointer_04.jpg",
    "Chinook": "Chinook_sitting_in_snow.jpg",
    "Toy Terrier": "Yorkshire_Terrier_studfee.jpg",
}

with open("assets/dogs.json", "r", encoding="utf-8") as f:
    dogs = json.load(f)

for dog in dogs:
    if dog["name"] in fixes:
        fname = fixes[dog["name"]]
        dog["imageUrl"] = f"https://commons.wikimedia.org/w/thumb.php?f={urllib.parse.quote(fname, safe='')}&w=400"
        print(f"Fixed: {dog['name']}")

with open("assets/dogs.json", "w", encoding="utf-8") as f:
    json.dump(dogs, f, indent=2, ensure_ascii=False)

print("Done")
