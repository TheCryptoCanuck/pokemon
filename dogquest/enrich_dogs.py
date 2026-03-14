#!/usr/bin/env python3
"""
Enrich dogs.json with breed-specific health and care data.
All data is hardcoded based on AKC/UKC/kennel club breed standards.
"""

import json
import os

# Breed enrichment data for all 147 breeds
BREED_DATA = {
    "Labrador Retriever": {
        "lifespan": "11-13 years",
        "sizeCategory": "large",
        "weight": "25-36 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Elbow dysplasia", "Obesity", "Progressive retinal atrophy"],
        "temperamentTraits": ["Friendly", "Active", "Outgoing", "Gentle", "Trusting"],
        "dietNotes": "Prone to obesity; measure meals carefully and limit treats. Needs high-quality protein with controlled fat content."
    },
    "German Shepherd": {
        "lifespan": "9-13 years",
        "sizeCategory": "large",
        "weight": "30-40 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Elbow dysplasia", "Degenerative myelopathy", "Bloat"],
        "temperamentTraits": ["Confident", "Courageous", "Intelligent", "Loyal", "Watchful"],
        "dietNotes": "Feed a high-protein diet formulated for large active breeds. Split meals into two servings to help prevent bloat."
    },
    "Golden Retriever": {
        "lifespan": "10-12 years",
        "sizeCategory": "large",
        "weight": "25-34 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "high",
        "healthPredispositions": ["Hip dysplasia", "Cancer", "Heart disease", "Eye conditions"],
        "temperamentTraits": ["Friendly", "Reliable", "Devoted", "Intelligent", "Kind"],
        "dietNotes": "Needs a balanced diet with omega fatty acids for coat health. Monitor portions closely as they tend to overeat."
    },
    "French Bulldog": {
        "lifespan": "10-12 years",
        "sizeCategory": "small",
        "weight": "8-13 kg",
        "exerciseNeeds": "low",
        "groomingNeeds": "low",
        "healthPredispositions": ["Brachycephalic syndrome", "Spinal disorders", "Allergies", "Hip dysplasia"],
        "temperamentTraits": ["Playful", "Adaptable", "Smart", "Affectionate"],
        "dietNotes": "Feed a high-quality diet for small breeds. Prone to food allergies; limited-ingredient diets may help. Avoid overfeeding due to low exercise tolerance."
    },
    "Bulldog": {
        "lifespan": "8-10 years",
        "sizeCategory": "medium",
        "weight": "18-25 kg",
        "exerciseNeeds": "low",
        "groomingNeeds": "low",
        "healthPredispositions": ["Brachycephalic syndrome", "Hip dysplasia", "Cherry eye", "Skin fold dermatitis"],
        "temperamentTraits": ["Calm", "Courageous", "Friendly", "Dignified"],
        "dietNotes": "Very prone to obesity; strict portion control is essential. Feed a moderate-calorie diet and keep facial wrinkles clean after meals."
    },
    "Poodle": {
        "lifespan": "12-15 years",
        "sizeCategory": "medium",
        "weight": "20-32 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "high",
        "healthPredispositions": ["Hip dysplasia", "Progressive retinal atrophy", "Epilepsy", "Addison's disease"],
        "temperamentTraits": ["Intelligent", "Active", "Alert", "Faithful", "Trainable"],
        "dietNotes": "Needs high-quality protein to support an active lifestyle. Regular meals with omega fatty acids help maintain their curly coat."
    },
    "Beagle": {
        "lifespan": "10-15 years",
        "sizeCategory": "small",
        "weight": "9-11 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Epilepsy", "Hypothyroidism", "Hip dysplasia", "Cherry eye"],
        "temperamentTraits": ["Merry", "Friendly", "Curious", "Determined", "Amiable"],
        "dietNotes": "Notorious food thieves; secure all food and measure meals carefully. Prone to obesity if allowed free-feeding."
    },
    "Rottweiler": {
        "lifespan": "8-10 years",
        "sizeCategory": "large",
        "weight": "36-60 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Hip dysplasia", "Elbow dysplasia", "Osteosarcoma", "Bloat"],
        "temperamentTraits": ["Loyal", "Confident", "Courageous", "Calm", "Good-natured"],
        "dietNotes": "Requires a large-breed formula with joint-supporting nutrients. Feed two meals daily to reduce bloat risk; avoid exercise right after eating."
    },
    "Yorkshire Terrier": {
        "lifespan": "11-15 years",
        "sizeCategory": "small",
        "weight": "2-3 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "high",
        "healthPredispositions": ["Patellar luxation", "Portosystemic shunt", "Collapsed trachea", "Dental disease"],
        "temperamentTraits": ["Bold", "Confident", "Spirited", "Affectionate", "Courageous"],
        "dietNotes": "Small stomachs need nutrient-dense food in small, frequent meals. Dental-friendly kibble helps prevent tooth problems common in the breed."
    },
    "Dachshund": {
        "lifespan": "12-16 years",
        "sizeCategory": "small",
        "weight": "7-15 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "low",
        "healthPredispositions": ["Intervertebral disc disease", "Obesity", "Patellar luxation", "Eye problems"],
        "temperamentTraits": ["Clever", "Stubborn", "Devoted", "Lively", "Courageous"],
        "dietNotes": "Weight management is critical to protect their long spine. Feed measured portions and avoid letting them jump on/off furniture."
    },
    "Boxer": {
        "lifespan": "10-12 years",
        "sizeCategory": "large",
        "weight": "25-32 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Cancer", "Heart conditions", "Hip dysplasia", "Bloat"],
        "temperamentTraits": ["Fun-loving", "Bright", "Active", "Loyal", "Playful"],
        "dietNotes": "Feed high-quality, grain-inclusive diet with good protein sources. Two meals daily to reduce bloat risk. Avoid foods with excessive fillers."
    },
    "Siberian Husky": {
        "lifespan": "12-14 years",
        "sizeCategory": "medium",
        "weight": "16-27 kg",
        "exerciseNeeds": "very high",
        "groomingNeeds": "high",
        "healthPredispositions": ["Hip dysplasia", "Eye disorders", "Hypothyroidism", "Zinc deficiency"],
        "temperamentTraits": ["Outgoing", "Mischievous", "Loyal", "Friendly", "Gentle"],
        "dietNotes": "Surprisingly efficient eaters that need less food than their size suggests. High-protein diet with fish-based omega oils for coat health."
    },
    "Cavalier King Charles Spaniel": {
        "lifespan": "9-14 years",
        "sizeCategory": "small",
        "weight": "5-8 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Mitral valve disease", "Syringomyelia", "Patellar luxation", "Eye conditions"],
        "temperamentTraits": ["Affectionate", "Gentle", "Graceful", "Patient", "Sociable"],
        "dietNotes": "Heart-healthy diet with omega-3 fatty acids is beneficial. Monitor weight as they can easily become overweight with their love of treats."
    },
    "Doberman Pinscher": {
        "lifespan": "10-12 years",
        "sizeCategory": "large",
        "weight": "27-45 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Dilated cardiomyopathy", "Von Willebrand's disease", "Hip dysplasia", "Wobbler syndrome"],
        "temperamentTraits": ["Loyal", "Fearless", "Alert", "Intelligent", "Energetic"],
        "dietNotes": "Feed a high-protein, heart-healthy diet with taurine supplementation. Active dogs need calorie-dense food split into two daily meals."
    },
    "Great Dane": {
        "lifespan": "7-10 years",
        "sizeCategory": "giant",
        "weight": "50-80 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "low",
        "healthPredispositions": ["Bloat", "Hip dysplasia", "Cardiomyopathy", "Osteosarcoma"],
        "temperamentTraits": ["Friendly", "Patient", "Dependable", "Gentle", "Loving"],
        "dietNotes": "Must use large-breed puppy food for slow, steady growth. Feed 2-3 small meals daily from an elevated bowl to reduce bloat risk."
    },
    "Australian Shepherd": {
        "lifespan": "12-15 years",
        "sizeCategory": "medium",
        "weight": "18-29 kg",
        "exerciseNeeds": "very high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Epilepsy", "Cataracts", "MDR1 gene sensitivity"],
        "temperamentTraits": ["Intelligent", "Work-oriented", "Exuberant", "Good-natured", "Protective"],
        "dietNotes": "High-energy dogs need calorie-dense food with quality protein. Adjust portions based on activity level; working dogs need significantly more."
    },
    "Miniature Schnauzer": {
        "lifespan": "12-15 years",
        "sizeCategory": "small",
        "weight": "5-9 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "high",
        "healthPredispositions": ["Pancreatitis", "Hyperlipidemia", "Urinary stones", "Cataracts"],
        "temperamentTraits": ["Friendly", "Smart", "Obedient", "Alert", "Spirited"],
        "dietNotes": "Prone to pancreatitis; feed a low-fat, high-quality diet. Avoid fatty table scraps entirely. Regular feeding schedule is important."
    },
    "Pembroke Welsh Corgi": {
        "lifespan": "12-13 years",
        "sizeCategory": "small",
        "weight": "10-14 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Degenerative myelopathy", "Intervertebral disc disease", "Obesity"],
        "temperamentTraits": ["Bold", "Friendly", "Playful", "Tenacious", "Protective"],
        "dietNotes": "Very prone to obesity; strict portion control is essential. Feed a balanced diet and resist their expert begging skills."
    },
    "Shih Tzu": {
        "lifespan": "10-18 years",
        "sizeCategory": "small",
        "weight": "4-7 kg",
        "exerciseNeeds": "low",
        "groomingNeeds": "high",
        "healthPredispositions": ["Brachycephalic syndrome", "Patellar luxation", "Eye problems", "Dental disease"],
        "temperamentTraits": ["Affectionate", "Happy", "Outgoing", "Playful", "Gentle"],
        "dietNotes": "Small-breed formula with small kibble size for their flat face. Keep hair around the face trimmed to avoid food contamination."
    },
    "Cocker Spaniel": {
        "lifespan": "10-14 years",
        "sizeCategory": "medium",
        "weight": "12-16 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "high",
        "healthPredispositions": ["Ear infections", "Progressive retinal atrophy", "Hip dysplasia", "Autoimmune hemolytic anemia"],
        "temperamentTraits": ["Gentle", "Smart", "Happy", "Merry", "Faithful"],
        "dietNotes": "Feed a balanced diet with omega fatty acids for their luxurious coat. Keep ears clean especially after eating from bowls to prevent infections."
    },
    "Pomeranian": {
        "lifespan": "12-16 years",
        "sizeCategory": "small",
        "weight": "1.5-3 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "high",
        "healthPredispositions": ["Patellar luxation", "Collapsed trachea", "Dental disease", "Alopecia X"],
        "temperamentTraits": ["Lively", "Bold", "Inquisitive", "Extroverted", "Intelligent"],
        "dietNotes": "Tiny dogs need nutrient-dense, small-kibble food. Prone to low blood sugar; feed small meals 3 times daily rather than twice."
    },
    "Chihuahua": {
        "lifespan": "14-16 years",
        "sizeCategory": "small",
        "weight": "1.5-3 kg",
        "exerciseNeeds": "low",
        "groomingNeeds": "low",
        "healthPredispositions": ["Patellar luxation", "Heart disease", "Hydrocephalus", "Dental disease"],
        "temperamentTraits": ["Charming", "Graceful", "Sassy", "Alert", "Devoted"],
        "dietNotes": "Very small stomachs require nutrient-dense food in tiny portions. Prone to hypoglycemia; provide small frequent meals throughout the day."
    },
    "Border Collie": {
        "lifespan": "12-15 years",
        "sizeCategory": "medium",
        "weight": "14-20 kg",
        "exerciseNeeds": "very high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Epilepsy", "Collie eye anomaly", "Osteochondritis dissecans"],
        "temperamentTraits": ["Intelligent", "Energetic", "Keen", "Alert", "Responsive"],
        "dietNotes": "Extremely active dogs need high-calorie, protein-rich food. Working dogs may need 25-30% more calories than typical recommendations."
    },
    "Pug": {
        "lifespan": "13-15 years",
        "sizeCategory": "small",
        "weight": "6-8 kg",
        "exerciseNeeds": "low",
        "groomingNeeds": "low",
        "healthPredispositions": ["Brachycephalic syndrome", "Pug dog encephalitis", "Eye injuries", "Obesity"],
        "temperamentTraits": ["Charming", "Mischievous", "Loving", "Even-tempered", "Sociable"],
        "dietNotes": "Highly prone to obesity; strictly measure all food and treats. Use a flat bowl or slow feeder to prevent gulping air while eating."
    },
    "Maltese": {
        "lifespan": "12-15 years",
        "sizeCategory": "small",
        "weight": "3-4 kg",
        "exerciseNeeds": "low",
        "groomingNeeds": "high",
        "healthPredispositions": ["Patellar luxation", "Heart murmurs", "Collapsed trachea", "Dental disease"],
        "temperamentTraits": ["Gentle", "Playful", "Charming", "Affectionate", "Lively"],
        "dietNotes": "Small-breed formula with easily digestible proteins. Tear staining can be diet-related; avoid foods with artificial dyes and excess iron."
    },
    "Bernese Mountain Dog": {
        "lifespan": "7-10 years",
        "sizeCategory": "giant",
        "weight": "36-50 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "high",
        "healthPredispositions": ["Cancer", "Hip dysplasia", "Elbow dysplasia", "Bloat"],
        "temperamentTraits": ["Good-natured", "Calm", "Strong", "Faithful", "Affectionate"],
        "dietNotes": "Large-breed formula with joint-supporting glucosamine. Prone to bloat; feed 2-3 smaller meals and avoid vigorous exercise after eating."
    },
    "Weimaraner": {
        "lifespan": "10-13 years",
        "sizeCategory": "large",
        "weight": "25-40 kg",
        "exerciseNeeds": "very high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Bloat", "Hip dysplasia", "Hypothyroidism", "Entropion"],
        "temperamentTraits": ["Friendly", "Fearless", "Alert", "Obedient", "Energetic"],
        "dietNotes": "High-energy breed needs calorie-dense food with quality animal proteins. Feed two meals daily and use a slow feeder to reduce bloat risk."
    },
    "Rhodesian Ridgeback": {
        "lifespan": "10-12 years",
        "sizeCategory": "large",
        "weight": "32-41 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Hip dysplasia", "Elbow dysplasia", "Dermoid sinus", "Hypothyroidism"],
        "temperamentTraits": ["Dignified", "Even-tempered", "Loyal", "Affectionate", "Strong-willed"],
        "dietNotes": "Athletic breed needs high-protein diet with moderate fat. Feed twice daily; they can be food-possessive, so teach good mealtime manners early."
    },
    "Akita": {
        "lifespan": "10-13 years",
        "sizeCategory": "large",
        "weight": "32-59 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "high",
        "healthPredispositions": ["Hip dysplasia", "Autoimmune disorders", "Bloat", "Progressive retinal atrophy"],
        "temperamentTraits": ["Courageous", "Dignified", "Loyal", "Profoundly Faithful", "Alert"],
        "dietNotes": "Feed a high-quality large-breed formula. Some Akitas are sensitive to certain proteins; monitor for food allergies. Two meals daily to prevent bloat."
    },
    "Dalmatian": {
        "lifespan": "11-13 years",
        "sizeCategory": "large",
        "weight": "23-32 kg",
        "exerciseNeeds": "very high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Deafness", "Urinary stones", "Hip dysplasia", "Skin allergies"],
        "temperamentTraits": ["Dignified", "Smart", "Outgoing", "Energetic", "Playful"],
        "dietNotes": "Unique purine metabolism requires a low-purine diet. Avoid organ meats, sardines, and high-purine foods. Ensure plenty of fresh water."
    },
    "Whippet": {
        "lifespan": "12-15 years",
        "sizeCategory": "medium",
        "weight": "9-13 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Heart murmurs", "Eye defects", "Anesthetic sensitivity", "Undescended testicles"],
        "temperamentTraits": ["Affectionate", "Playful", "Calm", "Gentle", "Quiet"],
        "dietNotes": "Lean sighthound needs moderate-calorie diet. Their thin frame means even a little extra weight is noticeable and harmful. Feed twice daily."
    },
    "Irish Setter": {
        "lifespan": "12-15 years",
        "sizeCategory": "large",
        "weight": "27-32 kg",
        "exerciseNeeds": "very high",
        "groomingNeeds": "high",
        "healthPredispositions": ["Hip dysplasia", "Bloat", "Epilepsy", "Progressive retinal atrophy"],
        "temperamentTraits": ["Outgoing", "Sweet-natured", "Active", "Loving", "Rollicking"],
        "dietNotes": "High-energy sporting dog needs protein-rich food. Prone to bloat; feed 2-3 smaller meals using a slow feeder. Avoid exercise after meals."
    },
    "Samoyed": {
        "lifespan": "12-14 years",
        "sizeCategory": "medium",
        "weight": "16-30 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "high",
        "healthPredispositions": ["Hip dysplasia", "Diabetes", "Progressive retinal atrophy", "Hypothyroidism"],
        "temperamentTraits": ["Friendly", "Gentle", "Adaptable", "Loyal", "Playful"],
        "dietNotes": "Needs a balanced diet with good protein for their thick double coat. Originally thrived on fish and reindeer; fish-based diets work well."
    },
    "Bull Terrier": {
        "lifespan": "12-13 years",
        "sizeCategory": "medium",
        "weight": "22-32 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Deafness", "Heart disease", "Kidney disease", "Patellar luxation"],
        "temperamentTraits": ["Playful", "Charming", "Mischievous", "Courageous", "Active"],
        "dietNotes": "Feed a balanced, protein-rich diet. Some are prone to skin allergies; a limited-ingredient diet can help identify triggers."
    },
    "Basset Hound": {
        "lifespan": "12-13 years",
        "sizeCategory": "medium",
        "weight": "20-29 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "low",
        "healthPredispositions": ["Obesity", "Ear infections", "Hip dysplasia", "Bloat"],
        "temperamentTraits": ["Patient", "Low-key", "Charming", "Tenacious", "Friendly"],
        "dietNotes": "Extremely prone to obesity; strict calorie control is critical. Their soulful begging eyes are deceiving; do not overfeed."
    },
    "Staffordshire Bull Terrier": {
        "lifespan": "12-14 years",
        "sizeCategory": "medium",
        "weight": "11-17 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Hip dysplasia", "Patellar luxation", "L-2-hydroxyglutaric aciduria", "Cataracts"],
        "temperamentTraits": ["Brave", "Tenacious", "Affectionate", "Loyal", "Reliable"],
        "dietNotes": "Muscular breed needs protein-rich diet. Active dogs with good appetites; measure meals to maintain lean muscle without excess weight."
    },
    "Shetland Sheepdog": {
        "lifespan": "12-14 years",
        "sizeCategory": "small",
        "weight": "6-12 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "high",
        "healthPredispositions": ["Collie eye anomaly", "Hip dysplasia", "Dermatomyositis", "Hypothyroidism"],
        "temperamentTraits": ["Intelligent", "Eager", "Loyal", "Playful", "Gentle"],
        "dietNotes": "Active herding breed needs quality protein and omega fatty acids for their abundant coat. MDR1 gene means some drugs interact with diet."
    },
    "Vizsla": {
        "lifespan": "12-14 years",
        "sizeCategory": "medium",
        "weight": "18-29 kg",
        "exerciseNeeds": "very high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Hip dysplasia", "Epilepsy", "Lymphosarcoma", "Eye disorders"],
        "temperamentTraits": ["Affectionate", "Energetic", "Gentle", "Loyal", "Sensitive"],
        "dietNotes": "Extremely active breed needs high-calorie, protein-rich food. Lean athletes that burn calories fast; adjust portions to activity level."
    },
    "Bichon Frise": {
        "lifespan": "14-15 years",
        "sizeCategory": "small",
        "weight": "3-5 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "high",
        "healthPredispositions": ["Patellar luxation", "Allergies", "Bladder stones", "Dental disease"],
        "temperamentTraits": ["Playful", "Curious", "Cheerful", "Gentle", "Sensitive"],
        "dietNotes": "Feed a high-quality small-breed formula. Prone to allergies; grain-free or limited-ingredient diets may benefit sensitive individuals."
    },
    "Airedale Terrier": {
        "lifespan": "11-14 years",
        "sizeCategory": "large",
        "weight": "23-29 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "high",
        "healthPredispositions": ["Hip dysplasia", "Hypothyroidism", "Gastric dilatation", "Dermatitis"],
        "temperamentTraits": ["Friendly", "Clever", "Courageous", "Confident", "Outgoing"],
        "dietNotes": "Active large terrier needs protein-rich food. Prone to skin issues; omega fatty acids and high-quality proteins support skin and coat health."
    },
    "Belgian Malinois": {
        "lifespan": "14-16 years",
        "sizeCategory": "large",
        "weight": "25-34 kg",
        "exerciseNeeds": "very high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Elbow dysplasia", "Progressive retinal atrophy", "Epilepsy"],
        "temperamentTraits": ["Confident", "Smart", "Hard-working", "Protective", "Alert"],
        "dietNotes": "Extremely high-energy working dog needs calorie-dense, protein-rich food. Working Malinois may need 30-40% more calories than pet dogs."
    },
    "Bloodhound": {
        "lifespan": "10-12 years",
        "sizeCategory": "large",
        "weight": "36-50 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "low",
        "healthPredispositions": ["Bloat", "Hip dysplasia", "Ear infections", "Eyelid problems"],
        "temperamentTraits": ["Friendly", "Independent", "Inquisitive", "Gentle", "Affectionate"],
        "dietNotes": "Very bloat-prone; feed 2-3 small meals daily from an elevated dish. Wipe face and ears after eating to prevent skin fold infections."
    },
    "English Springer Spaniel": {
        "lifespan": "12-14 years",
        "sizeCategory": "medium",
        "weight": "18-25 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Progressive retinal atrophy", "Ear infections", "Elbow dysplasia"],
        "temperamentTraits": ["Friendly", "Playful", "Obedient", "Alert", "Affectionate"],
        "dietNotes": "Active sporting dog needs balanced nutrition with good protein. Keep ears clean after meals; floppy ears trap moisture and food debris."
    },
    "Cane Corso": {
        "lifespan": "9-12 years",
        "sizeCategory": "giant",
        "weight": "40-50 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Hip dysplasia", "Bloat", "Eyelid abnormalities", "Idiopathic epilepsy"],
        "temperamentTraits": ["Intelligent", "Affectionate", "Majestic", "Loyal", "Protective"],
        "dietNotes": "Large, muscular breed needs high-protein, large-breed formula. Feed 2-3 meals daily to prevent bloat. Use slow feeders for fast eaters."
    },
    "Newfoundland": {
        "lifespan": "9-10 years",
        "sizeCategory": "giant",
        "weight": "55-70 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "high",
        "healthPredispositions": ["Hip dysplasia", "Elbow dysplasia", "Cystinuria", "Subvalvular aortic stenosis"],
        "temperamentTraits": ["Sweet", "Patient", "Devoted", "Gentle", "Trainable"],
        "dietNotes": "Giant breed needs large-breed formula with controlled calcium for joint health. Prone to bloat; feed multiple smaller meals rather than one large one."
    },
    "Papillon": {
        "lifespan": "14-16 years",
        "sizeCategory": "small",
        "weight": "3-5 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Patellar luxation", "Dental disease", "Progressive retinal atrophy", "Open fontanel"],
        "temperamentTraits": ["Friendly", "Alert", "Happy", "Intelligent", "Energetic"],
        "dietNotes": "Small-breed formula with nutrient-dense ingredients. Active little dogs with fast metabolisms; ensure consistent feeding schedule."
    },
    "Saint Bernard": {
        "lifespan": "8-10 years",
        "sizeCategory": "giant",
        "weight": "54-82 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Elbow dysplasia", "Bloat", "Osteosarcoma"],
        "temperamentTraits": ["Watchful", "Patient", "Gentle", "Friendly", "Calm"],
        "dietNotes": "Giant breed needs controlled-calorie diet to prevent rapid growth. Feed 2-3 meals daily; avoid free-feeding. Joint supplements are beneficial."
    },
    "Alaskan Malamute": {
        "lifespan": "10-14 years",
        "sizeCategory": "large",
        "weight": "34-45 kg",
        "exerciseNeeds": "very high",
        "groomingNeeds": "high",
        "healthPredispositions": ["Hip dysplasia", "Chondrodysplasia", "Hypothyroidism", "Polyneuropathy"],
        "temperamentTraits": ["Affectionate", "Loyal", "Playful", "Dignified", "Independent"],
        "dietNotes": "Working sled dogs are efficient eaters; they need less food than expected. High-protein, moderate-fat diet works best. Avoid overfeeding."
    },
    "West Highland White Terrier": {
        "lifespan": "13-15 years",
        "sizeCategory": "small",
        "weight": "7-10 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "high",
        "healthPredispositions": ["Skin allergies", "Patellar luxation", "Craniomandibular osteopathy", "Legg-Calve-Perthes"],
        "temperamentTraits": ["Friendly", "Alert", "Hardy", "Independent", "Happy"],
        "dietNotes": "Prone to skin allergies; a limited-ingredient or hypoallergenic diet can help. Avoid chicken-based foods if skin issues develop."
    },
    "Jack Russell Terrier": {
        "lifespan": "12-14 years",
        "sizeCategory": "small",
        "weight": "6-8 kg",
        "exerciseNeeds": "very high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Patellar luxation", "Deafness", "Legg-Calve-Perthes", "Eye disorders"],
        "temperamentTraits": ["Fearless", "Athletic", "Clever", "Vocal", "Energetic"],
        "dietNotes": "Extremely energetic small dog needs calorie-dense food. Despite small size, they burn enormous energy and need more food than you might expect."
    },
    "Afghan Hound": {
        "lifespan": "12-18 years",
        "sizeCategory": "large",
        "weight": "23-27 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "high",
        "healthPredispositions": ["Hip dysplasia", "Cataracts", "Hypothyroidism", "Chylothorax"],
        "temperamentTraits": ["Aloof", "Dignified", "Independent", "Happy", "Clownish"],
        "dietNotes": "Lean sighthound with fast metabolism. Feed a high-quality, protein-rich diet. Some benefit from elevated food bowls to protect their long necks."
    },
    "Irish Wolfhound": {
        "lifespan": "6-8 years",
        "sizeCategory": "giant",
        "weight": "48-70 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Bloat", "Heart disease", "Osteosarcoma", "Liver shunt"],
        "temperamentTraits": ["Courageous", "Dignified", "Calm", "Gentle", "Generous"],
        "dietNotes": "Giant breed with short lifespan needs giant-breed formula. Feed 2-3 small meals daily to prevent bloat. Avoid heavy exercise around mealtimes."
    },
    "Borzoi": {
        "lifespan": "9-14 years",
        "sizeCategory": "large",
        "weight": "27-48 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Bloat", "Osteosarcoma", "Heart conditions", "Progressive retinal atrophy"],
        "temperamentTraits": ["Affectionate", "Loyal", "Regally Dignified", "Calm", "Agreeable"],
        "dietNotes": "Deep-chested sighthound very prone to bloat. Feed 2-3 small meals daily and avoid exercise 1 hour before and after eating."
    },
    "Komondor": {
        "lifespan": "10-12 years",
        "sizeCategory": "giant",
        "weight": "36-60 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "high",
        "healthPredispositions": ["Hip dysplasia", "Bloat", "Entropion", "Ear infections"],
        "temperamentTraits": ["Loyal", "Dignified", "Brave", "Independent", "Calm"],
        "dietNotes": "Large guardian breed needs high-quality, moderate-calorie food. Feed twice daily; prone to bloat so avoid exercise around meals."
    },
    "Basenji": {
        "lifespan": "13-14 years",
        "sizeCategory": "small",
        "weight": "10-12 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Fanconi syndrome", "Progressive retinal atrophy", "Hip dysplasia", "Hypothyroidism"],
        "temperamentTraits": ["Independent", "Smart", "Poised", "Curious", "Alert"],
        "dietNotes": "Monitor for Fanconi syndrome symptoms that affect kidney function. Fresh water always available. High-quality protein diet in measured portions."
    },
    "Xoloitzcuintli": {
        "lifespan": "13-18 years",
        "sizeCategory": "medium",
        "weight": "5-25 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "low",
        "healthPredispositions": ["Skin issues", "Dental problems", "Acne", "Sunburn"],
        "temperamentTraits": ["Loyal", "Alert", "Calm", "Tranquil", "Attentive"],
        "dietNotes": "Hairless variety needs extra skin-supporting nutrients. Diet rich in omega fatty acids helps maintain healthy skin. Apply sunscreen before outdoor time."
    },
    "Chinese Crested": {
        "lifespan": "13-18 years",
        "sizeCategory": "small",
        "weight": "2-5 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Dental disease", "Patellar luxation", "Legg-Calve-Perthes", "Eye problems"],
        "temperamentTraits": ["Affectionate", "Playful", "Alert", "Lively", "Happy"],
        "dietNotes": "Hairless variety has dental issues; soft food may be needed. Small frequent meals; prone to weight gain if overfed."
    },
    "Saluki": {
        "lifespan": "10-17 years",
        "sizeCategory": "large",
        "weight": "18-27 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Heart conditions", "Hypothyroidism", "Hemangiosarcoma", "Anesthetic sensitivity"],
        "temperamentTraits": ["Gentle", "Dignified", "Independent", "Quiet", "Devoted"],
        "dietNotes": "Lean sighthound with low body fat; they naturally appear thin. Feed a high-quality, moderate-calorie diet. Sensitive to anesthesia."
    },
    "Tibetan Mastiff": {
        "lifespan": "10-12 years",
        "sizeCategory": "giant",
        "weight": "34-73 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "high",
        "healthPredispositions": ["Hip dysplasia", "Hypothyroidism", "Entropion", "Autoimmune disorders"],
        "temperamentTraits": ["Independent", "Reserved", "Intelligent", "Protective", "Strong-willed"],
        "dietNotes": "Guardian breed that eats less than their size suggests. Feed a large-breed formula; they may self-regulate food intake seasonally."
    },
    "Pharaoh Hound": {
        "lifespan": "12-14 years",
        "sizeCategory": "medium",
        "weight": "18-27 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Anesthetic sensitivity", "Allergies", "Hip dysplasia", "Patellar luxation"],
        "temperamentTraits": ["Friendly", "Affectionate", "Smart", "Noble", "Playful"],
        "dietNotes": "Athletic sighthound needs quality protein with moderate fat. Lean breed; avoid overfeeding but ensure enough calories for their active lifestyle."
    },
    "Norwegian Lundehund": {
        "lifespan": "12-15 years",
        "sizeCategory": "small",
        "weight": "6-7 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Lundehund syndrome", "Intestinal disease", "Protein-losing enteropathy", "Small intestinal bacterial overgrowth"],
        "temperamentTraits": ["Alert", "Energetic", "Loyal", "Protective", "Cheerful"],
        "dietNotes": "Prone to serious intestinal issues (Lundehund syndrome). May need special easily digestible diet. Consult vet for breed-specific dietary needs."
    },
    "Bedlington Terrier": {
        "lifespan": "11-16 years",
        "sizeCategory": "small",
        "weight": "8-10 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "high",
        "healthPredispositions": ["Copper toxicosis", "Patellar luxation", "Retinal dysplasia", "Kidney disease"],
        "temperamentTraits": ["Gentle", "Loyal", "Spirited", "Energetic", "Good-tempered"],
        "dietNotes": "Prone to copper storage disease; avoid foods high in copper (organ meats, shellfish). Requires a specifically low-copper diet if affected."
    },
    "Leonberger": {
        "lifespan": "7-10 years",
        "sizeCategory": "giant",
        "weight": "41-77 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "high",
        "healthPredispositions": ["Hip dysplasia", "Elbow dysplasia", "Bloat", "Osteosarcoma"],
        "temperamentTraits": ["Friendly", "Playful", "Loyal", "Gentle", "Adaptable"],
        "dietNotes": "Giant breed needs slow, controlled growth as a puppy. Feed large-breed formula in 2-3 meals daily. Joint supplements recommended."
    },
    "Otterhound": {
        "lifespan": "10-13 years",
        "sizeCategory": "large",
        "weight": "36-54 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Bloat", "Epilepsy", "Thrombocytopenia"],
        "temperamentTraits": ["Amiable", "Boisterous", "Even-tempered", "Friendly", "Independent"],
        "dietNotes": "Active hound needs good-quality food with balanced protein and fat. Can be messy eaters; their beard collects food and water."
    },
    "Lagotto Romagnolo": {
        "lifespan": "15-17 years",
        "sizeCategory": "medium",
        "weight": "11-16 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "high",
        "healthPredispositions": ["Hip dysplasia", "Epilepsy", "Storage disease", "Eye disorders"],
        "temperamentTraits": ["Keen", "Loyal", "Loving", "Active", "Trainable"],
        "dietNotes": "Active working breed needs quality protein. Their curly coat benefits from omega fatty acids. Moderate portions to maintain a healthy weight."
    },
    "Azawakh": {
        "lifespan": "12-15 years",
        "sizeCategory": "large",
        "weight": "15-25 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Seizures", "Autoimmune disorders", "Hypothyroidism", "Cardiac problems"],
        "temperamentTraits": ["Loyal", "Independent", "Affectionate", "Attentive", "Rugged"],
        "dietNotes": "Naturally lean sighthound; visible ribs are normal for the breed. Feed a high-quality protein diet; they may eat less in hot weather."
    },
    "Bergamasco Sheepdog": {
        "lifespan": "13-15 years",
        "sizeCategory": "medium",
        "weight": "26-38 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "low",
        "healthPredispositions": ["Hip dysplasia", "Eye problems", "Bloat", "Ear infections"],
        "temperamentTraits": ["Intelligent", "Patient", "Sociable", "Determined", "Vigilant"],
        "dietNotes": "Hardy breed with modest dietary needs. Feed a balanced large-breed diet. Once their coat 'sets' into mats, grooming needs are surprisingly low."
    },
    "Thai Ridgeback": {
        "lifespan": "12-13 years",
        "sizeCategory": "medium",
        "weight": "16-34 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Hip dysplasia", "Dermoid sinus", "Bloat", "Eye disorders"],
        "temperamentTraits": ["Loyal", "Independent", "Intelligent", "Tough", "Active"],
        "dietNotes": "Active, primitive breed does well on high-protein diets. Not prone to obesity but should still have measured meals twice daily."
    },
    "Peruvian Inca Orchid": {
        "lifespan": "12-14 years",
        "sizeCategory": "medium",
        "weight": "4-25 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "low",
        "healthPredispositions": ["Skin conditions", "Dental issues", "Epilepsy", "Inflammatory bowel disease"],
        "temperamentTraits": ["Affectionate", "Loyal", "Alert", "Lively", "Noble"],
        "dietNotes": "Hairless breed needs skin-nourishing diet rich in omega-3 and omega-6 fatty acids. Dental issues may require softer foods."
    },
    "Mudi": {
        "lifespan": "12-14 years",
        "sizeCategory": "medium",
        "weight": "8-13 kg",
        "exerciseNeeds": "very high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Epilepsy", "Patellar luxation", "Eye disorders"],
        "temperamentTraits": ["Intelligent", "Active", "Alert", "Versatile", "Courageous"],
        "dietNotes": "High-energy herding breed needs calorie-dense food. Active working dogs need more calories; adjust based on activity level."
    },
    "Catalburun": {
        "lifespan": "12-14 years",
        "sizeCategory": "medium",
        "weight": "16-25 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Hip dysplasia", "Ear infections", "Eye disorders", "Bloat"],
        "temperamentTraits": ["Loyal", "Energetic", "Focused", "Gentle", "Dedicated"],
        "dietNotes": "Active pointer needs high-quality protein diet. Feed twice daily; moderate portions appropriate for their medium build and activity level."
    },
    "New Guinea Singing Dog": {
        "lifespan": "12-18 years",
        "sizeCategory": "medium",
        "weight": "9-14 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Generally very healthy", "Hip dysplasia", "Thyroid issues", "Eye disorders"],
        "temperamentTraits": ["Alert", "Curious", "Independent", "Agile", "Intelligent"],
        "dietNotes": "Primitive breed does well on a high-protein diet. They are resourceful eaters in the wild; domestic feeding should mimic whole-prey nutrition."
    },
    "Chinook": {
        "lifespan": "12-15 years",
        "sizeCategory": "large",
        "weight": "25-41 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Epilepsy", "Cryptorchidism", "Gastrointestinal issues"],
        "temperamentTraits": ["Smart", "Patient", "Devoted", "Friendly", "Calm"],
        "dietNotes": "Working sled dog breed needs good-quality, protein-rich food. Moderate fat content; adjust calories to activity level."
    },
    "Telomian": {
        "lifespan": "12-14 years",
        "sizeCategory": "small",
        "weight": "8-13 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Generally healthy", "Patellar luxation", "Eye disorders", "Dental issues"],
        "temperamentTraits": ["Alert", "Intelligent", "Agile", "Independent", "Sociable"],
        "dietNotes": "Primitive breed thrives on high-protein diet. Small but active; feed measured meals twice daily with quality animal protein."
    },
    "Carolina Dog": {
        "lifespan": "12-15 years",
        "sizeCategory": "medium",
        "weight": "14-20 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Generally healthy", "Hip dysplasia", "Sensitive to anesthesia", "Skin allergies"],
        "temperamentTraits": ["Loyal", "Gentle", "Reserved", "Primitive", "Resourceful"],
        "dietNotes": "Hardy, primitive breed with few dietary issues. Benefits from high-protein, whole-ingredient foods. Moderate portions twice daily."
    },
    "Kai Ken": {
        "lifespan": "12-15 years",
        "sizeCategory": "medium",
        "weight": "11-25 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Generally healthy", "Patellar luxation", "Allergies", "Hip dysplasia"],
        "temperamentTraits": ["Intelligent", "Brave", "Alert", "Loyal", "Reserved"],
        "dietNotes": "Japanese breed traditionally fed fish-based diets. Quality protein with omega fatty acids supports their brindle double coat."
    },
    "Stabyhoun": {
        "lifespan": "13-15 years",
        "sizeCategory": "medium",
        "weight": "18-25 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Elbow dysplasia", "Epilepsy", "Patent ductus arteriosus"],
        "temperamentTraits": ["Friendly", "Gentle", "Patient", "Obedient", "Devoted"],
        "dietNotes": "Versatile sporting breed needs balanced nutrition with quality protein. Not prone to obesity but meals should still be measured."
    },
    "Fila Brasileiro": {
        "lifespan": "9-11 years",
        "sizeCategory": "giant",
        "weight": "41-50 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "low",
        "healthPredispositions": ["Hip dysplasia", "Elbow dysplasia", "Bloat", "Entropion"],
        "temperamentTraits": ["Loyal", "Brave", "Determined", "Docile", "Obedient"],
        "dietNotes": "Giant guardian breed needs large-breed formula with joint support. Prone to bloat; feed 2-3 smaller meals daily instead of one large meal."
    },
    "Canaan Dog": {
        "lifespan": "12-15 years",
        "sizeCategory": "medium",
        "weight": "18-25 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Hypothyroidism", "Patellar luxation", "Eye disorders"],
        "temperamentTraits": ["Alert", "Vigilant", "Devoted", "Docile", "Quick"],
        "dietNotes": "Hardy desert breed with efficient metabolism. Quality protein diet in moderate portions; they tend to be easy keepers."
    },
    "Kooikerhondje": {
        "lifespan": "12-15 years",
        "sizeCategory": "small",
        "weight": "9-14 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Von Willebrand's disease", "Patellar luxation", "Epilepsy", "Eye disorders"],
        "temperamentTraits": ["Friendly", "Alert", "Cheerful", "Agile", "Intelligent"],
        "dietNotes": "Active sporting breed needs balanced nutrition. Not prone to overeating; feed measured meals with quality protein twice daily."
    },
    "Japanese Chin": {
        "lifespan": "10-12 years",
        "sizeCategory": "small",
        "weight": "1.5-5 kg",
        "exerciseNeeds": "low",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Heart murmurs", "Patellar luxation", "Cataracts", "GM2 gangliosidosis"],
        "temperamentTraits": ["Charming", "Noble", "Loving", "Cat-like", "Loyal"],
        "dietNotes": "Toy breed needs small, nutrient-dense meals. Their flat face can make eating difficult; use shallow, wide bowls."
    },
    "Pekingese": {
        "lifespan": "12-14 years",
        "sizeCategory": "small",
        "weight": "3-6 kg",
        "exerciseNeeds": "low",
        "groomingNeeds": "high",
        "healthPredispositions": ["Brachycephalic syndrome", "Intervertebral disc disease", "Eye injuries", "Patellar luxation"],
        "temperamentTraits": ["Opinionated", "Affectionate", "Loyal", "Regal", "Good-natured"],
        "dietNotes": "Flat-faced breed prone to overheating; avoid warm food. Small meals with quality protein; monitor weight closely as excess weight worsens breathing."
    },
    "Blenheim Spaniel": {
        "lifespan": "9-14 years",
        "sizeCategory": "small",
        "weight": "5-8 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Mitral valve disease", "Syringomyelia", "Patellar luxation", "Eye conditions"],
        "temperamentTraits": ["Affectionate", "Gentle", "Graceful", "Patient", "Sociable"],
        "dietNotes": "Heart-healthy diet with omega-3 fatty acids. Monitor portions as they gain weight easily. Small-breed formula works well."
    },
    "Toy Terrier": {
        "lifespan": "12-13 years",
        "sizeCategory": "small",
        "weight": "3-4 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "low",
        "healthPredispositions": ["Patellar luxation", "Legg-Calve-Perthes", "Dental disease", "Collapsed trachea"],
        "temperamentTraits": ["Alert", "Spirited", "Clever", "Athletic", "Loyal"],
        "dietNotes": "Tiny breed needs small, frequent meals of nutrient-dense food. Dental-sized kibble helps maintain oral health."
    },
    "Bluetick Coonhound": {
        "lifespan": "11-12 years",
        "sizeCategory": "large",
        "weight": "20-36 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Hip dysplasia", "Bloat", "Ear infections", "Cataracts"],
        "temperamentTraits": ["Friendly", "Intelligent", "Devoted", "Tenacious", "Active"],
        "dietNotes": "Active hound needs high-quality protein diet. Clean ears regularly, especially after eating from deep bowls. Feed twice daily."
    },
    "Black and Tan Coonhound": {
        "lifespan": "10-12 years",
        "sizeCategory": "large",
        "weight": "25-34 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Hip dysplasia", "Ear infections", "Bloat", "Eye problems"],
        "temperamentTraits": ["Easy-going", "Friendly", "Bright", "Brave", "Trusting"],
        "dietNotes": "Active tracking dog needs calorie-dense food. Long, floppy ears need cleaning after meals. Feed twice daily to reduce bloat risk."
    },
    "Walker Hound": {
        "lifespan": "12-13 years",
        "sizeCategory": "large",
        "weight": "20-32 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Hip dysplasia", "Ear infections", "Bloat", "Eye disorders"],
        "temperamentTraits": ["Smart", "Brave", "Courteous", "Confident", "Loving"],
        "dietNotes": "Athletic coonhound needs quality protein for endurance. Feed measured meals twice daily; working dogs may need increased portions."
    },
    "English Foxhound": {
        "lifespan": "10-13 years",
        "sizeCategory": "large",
        "weight": "25-34 kg",
        "exerciseNeeds": "very high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Hip dysplasia", "Renal disease", "Epilepsy", "Ear infections"],
        "temperamentTraits": ["Affectionate", "Gentle", "Sociable", "Active", "Tolerant"],
        "dietNotes": "Bred for pack life and endurance; needs high-protein, calorie-dense food. Active hunters need significantly more calories than pet dogs."
    },
    "Redbone Coonhound": {
        "lifespan": "12-15 years",
        "sizeCategory": "large",
        "weight": "20-32 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Hip dysplasia", "Ear infections", "Bloat", "Eye disorders"],
        "temperamentTraits": ["Even-tempered", "Amiable", "Eager", "Mellow", "Accommodating"],
        "dietNotes": "Active hound breed needs balanced, protein-rich food. Prone to overeating; measure all meals. Keep ears clean after feeding."
    },
    "Italian Greyhound": {
        "lifespan": "14-15 years",
        "sizeCategory": "small",
        "weight": "3-5 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "low",
        "healthPredispositions": ["Dental disease", "Leg fractures", "Patellar luxation", "Progressive retinal atrophy"],
        "temperamentTraits": ["Playful", "Sensitive", "Alert", "Affectionate", "Athletic"],
        "dietNotes": "Delicate toy breed with fast metabolism. Feed small, frequent meals of nutrient-dense food. Dental health requires regular attention."
    },
    "Ibizan Hound": {
        "lifespan": "11-14 years",
        "sizeCategory": "large",
        "weight": "20-29 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Anesthetic sensitivity", "Seizures", "Axonal dystrophy", "Allergies"],
        "temperamentTraits": ["Clownish", "Family-oriented", "Even-tempered", "Polite", "Loyal"],
        "dietNotes": "Lean sighthound needs quality protein without excess fat. Naturally thin; visible ribs may be normal. Feed twice daily."
    },
    "Norwegian Elkhound": {
        "lifespan": "12-15 years",
        "sizeCategory": "medium",
        "weight": "20-24 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "high",
        "healthPredispositions": ["Hip dysplasia", "Fanconi syndrome", "Progressive retinal atrophy", "Sebaceous cysts"],
        "temperamentTraits": ["Bold", "Playful", "Hardy", "Alert", "Loyal"],
        "dietNotes": "Hardy Nordic breed prone to weight gain. Feed measured meals of quality food; reduce portions if activity decreases. Monitor kidney health."
    },
    "Scottish Deerhound": {
        "lifespan": "8-11 years",
        "sizeCategory": "giant",
        "weight": "34-50 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Bloat", "Osteosarcoma", "Cardiomyopathy", "Factor VII deficiency"],
        "temperamentTraits": ["Dignified", "Gentle", "Polite", "Friendly", "Docile"],
        "dietNotes": "Giant sighthound prone to bloat. Feed 2-3 small meals daily. They are naturally lean; do not overfeed to 'fill them out.'"
    },
    "American Staffordshire Terrier": {
        "lifespan": "12-16 years",
        "sizeCategory": "medium",
        "weight": "25-32 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Hip dysplasia", "Cerebellar ataxia", "Heart disease", "Skin allergies"],
        "temperamentTraits": ["Confident", "Smart", "Good-natured", "Courageous", "Loyal"],
        "dietNotes": "Muscular breed needs high-protein diet. Active dogs with strong jaws; durable chew toys complement their feeding routine."
    },
    "Border Terrier": {
        "lifespan": "12-15 years",
        "sizeCategory": "small",
        "weight": "5-7 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Patellar luxation", "Heart defects", "Hip dysplasia", "Seizures"],
        "temperamentTraits": ["Affectionate", "Happy", "Obedient", "Plucky", "Bold"],
        "dietNotes": "Active small terrier needs quality protein. Not typically food-obsessed but will eat well after exercise. Measured meals twice daily."
    },
    "Kerry Blue Terrier": {
        "lifespan": "12-15 years",
        "sizeCategory": "medium",
        "weight": "15-18 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "high",
        "healthPredispositions": ["Hip dysplasia", "Hypothyroidism", "Cataracts", "Skin cysts"],
        "temperamentTraits": ["Alert", "Smart", "People-oriented", "Adaptable", "Spirited"],
        "dietNotes": "Active terrier needs balanced protein-rich diet. Their non-shedding coat benefits from omega fatty acids and quality nutrition."
    },
    "Irish Terrier": {
        "lifespan": "13-15 years",
        "sizeCategory": "medium",
        "weight": "11-13 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Urinary stones", "Hyperkeratosis", "Cataracts", "Hip dysplasia"],
        "temperamentTraits": ["Bold", "Dashing", "Respectful", "Good-tempered", "Courageous"],
        "dietNotes": "Active terrier needs quality protein diet. Prone to urinary stones; ensure adequate water intake and avoid high-purine foods."
    },
    "Norfolk Terrier": {
        "lifespan": "12-16 years",
        "sizeCategory": "small",
        "weight": "5-6 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Mitral valve disease", "Patellar luxation", "Hip dysplasia", "Dental disease"],
        "temperamentTraits": ["Alert", "Fearless", "Self-confident", "Fun-loving", "Sociable"],
        "dietNotes": "Small terrier with a good appetite. Feed nutrient-dense small-breed food in measured portions. Dental care is important."
    },
    "Norwich Terrier": {
        "lifespan": "12-15 years",
        "sizeCategory": "small",
        "weight": "5-6 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Upper airway syndrome", "Epilepsy", "Hip dysplasia", "Patellar luxation"],
        "temperamentTraits": ["Fearless", "Loyal", "Affectionate", "Alert", "Hardy"],
        "dietNotes": "Small terrier with big appetite. Feed measured portions of quality small-breed food. Can be prone to weight gain if free-fed."
    },
    "Wire Fox Terrier": {
        "lifespan": "12-15 years",
        "sizeCategory": "small",
        "weight": "7-9 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "high",
        "healthPredispositions": ["Patellar luxation", "Legg-Calve-Perthes", "Lens luxation", "Epilepsy"],
        "temperamentTraits": ["Friendly", "Confident", "Alert", "Keen", "Lively"],
        "dietNotes": "Active terrier needs quality protein. Their wiry coat benefits from good nutrition with omega fatty acids. Feed twice daily."
    },
    "Lakeland Terrier": {
        "lifespan": "12-15 years",
        "sizeCategory": "small",
        "weight": "7-8 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "high",
        "healthPredispositions": ["Legg-Calve-Perthes", "Lens luxation", "Von Willebrand's disease", "Distichiasis"],
        "temperamentTraits": ["Bold", "Friendly", "Confident", "Entertaining", "Tenacious"],
        "dietNotes": "Active small terrier needs high-quality food. Not typically food-driven but will benefit from consistent feeding schedule twice daily."
    },
    "Sealyham Terrier": {
        "lifespan": "12-14 years",
        "sizeCategory": "small",
        "weight": "8-10 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "high",
        "healthPredispositions": ["Retinal dysplasia", "Lens luxation", "Deafness", "Allergies"],
        "temperamentTraits": ["Outgoing", "Friendly", "Calm", "Charming", "Adaptable"],
        "dietNotes": "Moderate activity breed; watch for weight gain. Feed quality food in measured portions. Their white coat benefits from good nutrition."
    },
    "Cairn Terrier": {
        "lifespan": "13-15 years",
        "sizeCategory": "small",
        "weight": "6-7 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Portosystemic shunt", "Globoid cell leukodystrophy", "Patellar luxation", "Allergies"],
        "temperamentTraits": ["Alert", "Cheerful", "Busy", "Hardy", "Independent"],
        "dietNotes": "Hardy terrier with good appetite. Feed quality food in controlled portions. Prone to weight gain if overfed or under-exercised."
    },
    "Australian Terrier": {
        "lifespan": "11-15 years",
        "sizeCategory": "small",
        "weight": "5-7 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Patellar luxation", "Legg-Calve-Perthes", "Diabetes", "Allergies"],
        "temperamentTraits": ["Spirited", "Courageous", "Affectionate", "Alert", "Companionable"],
        "dietNotes": "Small but hardy terrier needs quality, nutrient-dense food. Prone to diabetes; maintain consistent feeding schedule and healthy weight."
    },
    "Dandie Dinmont Terrier": {
        "lifespan": "12-15 years",
        "sizeCategory": "small",
        "weight": "8-11 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Intervertebral disc disease", "Glaucoma", "Cushing's disease", "Epilepsy"],
        "temperamentTraits": ["Independent", "Determined", "Intelligent", "Proud", "Affectionate"],
        "dietNotes": "Long-backed breed; weight management protects the spine. Feed measured portions and avoid excess treats that lead to weight gain."
    },
    "Boston Terrier": {
        "lifespan": "11-13 years",
        "sizeCategory": "small",
        "weight": "5-11 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "low",
        "healthPredispositions": ["Brachycephalic syndrome", "Patellar luxation", "Cataracts", "Deafness"],
        "temperamentTraits": ["Friendly", "Bright", "Amusing", "Gentle", "Lively"],
        "dietNotes": "Flat-faced breed; use wide, shallow bowls. Prone to gas and digestive sensitivity; quality food with easily digestible ingredients helps."
    },
    "Giant Schnauzer": {
        "lifespan": "12-15 years",
        "sizeCategory": "giant",
        "weight": "27-48 kg",
        "exerciseNeeds": "very high",
        "groomingNeeds": "high",
        "healthPredispositions": ["Hip dysplasia", "Osteochondritis dissecans", "Autoimmune thyroiditis", "Bloat"],
        "temperamentTraits": ["Loyal", "Alert", "Trainable", "Powerful", "Bold"],
        "dietNotes": "Large, active working dog needs high-protein, calorie-dense food. Feed twice daily to reduce bloat risk. Joint supplements are beneficial."
    },
    "Standard Schnauzer": {
        "lifespan": "13-16 years",
        "sizeCategory": "medium",
        "weight": "14-20 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "high",
        "healthPredispositions": ["Hip dysplasia", "Eye disorders", "Autoimmune conditions", "Skin tumors"],
        "temperamentTraits": ["Fearless", "Smart", "Spirited", "Reliable", "Good-natured"],
        "dietNotes": "Active medium breed needs balanced nutrition. Not typically food-driven; consistent meals with quality protein twice daily."
    },
    "Scottish Terrier": {
        "lifespan": "12 years",
        "sizeCategory": "small",
        "weight": "8-10 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "high",
        "healthPredispositions": ["Scottie cramp", "Von Willebrand's disease", "Bladder cancer", "Craniomandibular osteopathy"],
        "temperamentTraits": ["Confident", "Independent", "Spirited", "Alert", "Dignified"],
        "dietNotes": "Moderate exercise breed; avoid overfeeding. Quality protein with measured portions. Prone to bladder cancer; consider cancer-preventive nutrition."
    },
    "Tibetan Terrier": {
        "lifespan": "15-16 years",
        "sizeCategory": "medium",
        "weight": "8-14 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "high",
        "healthPredispositions": ["Progressive retinal atrophy", "Patellar luxation", "Hip dysplasia", "Lens luxation"],
        "temperamentTraits": ["Affectionate", "Sensitive", "Loyal", "Intelligent", "Reserved"],
        "dietNotes": "Long-lived breed benefits from a balanced diet with antioxidants. Their heavy coat needs nutritional support from omega fatty acids."
    },
    "Silky Terrier": {
        "lifespan": "13-15 years",
        "sizeCategory": "small",
        "weight": "4-5 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "high",
        "healthPredispositions": ["Patellar luxation", "Legg-Calve-Perthes", "Diabetes", "Tracheal collapse"],
        "temperamentTraits": ["Friendly", "Quick", "Keenly Alert", "Spirited", "Joyful"],
        "dietNotes": "Small breed with beautiful silky coat. Nutrient-dense food with omega fatty acids supports coat health. Feed small portions twice daily."
    },
    "Soft-Coated Wheaten Terrier": {
        "lifespan": "12-14 years",
        "sizeCategory": "medium",
        "weight": "14-20 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "high",
        "healthPredispositions": ["Protein-losing nephropathy", "Protein-losing enteropathy", "Addison's disease", "Renal dysplasia"],
        "temperamentTraits": ["Friendly", "Happy", "Devoted", "Steady", "Self-confident"],
        "dietNotes": "Prone to protein-wasting diseases; high-quality, easily digestible protein is essential. Avoid high-fat diets. Regular vet monitoring recommended."
    },
    "Lhasa Apso": {
        "lifespan": "12-15 years",
        "sizeCategory": "small",
        "weight": "5-8 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "high",
        "healthPredispositions": ["Patellar luxation", "Cherry eye", "Kidney problems", "Dry eye"],
        "temperamentTraits": ["Confident", "Smart", "Comical", "Loyal", "Independent"],
        "dietNotes": "Small breed needs quality food. Their long coat requires nutritional support; omega fatty acids help maintain coat quality."
    },
    "Flat-Coated Retriever": {
        "lifespan": "8-10 years",
        "sizeCategory": "large",
        "weight": "25-36 kg",
        "exerciseNeeds": "very high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Cancer", "Hip dysplasia", "Patellar luxation", "Bloat"],
        "temperamentTraits": ["Cheerful", "Optimistic", "Good-humored", "Confident", "Devoted"],
        "dietNotes": "Very active sporting dog needs high-calorie, protein-rich food. Sadly cancer-prone breed; antioxidant-rich diet may help."
    },
    "Curly-Coated Retriever": {
        "lifespan": "10-12 years",
        "sizeCategory": "large",
        "weight": "27-41 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Hip dysplasia", "Eye disorders", "Bloat", "Epilepsy"],
        "temperamentTraits": ["Confident", "Proud", "Intelligent", "Wickedly Clever", "Independent"],
        "dietNotes": "Active sporting breed needs balanced, protein-rich food. Their unique curly coat is low maintenance but benefits from good nutrition."
    },
    "Chesapeake Bay Retriever": {
        "lifespan": "10-13 years",
        "sizeCategory": "large",
        "weight": "25-36 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Progressive retinal atrophy", "Bloat", "Von Willebrand's disease"],
        "temperamentTraits": ["Affectionate", "Bright", "Sensitive", "Loyal", "Protective"],
        "dietNotes": "Hardy water retriever needs protein-rich diet with healthy fats. Their oily coat benefits from omega fatty acids in their food."
    },
    "German Shorthaired Pointer": {
        "lifespan": "10-12 years",
        "sizeCategory": "large",
        "weight": "20-32 kg",
        "exerciseNeeds": "very high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Hip dysplasia", "Bloat", "Lymphedema", "Eye conditions"],
        "temperamentTraits": ["Friendly", "Smart", "Willing", "Enthusiastic", "Bold"],
        "dietNotes": "Extremely active sporting dog needs high-calorie food. Working dogs may need 50% more calories than sedentary pets. Feed twice daily."
    },
    "English Setter": {
        "lifespan": "12 years",
        "sizeCategory": "large",
        "weight": "20-36 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Deafness", "Hypothyroidism", "Elbow dysplasia"],
        "temperamentTraits": ["Friendly", "Mellow", "Gentle", "Willing", "Affectionate"],
        "dietNotes": "Active sporting breed needs balanced nutrition with quality protein. Their feathered coat benefits from omega fatty acids."
    },
    "Gordon Setter": {
        "lifespan": "12-13 years",
        "sizeCategory": "large",
        "weight": "25-36 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Bloat", "Progressive retinal atrophy", "Hypothyroidism"],
        "temperamentTraits": ["Affectionate", "Confident", "Bold", "Loyal", "Alert"],
        "dietNotes": "Large sporting breed needs protein-rich food. Deep-chested and prone to bloat; feed 2 meals daily and avoid exercise around mealtimes."
    },
    "Brittany": {
        "lifespan": "12-14 years",
        "sizeCategory": "medium",
        "weight": "14-18 kg",
        "exerciseNeeds": "very high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Epilepsy", "Hypothyroidism", "Eye disorders"],
        "temperamentTraits": ["Bright", "Fun-loving", "Upbeat", "Agile", "Eager"],
        "dietNotes": "Extremely energetic sporting breed needs calorie-dense, high-protein food. Active hunting dogs may need significantly increased portions."
    },
    "Clumber Spaniel": {
        "lifespan": "10-12 years",
        "sizeCategory": "large",
        "weight": "25-39 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Intervertebral disc disease", "Entropion", "Ectropion"],
        "temperamentTraits": ["Gentle", "Loyal", "Amusing", "Dignified", "Mellow"],
        "dietNotes": "Heaviest spaniel breed; prone to weight gain. Strict portion control needed. Quality food with moderate calories to maintain healthy weight."
    },
    "Welsh Springer Spaniel": {
        "lifespan": "12-15 years",
        "sizeCategory": "medium",
        "weight": "16-20 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Epilepsy", "Glaucoma", "Hypothyroidism"],
        "temperamentTraits": ["Happy", "Active", "Loyal", "Faithful", "Reserved"],
        "dietNotes": "Active sporting breed needs balanced, protein-rich diet. Moderate eaters; feed quality food twice daily with appropriate portions."
    },
    "Sussex Spaniel": {
        "lifespan": "13-15 years",
        "sizeCategory": "medium",
        "weight": "16-20 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Intervertebral disc disease", "Heart murmurs", "Ear infections"],
        "temperamentTraits": ["Friendly", "Cheerful", "Calm", "Sociable", "Devoted"],
        "dietNotes": "Low-slung breed prone to weight gain. Feed measured portions of quality food. Long back means excess weight risks disc problems."
    },
    "Irish Water Spaniel": {
        "lifespan": "12-13 years",
        "sizeCategory": "large",
        "weight": "20-30 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Hypothyroidism", "Eye disorders", "Ear infections"],
        "temperamentTraits": ["Playful", "Hard-working", "Brave", "Alert", "Inquisitive"],
        "dietNotes": "Active water dog needs protein-rich diet. Their unique curly coat benefits from omega fatty acids. Feed measured meals twice daily."
    },
    "Kuvasz": {
        "lifespan": "10-12 years",
        "sizeCategory": "giant",
        "weight": "32-52 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Osteochondritis dissecans", "Hypothyroidism", "Bloat"],
        "temperamentTraits": ["Loyal", "Brave", "Patient", "Protective", "Independent"],
        "dietNotes": "Large guardian breed needs controlled calories with joint-supporting nutrients. Feed 2-3 meals daily to prevent bloat."
    },
    "Schipperke": {
        "lifespan": "12-14 years",
        "sizeCategory": "small",
        "weight": "5-9 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["MPS IIIB", "Legg-Calve-Perthes", "Epilepsy", "Hypothyroidism"],
        "temperamentTraits": ["Confident", "Alert", "Curious", "Faithful", "Foxlike"],
        "dietNotes": "Active small breed needs nutrient-dense food. Not prone to overeating but should have measured portions for optimal weight."
    },
    "Belgian Sheepdog": {
        "lifespan": "12-14 years",
        "sizeCategory": "large",
        "weight": "20-30 kg",
        "exerciseNeeds": "very high",
        "groomingNeeds": "high",
        "healthPredispositions": ["Hip dysplasia", "Epilepsy", "Progressive retinal atrophy", "Cancer"],
        "temperamentTraits": ["Bright", "Watchful", "Serious", "Devoted", "Versatile"],
        "dietNotes": "Active herding breed needs high-protein food. Their dense black coat benefits from omega fatty acids. Adjust calories to activity level."
    },
    "Briard": {
        "lifespan": "12 years",
        "sizeCategory": "large",
        "weight": "25-40 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "high",
        "healthPredispositions": ["Hip dysplasia", "Bloat", "Progressive retinal atrophy", "Hypothyroidism"],
        "temperamentTraits": ["Faithful", "Loyal", "Obedient", "Protective", "Spirited"],
        "dietNotes": "Large herding breed needs protein-rich food. Deep chest means bloat risk; feed 2 meals daily. Extensive coat needs nutritional support."
    },
    "Australian Kelpie": {
        "lifespan": "10-13 years",
        "sizeCategory": "medium",
        "weight": "14-21 kg",
        "exerciseNeeds": "very high",
        "groomingNeeds": "low",
        "healthPredispositions": ["Progressive retinal atrophy", "Cerebellar abiotrophy", "Hip dysplasia", "Cryptorchidism"],
        "temperamentTraits": ["Loyal", "Alert", "Intelligent", "Eager", "Energetic"],
        "dietNotes": "Extremely active herding dog needs high-calorie, protein-dense food. Working dogs may need double the calories of pet dogs."
    },
    "Old English Sheepdog": {
        "lifespan": "10-12 years",
        "sizeCategory": "large",
        "weight": "27-46 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "high",
        "healthPredispositions": ["Hip dysplasia", "Deafness", "Cataracts", "Hypothyroidism"],
        "temperamentTraits": ["Adaptable", "Gentle", "Smart", "Sociable", "Playful"],
        "dietNotes": "Large breed with enormous coat that hides weight gain. Weigh regularly and feed measured meals. Coat needs nutritional support."
    },
    "Collie": {
        "lifespan": "12-14 years",
        "sizeCategory": "large",
        "weight": "23-34 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "high",
        "healthPredispositions": ["Collie eye anomaly", "MDR1 gene sensitivity", "Dermatomyositis", "Bloat"],
        "temperamentTraits": ["Devoted", "Graceful", "Proud", "Friendly", "Intelligent"],
        "dietNotes": "MDR1 gene means drug sensitivity; some foods interact. Quality protein with omega fatty acids for their luxurious coat."
    },
    "Bouvier des Flandres": {
        "lifespan": "10-12 years",
        "sizeCategory": "large",
        "weight": "27-40 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "high",
        "healthPredispositions": ["Hip dysplasia", "Bloat", "Subaortic stenosis", "Hypothyroidism"],
        "temperamentTraits": ["Affectionate", "Courageous", "Strong-willed", "Loyal", "Gentle"],
        "dietNotes": "Large working breed needs protein-rich food. Prone to bloat; feed 2-3 smaller meals. Bearded face collects food; wipe after eating."
    },
    "Miniature Pinscher": {
        "lifespan": "12-16 years",
        "sizeCategory": "small",
        "weight": "4-5 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "low",
        "healthPredispositions": ["Patellar luxation", "Legg-Calve-Perthes", "Progressive retinal atrophy", "Hypothyroidism"],
        "temperamentTraits": ["Fearless", "Energetic", "Fun-loving", "Proud", "Alert"],
        "dietNotes": "Tiny breed with high metabolism. Feed nutrient-dense, small-breed food in measured portions. Prone to obesity if over-treated."
    },
    "Greater Swiss Mountain Dog": {
        "lifespan": "8-11 years",
        "sizeCategory": "giant",
        "weight": "45-64 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Bloat", "Epilepsy", "Distichiasis"],
        "temperamentTraits": ["Faithful", "Dependable", "Gentle", "Family-oriented", "Alert"],
        "dietNotes": "Giant breed needs large-breed formula with controlled growth nutrients. Very prone to bloat; feed 2-3 small meals daily."
    },
    "Appenzeller Sennenhund": {
        "lifespan": "12-15 years",
        "sizeCategory": "medium",
        "weight": "22-32 kg",
        "exerciseNeeds": "very high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Eye disorders", "Epilepsy", "Heart conditions"],
        "temperamentTraits": ["Reliable", "Fearless", "Energetic", "Self-assured", "Lively"],
        "dietNotes": "Very active mountain breed needs high-calorie food. Working dogs require increased portions. Balanced diet supports their active lifestyle."
    },
    "Entlebucher Mountain Dog": {
        "lifespan": "11-13 years",
        "sizeCategory": "medium",
        "weight": "20-30 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Progressive retinal atrophy", "Ectopic ureter", "Heart conditions"],
        "temperamentTraits": ["Loyal", "Smart", "Enthusiastic", "Determined", "Independent"],
        "dietNotes": "Active herding breed needs balanced, protein-rich food. Feed measured meals twice daily; adjust portions to activity level."
    },
    "Bullmastiff": {
        "lifespan": "7-9 years",
        "sizeCategory": "giant",
        "weight": "45-59 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "low",
        "healthPredispositions": ["Hip dysplasia", "Elbow dysplasia", "Bloat", "Lymphoma"],
        "temperamentTraits": ["Affectionate", "Loyal", "Brave", "Alert", "Docile"],
        "dietNotes": "Giant breed prone to bloat; feed 2-3 small meals daily. Large-breed formula with joint support. Avoid exercise around mealtimes."
    },
    "American Eskimo Dog": {
        "lifespan": "13-15 years",
        "sizeCategory": "small",
        "weight": "8-16 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "high",
        "healthPredispositions": ["Hip dysplasia", "Patellar luxation", "Progressive retinal atrophy", "Legg-Calve-Perthes"],
        "temperamentTraits": ["Playful", "Perky", "Smart", "Alert", "Friendly"],
        "dietNotes": "Active Spitz breed needs quality protein. Their thick white coat benefits from omega fatty acids. Feed measured meals twice daily."
    },
    "Affenpinscher": {
        "lifespan": "12-15 years",
        "sizeCategory": "small",
        "weight": "3-4 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Patellar luxation", "Heart murmurs", "Legg-Calve-Perthes", "Hip dysplasia"],
        "temperamentTraits": ["Confident", "Famously Funny", "Fearless", "Stubborn", "Curious"],
        "dietNotes": "Tiny breed needs small, frequent meals of nutrient-dense food. Their flat face may benefit from small kibble or wet food."
    },
    "Great Pyrenees": {
        "lifespan": "10-12 years",
        "sizeCategory": "giant",
        "weight": "39-54 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Bloat", "Patellar luxation", "Osteosarcoma"],
        "temperamentTraits": ["Patient", "Calm", "Smart", "Gentle", "Strong-willed"],
        "dietNotes": "Giant guardian breed; surprisingly modest appetite for their size. Feed large-breed formula in 2 meals daily. Prone to bloat."
    },
    "Chow Chow": {
        "lifespan": "8-12 years",
        "sizeCategory": "medium",
        "weight": "20-32 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "high",
        "healthPredispositions": ["Hip dysplasia", "Entropion", "Autoimmune disorders", "Bloat"],
        "temperamentTraits": ["Dignified", "Bright", "Serious-minded", "Aloof", "Loyal"],
        "dietNotes": "Prone to skin issues; quality protein with limited fillers helps. Their thick double coat needs nutritional support. Moderate portions."
    },
    "Keeshond": {
        "lifespan": "12-15 years",
        "sizeCategory": "medium",
        "weight": "16-20 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "high",
        "healthPredispositions": ["Hip dysplasia", "Patellar luxation", "Epilepsy", "Hyperparathyroidism"],
        "temperamentTraits": ["Friendly", "Lively", "Outgoing", "Alert", "Bright"],
        "dietNotes": "Spitz breed prone to weight gain under heavy coat. Regular weigh-ins important; feed measured portions of quality food."
    },
    "Brussels Griffon": {
        "lifespan": "12-15 years",
        "sizeCategory": "small",
        "weight": "3-5 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Patellar luxation", "Eye problems", "Cleft palate", "Hip dysplasia"],
        "temperamentTraits": ["Alert", "Curious", "Loyal", "Sensitive", "Self-important"],
        "dietNotes": "Tiny breed needs nutrient-dense food. Flat face can make eating messy; use wide, shallow bowls. Small frequent meals preferred."
    },
    "Cardigan Welsh Corgi": {
        "lifespan": "12-15 years",
        "sizeCategory": "small",
        "weight": "11-17 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "moderate",
        "healthPredispositions": ["Hip dysplasia", "Degenerative myelopathy", "Progressive retinal atrophy", "Intervertebral disc disease"],
        "temperamentTraits": ["Affectionate", "Loyal", "Smart", "Active", "Alert"],
        "dietNotes": "Prone to obesity like their Pembroke cousins. Strict portion control essential. Long-backed; excess weight risks spinal problems."
    },
    "Toy Poodle": {
        "lifespan": "10-18 years",
        "sizeCategory": "small",
        "weight": "2-4 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "high",
        "healthPredispositions": ["Patellar luxation", "Progressive retinal atrophy", "Legg-Calve-Perthes", "Epilepsy"],
        "temperamentTraits": ["Intelligent", "Agile", "Self-confident", "Active", "Faithful"],
        "dietNotes": "Tiny but long-lived breed needs nutrient-dense food. Small frequent meals to prevent hypoglycemia. Dental care is important."
    },
    "Miniature Poodle": {
        "lifespan": "10-18 years",
        "sizeCategory": "small",
        "weight": "5-9 kg",
        "exerciseNeeds": "moderate",
        "groomingNeeds": "high",
        "healthPredispositions": ["Progressive retinal atrophy", "Epilepsy", "Patellar luxation", "Legg-Calve-Perthes"],
        "temperamentTraits": ["Intelligent", "Active", "Proud", "Agile", "Trainable"],
        "dietNotes": "Active small breed needs quality protein for energy and coat health. Hypoallergenic coat benefits from omega fatty acids."
    },
    "Standard Poodle": {
        "lifespan": "10-18 years",
        "sizeCategory": "large",
        "weight": "20-32 kg",
        "exerciseNeeds": "high",
        "groomingNeeds": "high",
        "healthPredispositions": ["Hip dysplasia", "Bloat", "Addison's disease", "Progressive retinal atrophy"],
        "temperamentTraits": ["Intelligent", "Active", "Alert", "Faithful", "Elegant"],
        "dietNotes": "Active large breed needs protein-rich food. Prone to bloat; feed 2 meals daily. Curly coat needs nutritional support from quality fats."
    },
}

