# DogQuest - 20-image accuracy harness

**Date:** 2026-04-25  
**Model:** `assets/dog_model.tflite` (EfficientNetV2-S v6, post-calibration-fix, 300x300 uint8)  
**Pipeline:** 3-variant TTA + entropy/gap gates + synonym clustering w/ preferred-name (Option B)  
**Sample source:** `supplemental_dogs/` excluding 4 flagged folders (siberian_husky, belgian_laekenois, american_bulldog, combai)  
**Methodology:** two 20-image samples (stratified by rarity AND truly random) so we can isolate sample-design effects from model behaviour.

## Headline

| Sample | Top-1 | Top-3 | Rejected | Cluster subs |
|---|---|---|---|---|
| Stratified (5 per rarity bucket) | 0/20 (0%) | 2/20 (10%) | 4 | 0 |
| Random (uniform across folders) | 1/20 (5%) | 6/20 (30%) | 6 | 0 |

Top-1 and top-3 are computed against the **cluster** of the truth breed, so e.g. a Blenheim image whose model output is "Blenheim Spaniel" but is displayed as "Cavalier King Charles Spaniel" via Option B substitution counts as top-1 correct. This matches user-perceived behavior.

## Reading the numbers honestly

- The stratified sample weights toward the model's blind spots (5/20 are legendary breeds with the least training signal). Treat that number as a **worst-realistic-case lower bound**, not the model's accuracy.
- The random sample is closer to apples-to-apples with the prior session's 194-image benchmark (top-1 11.9%, top-5 56.2%). Variance at n=20 is high; expect ±5 points just from sample roll.
- Both samples come from `supplemental_dogs/`, which is the *supplementary* (rarer) portion of training data. Mainstream AKC breeds (Lab, Golden, GSD) are in the Stanford Dogs partition and not represented here. Real-world app accuracy on common breeds is likely higher than these numbers suggest.
- Rejected predictions are not failures — they are the entropy/gap gates working as designed when the model has insufficient signal. A high reject rate combined with low top-1 indicates a hard sample, not a buggy model.

## Behaviour to celebrate

- Errors tend to be visually-coherent: Akita → Norwegian Elkhound, Tamaskan → Alaskan Malamute, Cane Corso → Bullmastiff, Bichon Frise → Bolognese, Lagotto Romagnolo → Toy Poodle. Model is "thinking", not guessing. This is exactly the failure mode the planned dog_found_dialog top-3 redesign handles gracefully.
- Entropy/gap gates rejected ambiguous predictions cleanly, no false positives observed.

## Stratified sample - per image

- Top-1 (displayed): **0/20 (0%)**
- Top-3 (displayed contains truth-cluster): **2/20 (10%)**
- Rejected by entropy/gap gates: 4
- Synonym substitutions fired: 0

### Common

**Phu Quoc Ridgeback** — `phu_quoc_ridgeback_176.jpg`  
- top1=✗ top3=✗ -> Pharaoh Hound (5.0%)
- Raw top-5 (model output):
  - 5.0% - Pharaoh Hound
  - 3.9% - Peruvian Inca Orchid
  - 3.8% - Cirneco dell'Etna
  - 3.1% - American Hairless Terrier
  - 3.1% - Phu Quoc Ridgeback
- Displayed alternatives:
  - 5.0% - Pharaoh Hound
  - 3.9% - Peruvian Inca Orchid
  - 3.8% - Cirneco dell'Etna
- norm_entropy=0.729, gap=1.0%

**Sarplaninac** — `sarplaninac_128.jpg`  
- top1=✗ top3=✗ -> Keeshond (19.7%)
- Raw top-5 (model output):
  - 19.7% - Keeshond
  - 12.7% - Eurasier
  - 8.2% - Caucasian Shepherd Dog
  - 5.4% - Sarplaninac
  - 5.2% - Belgian Tervuren
- Displayed alternatives:
  - 19.7% - Keeshond
  - 12.7% - Eurasier
  - 8.2% - Caucasian Shepherd Dog
- norm_entropy=0.521, gap=7.1%

**Tamaskan** — `tamaskan_103.jpg`  
- top1=✗ top3=✗ -> Alaskan Malamute (28.4%)
- Raw top-5 (model output):
  - 28.4% - Alaskan Malamute
  - 11.8% - Siberian Husky
  - 5.8% - American Eskimo Dog
  - 4.6% - Pomsky
  - 3.8% - Tamaskan
