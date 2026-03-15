# Product Vision — DogQuest

---

## 1. Vision & Mission

### Vision Statement

Every dog owner understands, celebrates, and connects through the breed in their backyard — turning casual curiosity into lasting community.

### Mission Statement

DogQuest uses on-device AI breed identification, deep gamification, and hyperlocal social features to make learning about dogs as addictive as playing a game and as rewarding as meeting your neighbor's puppy.

### Founder's Why

Jesse built AviQuest — a bird identification app covering 1,049 species with visual ML and BirdNET audio recognition — entirely solo, from model training to Play Store polish. That project proved something: species identification is a gateway drug. People don't just want to know *what* they're looking at — they want to collect, compete, share, and belong. The birding community validated the core loop. Dogs are where that loop explodes.

Dogs are the most social animal on earth — and so are their owners. There are 65 million dog-owning households in the US alone, and yet every "dog ID" app on the market is a one-trick pony: snap a photo, get a breed name, close the app. No one has built the connective tissue between identification and community. No one has made breed knowledge feel like a game worth returning to. That gap is DogQuest's entire thesis.

This isn't a pivot away from birds — it's an expansion toward the full Shazanimal vision: "Shazam for every living creature." AviQuest is the proof of concept. DogQuest is the growth engine. Dogs have broader market appeal, stronger social hooks, and a monetization surface (pet services, local businesses, premium features) that dwarfs birding. Jesse's autodidact approach — training custom EfficientNet models, building Flutter UIs, wiring Riverpod state management — means the team of one can move faster than funded competitors stuck in committee.

### Core Values

**Curiosity Over Credentials**
You don't need to be a veterinarian to appreciate the difference between a Shiba Inu and an Akita. DogQuest treats every user as a learner worth investing in. This means breed information is layered — quick facts on first encounter, deeper content as mastery grows — never gatekept behind jargon.

**Local First, Cloud Second**
Dog ownership is hyperlocal. Your dog's friends live within a 2-mile radius. DogQuest prioritizes on-device ML, Hive-cached data, and offline capability because the park doesn't have WiFi. The Supabase backend amplifies local data — it never gates access to it.

**Play Is the Product**
Gamification isn't a layer on top of DogQuest — it *is* DogQuest. XP, combos, streaks, mastery, challenges, mystery rewards, and achievements exist because play drives retention better than utility alone. Every feature ships with a reason to come back tomorrow.

**Respect the Scroll**
No dark patterns. No notification spam. No interstitial ads blocking the camera. Revenue comes from non-intrusive banner ads and future premium features — never from manipulating attention. If a user opens the app, identifies a breed, and leaves in 30 seconds, that's a win.

**Ship Ugly, Ship Often**
Solo founder, zero budget. Perfection is the enemy of the Play Store listing. Every decision optimizes for learning speed: get the feature in front of real users, measure, iterate. The codebase has 34 screens and 50+ services already — velocity is the competitive moat.

### Strategic Pillars

1. **Identification is the entry point, not the product.** Every feature connects back to the moment someone points their camera at a dog. But the value compounds after that moment — in the collection, the social graph, the local map, the mastery system. Optimize for what happens *after* the ID.

2. **Build for the dog park, not the dog show.** The primary user is a casual owner who thinks their mutt might be part Lab. Design for approachability, not encyclopedic completeness. Expert features (rare breed sets, AKC group deep dives) exist but never overwhelm the casual path.

3. **Every feature must justify its retention cost.** With 34 screens already built, scope creep is the biggest risk. Before adding anything new, ask: does this make someone open the app tomorrow who wouldn't have otherwise? If not, it's a nice-to-have.

4. **The network is the moat.** ML models can be copied. Gamification can be cloned. A local social graph of dog owners, friendships between dogs, and neighborhood-specific data cannot. Every feature that strengthens the local network gets priority over features that don't.

### Success Looks Like

Twelve months from now, DogQuest has 10,000 monthly active users across three US metro areas where organic density is highest. The Play Store listing sits at 4.4 stars with reviews mentioning "addictive" and "my dog has more friends than I do." The average session lasts 4 minutes — double the industry norm for utility apps — because users are checking their streak, scrolling the neighborhood feed, and scanning a new dog at the coffee shop. The 294-breed v6 model is deployed and users are surfacing breed combinations the training data never anticipated, feeding a flywheel of user-contributed labels. Jesse has closed a $350K pre-seed round, framed around Shazanimal, with DogQuest's retention metrics as the centerpiece of the pitch deck. The Supabase backend handles real-time sync for 50,000 dog profiles without a single paid ops hire. Two part-time contributors — one ML engineer, one community manager — have joined, funded by the round. The codebase has shipped 40+ releases, and the backlog is driven by user requests, not founder intuition.

---

## 2. User Research

### Primary Persona

**Maya, 32 — "The Curious Owner"**

- **Location:** Austin, TX — walks her dog at Zilker Park 5x/week
- **Dog:** Adopted a mixed-breed from the shelter 2 years ago. Was told "Lab mix" but suspects there's something else in there.
- **Tech comfort:** Uses Instagram daily, has tried 2-3 dog apps (deleted them all within a week). Comfortable with mobile apps but won't tolerate slow onboarding.
- **Motivation:** Wants to know what breeds are in her dog. Wants to meet other dog owners nearby without the awkwardness of cold-approaching someone at the park. Loves the idea of tracking her dog's "social life."
- **Behavior:** Opens apps during downtime (lunch break, couch after work). Will spend 5-10 minutes if engaged, but bounces in under 30 seconds if the first experience is confusing. Responds strongly to progress indicators and streak mechanics (plays Duolingo).
- **Frustrations:** Dog Scanner gave her a different answer every time she scanned her dog. Google Lens said "dog." The shelter's breed guess was obviously wrong. She wants confidence scores, not guesses.
- **Willingness to pay:** Won't pay upfront for a dog app. Will tolerate tasteful ads. Might pay $2.99/month if the social features become part of her routine.
- **Quote:** "I just want to know what my dog actually is, and maybe find him some friends who aren't psycho at the park."

### Secondary Personas

**Kai, 22 — "The Breed Nerd"**

- College student, no dog (yet), but can name 150 breeds on sight. Follows dog accounts on TikTok and Reddit. Uses DogQuest as a knowledge game — scanning dogs on campus, building a collection, competing on mastery leaderboards. Cares about rare breeds, AKC groups, and getting the "Legendary" rarity badge. Will create TikTok content about breed ID if the app gives him something shareable. Zero willingness to pay but high willingness to evangelize.

**The Hernandez Family — "Weekend Dog People"**

- Parents (late 30s) with two kids (8 and 11). Got a Golden Retriever last year. The kids love scanning every dog they see on walks — it's become a family game. Parents appreciate the educational angle (breed history, origin countries). The 11-year-old is competitive about her collection size. The family uses Pack to co-manage their dog's profile. They'll tolerate ads if the kids aren't exposed to anything inappropriate. Session length is long (15+ minutes on weekend walks) but frequency is low (2-3x/week).

### Jobs To Be Done

**Functional Jobs**
- *When I see an unfamiliar dog,* I want to identify its breed instantly so I can learn about it and sound knowledgeable.
- *When I adopt a mixed-breed dog,* I want to understand its breed composition so I can anticipate behavior, size, and health needs.
- *When I'm at the dog park,* I want to find other owners nearby so my dog can have regular playmates.
- *When my dog goes missing,* I want to alert my neighborhood immediately so more eyes are searching.
- *When I'm bored on the couch,* I want a quick game loop (daily challenge, flash challenge) that teaches me something about dogs.

**Emotional Jobs**
- *I want to feel like an expert* — breed mastery and XP make casual knowledge feel like earned skill.
- *I want to feel connected to my neighborhood* — seeing dogs nearby and on the map makes my world feel smaller and friendlier.
- *I want to feel like my dog has a life* — Dog Passport, friendships, and social profiles give my pet a digital identity that mirrors their real personality.

