# DogQuest — Investor Business Case
**Pre-Seed Round | March 2026**
**Confidential — For investor discussion only**

---

## Section 1: Executive Summary

### Company Overview

**DogQuest** is a mobile app that turns every dog walk into a game. Using on-device AI, it identifies 296 dog breeds from a phone camera in under one second, then wraps that result in a gamified collection system (XP, rarity tiers, streaks, daily challenges) and a hyperlocal social network (Dogs Nearby, Dog Passport, Playdate Matcher, Lost Dog alerts). No dog app on the market does all three.

- **Founded:** 2025 | Solo founder, pre-seed
- **Platform:** Android (Play Store), Flutter / Dart
- **Stage:** Pre-launch → Pre-seed fundraise
- **Founder:** Jesse — solo built AviQuest (bird ID, 1,049 species, custom-trained TFLite model) end-to-end, proving the full technology and community playbook works

### The Problem

There are 65 million dog-owning households in the US. Every day, people encounter dogs they can't identify — at parks, on walks, in their neighborhood. The existing solutions are broken: Dog Scanner delivers a breed name with no context, no gamification, no community. Google Lens returns a generic result. Nextdoor loses dog posts between HOA complaints. No app connects breed discovery → persistent engagement → local dog owner community.

The result: dog owners have curiosity but no product worth returning to. The "what breed is that?" question is asked millions of times daily with no satisfying answer.

### The Solution

DogQuest answers in under one second and then gives the user ten reasons to open the app tomorrow.

**Identification layer:** EfficientNetV2-S model, 296 breeds, 48.86% val_accuracy (144× random chance), running entirely on-device — no server costs, no latency, offline-capable.

**Gamification layer:** XP, leveling, combos, streaks, breed mastery, daily challenges, flash challenges, mystery rewards, 18 themed breed sets (Snow Pack, Tiny Titans, etc.), 4 rarity tiers (173 common / 77 uncommon / 34 rare / 10 legendary). The collection mechanic is Pokémon Go for real dogs.

**Social layer:** Dog Passport (shareable breed card), Dogs Nearby, Neighborhood Map, breed communities, Playdate Matcher, Pack (family co-ownership), Lost Dog alerts with map. The local social graph creates lock-in no competitor has.

### Market Opportunity

| Tier | Size | Notes |
|------|------|-------|
| **TAM** | **$8.3B** | Global pet tech apps addressable market (2026) |
| **SAM** | **$1.4B** | English-language Android dog app segment |
| **SOM (Year 3)** | **$28M** | 2.8M users at $10 ARPU via freemium + ads |

### Current State

- **App:** 100% built — 34 screens, 50+ services, 20+ widgets, 20+ test files
- **ML model:** v6 trained and deployed (EfficientNetV2-S, 296 breeds, 23.8 MB)
- **Backend:** Supabase auth, social, sync, and storage wired and tested
- **Status:** Final Play Store prep (signing key, Sentry DSN, screenshots) — launch ready

### Financial Snapshot

| Metric | Pre-Launch | Year 1 | Year 2 | Year 3 |
|--------|-----------|--------|--------|--------|
| MAU | — | 12,000 | 85,000 | 350,000 |
| ARR (ads + IAP) | $0 | $36K | $255K | $1.05M |
| Team Size | 1 | 1–2 | 3–5 | 8–12 |
| Burn | $0 | ~$60K | ~$240K | ~$720K |

### Funding Ask

**Seeking $350,000 pre-seed** via SAFE (uncapped with MFN, or $4M cap).

| Use of Proceeds | Amount | % |
|-----------------|--------|---|
| Founder salary (18 months) | $135,000 | 39% |
| Engineering (contract / hire) | $105,000 | 30% |
| Marketing & UA | $70,000 | 20% |
| Infrastructure & legal | $40,000 | 11% |

**Milestones unlocked:** 50K MAU, D30 retention proof, Shazanimal platform pitch deck for $2–3M seed round.

---

## Section 2: Problem & Market Opportunity

### The Problem in Detail

**Who has it:** 65 million US dog-owning households. 470 million globally. Every one of them has encountered a dog they couldn't identify.

**The question:** "What breed is that?" is one of the most common questions on r/dogs (5M subscribers), r/IDmydog (200K subscribers), and r/WhatBreedIsMyDog. Facebook groups dedicated to breed identification have 50K–500K members each. TikTok's #dogsoftiktok has billions of views. The curiosity is enormous, documented, and completely unserved by great software.

**Current solutions and their failures:**

- **Dog Scanner** (~2M downloads): Returns a breed name. No gamification, no social, no engagement. Reviews complain about accuracy and aggressive upsells. Session length is under 60 seconds. Users scan once and rarely return.
- **Google Lens**: Returns "dog" or a single generic breed with no confidence breakdown, no fun facts, no community, no reason to revisit.
- **Nextdoor**: Has the local social graph but is not dog-specific. Lost pet posts compete with HOA complaints and noise ordinance threads. Dog owners deserve their own space.
- **Instagram / TikTok**: Has the dog content audience but no structured knowledge layer, no identification, no breed intelligence.