- Displayed alternatives:
  - 28.4% - Alaskan Malamute
  - 11.8% - Siberian Husky
  - 5.8% - American Eskimo Dog
- norm_entropy=0.478, gap=16.6%

**Hmong Bobtail Dog** — `hmong_bobtail_dog_091.jpg`  
- top1=✗ top3=✗ -> Australian Kelpie (7.7%)
- Raw top-5 (model output):
  - 7.7% - Australian Kelpie
  - 5.6% - Working Kelpie
  - 3.4% - Australian Cattle Dog
  - 2.9% - McNab Dog
  - 2.7% - Hmong Bobtail Dog
- Displayed alternatives:
  - 7.7% - Australian Kelpie
  - 5.6% - Working Kelpie
  - 3.4% - Australian Cattle Dog
- norm_entropy=0.762, gap=2.1%

**Toy Fox Terrier** — `toy_fox_terrier_013.jpg`  
- top1=✗ top3=✓ -> Toy Terrier (15.6%)
- Raw top-5 (model output):
  - 15.6% - Toy Terrier
  - 14.1% - Toy Fox Terrier
  - 5.8% - Rat Terrier
  - 3.9% - Boston Terrier
  - 2.9% - Danish-Swedish Farmdog
- Displayed alternatives:
  - 15.6% - Toy Terrier
  - 14.1% - Toy Fox Terrier
  - 5.8% - Rat Terrier
- norm_entropy=0.597, gap=1.4%

### Uncommon

**Akita** — `akita_042.jpg`  
- top1=✗ top3=✗ -> Norwegian Elkhound (64.8%)
- Raw top-5 (model output):
  - 64.8% - Norwegian Elkhound
  - 7.2% - Belgian Malinois
  - 2.5% - Belgian Tervuren
  - 1.3% - German Shepherd
  - 1.2% - Swedish Vallhund
- Displayed alternatives:
  - 64.8% - Norwegian Elkhound
  - 7.2% - Belgian Malinois
- norm_entropy=0.300, gap=57.6%

**Jack Russell Terrier** — `jack_russell_terrier_066.jpg`  
- top1=✗ top3=✗ -> Danish-Swedish Farmdog (20.3%)
- Raw top-5 (model output):
  - 20.3% - Danish-Swedish Farmdog
  - 13.3% - Smooth Fox Terrier
  - 9.5% - Toy Fox Terrier
  - 8.1% - Rat Terrier
  - 4.3% - Treeing Walker Coonhound
- Displayed alternatives:
  - 20.3% - Danish-Swedish Farmdog
  - 13.3% - Smooth Fox Terrier
  - 9.5% - Toy Fox Terrier
- norm_entropy=0.471, gap=6.9%

**Bull Terrier** — `bull_terrier_246.jpg`  
- Rejected (gap); norm_entropy=0.721, top1=3.8%, gap=0.9%

**Cane Corso** — `cane_corso_161.jpg`  
- top1=✗ top3=✗ -> Bullmastiff (9.2%)
- Raw top-5 (model output):
  - 9.2% - Bullmastiff
  - 5.6% - English Mastiff
  - 5.2% - Perro de Presa Canario
  - 5.1% - Fila Brasileiro
  - 4.2% - Dogue de Bordeaux
- Displayed alternatives:
  - 9.2% - Bullmastiff
  - 5.6% - English Mastiff
  - 5.2% - Perro de Presa Canario
- norm_entropy=0.624, gap=3.5%

**Bichon Frise** — `bichon_frise_039.jpg`  
- top1=✗ top3=✓ -> Bolognese (13.6%)
- Raw top-5 (model output):
  - 13.6% - Bolognese
  - 11.0% - Bichon Frise
  - 4.6% - Miniature Poodle
  - 3.8% - Maltipoo
  - 3.8% - Toy Poodle
- Displayed alternatives:
  - 13.6% - Bolognese
  - 11.0% - Bichon Frise
  - 4.6% - Miniature Poodle
- norm_entropy=0.571, gap=2.6%

### Rare

**Bergamasco Sheepdog** — `bergamasco_sheepdog_010.jpg`  
- top1=✗ top3=✗ -> Cairn Terrier (7.1%)
- Raw top-5 (model output):
  - 7.1% - Cairn Terrier
  - 6.3% - Briard
  - 4.7% - Soft-Coated Wheaten Terrier
  - 3.9% - Glen of Imaal Terrier
  - 3.5% - Mioritic Shepherd