**Social Jobs**
- *I want to share something interesting* — breed ID results and rare breed badges are inherently shareable on social media.
- *I want to bond with my kids over something screen-based that isn't mindless* — the collection game gives families a shared activity tied to the real world.
- *I want to meet my neighbors without it being weird* — the app provides a pretext for connection ("Your dog is a Vizsla? DogQuest says mine might be part Vizsla too!").

### Pain Points (Ranked by Severity)

1. **No reliable breed ID for mixed breeds** (Critical) — Shelter labels are guesses. Existing apps give inconsistent results. DNA tests cost $100-200. Users want a free, fast, "good enough" answer.
2. **Dog socialization is serendipitous** (High) — Finding compatible playmates depends entirely on who happens to be at the park at the same time. There's no way to coordinate or discover.
3. **One-and-done apps** (High) — Every competitor gives you a breed name and then has nothing else to offer. No reason to open the app a second time.
4. **Lost dog panic** (Medium-High) — When a dog escapes, owners post on Nextdoor, Facebook groups, and staple flyers to poles. There's no dedicated, location-aware alert system that reaches the right people.
5. **Breed information is scattered** (Medium) — Wikipedia, AKC, Reddit, and breeder sites all have different (sometimes contradictory) breed info. No single source combines identification with curated education.
6. **Dog apps feel cheap** (Medium) — Most dog apps have clip-art UIs, aggressive ads, and no personality. Owners want something that feels as polished as the apps they actually use daily.

### Current Alternatives & Competitive Landscape

| App | Strengths | Weaknesses | DogQuest Advantage |
|-----|-----------|------------|-------------------|
| **Dog Scanner** | Large breed database (350+), decent ML | Inconsistent results, no social features, aggressive premium upsell, no gamification | Gamification loop + social layer + honest confidence scores |
| **Google Lens** | Free, fast, universal | Returns "dog" for most breeds, no breed-specific data, no retention hook | Purpose-built ML model + deep breed content |
| **Dog Breed Identifier (various)** | Simple UX | One-trick pony, poor accuracy, ad-heavy, abandoned codebases | Active development, 294 breeds, custom-trained model |
| **Nextdoor** | Local community, lost pet posts | Not dog-specific, cluttered feed, no identification | Dog-first experience, breed ID, gamification |
| **BarkBuddy / Rover** | Dog services marketplace | Not identification or social, transactional relationship | Community-first, not transaction-first |
| **Instagram / TikTok** | Massive dog content audience | Not structured for breed knowledge, no local discovery | Structured data (breed profiles, maps) + local social graph |

**Competitive gap:** No app combines identification + gamification + local social. Each competitor owns one piece. DogQuest's bet is that combining all three creates a retention profile none of them can match individually.

### Key Assumptions to Validate

1. **"Mixed-breed ID is compelling enough to drive downloads."** Risk: users may not care about breed composition once the novelty wears off. Test: track Day 7 retention segmented by users who scanned their own dog vs. random dogs.

2. **"Gamification increases retention, not just session length."** Risk: XP and streaks may feel forced for a dog app audience that skews practical, not gamer. Test: A/B test onboarding with and without gamification framing; measure Day 30 retention.

3. **"Dog owners want a local social network."** Risk: Nextdoor already exists; users may not want *another* neighborhood app. Test: measure adoption of Dogs Nearby and Playdate Matcher in the first 1,000 users — if <5% engage, the social thesis is wrong.

4. **"Users will tolerate ads without churning."** Risk: ad-supported free apps have a ceiling; banner ads in a camera-first app may feel intrusive. Test: monitor ad-to-churn correlation in the first 90 days.

5. **"Reddit and TikTok are sufficient GTM channels for 500 users."** Risk: organic content creation is time-consuming for a solo founder; Reddit communities may flag self-promotion. Test: track cost-per-install (in time, not dollars) across channels.

6. **"The existing 150-breed model is accurate enough for launch."** Risk: 87.2% accuracy sounds good but means 1 in 8 scans is wrong — and wrong IDs erode trust fast. Test: track "re-scan" rates as a proxy for user dissatisfaction with results.