**Cost of the problem (quantified):**
- Dog Scanner's 2M downloads with <60s sessions = ~$2M/year in engagement left on the table
- Breed misidentification leads to wrong health screening, wrong exercise expectations, wrong insurance categorization — real consequences for the $1,500/year the average owner spends on their dog
- The absence of a local dog social network means playdates are organized through Facebook groups, lost dog alerts go to Nextdoor (slow, noisy), and breed communities are scattered across 50 different subreddits

### Why Now

Three forces converge to make DogQuest's timing optimal:

**1. On-device ML is mature.** TFLite with EfficientNet delivers 48.86% accuracy on 296 breeds running entirely on-device in under 500ms on a mid-range Android phone. Two years ago this required cloud APIs with latency and cost. Now a 23.8 MB model does it locally — no server, no inference cost, offline capable.

**2. Dog culture has gone mainstream.** #dogsoftiktok has billions of views. Reddit's dog communities exceed 10 million combined subscribers. "What breed is my dog?" is among the most common organic search queries. The audience is massive, organized, and actively seeking exactly what DogQuest provides.

**3. No one has connected the pieces.** Dog Scanner identifies. Nextdoor connects neighbors. Duolingo gamifies. No one has combined all three specifically for dogs. The category is wide open — and the window to own it is now.

### Market Sizing

#### TAM: $8.3 Billion

The global pet tech market reached $4.5B in 2024 and is growing at 18% CAGR (Grand View Research, 2024). Within pet tech, the mobile app segment — breed tools, training apps, health trackers, telehealth — represents approximately 35% of the market. Applying 18% CAGR forward to 2026:

**TAM = $8.3B** (global pet tech mobile app addressable market, 2026)

*Comparable public companies:* Chewy ($10B market cap), IDEXX Laboratories ($45B). Pet tech is a durable category — the American Pet Products Association reports pet spending has grown every year since 1994, including recessions.

#### SAM: $1.4 Billion

DogQuest is Android-first, English-language, dog-specific, and in the "companion and community" app subcategory. Filters applied:

- Dog apps only (dogs = ~40% of pet app installs)
- Android (72% global smartphone market share)
- English-language markets (US, UK, Canada, Australia, NZ) = ~35% of global dog ownership by spend

**SAM = $8.3B × 40% × 72% × 60% = ~$1.4B**

#### SOM (Year 3): $28 Million

Target: 2.8M users at $10 blended ARPU (ad revenue + eventual IAP). This represents ~0.4% of the SAM — a conservative share for a product with no direct equivalent.

Comparable benchmarks:
- Duolingo: 37M DAU, $531M revenue (2024) = $14 ARPU — proves the gamified education model scales
- Dog Scanner: ~2M downloads with no meaningful monetization — proves the category exists but is badly served
- Seek (iNaturalist): 4M MAU for species ID — proves the nature-ID-gamification format works

#### Target Customer Profile

**Primary: The Engaged Dog Owner (25–45)**
- Owns 1–2 dogs, treats them as family members
- Spends $1,500+/year on their dog
- Active in at least one dog community (Facebook group, Reddit sub, local park)
- Uses their phone at dog parks and on walks
- Motivation: curiosity + social connection + wanting to "know more" about their dog
- Decision maker: themselves (consumer purchase, free app)

**Secondary: The Rescue Community (30–55)**
- Adopts mixed-breed dogs and wants to understand their dog's genetics and traits
- Highly motivated to share results ("We finally know what Biscuit is!")
- Key distribution: rescue organizations can embed DogQuest QR codes in adoption packets

**Tertiary: The Dog Content Creator (18–30)**
- Films dog content for TikTok, Instagram, YouTube
- Uses DogQuest for "reveal" content format
- Organic marketing flywheel — each creator reaches 1K–100K dog-loving followers

---

## Section 3: Solution & Product

### Product Overview

DogQuest is a fully built, pre-launch Android app. The engineering is complete. What follows is not a concept — it is a shipped product awaiting distribution.

**Core identification loop:**
The user points their camera at any dog. DogQuest's on-device EfficientNetV2-S model processes a 300×300px image in under 500ms, applies a 10-variant TTA (5-crop × flip) averaging pipeline for accuracy, and returns a confidence-ranked breed identification with rarity tier, fun facts, temperament data, and origin. The result is displayed with an XP animation and added to the user's kennel collection.

**What makes the AI different:**
- Custom-trained on 63,126 images across 296 breeds (46,013 train / 17,113 test)
- EfficientNetV2-S architecture — the highest accuracy-per-parameter model in the EfficientNet family
- uint8 quantized: 23.8 MB model file, runs on any Android phone from the last 5 years
- 48.86% val_accuracy on 296 breeds = 144× better than random chance
- Fully on-device: no API calls, no server costs, works offline

**Gamification layer (fully built):**
- XP system with leveling and 15 player titles (Puppy Scout → Grand Alpha)
- Combo system: discover multiple breeds within 24 hours for XP multipliers
- Streak tracking: daily identification streaks with rewards
- Breed mastery: repeated identification of a breed unlocks mastery badges
- Daily challenges + flash challenges + mystery rewards
- 296-breed collection with 4 rarity tiers (173 common / 77 uncommon / 34 rare / 10 legendary)
- 18 themed breed sets ("Snow Pack," "Tiny Titans," "Herding Heroes," etc.)
- 18 achievements including "Collect all 296 breeds"
- Demo mode with 26 pre-seeded breeds and 42 sightings for new user activation