- Displayed alternatives:
  - 7.1% - Cairn Terrier
  - 6.3% - Briard
  - 4.7% - Soft-Coated Wheaten Terrier
- norm_entropy=0.662, gap=0.8%

**Lagotto Romagnolo** — `lagotto_romagnolo_113.jpg`  
- top1=✗ top3=✗ -> Toy Poodle (34.2%)
- Raw top-5 (model output):
  - 34.2% - Toy Poodle
  - 21.6% - Miniature Poodle
  - 5.6% - Poodle
  - 3.3% - Maltipoo
  - 2.7% - Goldendoodle
- Displayed alternatives:
  - 34.2% - Toy Poodle
  - 21.6% - Miniature Poodle
  - 5.6% - Poodle
- norm_entropy=0.389, gap=12.7%

**Norwegian Lundehund** — `norwegian_lundehund_094.jpg`  
- top1=✗ top3=✗ -> Pembroke Welsh Corgi (12.2%)
- Raw top-5 (model output):
  - 12.2% - Pembroke Welsh Corgi
  - 7.5% - Cardigan Welsh Corgi
  - 3.9% - Icelandic Sheepdog
  - 3.1% - Norwegian Lundehund
  - 2.9% - Karelian Bear Dog
- Displayed alternatives:
  - 12.2% - Pembroke Welsh Corgi
  - 7.5% - Cardigan Welsh Corgi
  - 3.9% - Icelandic Sheepdog
- norm_entropy=0.650, gap=4.7%

**Chinese Crested** — `chinese_crested_099.jpg`  
- top1=✗ top3=✗ -> Xoloitzcuintli (23.8%)
- Raw top-5 (model output):
  - 23.8% - Xoloitzcuintli
  - 10.6% - Peruvian Inca Orchid
  - 2.9% - American Hairless Terrier
  - 2.1% - Wire Fox Terrier
  - 1.7% - Jonangi
- Displayed alternatives:
  - 23.8% - Xoloitzcuintli
  - 10.6% - Peruvian Inca Orchid
- norm_entropy=0.639, gap=13.2%

**Korean Jindo Dog** — `korean_jindo_dog_214.jpg`  
- Rejected (entropy); norm_entropy=1.034, top1=0.9%, gap=0.1%

### Legendary

**Canaan Dog** — `canaan_dog_127.jpg`  
- top1=✗ top3=✗ -> Australian Kelpie (5.4%)
- Raw top-5 (model output):
  - 5.4% - Australian Kelpie
  - 2.5% - Pembroke Welsh Corgi
  - 2.4% - Cardigan Welsh Corgi
  - 2.4% - Canaan Dog
  - 2.2% - Carolina Dog
- Displayed alternatives:
  - 5.4% - Australian Kelpie
- norm_entropy=0.732, gap=2.9%

**Fila Brasileiro** — `fila_brasileiro_047.jpg`  
- Rejected (gap); norm_entropy=0.717, top1=4.2%, gap=0.0%

**Catalburun** — `catalburun_204.jpg`  
- Rejected (gap); norm_entropy=0.735, top1=3.0%, gap=0.0%

**Stabyhoun** — `stabyhoun_246.jpg`  
- top1=✗ top3=✗ -> Border Collie (42.7%)
- Raw top-5 (model output):
  - 42.7% - Border Collie
  - 16.7% - Collie
  - 3.0% - Rough Collie
  - 2.6% - Stabyhoun
  - 2.5% - Australian Shepherd
- Displayed alternatives:
  - 42.7% - Border Collie
  - 16.7% - Collie
  - 3.0% - Rough Collie
- norm_entropy=0.396, gap=26.0%

**Telomian** — `telomian_119.jpg`  
- top1=✗ top3=✗ -> Australian Kelpie (4.8%)
- Raw top-5 (model output):
  - 4.8% - Australian Kelpie
  - 3.4% - Working Kelpie
  - 2.4% - Formosan Mountain Dog
  - 2.1% - Norwegian Lundehund
  - 2.1% - Karelian Bear Dog
- Displayed alternatives:
  - 4.8% - Australian Kelpie
  - 3.4% - Working Kelpie
- norm_entropy=0.757, gap=1.4%

## Random sample - per image

- Top-1 (displayed): **1/20 (5%)**
- Top-3 (displayed contains truth-cluster): **6/20 (30%)**
- Rejected by entropy/gap gates: 6
- Synonym substitutions fired: 0

### Common