# Default data for any breed not explicitly mapped
DEFAULT_DATA = {
    "lifespan": "10-13 years",
    "sizeCategory": "medium",
    "weight": "15-25 kg",
    "exerciseNeeds": "moderate",
    "groomingNeeds": "moderate",
    "healthPredispositions": ["Hip dysplasia", "Eye disorders", "Allergies"],
    "temperamentTraits": ["Loyal", "Friendly", "Alert"],
    "dietNotes": "Feed a balanced, high-quality diet appropriate for the breed's size and activity level. Provide fresh water at all times."
}


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    json_path = os.path.join(script_dir, "assets", "dogs.json")

    # Read current data
    with open(json_path, "r", encoding="utf-8") as f:
        dogs = json.load(f)

    print(f"Loaded {len(dogs)} breeds from dogs.json")

    enriched_count = 0
    default_count = 0
    missing_breeds = []

    for dog in dogs:
        name = dog["name"]
        if name in BREED_DATA:
            data = BREED_DATA[name]
            enriched_count += 1
        else:
            data = DEFAULT_DATA
            default_count += 1
            missing_breeds.append(name)

        dog["lifespan"] = data["lifespan"]
        dog["sizeCategory"] = data["sizeCategory"]
        dog["weight"] = data["weight"]
        dog["exerciseNeeds"] = data["exerciseNeeds"]
        dog["groomingNeeds"] = data["groomingNeeds"]
        dog["healthPredispositions"] = data["healthPredispositions"]
        dog["temperamentTraits"] = data["temperamentTraits"]
        dog["dietNotes"] = data["dietNotes"]

    # Write back
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(dogs, f, indent=2, ensure_ascii=False)

    print(f"\nEnrichment complete!")
    print(f"  Breeds with specific data: {enriched_count}")
    print(f"  Breeds using defaults: {default_count}")
    if missing_breeds:
        print(f"  Missing breed mappings: {missing_breeds}")
    print(f"\nWritten to {json_path}")


if __name__ == "__main__":
    main()