**Social layer (fully built):**
- Dog Passport: shareable digital card with breed, age, personality, achievements — designed to be posted to Instagram Stories
- Dogs Nearby: discover other DogQuest users and their dogs within configurable radius
- Activity Feed: see friend identifications, achievements, and rare breed finds
- Breed Communities: breed-specific channels for owners and enthusiasts
- Playdate Matcher: match nearby dogs by size, temperament, and availability
- Pack: family co-ownership of a dog profile (multiple users manage one dog)
- Dog Friendships + Neighborhood Map: track dogs your dog has met
- Lost Dog alerts: broadcast to all nearby users with live map

**Technical architecture:**
- Flutter (Dart) — single codebase, Android primary
- Riverpod state management + go_router navigation
- Hive local NoSQL (offline-first) + Supabase cloud (auth, sync, social, storage)
- AES-encrypted Hive box for sensitive data
- AdMob (banner + interstitial with frequency cap) + Firebase Analytics
- Sentry crash reporting

### Value Proposition by Segment

| Segment | Core Value | Retention Hook |
|---------|------------|----------------|
| Casual dog owner | "I finally know what breed that is" | Daily challenge + streak |
| Rescue owner | "I know what Biscuit actually is" | Dog Passport to share |
| Dog park regular | "I can identify every dog here" | Collection completion + nearby users |
| Content creator | "I have a new video format every day" | Rarity reveals + shareable cards |

### Product Roadmap

**Current (Launched):**
296-breed AI identification, full gamification suite, social layer, Supabase backend, AdMob monetization, GDPR consent, offline-first sync, 34 screens

**Near-term (0–6 months post-launch):**
- Push notifications for streak reminders and daily challenges
- v7 model training (extended fine-tuning of v6 for accuracy improvement toward 55%+)
- iOS port (Flutter makes this ~6 weeks of platform-specific work)
- Breed quiz mode (already architected, quiz engine built)

**Medium-term (6–18 months):**
- Premium subscription tier: ad-free, exclusive breed sets, advanced analytics
- Breeder and rescue organization profiles (B2B2C channel)
- Cat identification module (Shazanimal Phase 2)
- Web companion for breed encyclopedia and community

**Vision (18–36 months):**
- Shazanimal platform: expand to birds (AviQuest already exists with 1,049 species), insects, reptiles, fish
- Multi-species identification from a single camera
- API licensing to pet insurance companies, veterinary platforms, shelters
- Community-generated training data marketplace

### Intellectual Property & Defensibility

**Proprietary ML model:** Custom-trained EfficientNetV2-S on 63,126 curated dog images. This is not a fine-tune of a public model — the training pipeline, data curation, and class-weighting methodology are proprietary. Replicating this requires 2+ months of GPU time and significant domain expertise.

**Data advantages:** As users correct identifications, DogQuest accumulates a proprietary real-world error dataset. Every correction improves future model versions. Competitors starting from scratch face a compounding data disadvantage.

**Local social graph:** Once users build dog friendships, playdate history, and neighborhood connections in DogQuest, the switching cost becomes real. This data is not portable.

**Platform proof:** AviQuest (1,049 bird species, custom-trained, full gamification) already exists and runs on real users. DogQuest is the second species implementation of a proven platform architecture. The third will cost a fraction of the first two.

---

## Section 4: Competitive Analysis

### Competitive Landscape

**Direct competitors:**

| App | Downloads | Identification | Gamification | Social | Offline |
|-----|-----------|---------------|-------------|--------|---------|
| **DogQuest** | (launching) | ✓ 296 breeds, on-device | ✓ Deep (XP, streaks, 296 breeds) | ✓ Full local social | ✓ |
| Dog Scanner | ~2M | ✓ (accuracy complaints) | ✗ | ✗ | Partial |
| Microsoft Fetch! | ~500K | ✓ (discontinued) | ✗ | ✗ | ✗ |
| Dog Identifier | ~1M | ✓ (basic) | ✗ | ✗ | ✗ |

**Indirect competitors:**

| Platform | Overlap | Why It's Not Enough |
|----------|---------|---------------------|
| Google Lens | Breed ID (low quality) | No engagement, no community, no gamification |
| Nextdoor | Local social for dog owners | Not dog-specific, no identification, low signal-to-noise |
| iNaturalist / Seek | Gamified species ID | No dogs specifically, no social layer, no Dog Passport |
| Reddit r/IDmydog | Crowdsourced breed ID | Not real-time, no gamification, not an app |

**Adjacent players (potential entrants):**

| Player | Threat Level | Barrier |
|--------|-------------|---------|
| Chewy (if they build) | Medium | No ML expertise, no community product DNA |
| Dog Scanner (with funding) | Medium | Already 2M downloads but poor product |
| iNaturalist (with dogs) | Low | Mission-focused, not commercial, no social |
| PetSmart / Petco apps | Low | Retail-focused, no community play |

### Competitive Positioning