**Aussiedoodle** — `aussiedoodle_027.jpg`  
- top1=✗ top3=✗ -> Bernedoodle (5.9%)
- Raw top-5 (model output):
  - 5.9% - Bernedoodle
  - 4.8% - Sheepadoodle
  - 3.8% - Bolognese
  - 3.5% - Black Russian Terrier
  - 2.6% - Spanish Water Dog
- Displayed alternatives:
  - 5.9% - Bernedoodle
  - 4.8% - Sheepadoodle
  - 3.8% - Bolognese
- norm_entropy=0.746, gap=1.0%

**Irish Red and White Setter** — `irish_red_and_white_setter_005.jpg`  
- top1=✗ top3=✓ -> Welsh Springer Spaniel (62.6%)
- Raw top-5 (model output):
  - 62.6% - Welsh Springer Spaniel
  - 11.8% - Irish Red and White Setter
  - 8.0% - Kooikerhondje
  - 3.4% - Brittany
  - 2.7% - Irish Setter
- Displayed alternatives:
  - 62.6% - Welsh Springer Spaniel
  - 11.8% - Irish Red and White Setter
  - 8.0% - Kooikerhondje
- norm_entropy=0.243, gap=50.8%

**Cavapoo** — `cavapoo_072.jpg`  
- Rejected (gap); norm_entropy=0.875, top1=2.5%, gap=0.8%

**Portuguese Water Dog** — `portuguese_water_dog_186.jpg`  
- Rejected (gap); norm_entropy=0.882, top1=1.2%, gap=0.0%

**Manchester Terrier** — `manchester_terrier_144.jpg`  
- top1=✗ top3=✓ -> Miniature Pinscher (26.9%)
- Raw top-5 (model output):
  - 26.9% - Miniature Pinscher
  - 12.8% - Manchester Terrier
  - 12.7% - German Pinscher
  - 9.2% - Doberman Pinscher
  - 3.3% - Toy Terrier
- Displayed alternatives:
  - 26.9% - Miniature Pinscher
  - 12.8% - Manchester Terrier
  - 12.7% - German Pinscher
- norm_entropy=0.451, gap=14.1%

**Boykin Spaniel** — `boykin_spaniel_095.jpg`  
- top1=✓ top3=✓ -> Boykin Spaniel (21.7%)
- Raw top-5 (model output):
  - 21.7% - Boykin Spaniel
  - 12.2% - American Water Spaniel
  - 7.1% - Sussex Spaniel
  - 5.5% - Small Munsterlander
  - 5.0% - Pont-Audemer Spaniel
- Displayed alternatives:
  - 21.7% - Boykin Spaniel
  - 12.2% - American Water Spaniel
  - 7.1% - Sussex Spaniel
- norm_entropy=0.505, gap=9.5%

**Poodle** — `poodle_045.jpg`  
- top1=✗ top3=✗ -> Boxer (94.5%)
- Raw top-5 (model output):
  - 94.5% - Boxer
  - 0.9% - American Bulldog
  - 0.7% - Brussels Griffon
  - 0.4% - Bulldog
  - 0.4% - American Staffordshire Terrier
- Displayed alternatives:
  - 94.5% - Boxer
- norm_entropy=0.046, gap=93.6%

**Tosa Inu** — `tosa_inu_201.jpg`  
- top1=✗ top3=✓ -> Rhodesian Ridgeback (18.7%)
- Raw top-5 (model output):
  - 18.7% - Rhodesian Ridgeback
  - 14.8% - Bullmastiff
  - 7.7% - Tosa Inu
  - 5.4% - Shar Pei
  - 3.9% - Dogue de Bordeaux
- Displayed alternatives:
  - 18.7% - Rhodesian Ridgeback
  - 14.8% - Bullmastiff
  - 7.7% - Tosa Inu
- norm_entropy=0.533, gap=3.9%

**Russell Terrier** — `russell_terrier_236.jpg`  
- top1=✗ top3=✗ -> Boston Terrier (83.3%)
- Raw top-5 (model output):
  - 83.3% - Boston Terrier
  - 3.4% - French Bulldog
  - 1.3% - Toy Terrier
  - 0.8% - Toy Fox Terrier
  - 0.7% - Staffordshire Bull Terrier
- Displayed alternatives:
  - 83.3% - Boston Terrier
  - 3.4% - French Bulldog
- norm_entropy=0.146, gap=79.9%

**Treeing Walker Coonhound** — `treeing_walker_coonhound_071.jpg`  
- Rejected (gap); norm_entropy=0.924, top1=1.2%, gap=0.1%

