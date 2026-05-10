# AviQuest — Pre-Seed Business Case

**Prepared:** March 17, 2026
**Stage:** Pre-Seed | **Ask:** $250K–$500K (SAFE)
**Status:** Working MVP, pre-launch

---

## 1. Executive Summary

**AviQuest** is a mobile bird identification app that combines on-device machine learning with Pokemon Go-style gamification to turn casual walks into wildlife adventures. Users point their phone at a bird, get an instant identification, earn XP, unlock achievements, and build a personal collection across 1,049 species — all without an internet connection.

**The problem:** Birding apps identify birds, then give users no reason to come back. The species identification market has 199 million cumulative downloads across fragmented single-kingdom apps, yet Day-30 retention across the category sits below 10%. Demand is proven; engagement is broken.

**The solution:** AviQuest wraps bird identification in a full progression system — leveling, daily streaks, combo multipliers, rarity tiers, mystery rewards, and 50+ achievements — creating a habit loop that turns one-time identifiers into daily active users. On-device ML means zero inference cost and full offline functionality.

**What exists today:** A fully functional Flutter app (Android) with 393 bird species in the database, 1,049 species visual identification via TFLite, 6,522 species audio identification via BirdNET, a FastAPI backend with JWT auth and sync, and a 27-test automated suite. The app has been field-tested on hardware and runs entirely offline.

**Market opportunity:**

| Scope | Size |
|-------|------|
| TAM (species ID apps + nature engagement) | $1.5–2.0B |
| SAM (English-speaking smartphone nature users) | $400–600M |
| SOM (3-year achievable) | $15–25M |

**The ask:** $250K–$500K pre-seed via SAFE notes to fund Play Store launch, growth marketing, model expansion, and the first enterprise data customer.

---

## 2. Problem and Market Opportunity

### The Problem

8.7 million species exist on Earth. The average person can name fewer than 50. A growing number of people want to engage with nature — hiking participation in the US grew 8.7% in 2024 — but identification tools are fragmented and forgettable.

The current landscape has three structural failures. First, fragmentation: identifying a bird, a plant, and an insect on a single hike requires three different apps. Second, retention: existing apps are digital field guides with no engagement loop, resulting in sub-10% Day-30 retention. Third, monetization gap: Merlin Bird ID has 30 million downloads but generates zero revenue, while PictureThis (plants only) generates over $36 million per year — proving the revenue model works for whoever cracks engagement.

### Why Now

Three trends are converging. Citizen science demand is surging as biodiversity regulation tightens globally (EU Nature Restoration Law 2024, US Migratory Bird Treaty Act enforcement expansion). On-device ML models have matured to the point where real-time species identification runs on a $200 phone with no cloud dependency. And the success of Pokemon Go ($1B in its first 10 months) proved that gamified real-world collection mechanics drive massive engagement and spending on mobile.

### Market Sizing

**TAM: $1.5–2.0B.** Total addressable market across species identification apps, adjacent nature/outdoor engagement apps, and biodiversity data services. Derived from 199M cumulative downloads across category apps, comparable freemium conversion rates, and B2B data licensing potential.

**SAM: $400–600M.** Smartphone users in English-speaking markets (US, UK, Canada, Australia) who actively engage with nature, outdoor recreation, or educational apps. Filtered by smartphone penetration, outdoor participation rates, and app category engagement benchmarks.

**SOM: $15–25M (3 years).** Based on achieving 500K downloads, 5% premium conversion at $59.99/year, plus initial B2B data licensing revenue. Validated against PictureThis's trajectory (single kingdom, no gamification, $36M+/year) and Merlin's 30M downloads (no monetization attempt).

### Target Users

The primary audience is nature-curious smartphone users aged 25–55 who hike, walk in parks, or travel outdoors regularly but are not expert birders. Secondary audiences include parents looking for educational outdoor activities with children, students in ecology or biology programs, and retirees who bird as a hobby. The B2B segment targets environmental consulting firms, energy developers conducting avian impact assessments, and government wildlife agencies.