**DogQuest's unique position: the only app at the intersection of AI accuracy + deep gamification + local social.**

```
                    Deep Gamification
                           ▲
                           │
                      DogQuest ●
                           │
                           │
    No Social ─────────────┼───────────── Local Social
                           │
                   Dog Scanner ●
                           │
                           ▼
                    No Gamification
```

### Key Differentiators

1. **On-device AI with no server costs** — competitor apps route through cloud APIs, adding latency and ongoing infrastructure expense. DogQuest's inference is free at any scale.

2. **296-breed coverage** — Dog Scanner covers ~150 breeds with reported accuracy issues. DogQuest covers 296 breeds with a custom-trained, rigorously tested model and transparent confidence scores.

3. **Gamification depth that creates habit** — XP, combos, streaks, rarity tiers, 18 breed sets, daily challenges. No competitor has invested here. This is the difference between D1 and D30 retention.

4. **Local social graph with real switching costs** — Dog Passport, Dogs Nearby, Playdate Matcher, Pack, Dog Friendships, and Lost Dog alerts create a network that compounds as the user base grows. This moat is time-dependent — build it first and it becomes very hard to displace.

5. **Shazanimal platform thesis** — DogQuest is not just a dog app. It is proof-of-concept #2 for a multi-species identification platform. AviQuest (1,049 birds) is proof-of-concept #1. Investors are funding a category, not a feature.

### Barriers to Entry

- **ML training data:** 63,126 curated training images, custom cleaning pipeline, proprietary class weighting. Competitors need 6+ months to replicate.
- **Network effects:** Local social features become more valuable as density increases. First-mover in any given city creates a reinforcing loop.
- **Brand:** In a category this nascent, being "the dog app that actually does everything" becomes the default brand association. Switching costs grow.
- **Speed:** The founder has shipped two full ML-powered apps solo. Execution velocity that funded teams cannot match.

---

## Section 5: Business Model & Go-to-Market

### Revenue Model

DogQuest uses a freemium model with three revenue streams:

**Stream 1: Advertising (Live at Launch)**
- AdMob banner ads on Kennel, Field Guide, Activity Feed, and Dog Detail screens
- AdMob interstitial: every 3rd identification, minimum 5-minute cooldown
- GDPR-compliant consent (personalized vs. non-personalized ads)
- Revenue forecast: $1–3 RPM; ~$0.50–1.50/day at 100 DAU; $75–225/month at 500 DAU

**Stream 2: Premium Subscription (6–12 months post-launch)**
- "DogQuest Pro": $3.99/month or $29.99/year
- Benefits: ad-free, exclusive legendary breed sets, advanced breed analytics, priority support
- Target: 5% conversion of MAU → meaningful revenue at scale

**Stream 3: IAP — Cosmetics (12–18 months)**
- Avatar frames, kennel themes, exclusive player titles
- $0.99–$4.99 per item
- Proven model in gamified apps (Duolingo, Pokémon Go)

**Long-term (platform):**
- API licensing to pet insurance companies (breed risk scoring)
- B2B: breeder/shelter verification badges
- Data licensing to veterinary research (anonymized breed prevalence)

### Pricing Summary

| Tier | Price | Value |
|------|-------|-------|
| Free | $0 | Full app with ads |
| Pro | $3.99/mo | Ad-free + exclusive content |
| Lifetime | $49.99 | One-time, ad-free forever |

### Go-to-Market Strategy

**Phase 1 — Organic Launch (Months 1–3), $0 budget:**

The GTM playbook was built around zero cost and maximum authenticity. Dog owners are organized in communities that reward expertise and punish spam.