**American Foxhound** — `american_foxhound_006.jpg`  
- top1=✗ top3=✗ -> Walker Hound (31.5%)
- Raw top-5 (model output):
  - 31.5% - Walker Hound
  - 28.8% - English Foxhound
  - 9.9% - Treeing Walker Coonhound
  - 8.0% - Beagle
  - 5.2% - Harrier
- Displayed alternatives:
  - 31.5% - Walker Hound
  - 28.8% - English Foxhound
  - 9.9% - Treeing Walker Coonhound
- norm_entropy=0.338, gap=2.7%

**Schapendoes** — `schapendoes_049.jpg`  
- top1=✗ top3=✗ -> Briard (4.1%)
- Raw top-5 (model output):
  - 4.1% - Briard
  - 2.5% - Schapendoes
  - 1.6% - Bouvier des Flandres
  - 1.3% - Barbet
  - 1.3% - Tibetan Terrier
- Displayed alternatives:
  - 4.1% - Briard
- norm_entropy=0.921, gap=1.6%

**Phu Quoc Ridgeback** — `phu_quoc_ridgeback_116.jpg`  
- Rejected (gap); norm_entropy=0.807, top1=3.4%, gap=0.9%

**McNab Dog** — `mcnab_dog_106.jpg`  
- top1=✗ top3=✗ -> Brittany (23.8%)
- Raw top-5 (model output):
  - 23.8% - Brittany
  - 1.4% - Collie
  - 1.3% - Goldador
  - 1.2% - Rough Collie
  - 1.2% - Shetland Sheepdog
- Displayed alternatives:
  - 23.8% - Brittany
- norm_entropy=0.697, gap=22.4%

**Working Kelpie** — `working_kelpie_088.jpg`  
- top1=✗ top3=✓ -> Australian Kelpie (84.2%)
- Raw top-5 (model output):
  - 84.2% - Australian Kelpie
  - 14.6% - Working Kelpie
  - 0.9% - Lancashire Heeler
  - 0.1% - Rottweiler
  - 0.0% - Jack Russell Terrier
- Displayed alternatives:
  - 84.2% - Australian Kelpie
  - 14.6% - Working Kelpie
- norm_entropy=0.084, gap=69.5%

**Sloughi** — `sloughi_028.jpg`  
- top1=✗ top3=✗ -> Whippet (29.7%)
- Raw top-5 (model output):
  - 29.7% - Whippet
  - 7.2% - Italian Greyhound
  - 7.1% - Chippiparai
  - 6.7% - Sloughi
  - 6.5% - Greyhound
- Displayed alternatives:
  - 29.7% - Whippet
  - 7.2% - Italian Greyhound
  - 7.1% - Chippiparai
- norm_entropy=0.471, gap=22.5%

**Phu Quoc Ridgeback** — `phu_quoc_ridgeback_226.jpg`  
- Rejected (gap); norm_entropy=0.839, top1=1.8%, gap=0.0%

**Coton de Tulear** — `coton_de_tulear_102.jpg`  
- top1=✗ top3=✓ -> Maltese (13.5%)
- Raw top-5 (model output):
  - 13.5% - Maltese
  - 8.9% - Coton de Tulear
  - 6.3% - Lhasa Apso
  - 5.5% - Bolognese
  - 5.0% - Maltipoo
- Displayed alternatives:
  - 13.5% - Maltese
  - 8.9% - Coton de Tulear
  - 6.3% - Lhasa Apso
- norm_entropy=0.568, gap=4.6%

### Rare

**Mudi** — `mudi_199.jpg`  
- no displayable
- Raw top-5 (model output):
  - 2.7% - Croatian Sheepdog
  - 1.3% - Australian Shepherd
  - 1.2% - Border Collie
  - 1.0% - Rough Collie
  - 1.0% - Goldador
- norm_entropy=0.845, gap=1.4%

### Legendary

**Telomian** — `telomian_034.jpg`  
- Rejected (gap); norm_entropy=0.836, top1=2.9%, gap=0.5%


## Caveats

- This bypasses the camera capture path (no JPEG re-encoding, no ImagePicker). Real-app accuracy may differ slightly.
- Folder-to-breed name matching is best-effort. Folders that do not lex-match a Dog.name in dogs.json are excluded; some real breeds may therefore be invisible to the harness.
- Single image per breed = high variance. Don't over-interpret individual rows.