7. **"Lost Dog alerts will drive viral growth."** Risk: lost dog events are infrequent per user; the feature may never reach critical mass. Test: measure alert-to-install conversion (do recipients who don't have the app install it?).

8. **"A solo founder can support 500 users without burning out."** Risk: support requests, bug reports, and content moderation scale linearly with users. Test: track hours-per-week on support after launch; set a 5-hour/week ceiling.

### User Journey Map

**Stage 1: Awareness**
- Trigger: Sees a TikTok/Reel of someone scanning a dog with DogQuest, or a Reddit post in r/IDmydog recommending the app.
- Feeling: Curious ("I wonder what breed my dog is").
- Action: Searches Play Store for "dog breed identifier."

**Stage 2: Acquisition**
- Trigger: Finds DogQuest listing. Reads "Identify, collect, and connect" tagline. Sees 4.4-star rating and screenshots of breed ID + social features.
- Feeling: Intrigued but skeptical ("Another dog app?").
- Action: Installs. Opens app.

**Stage 3: Activation (Magic Moment #1 — First ID)**
- Trigger: Onboarding prompts camera scan. User points at their dog.
- Feeling: Delight ("It actually got it right!" or "Huh, 40% Lab, 30% Pit Bull — that explains a lot").
- Action: Reads breed info. Earns first XP. Sees collection screen with 1/294 breeds discovered.

**Stage 4: Engagement (Magic Moment #2 — First Social Connection)**
- Trigger: App surfaces "3 dogs near you" or "Daily Challenge: scan a dog with floppy ears."
- Feeling: Competitive ("I want to fill this collection") and social ("There's a Corgi two blocks away?").
- Action: Completes a challenge. Follows a neighbor's dog. Checks streak the next day.

**Stage 5: Retention**
- Trigger: Daily push notification ("Your streak is at 5 days — don't break it!") or neighborhood feed update ("Luna made a new friend").
- Feeling: Habitual ("Let me check DogQuest" becomes part of the daily walk routine).
- Action: Scans dogs on walks, checks feed, completes challenges, builds mastery in favorite breeds.

**Stage 6: Revenue**
- Trigger: Banner ads shown on non-camera screens. Future: premium features (ad-free, advanced stats, custom Passport designs).
- Feeling: Tolerant ("Ads aren't bad") or invested ("I'd pay $3/month to remove ads and get detailed breed reports").
- Action: Views ads or converts to premium.

**Stage 7: Advocacy**
- Trigger: User scans a friend's dog at a barbecue. Shares a rare breed badge on Instagram. Posts a Lost Dog alert that actually works.
- Feeling: Evangelical ("You NEED this app").
- Action: Word-of-mouth referral, Play Store review, social media share.

---

## 3. Product Strategy

### Product Principles

1. **Camera is home.** The identify screen is the default landing state. Every session should start with the possibility of a scan, even if the user came to check their feed. The camera is always one tap away.

2. **Progress must be visible.** XP bars, collection counts, streak counters, and mastery levels should be glanceable from the main navigation. If a user can't see their progress without navigating to a dedicated screen, it's buried too deep.

3. **Social features are opt-in, never forced.** Not every dog owner wants to share their location or connect with strangers. Social features (Dogs Nearby, Live Map, Playdate Matcher) must be discoverable but never required. The core loop (scan → learn → collect) works without social.

4. **Accuracy earns trust; transparency keeps it.** Show confidence scores, not just top-1 results. If the model is 60% confident it's a Labrador and 25% confident it's a Golden, show both. Users forgive uncertainty; they don't forgive false confidence.

5. **Offline is a first-class citizen.** Dog parks have bad reception. The ML model runs on-device. Breed data is cached in Hive. Sightings queue for sync when connectivity returns. No screen should show a blank state just because the network is down.

6. **Ads fund the mission, not define the experience.** Banner ads appear on content screens (feed, breed info, collection). Never on the camera screen. Never as interstitials that block user flow. Ad placement is reviewed against the "would this annoy Maya?" test.

### Market Differentiation

DogQuest sits at an intersection no competitor occupies: **AI identification × deep gamification × local social network**.

Dog Scanner has the identification piece but treats it as a standalone utility — scan, see result, close app. Their 350+ breed database is larger than DogQuest's current 150-breed deployed model, but their accuracy is inconsistent and their UX is cluttered with premium upsells. They have zero social features and zero gamification.

Google Lens has the AI but no domain expertise. It returns "dog" or "Golden Retriever" with no breed detail, no confidence breakdown, no educational content. It's a feature inside a search engine, not a product.

Nextdoor has the local social graph but isn't dog-specific. Lost pet posts compete with complaints about leaf blowers and HOA drama. There's no structured data — no breed profiles, no friendship graphs, no location-aware matching.

The Instagram/TikTok dog content ecosystem has the audience — millions of people who watch dog content daily — but no structured knowledge layer. You can watch a Shiba Inu video without ever learning why the breed exists or finding one in your neighborhood.

DogQuest's thesis is that **the combination creates compounding retention**: identification drives the first session, gamification drives the first week, and social drives the first month. No single feature wins the market alone. The bundle does.

The defensibility timeline is clear: ML models are commoditizing (any developer can fine-tune EfficientNet), gamification mechanics are well-documented (Duolingo's playbook is public), but a local social graph of dog owners and their pets' relationships is a cold-start problem that takes months of user density to solve. Every day of head start on that graph is a day competitors can't shortcut.

### Magic Moment Design

**Magic Moment #1: First Successful Breed ID**

What needs to be true:
- Camera loads in under 2 seconds (currently achieved with pre-initialized camera controller)
- ML inference completes in under 1 second on-device (EfficientNetB2 at 10.3 MB delivers this)
- Result screen shows breed name, confidence percentage, top-3 alternatives, a breed photo, and 2-3 quick facts
- The user earns XP immediately — a visible "+25 XP" animation fires on the result screen
- The breed is added to their collection with a satisfying visual (card flip, particle effect)
- A clear CTA leads to the next action: "Scan another" or "See your collection"

What can go wrong:
- Camera permission denied → must have a graceful fallback with re-prompt
- Low confidence result (<40%) → show "We're not sure, but here are our best guesses" instead of a wrong answer
- Photo is blurry or too far away → prompt to re-scan with guidance ("Try getting closer" or "Make sure the dog's face is visible")
- User scans a cat → handle gracefully with humor ("That's not a dog, but we respect the effort. +5 XP for trying.")

**Magic Moment #2: First Social Connection**

What needs to be true:
- At least 3 other dog profiles exist within the user's visibility radius (bootstrapped via demo mode seeding for early users; real profiles replace seeds as density grows)
- Dogs Nearby screen loads with profile cards showing breed, name, distance, and photo
- Tapping a dog profile shows its Passport card and an option to send a friendship request
- The friendship request flow is frictionless (one tap to send, push notification to recipient)
- Accepting a friendship triggers a celebratory moment ("+50 XP — Luna and Max are now friends!")

What can go wrong:
- No dogs nearby (empty state) → show "Be the first in your neighborhood!" with a share CTA to invite friends, plus breed community content as fallback engagement
- User is privacy-conscious → location sharing must be opt-in with clear radius controls; approximate location (neighborhood-level) as default, precise location only for Live Map with explicit consent
- Early density problem → the first 100 users in a city will see a sparse map; the social thesis doesn't work until local density hits ~20 users per 5-mile radius

### MVP Definition

**MVP = the existing app + Supabase backend + Play Store listing.** This is not a hypothetical feature set — it's a punch list for shipping what's already built.

**Already Built (34 screens, 50+ services):**
- Camera-based breed identification (EfficientNetB2, 150 breeds, 87.2% accuracy)
- Full gamification: XP, combos (24h window), streaks, mastery, daily challenges, flash challenges, mystery rewards, achievements
- Dog Passport card generation
- Pack (family co-ownership)
- Dog Friendships
- Neighborhood Map
- Social layer: dog profiles, activity feed, Dogs Nearby, Breed Communities, Playdate Matcher, Live Map with OSM tiles
- Lost Dog report system
- Demo mode with pre-seeded data (26 breeds, 42 sightings)
- Custom paw print app icon
- Riverpod state management, go_router navigation
- Hive local data persistence
- Firebase Analytics

**Must Build for Launch:**
- Supabase backend: auth, PostgreSQL database, real-time subscriptions, file storage for dog photos
- Data migration path: Hive local data → Supabase sync (conflict resolution strategy)
- Push notifications via Firebase Cloud Messaging (streak reminders, friendship requests, Lost Dog alerts)
- AdMob integration: banner ads on feed, collection, and breed info screens
- Privacy policy and terms of service (hosted web pages)
- Play Store listing: screenshots, description, feature graphic, content rating
- Release signing key and production build configuration
- Basic moderation: report/block for social features
- Crash reporting (Sentry DSN — code already wired, needs project creation)

### Explicitly Out of Scope

| Feature | Reason for Deferral |
|---------|-------------------|
| **v6 294-breed model deployment** | Training script ready (~10h on CPU). Ship with v5.1 (150 breeds) and upgrade post-launch. Users scanning rare breeds get "Unknown breed — help us learn!" which doubles as data collection. |
| **iOS version** | Flutter supports iOS, but App Store review is slower, Apple developer account costs $99/year, and the primary audience (Reddit/TikTok-driven) skews Android. Launch Android-only; iOS follows after product-market fit signal. |
| **Premium subscription tier** | No payment infrastructure yet. Ads are sufficient for the first 90 days. Premium features (ad-free, advanced breed reports, custom Passport designs) are designed but not built. |
| **DNA test partnership** | Embark/Wisdom Panel integrations would be valuable ("Verify your DogQuest ID with a DNA test — 15% off") but require business development capacity a solo founder doesn't have yet. |
| **Web app** | Flutter Web is technically possible but mobile-first is the right bet for a camera-based app. A web presence is limited to marketing landing page. |
| **Multi-language support** | English-only at launch. Internationalization is architecturally trivial (Flutter's l10n) but content translation is not. Defer until organic demand from a specific locale appears. |
| **Breeding / health tracking** | Out of brand — DogQuest is about identification, education, and social connection, not pet health management. Competing with PetDesk or Pawprint is a losing game. |

### Feature Priority (MoSCoW)

**Must Have (Launch Blockers)**
- Supabase auth + user accounts
- Supabase PostgreSQL schema for dogs, sightings, friendships, social
- Real-time sync: Hive ↔ Supabase with conflict resolution
- Push notifications (streaks, social, Lost Dog)
- AdMob banner integration
- Play Store listing + release build
- Privacy policy + terms of service
- Sentry crash reporting
- Report/block for social content
- Camera permission handling edge cases

**Should Have (First 30 Days Post-Launch)**
- v6 model upgrade (294 breeds)
- Share-to-Instagram/TikTok: breed ID result cards formatted for Stories
- Onboarding tutorial (3-screen walkthrough, skippable)
- Push notification opt-in flow with granular controls
- Performance profiling and cold-start optimization

**Could Have (Days 30-90)**
- Leaderboards (neighborhood, city, global)
- Breed of the Day featured content
- Widget for Android home screen (streak counter, daily challenge preview)
- Referral program ("Invite a friend, both earn 100 XP")
- Seasonal events (Halloween costume scan, holiday breed trivia)

**Won't Have (Not This Year)**
- iOS launch (deferred to post-PMF)
- Premium subscription infrastructure
- Web app
- AR breed overlay ("point camera, see breed label floating over dog")
- Marketplace / e-commerce (dog products, services)
- Veterinary integration

### Core User Flows

**Flow 1: First-Time Breed Identification**

1. User opens DogQuest → camera viewfinder loads as default screen
2. User points camera at a dog → live viewfinder shows the scene
3. User taps the capture button (prominent, centered, paw-print styled)
4. Shutter flash animation fires → image captured
5. ML inference runs on-device (EfficientNetB2, <1s)
6. Result screen slides up: breed name, confidence %, top-3 alternatives, breed photo, quick facts
7. "+25 XP" animation fires → XP bar updates in real-time
8. Breed card flips into the collection → "1/294 breeds discovered" counter increments
9. User sees CTAs: "Scan Another" (returns to camera) | "View Collection" | "Share Result"
10. If confidence <40%: "We're not sure — here are our best guesses" with a "Help us learn" feedback button

**Flow 2: Connecting with a Nearby Dog**

1. User taps "Nearby" in bottom nav → Dogs Nearby screen loads
2. Screen shows cards: dog photo, name, breed, distance (e.g., "Luna — Golden Retriever — 0.3 mi")
3. User taps Luna's card → Dog Passport slides up: full profile, owner info (first name only), friendship count
4. User taps "Send Friend Request" → confirmation dialog ("Max wants to be friends with Luna!")
5. Request sent → owner receives push notification
6. Owner opens notification → sees Max's profile → taps "Accept"
7. Both users see: "+50 XP — Max and Luna are now friends!" with confetti animation
8. Friendship appears on both dogs' Passport cards under "Friends"
9. Both owners now see each other in the neighborhood feed

**Flow 3: Lost Dog Alert**

1. User taps "Report Lost Dog" from their dog's profile or the emergency button on the map
2. Form pre-fills: dog name, breed, photo, last known location (GPS)
3. User adds description ("Escaped from backyard, wearing red collar, responds to 'Buddy'")
4. User taps "Send Alert" → confirmation: "This will notify all DogQuest users within 5 miles"
5. Alert broadcasts via push notification to nearby users
6. Recipients see: dog photo, breed, distance, description, "I've Seen This Dog" button
7. If a recipient taps "I've Seen This Dog" → they can drop a pin on the map with a timestamp
8. The owner's map updates in real-time with sighting pins
9. When the dog is found, the owner marks "Resolved" → all recipients get a follow-up ("Buddy is home safe!")

### Success Metrics

**Primary Metric: Day 7 Retention Rate**
- Target: 25% (industry average for utility apps is 12-15%; gamified apps reach 25-30%)
- Why: retention is the single best predictor of product-market fit for a free app. If users come back after a week, the core loop works.

**Secondary Metrics:**

| Metric | Target | Rationale |
|--------|--------|-----------|
| Day 30 Retention | 12% | Validates that social/gamification sustain engagement beyond novelty |
| Scans per User per Week | 3+ | Proves the identification loop is repeatable, not one-and-done |
| Social Feature Adoption | 15% of MAU | Validates the local social thesis; below 5% means social isn't working |
| Average Session Length | 3+ minutes | Above utility-app norms (90s); proves engagement depth |
| Play Store Rating | 4.3+ stars | Below 4.0 signals quality issues that kill organic discovery |
| Crash-Free Rate | 99.5% | Below 99% triggers user reviews mentioning crashes |

**Leading Indicators:**

| Indicator | Signal | Threshold |
|-----------|--------|-----------|
| Camera permission grant rate | Onboarding effectiveness | >85% |
| Second scan rate (within first session) | Magic moment success | >50% |
| Collection screen visits | Gamification engagement | >60% of users within Day 1 |
| Share action rate | Viral potential | >5% of ID results shared |
| Re-scan rate (same dog, same session) | Accuracy dissatisfaction | <15% (higher = trust problem) |
| Streak maintenance (Day 3+) | Habit formation | >30% of Day 1 users |

### Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| **Low accuracy erodes trust** — 87.2% means ~13% wrong answers, and users remember the misses | High | Critical | Show confidence scores transparently. Add "Not right? Help us improve" feedback loop. Prioritize v6 model (294 breeds, expected >90% accuracy) in first 30 days. |
| **Cold start: empty social graph** — first users in any area see no dogs nearby, no feed activity, no playdate options | High | High | Seed with demo data. Geo-focus launch marketing on 2-3 metro areas to build density. Show breed community content as fallback when local content is sparse. |
| **Solo founder bottleneck** — one person handles development, support, moderation, marketing, and fundraising simultaneously | High | High | Automate ruthlessly: CI/CD pipeline, auto-moderation rules, canned support responses. Set a 5-hour/week support ceiling. Hire community manager first with pre-seed funding. |
| **Ad revenue too low to sustain** — banner ads on a niche app with <10K users generate negligible revenue (<$100/month) | High | Medium | Ads are a bridge, not the business model. Real revenue comes from the pre-seed round. Design premium features now; build them when retention metrics justify the investment. |
| **Reddit/TikTok GTM fails** — organic content takes months to gain traction; Reddit communities may flag self-promotion | Medium | High | Create genuinely useful content (breed comparison posts, "Can you guess the breed?" challenges) rather than app promotion. Budget 5 hours/week for content creation. Track installs per content piece. |
| **Supabase migration breaks local-first experience** — syncing Hive local data to Supabase introduces conflicts, latency, and new failure modes | Medium | High | Implement optimistic local-first writes: Hive is always the source of truth for reads, Supabase syncs in the background. Build a conflict resolution queue before launch. Test with 100 synthetic users before real users touch it. |
| **Privacy backlash from location features** — Live Map, Dogs Nearby, and Lost Dog alerts require location sharing, which some users will find creepy | Medium | Medium | Default to approximate location (neighborhood-level). Precise location is opt-in with clear UI explaining what's shared. Add "ghost mode" to hide from map entirely. Never expose exact addresses. |
| **App Store rejection or delay** — Play Store review can flag user-generated content, location tracking, or ad implementation | Low | High | Pre-review the listing against Google Play policies. Ensure content moderation (report/block) is in place before submission. Test ad implementation against AdMob policies. Budget 2 weeks for review cycles. |

---

## 4. Brand Strategy

### Positioning Statement

For dog owners who want more than a breed name, DogQuest is the AI-powered companion app that turns every walk into a discovery — combining camera-based breed identification with gamified learning and a local social network built around the dogs in your neighborhood.

### Brand Personality

DogQuest is **your most enthusiastic friend who also happens to know everything about dogs.** Not the professor who lectures — the friend who says "Oh! That's a Vizsla! They were bred by Hungarian nobility as hunting dogs. There's one that lives two streets over, want me to introduce you?"

**Adventurous:** DogQuest treats every walk as an expedition and every new dog as a discovery. The language leans into exploration metaphors — "discover," "quest," "expedition," "uncharted." The app feels like a field guide, not a database.

**Energetic:** Interactions are fast and rewarding. Animations pop. XP gains are celebrated. The app never feels sluggish or static. But energetic doesn't mean frantic — there's a warmth to the pace, like an excited dog that still listens to commands.

**Warm:** The color palette (earthy browns, ambers, forest greens) creates a grounded, natural feeling. The voice is friendly, never corporate. Errors are apologized for with personality, not sterile "something went wrong" messages.

**Knowledgeable but not pedantic:** Breed information is accurate and specific (origin country, AKC group, temperament traits, historical purpose) but delivered in conversational language. A breed card reads like a well-written Wikipedia article, not a veterinary textbook.

**Playful without being childish:** Gamification elements (XP, streaks, badges) are inspired by Duolingo's motivational design, not by children's games. The paw-print icon and brown palette signal "dog lover," not "kids' app." Humor is dry and knowing, not silly.

### Voice & Tone Guide

| Context | DO | DON'T |
|---------|-----|-------|
| **Onboarding** | "Point your camera at any dog to discover its breed. Your quest starts now." | "Welcome to DogQuest! We're so excited to have you! Let's get started with a quick tutorial about all our amazing features!" |
| **Successful ID** | "Labrador Retriever — 92% confident. America's most popular breed since 1991." | "Congratulations!!! You identified a Labrador Retriever! Great job! 🎉🎉🎉" |
| **Low-Confidence ID** | "We're not certain, but this looks like a Pit Bull mix. Here are our other guesses." | "ERROR: Unable to identify breed with sufficient confidence." |
| **Error / Crash** | "Something broke on our end. Your data is safe — try again in a moment." | "An unexpected error occurred. Error code: 0x4F2A. Please contact support." |
| **Empty State (no dogs nearby)** | "No dogs spotted in your area yet. Be the pioneer — share DogQuest with a fellow dog owner." | "No results found. There are no dogs in your vicinity at this time." |
| **Streak Reminder** | "Day 7 streak — you're on a roll. Scan one dog to keep it alive." | "Don't forget to open the app today or you'll lose your streak!!!" |
| **Lost Dog Alert** | "LOST: Buddy, Golden Retriever, last seen near Oak Park. Tap to help." | "🚨 ALERT 🚨 A dog has been reported missing in your area! Open app for details!" |
| **Achievement Earned** | "Rare Find: You've identified a Xoloitzcuintli. Only 3% of users have spotted one." | "ACHIEVEMENT UNLOCKED! You're amazing! You found a super rare breed!" |
| **Marketing Copy** | "294 breeds. One camera. Zero excuses not to know what that dog is." | "DogQuest is the world's best AI-powered dog breed identification platform!" |
| **In-App Upsell (future)** | "Go ad-free and unlock detailed breed reports. $2.99/month." | "UPGRADE NOW for the PREMIUM experience! Limited time offer!" |

### Messaging Framework

**Tagline:** "Identify. Collect. Connect."

**Headline (Play Store / marketing):** "The dog lover's field guide — powered by AI, fueled by curiosity."

**Value Propositions:**

1. **Instant breed ID:** "Point your camera at any dog. Know its breed in under a second — with confidence scores, not guesses."
2. **Gamified discovery:** "294 breeds to collect, daily challenges to complete, and streaks to protect. Learning about dogs has never been this addictive."
3. **Local dog network:** "Find dogs in your neighborhood, make friends for your pup, and never miss a Lost Dog alert on your block."
4. **Dog Passport:** "Give your dog a digital identity — breed, friends, adventures, all in one shareable card."

**Objection Handlers:**

| Objection | Response |
|-----------|----------|
| "I already know my dog's breed." | "But do you know the 293 others? DogQuest turns every walk into a breed discovery game — and connects you with dog owners nearby." |
| "Google Lens can identify dogs." | "Google Lens says 'dog.' DogQuest says 'Australian Shepherd — 87% confident. Originally bred to herd livestock in the American West. There's one 2 blocks from you named Rosie.'" |
| "I don't want another social app." | "Social is optional. The core loop — scan, learn, collect — works completely solo. But when your dog needs a playmate, we're here." |
| "Dog Scanner already does this." | "Dog Scanner identifies. DogQuest identifies, gamifies, and connects. After the scan, Dog Scanner has nothing left to offer. DogQuest is just getting started." |
| "Is it accurate?" | "87.2% accuracy on 150 breeds today, with a 294-breed upgrade coming. We show confidence scores so you always know how sure we are — no false certainty." |

### Elevator Pitches

**5-Second Pitch:**
"DogQuest identifies dog breeds with your camera and turns it into a game with a social network."

**30-Second Pitch:**
"DogQuest is a mobile app that uses AI to identify 294 dog breeds from a photo — and then keeps you coming back with gamification like Duolingo and a local social network for dog owners. Scan a dog, learn its breed, add it to your collection, and connect with other owners in your neighborhood. No competitor combines identification, gamification, and social — and we're already built, with 34 screens and a working ML model."

**2-Minute Pitch:**
"There are 65 million dog-owning households in the US, and every one of them has googled 'what breed is my dog' at least once. The apps that exist today give you a breed name and then have nothing else to offer — you identify, you close the app, you never open it again.

DogQuest changes that equation. We use on-device AI to identify 294 dog breeds from a phone camera in under a second. But identification is just the entry point. After the scan, users enter a gamified collection system — XP, streaks, daily challenges, mastery levels, rare breed badges — inspired by Duolingo's retention mechanics. And beneath the game layer is a local social network: find dogs near you, make friends for your pup, coordinate playdates, and receive real-time Lost Dog alerts for your neighborhood.

The app is already built — 34 screens, 50+ services, a custom-trained EfficientNet model at 87.2% accuracy, and a full social layer with live maps. We're launching on the Play Store within 90 days and targeting 500 users through Reddit and TikTok content.

But DogQuest is the wedge, not the ceiling. It's part of Shazanimal — 'Shazam for every living creature.' We've already built AviQuest for birds, covering 1,049 species with visual and audio ML. Dogs are next because they have the broadest consumer market and the strongest social hooks. The architecture is designed to add new creature modules — plants, insects, marine life — as the platform scales.

We're raising $250-500K pre-seed to ship the Supabase backend, deploy the 294-breed model, hire a community manager, and reach 10,000 MAU within 12 months."

### Competitive Differentiation Narrative

Every dog identification app on the market was built by someone who thought, "Let me fine-tune an image classifier and wrap it in an ad-supported UI." The result is a category full of disposable utilities — apps with one feature, no retention, and user reviews that say "worked once, deleted." DogQuest was built by someone who asked a different question: "What would it take to make a dog owner open this app every single day?" The answer isn't a better classifier (though DogQuest has one). It's the connective tissue between identification and community — the gamification loop that turns a single scan into a collection quest, and the local social graph that turns a stranger at the dog park into your dog's best friend's owner. Dog Scanner has 350 breeds in their database but zero reasons to open the app a second time. DogQuest has 294 breeds, a mastery system, 18 themed breed sets, daily challenges, and a neighborhood map of every dog within a mile. The identification model is table stakes. The ecosystem around it is the product.

### Brand Anti-Patterns

**Never Clinical**
- Don't say: "Canine breed classification results" → Say: "Your dog's breed"
- Don't say: "User engagement metrics indicate..." → Say: "People love..."
- Don't use medical/veterinary terminology unless directly relevant to breed health traits
- Don't present breed info as a data table — always lead with a narrative sentence, then support with structured data
- Don't use gray-on-white minimalist UI — this isn't a health app

**Never Ad-Heavy / Spammy**
- Don't show ads on the camera screen — ever
- Don't show interstitial ads between scan and result — that's the magic moment
- Don't send more than 1 push notification per day (except Lost Dog alerts)
- Don't gate basic features behind a paywall in V1 — the entire app is free
- Don't use "UPGRADE NOW" banners with countdown timers or fake urgency
- Don't show ads within 3 seconds of app open — let the user settle in

**Never Childish**
- Don't use cartoon dog illustrations — use real photography
- Don't use rainbow color schemes or primary-color palettes
- Don't use exclamation marks in clusters ("Great job!!!")
- Don't use baby-talk with dogs ("Who's a good boy?! You found a pupper!")
- Don't add sound effects that mimic children's toys (boings, whistles)
- The paw-print icon is the extent of the "cute" design vocabulary — everything else is warm, mature, and confident

---

## 5. Design Direction

### Design Philosophy

1. **Field Guide, Not Dashboard.** Every screen should feel like a page from a beautifully designed field guide — rich photography, considered typography, data presented as narrative rather than spreadsheet. The inspiration is National Geographic's app, not a fitness tracker.

2. **Earn Complexity.** New users see a camera viewfinder and a scan button. Mastery stats, AKC groups, rare breed sets, and community leaderboards reveal themselves as the user progresses. The app feels simple on Day 1 and deep on Day 30.

3. **Nature's Palette.** The visual language draws from the natural world — earthy tones, organic shapes, photography over illustration. Digital elements (XP bars, badges, buttons) are warm and tactile, never flat or sterile.

4. **Celebrate the Dog, Not the UI.** Every design decision serves the dog photo. Breed cards, Passport layouts, and the neighborhood map all give primacy to the animal's image. Chrome is minimal; content is maximal.

### Visual Mood

**National Geographic meets Duolingo — editorial richness with motivational game mechanics.**

The base layer is warm and natural: brown leather textures, amber highlights, forest-green accents that evoke outdoor exploration. Layered on top is a crisp, modern UI system: clean cards, readable typography, satisfying micro-animations. The gamification elements (XP counters, streak badges, mastery rings) borrow Duolingo's clarity and reward psychology but render them in DogQuest's earthy palette instead of Duolingo's bright green.

Photography drives the mood: high-quality breed reference photos, user-submitted snapshots on social feeds, the live camera viewfinder as the app's centerpiece. The visual hierarchy always prioritizes the image.

Surfaces feel tactile — subtle grain on background textures, soft shadows on cards that suggest physical depth, border radii that feel rounded like a pebble rather than sharp or pill-shaped.

### Color Palette

**Light Mode:**

| Role | Color | Hex | CSS Variable | Tailwind | Flutter |
|------|-------|-----|-------------|----------|---------|
| Primary | Deep Brown | `#4A2F1A` | `--color-primary` | `brown-900` (custom) | `Color(0xFF4A2F1A)` |
| Primary Light | Warm Brown | `#6B4832` | `--color-primary-light` | `brown-700` (custom) | `Color(0xFF6B4832)` |
| Primary Dark | Espresso | `#2E1A0E` | `--color-primary-dark` | `brown-950` (custom) | `Color(0xFF2E1A0E)` |
| Secondary | Forest Green | `#2D5A3D` | `--color-secondary` | `green-800` (custom) | `Color(0xFF2D5A3D)` |
| Secondary Light | Sage | `#4A7C5C` | `--color-secondary-light` | `green-600` (custom) | `Color(0xFF4A7C5C)` |
| Accent / XP Gold | Amber Gold | `#D4A843` | `--color-accent` | `amber-500` (custom) | `Color(0xFFD4A843)` |
| Accent Bright | Sunflower | `#F0C246` | `--color-accent-bright` | `amber-400` (custom) | `Color(0xFFF0C246)` |
| Background | Warm White | `#FAF7F2` | `--color-bg` | `stone-50` (custom) | `Color(0xFFFAF7F2)` |
| Surface | Cream | `#F5F0E8` | `--color-surface` | `stone-100` (custom) | `Color(0xFFF5F0E8)` |
| Surface Elevated | Parchment | `#EDE6D9` | `--color-surface-elevated` | `stone-200` (custom) | `Color(0xFFEDE6D9)` |
| On Primary | White | `#FFFFFF` | `--color-on-primary` | `white` | `Colors.white` |
| On Background | Charcoal | `#2C2419` | `--color-on-bg` | `stone-900` (custom) | `Color(0xFF2C2419)` |
| On Surface (secondary text) | Warm Gray | `#6B5E50` | `--color-on-surface` | `stone-500` (custom) | `Color(0xFF6B5E50)` |

**Semantic Colors:**

| Role | Hex | CSS Variable | Flutter | Usage |
|------|-----|-------------|---------|-------|
| Success | `#3D8B5E` | `--color-success` | `Color(0xFF3D8B5E)` | Friend request accepted, dog found |
| Warning | `#C4882F` | `--color-warning` | `Color(0xFFC4882F)` | Low confidence, streak at risk |
| Error / Alert | `#C4483E` | `--color-error` | `Color(0xFFC4483E)` | Lost Dog alerts, errors, destructive actions |
| Info | `#4A7A9B` | `--color-info` | `Color(0xFF4A7A9B)` | Tips, hints, educational callouts |

**Dark Mode:**

| Role | Color | Hex | Flutter |
|------|-------|-----|---------|
| Background | Dark Earth | `#1A1410` | `Color(0xFF1A1410)` |
| Surface | Dark Brown | `#241C14` | `Color(0xFF241C14)` |
| Surface Elevated | Medium Dark | `#3A2E22` | `Color(0xFF3A2E22)` |
| Primary | Warm Tan | `#C4956A` | `Color(0xFFC4956A)` |
| On Background | Warm Light | `#E8DFD1` | `Color(0xFFE8DFD1)` |
| On Surface | Muted Tan | `#A89880` | `Color(0xFFA89880)` |
| Accent | Bright Gold | `#E8B94A` | `Color(0xFFE8B94A)` |

### Typography

**Heading Font: [Nunito](https://fonts.google.com/specimen/Nunito)**
- Rounded sans-serif that feels warm and approachable without being childish
- Weight range: 600 (SemiBold) for subheadings, 700 (Bold) for primary headings, 800 (ExtraBold) for hero text
- Flutter: `GoogleFonts.nunito()`

**Body Font: [Source Sans 3](https://fonts.google.com/specimen/Source+Sans+3)**
- Highly readable at small sizes, professional but not cold
- Weight range: 400 (Regular) for body, 600 (SemiBold) for emphasis
- Flutter: `GoogleFonts.sourceSans3()`

**Mono Font: [JetBrains Mono](https://fonts.google.com/specimen/JetBrains+Mono)**
- Used sparingly: confidence percentages, XP counters, data-heavy displays
- Weight: 500 (Medium)
- Flutter: `GoogleFonts.jetBrainsMono()`

**Type Scale (rem / px at 16px base):**

| Token | rem | px | Font | Weight | Flutter TextStyle |
|-------|-----|-----|------|--------|-------------------|
| `display` | 2.25 | 36 | Nunito | 800 | `TextStyle(fontSize: 36, fontWeight: FontWeight.w800)` |
| `h1` | 1.75 | 28 | Nunito | 700 | `TextStyle(fontSize: 28, fontWeight: FontWeight.w700)` |
| `h2` | 1.375 | 22 | Nunito | 700 | `TextStyle(fontSize: 22, fontWeight: FontWeight.w700)` |
| `h3` | 1.125 | 18 | Nunito | 600 | `TextStyle(fontSize: 18, fontWeight: FontWeight.w600)` |
| `body-lg` | 1.0 | 16 | Source Sans 3 | 400 | `TextStyle(fontSize: 16, fontWeight: FontWeight.w400)` |
| `body` | 0.875 | 14 | Source Sans 3 | 400 | `TextStyle(fontSize: 14, fontWeight: FontWeight.w400)` |
| `body-sm` | 0.75 | 12 | Source Sans 3 | 400 | `TextStyle(fontSize: 12, fontWeight: FontWeight.w400)` |
| `caption` | 0.6875 | 11 | Source Sans 3 | 600 | `TextStyle(fontSize: 11, fontWeight: FontWeight.w600)` |
| `mono` | 0.875 | 14 | JetBrains Mono | 500 | `TextStyle(fontSize: 14, fontWeight: FontWeight.w500)` |

### Spacing & Layout

**Base Unit: 4px**

| Token | Value | CSS Variable | Flutter |
|-------|-------|-------------|---------|
| `space-1` | 4px | `--space-1` | `4.0` |
| `space-2` | 8px | `--space-2` | `8.0` |
| `space-3` | 12px | `--space-3` | `12.0` |
| `space-4` | 16px | `--space-4` | `16.0` |
| `space-5` | 20px | `--space-5` | `20.0` |
| `space-6` | 24px | `--space-6` | `24.0` |
| `space-8` | 32px | `--space-8` | `32.0` |
| `space-10` | 40px | `--space-10` | `40.0` |
| `space-12` | 48px | `--space-12` | `48.0` |
| `space-16` | 64px | `--space-16` | `64.0` |

**Layout Constraints:**

| Property | Value | Rationale |
|----------|-------|-----------|
| Max content width | 428px | Largest common phone width (iPhone 14 Pro Max). Content never stretches wider. |
| Screen padding (horizontal) | 16px | Standard mobile padding. Consistent on every screen. |
| Section spacing | 24px minimum | Between distinct content sections (e.g., breed info → similar breeds). |
| Card internal padding | 16px | Consistent breathing room inside all card components. |
| List item spacing | 12px | Between items in vertical lists (dogs nearby, breed list). |
| Bottom nav height | 64px | Room for icons + labels, with safe area padding below. |
| Camera button size | 72px | Large enough for confident tapping during one-handed use. |

**Responsive Breakpoints (mobile-focused):**

| Breakpoint | Width | Behavior |
|------------|-------|----------|
| Small phone | <360px | Reduce horizontal padding to 12px. Stack horizontal layouts. |
| Standard phone | 360-428px | Default layout. All designs target this range. |
| Large phone / small tablet | 429-600px | Content remains max 428px, centered. No layout changes. |
| Tablet (future) | >600px | Two-column layout: sidebar nav + content pane. Not in V1 scope. |

### Component Philosophy

**Border Radius**
- Cards: 16px (`BorderRadius.circular(16)`) — rounded enough to feel organic, not so round it's bubbly
- Buttons: 12px (`BorderRadius.circular(12)`) — slightly tighter than cards for visual hierarchy
- Input fields: 12px — matching buttons for consistency
- Chips / Tags: 20px (`BorderRadius.circular(20)`) — pill-shaped for breed tags, rarity labels
- Bottom sheets: 24px top-left/top-right (`BorderRadius.vertical(top: Radius.circular(24))`)
- Avatar / dog photos: circular (`BorderRadius.circular(999)`) for profile images, 16px for breed reference photos

**Shadows**
Shadows are warm, not neutral gray. All shadows use the primary brown hue at low opacity.

| Level | CSS | Flutter |
|-------|-----|---------|
| Subtle | `0 1px 3px rgba(74, 47, 26, 0.08)` | `BoxShadow(color: Color(0x144A2F1A), blurRadius: 3, offset: Offset(0, 1))` |
| Card | `0 2px 8px rgba(74, 47, 26, 0.12)` | `BoxShadow(color: Color(0x1F4A2F1A), blurRadius: 8, offset: Offset(0, 2))` |
| Elevated | `0 4px 16px rgba(74, 47, 26, 0.16)` | `BoxShadow(color: Color(0x294A2F1A), blurRadius: 16, offset: Offset(0, 4))` |
| Modal | `0 8px 32px rgba(74, 47, 26, 0.24)` | `BoxShadow(color: Color(0x3D4A2F1A), blurRadius: 32, offset: Offset(0, 8))` |

**Buttons**

| Type | Background | Text | Border | Usage |
|------|-----------|------|--------|-------|
| Primary | `#4A2F1A` | `#FFFFFF` | None | Main CTAs: "Scan," "Send Friend Request," "Report Lost Dog" |
| Secondary | Transparent | `#4A2F1A` | 1.5px `#4A2F1A` | Secondary actions: "View Collection," "Share" |
| Accent | `#D4A843` | `#2E1A0E` | None | XP-related: "Claim Reward," "Complete Challenge" |
| Danger | `#C4483E` | `#FFFFFF` | None | Destructive: "Delete Dog," "Cancel Alert" |
| Ghost | Transparent | `#6B5E50` | None | Tertiary: "Skip," "Maybe Later" |

All buttons: minimum height 48px, horizontal padding 24px, font Source Sans 3 SemiBold 16px.

**Input Fields**
- Background: `#F5F0E8` (surface color)
- Border: 1.5px `#D9CFC2` (neutral border), focus state 2px `#4A2F1A` (primary)
- Height: 52px (generous touch target)
- Placeholder text: `#A89880` (muted)
- Border radius: 12px

### Iconography & Imagery

**Icon Style:** Outlined icons with 1.5px stroke weight, rounded caps and joins. The outline style feels lighter and more exploratory than filled icons, matching the field-guide aesthetic.

**Icon Library:** [Phosphor Icons](https://phosphoricons.com/) — excellent Flutter support via `phosphor_flutter` package. Offers regular, light, bold, fill, and duotone variants. Use regular weight for navigation, bold for emphasis, duotone for decorative/illustrative contexts.

Fallback: [Lucide](https://lucide.dev/) via `lucide_icons` if Phosphor doesn't cover a specific glyph.

**Custom Icons:**
- Paw print (app icon, scan button, loading states)
- Bone (XP/reward indicator)
- Dog silhouette (placeholder for missing photos)
- Leash (friendship connection line on map)

Custom icons should match Phosphor's 1.5px stroke weight and 24x24 artboard for seamless mixing.

**Photography Direction:**
- Breed reference photos: professional, well-lit, showing the dog's full body in a natural setting (not studio white background). Source from Unsplash, Pexels, or licensed breed photography. Each breed card needs a hero photo (landscape crop, 16:9) and a profile photo (square crop, 1:1).
- User-submitted photos: displayed as-is, with EXIF orientation correction applied. No filters, no artificial enhancement. Authenticity is the aesthetic.
- Empty state illustrations: minimal line-art dogs in the primary brown color, not cartoon dogs. A sitting dog silhouette for "no results," a running dog for "loading," a sleeping dog for "nothing happening yet."

### Accessibility Commitments

**WCAG Target: AA compliance minimum, AAA for text contrast.**

| Requirement | Standard | DogQuest Implementation |
|-------------|----------|------------------------|
| Text contrast (normal) | 4.5:1 minimum | Primary brown `#4A2F1A` on warm white `#FAF7F2` = 10.2:1 (exceeds AAA) |
| Text contrast (large) | 3:1 minimum | All heading combinations exceed 7:1 |
| Touch targets | 48x48dp minimum | All interactive elements: buttons (48px height), nav items (64px zone), list items (56px row height) |
| Focus indicators | Visible on all interactive elements | 2px primary-color outline with 2px offset on focus |
| Screen reader | Full semantic labels | All images get `semanticsLabel`, all icons get `tooltip`, all buttons get descriptive labels |
| Color independence | Information not conveyed by color alone | Confidence scores use color + percentage number. Rarity uses color + text label. Streak status uses color + icon + text. |
| Motion | Respect reduced motion | Check `MediaQuery.disableAnimations` — skip all decorative animations, keep only functional transitions |
| Font scaling | Support system font size | Use `MediaQuery.textScaleFactor` — layouts flex with scaled text up to 2x. Test at 1.0x, 1.5x, and 2.0x. |
| Dark mode | Full dark mode support | Every color token has a dark-mode variant. Contrast ratios re-verified for dark surfaces. |

**Specific contrast checks for dark mode:**
- Warm Light `#E8DFD1` on Dark Earth `#1A1410` = 11.8:1 (exceeds AAA)
- Muted Tan `#A89880` on Dark Earth `#1A1410` = 5.6:1 (exceeds AA)
- Bright Gold `#E8B94A` on Dark Brown `#241C14` = 7.3:1 (exceeds AAA)

### Motion & Interaction

**Animation Library: `flutter_animate`**

All animations use `flutter_animate` for declarative, composable transitions. The motion language is quick and decisive — not bouncy or springy.

**Transition Tokens:**

| Token | Duration | Curve | Flutter | Usage |
|-------|----------|-------|---------|-------|
| `instant` | 100ms | `easeOut` | `Duration(milliseconds: 100), Curves.easeOut` | Button press states, toggle switches |
| `fast` | 200ms | `easeOut` | `Duration(milliseconds: 200), Curves.easeOut` | List item appear, chip select, tab switch |
| `standard` | 300ms | `easeInOut` | `Duration(milliseconds: 300), Curves.easeInOut` | Card expand/collapse, screen transitions, bottom sheet |
| `emphasis` | 500ms | `easeInOutCubic` | `Duration(milliseconds: 500), Curves.easeInOutCubic` | XP gain animation, breed card flip, confetti burst |
| `dramatic` | 800ms | `easeInOutCubic` | `Duration(milliseconds: 800), Curves.easeInOutCubic` | First breed discovery reveal, achievement unlock |

**Specific Animations:**

| Interaction | Animation | Implementation |
|-------------|-----------|----------------|
| Scan result reveal | Card slides up from bottom + fade in, breed photo scales from 0.9→1.0 | `.slideY(begin: 0.3, end: 0).fadeIn().scale(begin: Offset(0.9, 0.9))` with `standard` timing |
| XP gain | "+25 XP" text floats upward and fades out, XP bar fills with gold shimmer | `.slideY(begin: 0, end: -0.5).fadeOut()` with `emphasis` timing; bar uses `AnimatedContainer` |
| Collection add | Breed card flips 180° on Y-axis, landing face-up in collection grid | `AnimationController` with `Transform` matrix rotation, `emphasis` duration |
| Streak counter | Numbers tick up one-by-one (slot machine style) | `AnimatedSwitcher` with `slideY` transition per digit |
| Pull to refresh | Paw-print icon rotates as pull distance increases | Custom `RefreshIndicator` with rotation linked to scroll offset |
| Loading state | Three paw prints pulse in sequence (left, center, right) | `.fadeIn().fadeOut()` with staggered 200ms delays |
| Error shake | Input field or card shakes horizontally 3 times | `.shakeX(amount: 4, hz: 3)` with `fast` timing |
| Friend request accept | Dog avatars slide toward each other, overlap, heart icon pops | Dual `slideX` + `scale` on heart with `emphasis` timing |

**Haptics:**

| Event | Haptic Type | Flutter |
|-------|------------|---------|
| Scan button press | Medium impact | `HapticFeedback.mediumImpact()` |
| Successful ID result | Light impact | `HapticFeedback.lightImpact()` |
| XP gain | Selection click | `HapticFeedback.selectionClick()` |
| Achievement unlock | Heavy impact | `HapticFeedback.heavyImpact()` |
| Error / wrong input | Heavy impact (double) | `HapticFeedback.heavyImpact()` x2 with 100ms delay |
| Streak milestone (7, 30, 100) | Heavy impact | `HapticFeedback.heavyImpact()` |
| Pull to refresh threshold | Light impact | `HapticFeedback.lightImpact()` |

**Loading States:**
- Skeleton screens for all list views (dogs nearby, feed, collection) — warm gray shimmer on cream background, never blank white
- Camera inference: circular progress ring around the capture button in accent gold
- Network requests: bottom snackbar with paw-print spinner, auto-dismiss on completion
- Never show a bare `CircularProgressIndicator` — always wrap in branded styling

### Design Tokens — Consolidated Reference

**Color Tokens:**

| Token | Light Mode | Dark Mode | CSS Variable | Flutter Constant |
|-------|-----------|-----------|-------------|-----------------|
| `color.primary` | `#4A2F1A` | `#C4956A` | `--color-primary` | `AppColors.primary` |
| `color.primaryLight` | `#6B4832` | `#D4A87A` | `--color-primary-light` | `AppColors.primaryLight` |
| `color.primaryDark` | `#2E1A0E` | `#8B6440` | `--color-primary-dark` | `AppColors.primaryDark` |
| `color.secondary` | `#2D5A3D` | `#4A7C5C` | `--color-secondary` | `AppColors.secondary` |
| `color.secondaryLight` | `#4A7C5C` | `#6B9E7C` | `--color-secondary-light` | `AppColors.secondaryLight` |
| `color.accent` | `#D4A843` | `#E8B94A` | `--color-accent` | `AppColors.accent` |
| `color.accentBright` | `#F0C246` | `#F5D060` | `--color-accent-bright` | `AppColors.accentBright` |
| `color.background` | `#FAF7F2` | `#1A1410` | `--color-bg` | `AppColors.background` |
| `color.surface` | `#F5F0E8` | `#241C14` | `--color-surface` | `AppColors.surface` |
| `color.surfaceElevated` | `#EDE6D9` | `#3A2E22` | `--color-surface-elevated` | `AppColors.surfaceElevated` |
| `color.onPrimary` | `#FFFFFF` | `#1A1410` | `--color-on-primary` | `AppColors.onPrimary` |
| `color.onBackground` | `#2C2419` | `#E8DFD1` | `--color-on-bg` | `AppColors.onBackground` |
| `color.onSurface` | `#6B5E50` | `#A89880` | `--color-on-surface` | `AppColors.onSurface` |
| `color.success` | `#3D8B5E` | `#5AAF7A` | `--color-success` | `AppColors.success` |
| `color.warning` | `#C4882F` | `#D4A04A` | `--color-warning` | `AppColors.warning` |
| `color.error` | `#C4483E` | `#D46A60` | `--color-error` | `AppColors.error` |
| `color.info` | `#4A7A9B` | `#6A9ABB` | `--color-info` | `AppColors.info` |

**Typography Tokens:**

| Token | Font | Size | Weight | Line Height | Letter Spacing | Flutter |
|-------|------|------|--------|-------------|---------------|---------|
| `type.display` | Nunito | 36px | 800 | 1.2 | -0.5px | `AppTypography.display` |
| `type.h1` | Nunito | 28px | 700 | 1.25 | -0.3px | `AppTypography.h1` |
| `type.h2` | Nunito | 22px | 700 | 1.3 | 0 | `AppTypography.h2` |
| `type.h3` | Nunito | 18px | 600 | 1.35 | 0 | `AppTypography.h3` |
| `type.bodyLg` | Source Sans 3 | 16px | 400 | 1.5 | 0 | `AppTypography.bodyLg` |
| `type.body` | Source Sans 3 | 14px | 400 | 1.5 | 0 | `AppTypography.body` |
| `type.bodySm` | Source Sans 3 | 12px | 400 | 1.4 | 0.1px | `AppTypography.bodySm` |
| `type.caption` | Source Sans 3 | 11px | 600 | 1.35 | 0.3px | `AppTypography.caption` |
| `type.mono` | JetBrains Mono | 14px | 500 | 1.4 | 0 | `AppTypography.mono` |

**Spacing Tokens:**

| Token | Value | CSS Variable | Flutter |
|-------|-------|-------------|---------|
| `space.xs` | 4px | `--space-xs` | `AppSpacing.xs` (4.0) |
| `space.sm` | 8px | `--space-sm` | `AppSpacing.sm` (8.0) |
| `space.md` | 12px | `--space-md` | `AppSpacing.md` (12.0) |
| `space.base` | 16px | `--space-base` | `AppSpacing.base` (16.0) |
| `space.lg` | 20px | `--space-lg` | `AppSpacing.lg` (20.0) |
| `space.xl` | 24px | `--space-xl` | `AppSpacing.xl` (24.0) |
| `space.2xl` | 32px | `--space-2xl` | `AppSpacing.xxl` (32.0) |
| `space.3xl` | 40px | `--space-3xl` | `AppSpacing.xxxl` (40.0) |
| `space.4xl` | 48px | `--space-4xl` | `AppSpacing.xxxxl` (48.0) |
| `space.5xl` | 64px | `--space-5xl` | `AppSpacing.xxxxxl` (64.0) |

**Radius Tokens:**

| Token | Value | CSS Variable | Flutter |
|-------|-------|-------------|---------|
| `radius.sm` | 8px | `--radius-sm` | `AppRadius.sm` (8.0) |
| `radius.md` | 12px | `--radius-md` | `AppRadius.md` (12.0) |
| `radius.lg` | 16px | `--radius-lg` | `AppRadius.lg` (16.0) |
| `radius.xl` | 20px | `--radius-xl` | `AppRadius.xl` (20.0) |
| `radius.2xl` | 24px | `--radius-2xl` | `AppRadius.xxl` (24.0) |
| `radius.full` | 999px | `--radius-full` | `AppRadius.full` (999.0) |

**Shadow Tokens:**

| Token | CSS | Flutter |
|-------|-----|---------|
| `shadow.subtle` | `0 1px 3px rgba(74,47,26,0.08)` | `AppShadows.subtle` |
| `shadow.card` | `0 2px 8px rgba(74,47,26,0.12)` | `AppShadows.card` |
| `shadow.elevated` | `0 4px 16px rgba(74,47,26,0.16)` | `AppShadows.elevated` |
| `shadow.modal` | `0 8px 32px rgba(74,47,26,0.24)` | `AppShadows.modal` |

**Animation Tokens:**

| Token | Duration | Curve | Flutter |
|-------|----------|-------|---------|
| `motion.instant` | 100ms | easeOut | `AppMotion.instant` / `AppMotion.curveInstant` |
| `motion.fast` | 200ms | easeOut | `AppMotion.fast` / `AppMotion.curveFast` |
| `motion.standard` | 300ms | easeInOut | `AppMotion.standard` / `AppMotion.curveStandard` |
| `motion.emphasis` | 500ms | easeInOutCubic | `AppMotion.emphasis` / `AppMotion.curveEmphasis` |
| `motion.dramatic` | 800ms | easeInOutCubic | `AppMotion.dramatic` / `AppMotion.curveDramatic` |

---

*Document version: 1.0 — March 15, 2026*
*Author: Jesse (founder) with strategic advisory from Claude*
*Next review: After Play Store launch or at 500 MAU, whichever comes first*