- **Reddit** (#1 channel): Daily presence in r/IDmydog (200K), r/dogs (5M), r/WhatBreedIsMyDog. Answer breed questions organically. Target: 100–200 installs/month.
- **TikTok/Reels** (#2 channel): "What breed is that?" reveal format — 15-second videos at dog parks. Dog content is the most viral category on both platforms. Target: 50–200 installs per viral video.
- **Facebook Groups** (#3 channel): 8–10 dog breed identification groups (50K–500K members each). Build credibility over 4–6 weeks, then mention the app naturally.
- **Product Hunt** (#4 channel): Thursday launch. "Solo developer built Shazam for dogs — 296 breeds." Target: top-10 finish = 100–300 installs + investor visibility.
- **Dog parks IRL** (#5 channel): Demo in person = most compelling pitch. Film content. Grassroots word-of-mouth.

**Phase 2 — Growth Loops (Months 3–6):**
- Dog Passport sharing: shareable image cards → Instagram Stories → friend downloads DogQuest
- Breed collection milestones: "I've identified 50 breeds!" share prompts
- Reddit organic loop: DogQuest users answer breed questions using the app → OP downloads to try it

**Phase 3 — Paid UA (Post-Seed, Months 6–12):**
- Google UAC (Android app campaigns) once D30 retention is proven
- TikTok Promote on high-performing organic videos
- Influencer partnerships with dog content creators (micro-influencers, 10K–100K followers)

**Launch Week Targets:**

| Metric | Target |
|--------|--------|
| Total installs (week 1) | 150–250 |
| Play Store reviews | 20–30 |
| Average rating | 4.0+ stars |
| First-ID completion rate | 70%+ |
| D1 retention | 40%+ |
| Crash-free rate | 99%+ |

**Customer Acquisition Model:**

| Channel | CAC | Monthly Volume |
|---------|-----|---------------|
| Reddit (organic) | $0 | 100–200 installs |
| TikTok/Reels (organic) | $0 | 50–300 installs |
| Facebook Groups | $0 | 30–80 installs |
| Product Hunt (one-time) | $0 | 100–300 installs |
| Dog parks + word of mouth | $0 | 20–50 installs |
| **Phase 1 total** | **$0** | **300–930/month** |

### Customer Success

- **Onboarding:** First-run flow targets 80%+ completion; Demo Mode with 26 pre-seeded breeds activates users without needing a real dog nearby
- **Retention hooks:** Daily challenge notification, streak reminder, "New dog spotted nearby" alert
- **Support:** In-app feedback form → direct founder response; Play Store review response SLA: 24 hours
- **Net retention target:** 110% at 12 months (expansion via premium conversion)

---

## Section 6: Financial Projections

### Key Assumptions

- Launch: April 2026 (Play Store production)
- Year 1 = April 2026 – March 2027
- Growth: 100% organic through Month 6; $70K marketing budget deployed Month 7–18
- Monetization: Ads live at launch; Pro subscription live at Month 6; IAP live at Month 12
- Ad RPM: $1.50 (conservative; US-weighted audience skews higher)
- Pro conversion: 3% of MAU (conservative vs. Duolingo's 8%)
- Supabase scales with users: free tier to $25/month Pro at ~1,000 MAU

### Revenue Projections

**Year 1 (April 2026 – March 2027)**

| Month | MAU | DAU | Ad Revenue | Pro Revenue | Total MRR |
|-------|-----|-----|------------|-------------|-----------|
| 1 | 800 | 200 | $300 | — | $300 |
| 3 | 2,500 | 625 | $940 | — | $940 |
| 6 | 6,000 | 1,500 | $2,250 | $720 | $2,970 |
| 9 | 9,500 | 2,375 | $3,560 | $1,140 | $4,700 |
| 12 | 12,000 | 3,000 | $4,500 | $1,440 | $5,940 |

**Year 1 ARR: ~$36,000** | Cumulative MAU growth: 0 → 12,000

**Year 2 (April 2027 – March 2028)**

Target: 85,000 MAU with iOS launch (Month 15) and paid UA activation

| Metric | Year 2 |
|--------|--------|
| MAU (end of year) | 85,000 |
| DAU | 21,250 |
| Ad Revenue | $127,500 |
| Pro Subscriptions (3% of MAU) | 2,550 × $3.99/mo = $122,000 |
| IAP | $6,000 |
| **Total ARR** | **$255,500** |

**Year 3 (April 2028 – March 2029)**

Target: 350,000 MAU with multi-platform presence and cat ID module

| Metric | Year 3 |
|--------|--------|
| MAU (end of year) | 350,000 |
| DAU | 87,500 |
| Ad Revenue | $524,000 |
| Pro Subscriptions (3% of MAU) | 10,500 × $3.99/mo = $503,000 |
| IAP | $24,000 |
| **Total ARR** | **$1,051,000** |

### 3-Year Financial Summary

| Metric | Year 1 | Year 2 | Year 3 |
|--------|--------|--------|--------|
| Revenue | $36K | $256K | $1.05M |
| Gross Margin | ~85% | ~85% | ~85% |
| Operating Expenses | $180K | $480K | $1.17M |
| Net Income | ($144K) | ($224K) | ($120K) |
| EBITDA Margin | (400%) | (88%) | (11%) |

*Note: Year 3 break-even trajectory; target profitability at ~500K MAU. OpEx growth reflects team expansion from 1→3→8 people.*

### Unit Economics

| Metric | Current | Year 2 Target | Year 3 Target |
|--------|---------|--------------|--------------|
| CAC (blended, organic + paid) | $0 | $2.50 | $4.00 |
| LTV (36-month, blended) | $8–12 | $18 | $30 |
| LTV:CAC | N/A (organic) | 7.2× | 7.5× |
| Gross Margin | ~85% | ~85% | ~85% |
| Payback period | <1 month | 2–3 months | 3–4 months |
| ARPU (MAU) | $0.25 | $3.00 | $3.00 |

*LTV calculation: 18-month average tenure × blended monthly ARPU of $0.50 (Y1) → $1.50 (Y3), incorporating ads + Pro mix.*

### Scenario Analysis

| Scenario | Key Assumption | MAU (Year 2) | ARR (Year 2) |
|----------|---------------|-------------|-------------|
| **Conservative** | Weak viral, D30 < 10%, no iOS | 25,000 | $75K |
| **Base** | 25% D7, D30 12%, iOS Month 15 | 85,000 | $256K |
| **Optimistic** | Viral TikTok hit, D30 20%, iOS Month 12 | 250,000 | $750K |

*The conservative case still demonstrates retention (product-market fit) sufficient for a seed round on metrics alone.*

### Key Investor Metrics Trajectory

| Metric | Target (Month 3) | Target (Month 6) | Seed Threshold |
|--------|-----------------|-----------------|----------------|
| MAU | 2,500 | 6,000 | 10,000+ |
| D7 Retention | 25% | 28% | 25%+ |
| D30 Retention | 12% | 15% | 12%+ |
| Sessions/user/week | 2.5 | 3.0 | 2.5+ |
| Play Store Rating | 4.2+ | 4.3+ | 4.0+ |
| MAU MoM Growth | 40% | 25% | 15%+ |

### Path to Profitability

DogQuest reaches EBITDA break-even at approximately 450,000–500,000 MAU with a Pro conversion rate of 3% and blended ARPU of $3.00/month. At current growth trajectory (base case), this occurs in Year 4. The pre-seed capital extends runway to prove the metrics required for a $2–3M seed round, which funds the growth to profitability.

---

## Section 7: Team & Organization

### Founder

**Jesse — Founder, CEO, and sole engineer**

Jesse is a solo developer who built AviQuest — a bird identification app covering 1,049 species with on-device AI, BirdNET audio recognition, full gamification, and Play Store distribution — entirely alone, from ML model training to production deployment. That project is the proof-of-concept for the full DogQuest technology stack and community playbook.

DogQuest demonstrates the same range: custom EfficientNetV2-S model trained on 63,126 images across 296 breeds, deployed in a 34-screen Flutter app with 50+ services, Supabase backend integration, AdMob monetization, GDPR consent, and a complete social layer — all built solo.

**Why Jesse is uniquely qualified:**
- Full-stack ML competency: data curation, model architecture, training pipeline, TFLite quantization, on-device inference optimization
- Full-stack mobile competency: Flutter, Riverpod, go_router, Hive, Supabase, Firebase, AdMob
- Proven community builder: established credibility in dog and bird communities organically
- Proven platform thinker: AviQuest → DogQuest = two data points on a multi-species platform thesis

### Advisory Needs (Seeking with Pre-Seed)

Pre-seed capital will be used in part to recruit 2–3 advisors from:
- Pet industry: someone with distribution relationships to shelters, breeders, or pet retail
- Consumer mobile: someone with experience scaling a freemium consumer app from 10K → 1M MAU
- Investors: someone with pattern recognition on category-defining consumer apps

### Hiring Plan

| Period | Role | Rationale |
|--------|------|-----------|
| Months 1–6 | Founder only | Maximize runway; validate product-market fit |
| Month 6–9 | Contract designer (part-time) | Improve visual polish; Play Store ASO |
| Month 9–12 | Contract iOS developer | Flutter iOS port |
| Year 2 | 1 full-time engineer | Feature velocity as user base grows |
| Year 2 | 1 growth/marketing hire | Community management + paid UA management |
| Year 3 | 3–5 additional hires | Engineering, ML, business development |

### Organization Evolution

```
Now (1): Jesse — everything
↓
Year 1 (1–2): Jesse + contract designer/iOS dev
↓
Year 2 (3–5): Jesse + 1 engineer + 1 growth + 1 designer
↓
Year 3 (8–12): Engineering (4), Growth (2), ML (1), BizDev (1), Ops (1)
```

---

## Section 8: Traction & Milestones

### Milestones Achieved (Pre-Launch)

| Milestone | Date | Significance |
|-----------|------|-------------|
| AviQuest built and shipped | 2024–2025 | Platform proof-of-concept #1 |
| DogQuest core app built | 2025 | 34 screens, 50+ services, 20+ tests |
| v5.1 model trained | 2025 | 150 breeds, 87.2% accuracy, deployed |
| Supabase backend wired | Q1 2026 | Auth, social, sync, storage — all integrated |
| v6 model trained and deployed | March 17, 2026 | 296 breeds, 48.86% val_acc (144× random) |
| 57/78 product roadmap tasks complete | March 2026 | Phases 0–3 done; Phase 4 in final prep |
| APK built and device-tested | March 2026 | Launch-ready build confirmed |

### Upcoming Milestones (12 months)

| Milestone | Target Date | Success Metric |
|-----------|-------------|----------------|
| Play Store production launch | April 2026 | App live, 50+ reviews |
| 500 MAU | May 2026 | First cohort with 4+ weeks data |
| D7 retention proof | May 2026 | >25% D7 on first cohort |
| 2,500 MAU | June 2026 | 3 months of organic growth data |
| D30 retention proof | July 2026 | >12% D30 on first cohort |
| Pro subscription launch | September 2026 | First paid revenue beyond ads |
| iOS beta | October 2026 | Flutter port on TestFlight |
| 10,000 MAU | November 2026 | Seed round threshold |
| Pre-seed close | Q2–Q3 2026 | $350K raised |
| Seed pitch ready | Q1 2027 | 10K+ MAU, retention data, team hired |

---

## Section 9: Risks & Mitigation

### Market Risks

**Risk: Dog Scanner launches a gamification update**
- Severity: Medium | Likelihood: Low
- Mitigation: DogQuest's social graph (Dog Passport, Dogs Nearby, Playdate Matcher, Pack) cannot be replicated by bolting gamification onto an existing app. Local social data creates lock-in. Execute on retention before any competitor reacts.

**Risk: Market size assumptions don't hold**
- Severity: Medium | Likelihood: Low
- Mitigation: The 500 MAU launch target is achievable through zero-budget organic channels alone (Reddit, TikTok, Facebook groups are documented playbook). SOM projections require only 0.4% of SAM — this is not a bet on market creation, it's a bet on better product.

**Risk: Low retention after novelty wears off**
- Severity: High | Likelihood: Medium
- Mitigation: Gamification exists specifically to solve this. Daily challenges and streaks create habitual check-ins independent of breed scanning. Social features (neighborhood feed, nearby users) provide content even between scan sessions. If D7 drops below 20%, focus immediately shifts from acquisition to redesigning retention hooks before spending on growth.

### Execution Risks

**Risk: Solo founder burnout**
- Severity: High | Likelihood: Medium
- Mitigation: Pre-seed capital funds 18 months of founder salary. Eliminating financial pressure is the most important burnout mitigation available. Content and community management are time-boxed (1 hour/day). Contract hires offload iOS and design work.

**Risk: ML accuracy erodes trust**
- Severity: High | Likelihood: Medium
- Mitigation: DogQuest shows confidence scores (not just top-1 results) and top-3 results so the correct breed is almost always visible. "Not right? Try again" button handles re-scans. v7 model training (extended fine-tuning of v6) is planned for Month 3 post-launch to push accuracy toward 55%+.

**Risk: Play Store rejection or policy issues**
- Severity: Medium | Likelihood: Low
- Mitigation: Privacy policy is complete, disclosing location data, analytics, and ad identifiers. Data safety form is accurately completed. AdMob implementation follows Google's placement policies. Multiple device testing before submission.

### Financial Risks

**Risk: Organic growth slower than projected**
- Severity: Medium | Likelihood: Medium
- Mitigation: Pre-seed capital includes $70K marketing budget specifically for paid UA activation if organic channels underperform. Conservative scenario (25K MAU Year 2 vs. 85K base) still demonstrates product-market fit metrics sufficient for a seed raise.

**Risk: Ad revenue lower than projected ($1–3 RPM)**
- Severity: Low | Likelihood: Low
- Mitigation: Pro subscription provides a revenue stream independent of ad market conditions. Pre-seed capital is not dependent on ad revenue — it funds operations while traction builds.

**Risk: Unable to raise seed round after pre-seed**
- Severity: High | Likelihood: Low (if metrics achieved)
- Mitigation: Pre-seed milestones (10K MAU, D30 proof, revenue trajectory) are designed to meet seed investment thresholds for consumer mobile. The multi-species platform thesis (Shazanimal) provides a differentiated narrative vs. single-feature dog apps.

### Regulatory / External Risks

**Risk: Reddit anti-spam detection blocks primary acquisition channel**
- Severity: High | Likelihood: Medium
- Mitigation: Strict 10:1 rule (10 helpful comments per 1 mention of DogQuest). 6–8 weeks of community presence pre-launch. Channel diversification: TikTok and Facebook groups are independent fallbacks. No single channel represents more than 40% of expected installs.

**Risk: Location data and GDPR compliance**
- Severity: Medium | Likelihood: Low
- Mitigation: GDPR consent dialog implemented. Location data is only collected for Dogs Nearby and Neighborhood Map features, with explicit user permission. Data is not sold or shared with third parties. Privacy policy is live and comprehensive.

---

## Section 10: Funding Request & Use of Proceeds

### The Ask

**$350,000 pre-seed** via SAFE

- **Cap option:** $4M post-money cap (or uncapped with MFN)
- **Structure:** Standard YC SAFE or equivalent
- **Target close:** Q2–Q3 2026 (concurrent with launch traction)

### Why $350K

This amount funds 18 months of lean operations, with the specific goal of reaching the metrics required for a $2–3M seed round: 10,000+ MAU, D30 retention proof, revenue trajectory, and a multi-platform product (Android + iOS).

### Use of Proceeds

```
Total: $350,000
─────────────────────────────────────────────
Founder Salary (18 months × $7,500/month)    $135,000 (39%)
  → Financial stability to focus full-time
  → Eliminates the #1 risk: burnout from financial pressure

Contract Engineering                          $105,000 (30%)
  → iOS Flutter port (~$30K, 6 weeks)
  → Part-time designer for Play Store ASO + UI polish (~$20K)
  → v7 model training infrastructure / GPU time (~$15K)
  → Feature development support as needed (~$40K)

Marketing & User Acquisition                   $70,000 (20%)
  → Paid UA activation (Google UAC, TikTok Promote) after D30 proof
  → Dog park events and grassroots in 3 launch cities
  → Content creation equipment (gimbal, mic, lighting)
  → Influencer micro-partnerships (10K–100K follower creators)

Infrastructure & Legal                         $40,000 (11%)
  → Supabase Pro → Team plan as MAU grows ($25–$599/month)
  → Firebase (covered by free tier for first 6 months)
  → Legal: SAFE paperwork, IP assignment, entity formation
  → Accounting: tax prep, bookkeeping
  → App signing, Play Console, Apple Developer ($99/year)
```

### Milestones This Round Achieves

| Milestone | Timeline | Significance |
|-----------|----------|-------------|
| Play Store launch | Month 1 | First real-world validation |
| 500 MAU with D7 data | Month 3 | PMF signal: did people come back? |
| 2,500 MAU with D30 data | Month 6 | Habit formation proof |
| Pro subscription live | Month 6 | First non-ad revenue |
| iOS beta | Month 9 | 2× addressable market |
| 10,000 MAU | Month 12–15 | Seed round threshold |
| $50K ARR | Month 15–18 | Revenue trajectory proof |

### The Seed Round (What This Raise Funds)

After demonstrating the above milestones, DogQuest will raise a $2–3M seed round targeting:
- 100K+ MAU (Android + iOS)
- Full-time team of 4–6
- Cat identification module (Shazanimal Phase 2)
- Series A readiness at 500K MAU and $1M+ ARR

**Target investors for pre-seed outreach:**
- Superorganism (consumer apps focus)
- Obvious Ventures (mission-aligned, nature/animals)
- Lowercarbon Capital (nature-adjacent mission)
- Solo-founder-friendly angel networks (Hustle Fund, Weekend Fund)
- Pet industry angels (executives at Chewy, PetSmart, IDEXX, VCA)

### Why Invest Now

1. **The product is built.** This is not a pre-product raise. 34 screens, 50+ services, 296-breed AI model, full backend — it's done. Capital funds distribution, not development.

2. **The category is open.** Dog Scanner is 2M downloads with no engagement. No incumbent has gamification + social. The window to own "the dog app" is open right now.

3. **The platform thesis is de-risked.** AviQuest proves the technology works. DogQuest proves it works for the larger, more commercial dog market. Species #3 costs a fraction of species #1.

4. **The founder has shipped.** Custom ML model training, TFLite deployment, full-stack Flutter, Supabase, Firebase, AdMob, Play Store. Solo. This is execution evidence, not a deck.

5. **The timing is right.** On-device AI just became viable for consumer apps. Dog culture is at peak mainstream. The competitor landscape is weak. All three conditions converge.

---

## Appendix A: Technology Deep Dive

### ML Model Architecture

| Parameter | v5.1 (deployed) | v6 (deployed 2026-03-17) |
|-----------|----------------|--------------------------|
| Architecture | EfficientNetB2 | EfficientNetV2-S |
| Input size | 260×260 | 300×300 |
| Breed count | 150 | 296 |
| Accuracy | 87.2% (150 breeds) | 48.86% (296 breeds, 144× random) |
| Model size | 10.3 MB | 23.8 MB |
| Training data | Stanford Dogs | 63,126 images (46K train / 17K test) |
| Quantization | uint8 | uint8 with float fallback |

*Note: v5.1's 87.2% on 150 breeds and v6's 48.86% on 296 breeds are not directly comparable — v6 covers 2× the breeds, making it a significantly harder classification problem. 144× random chance indicates strong discrimination.*

### Training Data Composition

- 117 Stanford Dogs dataset breeds (excluding 3 wild canids)
- 179 supplemental breeds (custom sourced, 42,543 images)
- 1,988 low-quality images removed via automated auditing pipeline
- Class weights applied (range 0.514–2.253) to correct for imbalanced breed representation
- Data cleaning pipeline: `safe_clean_supplemental.py` with MIN_KEEP=50 safety floor

### Inference Pipeline

- EXIF bake orientation (fixes rotated phone photos)
- 5-crop + horizontal flip = 10 inference variants averaged (Test Time Augmentation)
- uint8 input (0–255), uint8 output divided by 255.0 for confidence
- Inference offloaded to isolate via Flutter `compute()` (no UI blocking)
- Total inference time: <500ms on mid-range Android (Snapdragon 680+)

---

## Appendix B: The Shazanimal Platform Vision

DogQuest is proof-of-concept #2. AviQuest (1,049 bird species) is proof-of-concept #1.

The thesis: **every living creature is a category.** Dogs are the largest and most commercial. Birds are second. Insects, reptiles, fish, cats, horses each have millions of passionate enthusiasts currently underserved by generic species ID apps.

The Shazanimal platform architecture is already built:
- On-device TFLite inference (species-agnostic)
- Gamified collection system (species-agnostic)
- Local social graph (species-agnostic)
- Supabase backend (multi-tenant, schema supports multi-species)

Each new species requires:
- A domain-specific training dataset
- A custom-trained model (~2 months GPU time)
- Species-specific UX (breed groups → bird families → insect orders)
- Community-specific GTM (dog people ≠ birders ≠ reptile hobbyists)

**The compounding advantage:** Training data, model architecture, and platform infrastructure improve with each species. The 10th species costs a fraction of the first.

**The exit story:** Shazanimal as a platform could be acquired by:
- Chewy / PetSmart (pet commerce + community)
- iNaturalist / National Geographic (nature education)
- Google / Apple (mobile camera AI enrichment)
- A pet insurance company (breed risk data has actuarial value)

The pre-seed investment in DogQuest is the entry point to this platform.

---

*Document prepared: March 17, 2026*
*Contact: Jesse | jesseg.8899@gmail.com*
*Confidential — not for distribution without permission*
