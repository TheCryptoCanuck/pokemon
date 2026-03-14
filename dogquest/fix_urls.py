"""Fix broken image URLs in dogs.json by searching Wikimedia Commons API."""
import json
import urllib.request
import urllib.parse
import time

# Known good Wikimedia Commons filenames for dog breeds
# Sourced from actual Wikipedia articles and Commons categories
KNOWN_FILES = {
    "Labrador Retriever": "YellowLabradorLooking_new.jpg",
    "German Shepherd": "German_Shepherd_-_DSC_0346_(10096362833).jpg",
    "French Bulldog": "Bouledogue_fran%C3%A7ais_-_2.jpg",
    "Bulldog": "English_Bulldog_about_1_year_old.jpg",
    "Dachshund": "Short-haired-Dachshund.jpg",
    "Great Dane": "Great_Dane_DSCF0177.jpg",
    "Australian Shepherd": "Australian_Shepherd_600.jpg",
    "Bernese Mountain Dog": "Bernese_Mountain_Dog_-_9_months.jpg",
    "Dalmatian": "Dalmatian_b_01.jpg",
    "Whippet": "Whippet_047.jpg",
    "Irish Setter": "Irish_Setter_2.jpg",
    "Bull Terrier": "Bull_Terrier_Spike.jpg",
    "Vizsla": "Vizsla_r%C3%BCde.jpg",
    "Belgian Malinois": "Malinois_-_Belgian_Shepherd_Dog.jpg",
    "Bloodhound": "Bloodhound_Portrait.jpg",
    "English Springer Spaniel": "English_Springer_Spaniel.jpg",
    "Cane Corso": "CaneCorso_(22).jpg",
    "Papillon": "Papillon_dog.jpg",
    "Saint Bernard": "Hummel_Saint_Bernard.jpg",
    "Komondor": "Komondor_02.jpg",
    "Xoloitzcuintli": "Xoloitzcuintle.jpg",
    "Tibetan Mastiff": "Tibetan_Mastiff_(1).jpg",
    "Otterhound": "Otterhound.jpg",
    "Azawakh": "Azawakh_brindle.jpg",
    "Bergamasco Sheepdog": "Bergamasco_pastore.jpg",
    "Mudi": "Mudi_-_2.jpg",
    "Catalburun": "Catalburun_2.jpg",
    "New Guinea Singing Dog": "New_Guinea_Singing_Dog_2.jpg",
    "Chinook": "Chinook_Dog.jpg",
    "Kooikerhondje": "Kooikerhondje_GCh_Tudorose_Dorien.jpg",
    "Pekingese": "Pekingese_right.jpg",
    "Toy Terrier": "Russkiy_Toy_LH_1.jpg",
    "Redbone Coonhound": "Redbone-Coonhound.jpg",
    "Norfolk Terrier": "Norfolk_Terrier_0155.jpg",
    "Sealyham Terrier": "Sealyham_terrier2.jpg",
    "Australian Terrier": "Australian_Terrier_-_Pumpkin_1.jpg",
    "Boston Terrier": "Boston_Terrier_male.jpg",
    "Giant Schnauzer": "Giant_Schnauzer_01.jpg",
    "Soft-Coated Wheaten Terrier": "Soft_Coated_Wheaten_Terrier_600.jpg",
    "Lhasa Apso": "Lhasa_Apso.jpg",
    "Flat-Coated Retriever": "Flat_Coated_Retriever_-_Black_(1).jpg",
    "German Shorthaired Pointer": "German_shorthaired_pointer.jpg",
    "English Setter": "English_setter.jpg",
    "Gordon Setter": "Gordon_Setter_2.jpg",
    "Sussex Spaniel": "Sussex_Spaniel.jpg",
    "Briard": "Briard_2.jpg",
    "Australian Kelpie": "Working_Kelpie.jpg",
    "Appenzeller Sennenhund": "Appenzeller-sennenhund.jpg",
    "Entlebucher Mountain Dog": "Entlebucher.jpg",
    "Bullmastiff": "Bullmastiff_edited.jpg",
    "Chow Chow": "ChowChow2Szczecin.jpg",
    "Keeshond": "Keeshond_Majansen_Campansen.jpg",
    "Brussels Griffon": "Griffon_Bruxellois_(1).jpg",
    "Miniature Poodle": "Miniature_Poodle_apricot.jpg",
    "Standard Poodle": "Full_attention_(8067543916).jpg",
}

with open("assets/dogs.json", "r", encoding="utf-8") as f:
    dogs = json.load(f)

fixed = 0
for dog in dogs:
    name = dog["name"]
    if name in KNOWN_FILES:
        filename = KNOWN_FILES[name]
        new_url = f"https://commons.wikimedia.org/w/thumb.php?f={filename}&w=400"
        dog["imageUrl"] = new_url
        fixed += 1
        print(f"  Fixed: {name}")

with open("assets/dogs.json", "w", encoding="utf-8") as f:
    json.dump(dogs, f, indent=2, ensure_ascii=False)

print(f"\nFixed {fixed} URLs in dogs.json")