---

## 3. Solution and Product

### What AviQuest Does

AviQuest is a mobile bird identification and collection game built in Flutter. The core loop is: spot a bird, photograph or record it, receive an instant ML-powered identification, earn XP, and add the species to your personal collection. Every interaction feeds into a progression system designed to bring users back daily.

### Key Capabilities

**Identification engine.** Dual-mode identification via camera (TFLite on-device visual model, 1,049 species) and microphone (BirdNET audio model, 6,522 species). Works fully offline — no cloud inference, no API costs, no connectivity requirements. Current visual model accuracy exceeds 87% on the 150-breed core set.

**Gamification stack.** XP and leveling system with 20+ levels and 8 rank titles (Fledgling through Master Birder). Daily streaks, combo multipliers for sequential discoveries within 24 hours, mystery rewards, flash challenges, and 50+ achievements. Four rarity tiers — Common (60%), Uncommon (25%), Rare (12%), Legendary (3%) — create collection scarcity that drives ongoing engagement.

**Collection and encyclopedia.** Personal aviary tracks every species collected. Full species cards with scientific data, habitat information, conservation status, images, and bird calls via Xeno-Canto. Browse and search the complete 393-species database with filtering by rarity, family, and region.

**Backend and sync.** FastAPI backend with JWT authentication, collection sync, and leaderboard. Hive local persistence ensures full offline functionality with seamless cloud sync when connected.

### Technology Advantages

On-device ML is the structural cost advantage. Every identification is free to serve — no GPU clusters, no API metering, no per-inference marginal cost. This means the free tier costs almost nothing to operate, allowing aggressive freemium conversion funnels that cloud-inference competitors cannot match.

The Flutter codebase enables cross-platform (iOS + Android) from a single codebase, roughly 2x faster delivery than maintaining separate native apps. The modular architecture (Riverpod state management, go_router navigation, 60+ services) supports rapid feature iteration.

### Product Roadmap

**Now (launch):** 393 bird species, visual + audio identification, full gamification, Android.

**6 months:** iOS launch. GPS-tagged sightings. Social features (leaderboards, friend challenges). Push notifications for streaks and challenges. Expanded species database to 500+.

**12 months:** Explore multi-kingdom expansion (plants as second vertical). B2B data API for enterprise customers. Regional challenges and community events.

**18–24 months:** Additional kingdoms (insects, amphibians). White-label partnerships with national parks. Expanded B2B data licensing.

### Defensibility

The moat compounds over time across three dimensions. First, the species observation dataset grows with every user interaction — GPS-tagged, timestamped, confidence-scored biodiversity data that becomes more valuable as coverage density increases. Second, the gamification layer creates switching costs through invested progression (leveling, collections, streaks). Third, network effects emerge as social features launch — competing with friends on leaderboards and participating in community challenges create retention that single-player apps cannot match.

---

## 4. Competitive Analysis

### Landscape

| App | Kingdom | Gamification | Monetization | Downloads | Revenue |
|-----|---------|-------------|-------------|-----------|---------|
| **AviQuest** | Birds (expanding) | Full stack | Freemium + B2B data | Pre-launch | Pre-revenue |
| Merlin Bird ID | Birds | None | Free (Cornell funded) | 30M+ | $0 |
| PictureThis | Plants | Minimal | Subscription | 100M+ | $36M+/yr |
| iNaturalist | Multi-kingdom | Minimal | Free (nonprofit) | 10M+ | Grants |
| Seek by iNaturalist | Multi-kingdom | Basic (badges) | Free | 10M+ | $0 |
| Picture Insect | Insects | None | Subscription | 30M+ | ~$10M/yr |

### Differentiation

AviQuest occupies a white space that no current app fills: the intersection of accurate species identification and deep gamification. Merlin is the gold standard for bird ID accuracy but has zero engagement mechanics — identify and close. PictureThis proved the subscription model works but has minimal retention features beyond the utility. iNaturalist serves citizen scientists but not casual users. None offer the XP/leveling/streak/achievement/rarity system that AviQuest has already built and shipped.

### Competitive Positioning

AviQuest competes on engagement, not identification accuracy alone. The positioning is: "the only species ID app that makes you want to open it every day." This sidesteps direct accuracy comparisons with Merlin (backed by Cornell Lab of Ornithology's dataset) and instead competes on the dimension where no competitor has invested — retention through game mechanics.

### Barriers to Entry

Cornell/Merlin could theoretically add gamification, but institutional incentives (scientific credibility, nonprofit mission) make game mechanics culturally misaligned. PictureThis could expand to birds, but their ML pipeline is optimized for static plant photography, not the dynamic conditions of bird identification. The most likely competitive response is from a well-funded startup — which validates the market and increases acquisition interest.

---

## 5. Business Model and Go-to-Market

### Revenue Model

**B2C subscriptions (primary).** Free tier with 5 identifications per day, basic gamification. Premium at $9.99/month or $59.99/year unlocks unlimited IDs, advanced species data, rare species alerts, premium achievements, and offline model packs. On-device ML means free-tier users cost nearly nothing to serve, enabling a wide funnel.

**B2B data licensing.** GPS-tagged, timestamped species observation data sold to environmental consulting firms, wind/solar energy developers, and government wildlife agencies. Environmental Impact Assessments for avian collision risk cost $150K–$400K per project; AviQuest data substitution is worth $5K–$25K per geographic query. Target: one anchor enterprise customer in Year 1.

**Unit economics advantage.** Zero marginal cost per identification (on-device ML). Server costs are limited to sync, auth, and leaderboard — lightweight operations that scale cheaply. This enables 85%+ gross margins at scale, compared to 50–60% for cloud-inference competitors.

### Go-to-Market Strategy

**Phase 1 — Organic launch (Months 1–3).** Google Play Store launch with ASO optimization. Seed content on birding subreddits, Facebook birding groups, and nature communities. Target birding influencers on YouTube and Instagram for early reviews. Goal: 10K downloads, baseline retention metrics.

**Phase 2 — Paid acquisition (Months 4–9).** Facebook/Instagram ads targeting outdoor enthusiasts, hikers, and nature photography communities. Google UAC campaigns. Budget: $3–5 CPI target. Begin iOS launch to double addressable market. Goal: 50K downloads, Day-30 retention above 15%.

**Phase 3 — Partnerships and B2B (Months 9–18).** National parks and nature reserves partnerships for co-branded experiences. First B2B data customer (environmental consulting or wind energy). Content marketing around citizen science and conservation. Goal: 200K downloads, first B2B revenue.

### Customer Acquisition Cost

Pre-seed target CAC of $2–4 per install via organic channels and targeted paid social. Premium conversion target of 3–5% of active users. Effective subscriber CAC of $40–80, against LTV of $120–180 (24–36 month average subscription life at blended ARPU).

---

## 6. Financial Projections

### 3-Year Revenue Model

| Metric | Year 1 | Year 2 | Year 3 |
|--------|--------|--------|--------|
| Downloads (cumulative) | 50,000 | 300,000 | 1,000,000 |
| MAU | 12,000 | 60,000 | 200,000 |
| Premium subscribers | 400 | 4,500 | 18,000 |
| B2C subscription revenue | $24K | $270K | $1.1M |
| B2B data revenue | $0 | $50K | $300K |
| **Total revenue** | **$24K** | **$320K** | **$1.4M** |

### Cost Structure

| Category | Year 1 | Year 2 | Year 3 |
|----------|--------|--------|--------|
| Engineering (founder + contract) | $120K | $280K | $500K |
| Marketing and UA | $60K | $200K | $400K |
| Infrastructure (servers, ML compute) | $15K | $40K | $80K |
| Operations (legal, admin, tools) | $25K | $60K | $120K |
| **Total expenses** | **$220K** | **$580K** | **$1.1M** |
| **Net income** | **($196K)** | **($260K)** | **$300K** |

### Unit Economics (Year 3 targets)

| Metric | Value |
|--------|-------|
| CAC (paid installs) | $3.50 per install |
| Organic share of installs | ~80% (ASO, virality, PR) |
| Blended CAC (all installs) | $0.70 per install |
| Premium conversion | 1.8% of cumulative downloads |
| Effective subscriber CAC | $39 |
| LTV (avg 28-month life × $5/mo blended ARPU) | $140 |
| LTV:CAC | 3.6x |
| Gross margin | 85%+ |
| CAC payback | 8 months |

*Note: Marketing budgets ($660K cumulative Years 1–3) fund ~190K paid installs at $3.50 CPI. Remaining ~810K of 1M cumulative downloads are organic (ASO, word-of-mouth, content marketing, PR). Organic-heavy acquisition is typical for pre-seed consumer apps and validated by Merlin's 30M unpaid downloads. Premium conversion of 1.8% is conservative against PictureThis's 4–6%; gamification mechanics are expected to push this toward 3%+ as the product matures.*

### Scenario Analysis

**Conservative:** 500K cumulative downloads by Year 3, 1.5% conversion (7,500 subscribers × $60 avg = $450K B2C + $50K B2B = $500K revenue). Breakeven delayed to Year 4. Requires follow-on funding.

**Base case (above):** 1M downloads, 1.8% conversion, $1.4M revenue (including $300K B2B). Path to profitability in Year 3.

**Optimistic:** iOS launch accelerates growth to 2M downloads with 3% conversion (60K subscribers). B2B data revenue reaches $500K via 3+ enterprise contracts. Year 3 revenue exceeds $4M. Positioned for Series A.

---

## 7. Team

### Founder

**Solo technical founder** with full-stack capability across the entire product: Flutter mobile development, Python ML pipeline (TensorFlow, TFLite quantization, custom training scripts), FastAPI backend, and product design. Built the complete AviQuest application including the ML identification system, gamification engine, backend with auth/sync, and 27-test automated suite — as a single developer.

This signals two things to investors: extreme capital efficiency (the entire product was built with zero funding), and technical depth across mobile, ML, and backend that would typically require a 3-person team.

### Hiring Plan

| Role | Timing | Purpose |
|------|--------|---------|
| ML Engineer (contract) | Month 1–3 | Model accuracy improvement, multi-kingdom expansion |
| Growth Marketer (part-time) | Month 3 | ASO, paid acquisition, content strategy |
| Mobile Developer | Month 6–9 | iOS launch, feature velocity |
| Data Engineer | Month 12+ | B2B data API, pipeline automation |

### Advisory Needs

Seeking advisors in: consumer app growth (ideally with freemium mobile game experience), biodiversity/conservation domain (credibility for B2B data sales), and fundraising (seed-stage VC introductions).

---

## 8. Traction and Milestones

### Achieved

- Working Flutter app with 393 species database and full gamification stack
- On-device TFLite visual identification (1,049 species, 87%+ accuracy on core set)
- BirdNET audio identification integration (6,522 species)
- FastAPI backend with JWT auth, collection sync, and leaderboard
- 27 automated tests (unit, widget, integration)
- Field-tested on Android hardware
- Full investor materials prepared (one-pager, pitch deck outline, financial model, B2B analysis, go-to-market strategy)
- Multi-agent orchestration system for development velocity

### 12-Month Milestones

| Milestone | Target | Timeline |
|-----------|--------|----------|
| Google Play Store launch | Live | Month 1 |
| 10,000 downloads | Organic + initial paid | Month 3 |
| Day-30 retention > 15% | Gamification-driven | Month 4 |
| iOS launch | Cross-platform | Month 6 |
| 50,000 cumulative downloads | Paid + organic + PR | Month 9 |
| First B2B data customer | Environmental consulting | Month 12 |
| Premium subscriber base | 400+ paying users | Month 12 |

---

## 9. Risks and Mitigation

### Market Risks

**Risk:** Merlin or another incumbent adds gamification features.
**Mitigation:** Institutional culture at Cornell makes deep gamification unlikely. AviQuest's 6+ month head start in building progression mechanics creates a meaningful moat. If a competitor does respond, it validates the thesis and increases acquisition interest.

**Risk:** Species ID market does not support premium conversion above 3%.
**Mitigation:** PictureThis demonstrates 4–6% conversion in an adjacent category. AviQuest's gamification layer (streaks, achievements, collection scarcity) creates additional premium triggers that utility-only apps lack.

### Execution Risks

**Risk:** Solo founder bandwidth limits development velocity.
**Mitigation:** The Flutter/Dart codebase is already modular (60+ services, clear separation of concerns), making it straightforward to onboard additional developers. First hire (ML engineer) is scoped and budgeted. The existing multi-agent orchestration system accelerates development planning.

**Risk:** ML model accuracy insufficient for user satisfaction.
**Mitigation:** Current visual model exceeds 87% on the core species set, with a trained v6 model covering 296 breeds in the sister app (DogQuest) demonstrating the training pipeline's maturity. Audio identification via BirdNET provides a high-accuracy fallback for visual misses.

### Financial Risks

**Risk:** Pre-seed runway insufficient to reach Series A metrics.
**Mitigation:** On-device ML architecture means near-zero marginal costs. A $350K raise provides 18+ months of runway at projected burn. Conservative case reaches 500K downloads and $500K revenue, sufficient for seed fundraising even if Series A metrics are not fully met.

**Risk:** B2B data revenue takes longer than projected.
**Mitigation:** B2B is modeled as supplementary, not primary revenue. The B2C subscription model is viable standalone. B2B data licensing is upside that strengthens the overall business case but is not required for survival.

---

## 10. Funding Request

### The Ask

**$250K–$500K** via SAFE notes (post-money SAFE, standard YC terms).

### Use of Proceeds

| Category | Allocation | Amount ($350K base) | Purpose |
|----------|-----------|-------------------|---------|
| Engineering | 40% | $140K | ML engineer (contract), founder salary, iOS development |
| Marketing & Growth | 25% | $87.5K | Play Store launch, ASO, paid acquisition, influencer partnerships |
| ML & Compute | 20% | $70K | Model training (multi-kingdom), GPU compute, data acquisition |
| Operations | 15% | $52.5K | Legal (Delaware C-Corp, IP), infrastructure, tools, compliance |

### Milestones This Capital Achieves

With $350K and 18 months of runway, AviQuest targets:

- **50,000+ downloads** across Android and iOS
- **Day-30 retention > 15%** (gamification-driven, well above category average)
- **400+ premium subscribers** generating $24K+ ARR
- **First B2B data customer** validating the enterprise revenue channel
- **iOS launch** doubling the addressable market
- **Species database expansion** to 500+ with improved ML accuracy

### Path to Next Round

Series Seed ($1.5–3M) targeted at 18–24 months, based on achieving 200K+ downloads, 15%+ Day-30 retention, $300K+ ARR run rate, and at least one B2B data contract. These metrics position AviQuest competitively for consumer app seed rounds, with the B2B data angle providing a differentiated narrative versus pure consumer plays.

---

## Appendix A: Comparable Transactions

| Company | Category | Round | Amount | Key Metric at Round |
|---------|----------|-------|--------|-------------------|
| PictureThis | Plant ID | Series B | $20M | $36M+ ARR |
| Seek (iNaturalist) | Multi-kingdom | Grant funded | N/A | 10M+ downloads |
| Merlin | Bird ID | Cornell funded | N/A | 30M+ downloads |
| Pokemon Go (Niantic) | Gamified real-world | Series A | $30M | Pre-launch hype |

The species identification category has demonstrated both massive user acquisition potential and subscription revenue viability. AviQuest is the first entrant combining both proven mechanics (accurate ML identification + deep gamification) in a category with 199M cumulative downloads and no dominant retention-focused player.

---

*Prepared for angel investor review. Contact: Jesse (jesseg.8899@gmail.com)*
