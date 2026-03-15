# Go-to-Market — DogQuest

---

## 1. Market Context

### The Pet Tech Landscape

The global pet care market exceeded $150 billion in 2025 and continues growing at 6-7% annually. Within that, pet tech — apps, wearables, telehealth — is the fastest-growing segment, driven by the "pet humanization" trend: owners treat dogs as family members and spend accordingly. There are 65 million dog-owning households in the US alone, and the average owner spends $1,500+ per year on their dog.

### Why Now

Three forces converge to make DogQuest's timing ideal:

1. **On-device ML is mature.** TFLite and EfficientNet models run inference in under 500ms on mid-range Android phones. Two years ago, this required cloud APIs with latency and cost. Now a 10 MB model delivers 87%+ accuracy locally, with no server costs.

2. **Dog culture has gone mainstream.** Dog content dominates TikTok (billions of views on #dogsoftiktok), Reddit's dog communities exceed 10 million combined subscribers, and "what breed is my dog?" is one of the most common questions on r/dogs. The audience is massive, engaged, and actively searching for answers DogQuest provides.

3. **No one has combined the pieces.** Dog Scanner does identification (poorly). Nextdoor does local community (generically). Duolingo does gamification (for languages). No app combines breed ID + gamification + local social for dog owners. The gap is wide open.

### Opportunity for a Solo Founder

The dog breed ID category has no dominant player. Dog Scanner is the closest competitor at ~2M downloads, but their reviews complain about accuracy, aggressive upsells, and lack of features beyond basic ID. A solo founder with a better product, genuine community presence, and the Shazanimal backstory can carve out a meaningful niche with zero budget — because the content (breed ID results) is inherently shareable and the communities (Reddit, Facebook groups) are already organized around the exact use case.

The bar is low. Dog owners are underserved by lazy apps. Ship something good, show up authentically, and the first 500 users will find you.

---

## 2. Launch Strategy

### Phase 1: Pre-Launch (Weeks -8 to -1)

**Goal:** Build a waitlist of 100+ beta testers and establish credibility in 3-5 dog communities.

- Weeks -8 to -5: Lurk and contribute in target subreddits and Facebook groups. Answer breed questions. Share dog knowledge. Build a post history that proves you care about dogs, not just downloads.
- Weeks -4 to -3: Start teasing DogQuest in relevant conversations ("I've been building something for this exact problem..."). Recruit beta testers from people who engage with your helpful comments.
- Weeks -2 to -1: Closed Play Store beta with 50-100 testers. Collect feedback on first-run experience, ID accuracy, and retention hooks. Fix critical bugs. Prepare launch content.

### Phase 2: Soft Launch (Weeks 1-2)

**Goal:** 50-100 active users with D7 retention above 25%.

- Open Play Store listing (public but not promoted). Let beta testers leave reviews first — aim for 15-20 reviews at 4+ stars before any promotion.
- Monitor crash reports (Sentry/Firebase), ID accuracy complaints, and onboarding drop-offs.
- Iterate daily on the top 3 friction points users report.
- Do NOT promote heavily yet. This phase is about fixing the leaky bucket before pouring water in.

### Phase 3: Public Launch (Weeks 3-4)

**Goal:** 200+ downloads in the first week of promotion.

- Coordinated content push across Reddit, TikTok/Reels, Facebook groups, and Product Hunt.
- Launch week content calendar (see Section 4).
- Engage every single commenter, reviewer, and question-asker personally.
- Track install-to-first-ID conversion rate. If below 60%, the onboarding is broken — fix before spending more energy on acquisition.

---

## 3. Pre-Launch Playbook

### Week -8: Establish Presence

**Reddit (2 hours/day, 5 days)**
- Join and subscribe to: r/dogs (5M+), r/IDmydog (200K+), r/dogpictures (4M+), r/rarepuppers (3M+), r/WhatBreedIsMyDog, r/DogAdvice, r/Dogtraining, r/mutt, r/mixedbreeds
- Join 3-5 breed-specific subs relevant to breeds you can ID well: r/goldenretrievers, r/germanshepherds, r/labrador, r/husky, r/corgi
- Spend this week ONLY commenting helpfully. Answer "what breed is my dog?" posts with genuine analysis. Share breed facts. Upvote good content. Post nothing about DogQuest.
- Goal: 20+ helpful comments across multiple subs. Build karma and recognition.

**Facebook (1 hour/day, 3 days)**
- Join 5-10 Facebook groups: "Dog Breed Identification," "What Breed Is My Dog?", "Dog Lovers Community," "Mixed Breed Dog Owners," and 2-3 breed-specific groups.
- Same approach: help, don't promote. Answer breed questions with detailed responses.

### Week -7: Deepen Engagement

**Reddit**
- Continue commenting (15+ comments this week).
- Make your first standalone posts in r/dogs or r/IDmydog — share interesting breed knowledge, not app promotion. Example: "I've been studying dog breeds for months — here's how to tell apart a Shiba Inu from an Akita" with a side-by-side photo comparison.
- Respond to every reply on your posts.

**TikTok/Instagram**
- Create your DogQuest account on both platforms.
- Film 3 raw "what breed is that?" videos at a dog park (without the app — just you identifying breeds and sharing fun facts). Post on both platforms.
- Use hashtags: #dogsoftiktok #dogbreeds #whatbreedismydog #dogpark #doglover
- These videos establish your authority BEFORE you ever show the app.

### Week -6: Tease the App

**Reddit**
- When answering a "what breed?" post, casually mention: "I've actually been building an app that does this — still in development, but the ML model is getting really good at mixed breeds." Do this once or twice, naturally. Do NOT drop links.
- If anyone asks about the app, reply with genuine enthusiasm and ask if they'd want to beta test.

**Content Creation**
- Film 2-3 videos showing the app in action: point camera at dog, instant breed result with confidence score, rarity tier reveal. Keep videos under 30 seconds.
- Do NOT post these yet. Stockpile for launch week.

### Week -5: Beta Recruitment Round 1

**Reddit**
- Post in r/dogs (if rules allow) or r/androidapps: "I'm a solo developer building a dog breed identification app with gamification — looking for beta testers." Be transparent about being the developer. Include 2-3 screenshots.
- DM users who expressed interest in previous weeks.
- Target: 30 beta signups.

**Facebook Groups**
- Post beta recruitment in 2-3 groups where you've been active. "Hey everyone, I've been answering breed questions here for weeks and it inspired me to build an app for this. Looking for beta testers."
- Target: 20 beta signups.

### Week -4: Closed Beta Launch

- Publish closed beta on Google Play (Internal Testing track, then Open Testing).
- Send Play Store opt-in links to all beta signups.
- Create a simple feedback form (Google Forms): What device? First breed scanned? Was the ID correct? What's missing? Would you use this daily?
- Post in beta tester group/thread: "Beta is live! Here's the link."
- Target: 50 installs from beta testers.

### Week -3: Iterate on Beta Feedback

- Review every piece of feedback daily. Categorize into: critical bugs, accuracy complaints, UX confusion, feature requests.
- Ship 2-3 bug fix updates during this week.
- Reach out personally to every beta tester who reported an issue: "Fixed the bug you found — thanks for catching it."
- Ask top 10 most engaged testers to leave honest Play Store reviews when you go public.
- Film 2 more "breed ID in action" videos using polished beta build.

### Week -2: Content Stockpile

- Record 5-7 short-form videos (15-30 seconds each):
  - "POV: You finally find out what breed your rescue actually is" (point at mixed breed, show result)
  - "This dog is rarer than you think" (scan a rare breed, show Legendary tier)
  - "I scanned 10 dogs at the park — here's what happened" (montage)
  - "Day 1 of collecting every dog breed" (show empty kennel, first scan)
  - "The app that turns dog walks into treasure hunts"
- Write 3 Reddit posts for launch week (drafts, not posted yet).
- Prepare Product Hunt listing (ship page with description, screenshots, maker story).

### Week -1: Final Prep

- Move Play Store listing from closed to open beta (or production).
- Ensure 10-15 genuine reviews are posted by beta testers.
- Finalize Play Store screenshots, description, and metadata.
- Schedule launch week content (see Section 4).
- Test the full onboarding flow on 3 different Android devices.
- Set up basic analytics dashboard: daily installs, D1/D7 retention, first-ID completion rate.
- Tell your beta testers: "We go public next Monday. If you love the app, a Play Store review this week would mean the world."

---

## 4. Launch Week Plan

### Monday — Reddit Day

- **Morning (9 AM):** Post in r/IDmydog: "I built an AI app that identifies dog breeds — here's how it works on 20 different dogs" with a gallery of before/after screenshots (dog photo → breed result). Flair appropriately; follow sub rules exactly.
- **Midday (12 PM):** Post in r/dogs (check rules for self-promotion — some allow "Show & Tell" or weekly threads): honest maker story. "I'm a solo developer who spent 6 months training an ML model on 294 dog breeds. Here's what I built."
- **Evening:** Respond to EVERY comment on both posts. Answer breed questions from other posts using the app live (screenshot the result, share it as a reply).
- **Metrics to watch:** Post upvotes, comment sentiment, Play Store installs, crash reports.

### Tuesday — TikTok/Reels Day

- **Post Video 1:** "POV: You finally find out what breed your rescue is" — your strongest, most satisfying video. Post on TikTok AND Instagram Reels simultaneously.
- **Post Video 2 (4 hours later):** "I scanned 10 dogs at the park" montage.
- **Engage:** Reply to every comment. Answer "scan my dog!" requests with "Drop a photo and I'll run it through the app!"
- **Metrics:** Views, comments, profile visits, Play Store referral traffic.

### Wednesday — Facebook Groups

- Post in 3-5 Facebook dog groups where you've been active: "Hey everyone — the breed ID app I mentioned is now live on Play Store. It's free, uses AI, and I built it solo. Would love your feedback." Include 2 screenshots and the Play Store link.
- Respond to every comment within 2 hours.
- **Metrics:** Group post engagement, installs from Facebook referral.

### Thursday — Product Hunt

- Launch on Product Hunt. Use the maker story angle: "Solo developer built a Shazam for dogs — 294 breeds, gamification, social features."
- Share the Product Hunt link on Twitter/X, LinkedIn, and in your Reddit bio.
- Engage with every Product Hunt comment and upvoter.
- **Metrics:** Product Hunt upvotes, ranking, referral installs.

### Friday — Community Day

- Go to a dog park with your phone. Film 3-5 new breed ID videos in real-time.
- Post the best one on TikTok/Reels as a "Launch week — Day 5" update.
- Post a "Launch week update" in r/dogs or r/androidapps: share install numbers, user feedback, and what you're fixing based on feedback. Transparency builds trust.
- **Metrics:** Weekend retention (do Monday-Thursday installs come back?).

### Saturday-Sunday — Respond and Iterate

- Do NOT post new promotional content. Spend the weekend:
  - Responding to every Play Store review (positive and negative).
  - Fixing the #1 bug or UX complaint from the week.
  - Shipping a patch update with fixes.
  - Preparing Week 2 content.
- **Metrics:** D1 retention from Monday installs, crash-free rate, average session length.

### Launch Week Targets

| Metric | Target |
|--------|--------|
| Total installs | 150-250 |
| Play Store reviews | 20-30 |
| Average rating | 4.0+ stars |
| First-ID completion rate | 70%+ |
| D1 retention | 40%+ |
| Crash-free rate | 99%+ |

---

## 5. Post-Launch Growth

### Weeks 1-4: Fix the Funnel

**Priority:** Retention over acquisition. Do NOT chase downloads until the product retains.

- **Week 1-2:** Analyze onboarding funnel. Where do users drop off? Common failure points:
  - Camera permission denied → add a compelling permission rationale screen
  - First scan fails or is wrong → improve error states, show top-3 results
  - User scans one dog and never returns → ensure the "1/294 breeds collected" hook is visible and satisfying
- **Week 3-4:** Implement the top 3 retention improvements from user feedback. Common wins:
  - Push notifications for streak reminders (opt-in)
  - Daily challenge surfaced on app open
  - "Scan your dog" prompt for users who haven't set up a Dog Passport
- **Content cadence:** 2 TikTok/Reels per week, 3-5 Reddit comments per day, 1 Reddit post per week.

### Weeks 5-8: Growth Loops

**Priority:** Activate sharing mechanics. Each user should bring 0.3-0.5 additional users.

- **Share triggers:** After every breed ID, show a "Share Result" button that generates a branded card (breed name, confidence, rarity tier, DogQuest logo). Make the card look good enough that people WANT to post it on Instagram Stories.
- **Dog Passport sharing:** The Dog Passport card should be shareable as an image. When someone sees a friend's Dog Passport, they should think "I want one of those for my dog."
- **Breed collection milestones:** "I've identified 50 breeds!" share prompt. People love sharing collection progress (Pokemon Go proved this).
- **Reddit organic loop:** Continue answering breed ID questions on r/IDmydog. When your answer matches what the app would say, mention it naturally. This is not spam — it's being helpful with a relevant tool.
- **Content cadence:** 3 TikTok/Reels per week (lean into whatever format got the most views in weeks 1-4), 5 Reddit comments per day.

### Weeks 9-12: Investor Readiness

**Priority:** Compile metrics that prove retention and engagement for pre-seed pitch.

- By week 9, you should have 60-90 days of retention data. The metrics investors care about:
  - **D7 retention > 25%** (proves the app isn't a novelty)
  - **D30 retention > 12%** (proves habit formation)
  - **MAU growth rate > 15% month-over-month** (proves organic pull)
  - **Average session length > 3 minutes** (proves engagement depth)
  - **Sessions per user per week > 2** (proves repeat usage)
- **Start investor outreach when you have:**
  - 300+ MAU with measurable retention
  - At least 50 Play Store reviews at 4.0+ stars
  - A clear growth trajectory (not a spike that decayed)
  - The Shazanimal narrative fully framed (DogQuest metrics + AviQuest existence = platform proof)
- **Outreach targets:** Superorganism, Obvious Ventures, Lowercarbon Capital (already identified in fundraise plan). Lead with metrics, not vision. "DogQuest has 400 MAU with 28% D7 retention after 90 days of organic growth. Here's why that's the beginning of Shazanimal."
- **Content cadence:** Maintain 2-3 posts per week. Don't let content slip during fundraise prep.

### Growth Loop Diagram

```
User scans dog → Gets breed result with rarity tier
    ↓
Shares result card on Instagram/TikTok → Friend sees it
    ↓
Friend downloads DogQuest → Scans their own dog
    ↓
Friend shares THEIR result → Cycle repeats
```

Secondary loop:
```
User posts on Reddit "what breed is my dog?"
    ↓
You (or another DogQuest user) replies with app result
    ↓
OP downloads app to try it themselves
    ↓
OP answers ANOTHER breed question using DogQuest → Cycle repeats
```

---

## 6. Channel Strategy

### Channel 1: Reddit

**ROI Rank:** #1 (highest ROI for zero budget)

**Why:** r/IDmydog (200K+) and r/WhatBreedIsMyDog are literally the use case. People post photos asking "what breed is this?" every day. You can answer with the app and provide genuine value. r/dogs (5M+) has massive reach for launch announcements.

**What to Do:**
- **Daily (15-20 min):** Browse r/IDmydog, r/WhatBreedIsMyDog, r/dogs new posts. Answer 3-5 breed identification questions per day. Use the app to identify, then share your analysis with breed facts. Don't always mention the app — sometimes just be helpful.
- **Weekly (30 min):** Post one piece of content. Rotate between: breed comparison posts ("Shiba Inu vs. Akita — how to tell them apart"), collection milestones ("I've identified 100 breeds in my neighborhood"), and app updates ("Just shipped the v6 model with 294 breeds — accuracy improved 12%").
- **Monthly:** Share a transparent "indie dev update" post in r/androidapps or r/SideProject. Reddit loves authenticity. Share real metrics, real challenges, real learnings.

**Effort:** 30-45 minutes per day.

**Expected Return:** 100-200 installs per month from Reddit alone once you have a post history. Individual viral posts can drive 50-100 installs in a day.

**Timeline:** Start 8 weeks before launch. Never stop.

**Rules:**
- Read and follow each subreddit's self-promotion rules exactly. Many allow it in weekly threads only.
- Never post the same content to multiple subs simultaneously (crosspost = spam flag).
- If a post gets removed, message the mods politely. Don't repost.
- Your Reddit profile should link to DogQuest. Let people discover it organically.

---

### Channel 2: TikTok / Instagram Reels

**ROI Rank:** #2 (viral potential, but requires consistent content creation)

**Why:** Dog content is the most popular category on both platforms. "What breed is that?" is an inherently satisfying video format — point camera, get instant answer, reveal rarity. The before/after format is proven on short-form video.

**What to Do:**
- Film at dog parks, pet stores, on walks, at friends' houses. Every dog is content.
- **Core format:** 15-second video. Point phone at dog → app identifies breed → show fun fact or rarity tier. Add trending audio. Caption: "POV: You find out your neighbor's dog is actually a rare breed."
- **Post frequency:** 3x per week minimum. Daily is better if you can sustain it for the first month.
- **Hashtags:** #dogsoftiktok #dogbreed #whatbreedismydog #dogpark #doglovers #dogquest #doglover #rarepuppers #dogbreeds #pettech
- **Engage:** Reply to every comment. When people comment "scan my dog!", reply with "Drop a photo!" and then actually run it through the app and reply with the result.

**Effort:** 1-2 hours per week (filming + editing + posting + engaging).

**Expected Return:** Highly variable. Most videos get 200-500 views. One viral video (10K+ views) can drive 50-200 installs. Consistency matters more than any single video.

**Timeline:** Start 6 weeks before launch with non-app dog content. Switch to app-focused content at launch.

**Content Ideas (20-video backlog):**
1. "What breed is your dog? Let AI decide" (scan friend's dog)
2. "Rating dog breeds by rarity" (show tier system)
3. "I scanned every dog at the park" (montage, 5-8 dogs)
4. "This is the rarest dog breed I've ever found" (Legendary tier reveal)
5. "Day 1 of collecting every dog breed" (empty kennel → first scan)
6. "Can AI tell what breed a mutt is?" (scan a mixed breed, show percentages)
7. "Dog breed facts that will blow your mind" (fun facts from dogs.json)
8. "POV: Your rescue dog is actually a rare breed"
9. "Turning dog walks into a real-life Pokemon game"
10. "Testing AI on the hardest dog breeds to identify"

---

### Channel 3: Facebook Dog Groups

**ROI Rank:** #3 (high intent audience, but slower and more effort to build trust)

**Why:** Facebook dog groups are massive, engaged, and organized by breed. "What breed is my dog?" groups have 50K-500K members. These are dog owners who actively seek breed information.

**What to Do:**
- Join 8-10 groups: "Dog Breed Identification" (various sizes), "What Breed Is My Dog?", "Mixed Breed Dog Owners," "Dog Lovers Community," and 3-4 breed-specific groups for popular breeds.
- **Daily (10 min):** Answer 2-3 breed identification posts with detailed, helpful responses. Same approach as Reddit — be helpful first.
- **Weekly:** Share one piece of content when group rules allow. App screenshots, breed comparison graphics, or "I built this" maker stories.
- **After launch:** When answering breed questions, you can mention: "I actually built an app for this — here's what it says" with a screenshot. This feels helpful, not spammy, because you're answering their question AND showing your tool.

**Effort:** 20-30 minutes per day.

**Expected Return:** 30-80 installs per month. Facebook users skew older (30-50) and are more likely to be actual dog owners (your primary persona).

**Timeline:** Start 6 weeks before launch.

---

### Channel 4: Product Hunt

**ROI Rank:** #4 (one-time burst, good for credibility and investors)

**Why:** Product Hunt reaches tech-savvy early adopters and, crucially, investors who browse it for deal flow. A top-10 finish on your launch day gives you a credibility badge and a story for your pitch deck.

**What to Do:**
- **Prep (week -2):** Create your Product Hunt ship page. Write a compelling maker story. Prepare 5 screenshots and a 30-second demo GIF.
- **Launch day (Thursday is best):** Go live at 12:01 AM PT. Share the link across all your channels. Ask beta testers and supporters to upvote and comment.
- **During the day:** Respond to every comment within 1 hour. Be transparent about being a solo founder. Share your Shazanimal vision when asked about the roadmap.

**Effort:** 4-6 hours on launch day, 2 hours prep.

**Expected Return:** 100-300 installs if you finish in the top 10 for the day. 30-50 if you don't. The real value is the credibility badge and investor visibility.

**Timeline:** Launch week, Thursday.

---

### Channel 5: Dog Parks IRL

**ROI Rank:** #5 (post-launch retention and content, not acquisition)

**Why:** Dog parks are where DogQuest delivers its most compelling experience. Scanning real dogs in real time, meeting other owners, discovering breeds — this is the magic moment. Dog parks also solve two problems: content creation (film videos there) and user activation (show the app to people in person).

**What to Do:**
- **Weekly:** Visit 1-2 dog parks. Use the app openly. When someone asks "What are you doing?", demo it. This is the most natural sales pitch imaginable.
- **Content:** Film 2-3 videos per park visit. The "scanning dogs at the park" format is endlessly repeatable and each video features different breeds.
- **Grassroots:** If you meet a dog owner who loves the app, ask them to leave a review. Word-of-mouth from a park friend is the strongest acquisition channel — it just doesn't scale yet.
- **Flyers (if budget allows):** A simple flyer with a QR code at dog park bulletin boards. Cost: $5 at a print shop.

**Effort:** 2-3 hours per week (combined with actual dog park time — this should be fun, not work).

**Expected Return:** 5-15 installs per week from direct demos. Unlimited content value.

**Timeline:** Start at launch, continue indefinitely.

---

## 7. Content Strategy

### Core Content Format: "What Breed Is That?"

This is DogQuest's native content format. It works because it combines three things people love: dogs, mystery/reveal, and satisfying technology.

**The formula:**
1. Show a dog (3 seconds)
2. Point the app at it (2 seconds)
3. Reveal the breed with fun fact or rarity tier (5 seconds)
4. React or comment (2-3 seconds)

Total: 12-15 seconds. Perfect for TikTok/Reels.

### Content Pillars

**Pillar 1: Breed ID Reveals (60% of content)**
- "What breed is this?" — the core loop, filmed at parks, streets, pet stores
- Mixed breed reveals are the most compelling ("40% Lab, 30% Pit Bull, 20% Boxer")
- Rare breed discoveries get the most engagement ("I found a Legendary breed!")
- Variations: "Rating dogs by rarity," "Scanning every dog I see today," "Can AI identify a puppy?"

**Pillar 2: Breed Education (20% of content)**
- Fun facts from the breed database (dogs.json has 294 breeds with fun facts, temperament, origin)
- "3 things you didn't know about Golden Retrievers"
- "The rarest dog breed in the world" (Legendary tier breeds)
- Breed comparisons: "Shiba Inu vs. Akita — what's the difference?"
- These establish authority and provide value even to people who don't download the app

**Pillar 3: Maker/Behind-the-Scenes (15% of content)**
- "I'm a solo developer building a dog app — here's how the AI works"
- Training data compilation process, model accuracy improvements
- Indie dev journey updates: install milestones, user feedback, shipping features
- This content resonates on Reddit, Product Hunt, and Twitter/X

**Pillar 4: User-Generated Content (5% initially, growing to 30%)**
- Repost/share user breed ID results (with permission)
- "Our users found the rarest breeds this week" compilations
- Beta tester testimonials and reviews
- Dog Passport showcase: share users' shareable Passport cards

### Publishing Schedule

| Day | Platform | Content Type |
|-----|----------|-------------|
| Monday | TikTok + Reels | Breed ID reveal video |
| Tuesday | Reddit | Answer 3-5 breed questions in r/IDmydog |
| Wednesday | TikTok + Reels | Breed education or rare breed reveal |
| Thursday | Facebook Groups | Answer breed questions, share one app-related post |
| Friday | TikTok + Reels | "Scanning dogs at the park" montage |
| Saturday | Reddit | Weekly app update or breed knowledge post |
| Sunday | Rest | Plan next week's content |

**Total time commitment:** 5-7 hours per week across all channels.

### Content Creation Tips

- Film in landscape AND portrait simultaneously (or just portrait for TikTok/Reels).
- Always get verbal permission from dog owners before filming their dog.
- Natural lighting at parks is better than any ring light.
- Use CapCut (free) for editing. Add captions — 80% of TikTok is watched on mute.
- Batch content: film 5-7 videos in one park visit, post throughout the week.
- Save every video to a "content library" folder. Repurpose across platforms with different captions.

---

## 8. Community Strategy

### Reddit: Be the Breed Expert, Not the App Pusher

**The rule:** For every 1 post that mentions DogQuest, make 10 comments that are purely helpful. Reddit will destroy you if you violate this ratio.

**Practical approach:**
- Set a daily alarm: "Browse dog subs for 15 minutes." Answer questions, share knowledge, upvote good content.
- Use DogQuest to answer breed questions, but present the information as your own knowledge. "That looks like a Catahoula Leopard Dog — the blue merle coat and heterochromia are telltale signs." You used the app to confirm, but the comment is about the breed, not the app.
- When someone asks HOW you know so much about breeds, THEN mention the app. This is earned promotion.
- Maintain a presence in r/androidapps and r/SideProject for indie dev updates. These communities celebrate solo builders.

**Account hygiene:**
- Your Reddit profile should have a clear bio: "Solo developer building DogQuest. Dog breed nerd."
- Don't use an account name like "DogQuestApp" — use your personal account. People trust humans, not brands.
- If your post gets flagged as spam, don't argue. Message the mods, explain you're a solo dev, ask what's allowed. Most mods are reasonable if you approach them respectfully.

### Facebook Groups: The Long Game

- Facebook groups are moderated more heavily than Reddit. Many ban self-promotion entirely.
- Strategy: become a recognized "breed expert" in 3-5 groups over 4-6 weeks. Then, when you mention your app, the group already trusts you.
- Avoid groups that are primarily spam/promotion. Stick to groups with active moderators and real conversations.
- The most valuable Facebook groups are breed-specific (e.g., "German Shepherd Owners," "Labrador Lovers"). These users are passionate and will engage deeply with breed-specific content.

### Discord: Not Yet

- Don't build a Discord server until you have 200+ active users. Managing a dead Discord is worse than having none.
- When you do launch one, seed it with: #breed-id-results, #what-breed-is-this, #rare-breed-finds, #feature-requests, #bug-reports.
- Invite your most engaged users first. A Discord with 20 active members feels alive. A Discord with 200 silent members feels dead.

### Dog Park Meetups: Post-Launch Retention

- Once you have 10+ users in a single metro area, organize an informal "DogQuest meetup" at a local dog park. Post on the app's social feed and in local Facebook groups.
- The meetup IS the product. People bringing their dogs, scanning each other's breeds, comparing collections — this is DogQuest in real life.
- Film the meetup. This is your best content ever: real users, real dogs, real engagement.
- Start with one meetup. If it works, do monthly meetups in your city. If you have users in other cities, encourage them to organize their own.

---

## 9. Key Metrics

### Acquisition Metrics

| Metric | Target (90 days) | How to Measure |
|--------|-------------------|----------------|
| Total downloads | 500+ | Play Store Console |
| Weekly new installs | 40-60 by month 3 | Play Store Console |
| Install rate (listing views → installs) | 30%+ | Play Store Console |
| CAC (cost per acquisition) | $0 (organic only) | Time tracking |
| Time-per-install | < 15 min of effort | Manual tracking |
| Top acquisition channel | Reddit (40%+) | UTM params / Play Store referral |

### Activation Metrics

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Onboarding completion rate | 80%+ | Firebase event: onboarding_complete |
| First breed ID within 5 minutes | 65%+ | Firebase event: first_identification |
| Camera permission grant rate | 85%+ | Firebase event: camera_permission |
| First collection view | 70%+ | Firebase event: kennel_viewed |

### Retention Metrics

| Metric | Target | Why It Matters |
|--------|--------|---------------|
| D1 retention | 40%+ | First impression — did the magic moment land? |
| D7 retention | 25%+ | Did gamification hook them for the week? |
| D30 retention | 12%+ | Habit formed — this is the investor metric |
| Weekly sessions per user | 2.5+ | Proves utility beyond novelty |
| Average session length | 3+ minutes | Proves engagement depth |
| Streak maintenance rate | 20%+ of active users | Gamification is working |

### Revenue Metrics

| Metric | Target | Notes |
|--------|--------|-------|
| AdMob banner impressions/day | Scale with DAU | Non-intrusive placements only |
| AdMob RPM (revenue per 1K impressions) | $1-3 | Typical for utility apps |
| Daily ad revenue at 100 DAU | $0.50-1.50 | Roughly $15-45/month |
| Daily ad revenue at 500 DAU | $2.50-7.50 | Roughly $75-225/month |

### Investor-Relevant Metrics

| Metric | What Investors Want to See |
|--------|--------------------------|
| MAU growth rate | 15%+ month-over-month (organic) |
| D30 retention | 12%+ (proves habit, not novelty) |
| Session frequency | 2.5+ sessions/week (proves daily utility) |
| Collection completion % | Average user has identified 10+ breeds (proves engagement depth) |
| Social feature adoption | 20%+ of users have created a Dog Passport or followed another user |
| NPS or review sentiment | 4.0+ stars, reviews mentioning "addictive" or "fun" |
| Organic acquisition % | 80%+ (proves product-market pull, not paid push) |

---

## 10. Budget Considerations

### $0 Budget Launch Plan

Everything in this document is executable at zero cost:

| Item | Cost | Notes |
|------|------|-------|
| Google Play Developer Account | $25 (one-time) | Already paid if AviQuest is listed |
| Supabase | $0 | Free tier: 50K MAU, 500 MB database, 1 GB storage, 2 GB bandwidth |
| Firebase Analytics | $0 | Free tier covers all analytics needs |
| AdMob | $0 | Revenue, not cost |
| TikTok/Instagram/Reddit | $0 | Organic content only |
| Video editing (CapCut) | $0 | Free mobile editor |
| Product Hunt | $0 | Free to launch |
| App hosting/CDN | $0 | On-device ML, no server for inference |

**Total launch cost: $0** (assuming Play Store account exists).

### Where to Spend the First $100-500

If you find $100-500 (from early ad revenue, personal funds, or a small grant):

| Priority | Item | Cost | Expected Return |
|----------|------|------|-----------------|
| 1 | Dog park flyers with QR codes (200 flyers) | $15-30 | 20-40 installs, hyperlocal |
| 2 | Supabase Pro upgrade (if approaching free tier limits) | $25/month | Unlocks 100K MAU, 8 GB database |
| 3 | Canva Pro (for branded share cards and store assets) | $13/month | Better visual content across all channels |
| 4 | One promoted Reddit post (r/dogs allows promoted content) | $50-100 | 100-300 targeted installs |
| 5 | TikTok Promote on your best-performing video | $20-50 | Amplify proven content to 5K-20K views |
| 6 | Coffee for a dog influencer meetup | $10 | Potential content collaboration |

**Do NOT spend money on:** Google Ads, Facebook Ads, influencer payments, PR agencies, or any paid acquisition until you have proven organic retention (D30 > 12%).

### Supabase Free Tier Limits

| Resource | Free Tier Limit | When You'll Hit It |
|----------|----------------|-------------------|
| Database | 500 MB | ~50K dog profiles + social data |
| Auth MAU | 50,000 | Not a concern until massive scale |
| Storage | 1 GB | ~5,000 dog photos at 200 KB each |
| Bandwidth | 2 GB/month | ~1,000 active users with moderate sync |
| Realtime connections | 200 concurrent | ~500 DAU with live map features |
| Edge functions | 500K invocations/month | Depends on usage patterns |

**Upgrade trigger:** When you consistently hit 80% of any limit, upgrade to Pro ($25/month). This is unlikely before 1,000 active users.

### AdMob Revenue Projections

| DAU | Daily Impressions | Daily Revenue | Monthly Revenue |
|-----|-------------------|--------------|-----------------|
| 50 | 150-250 | $0.15-0.75 | $5-23 |
| 100 | 300-500 | $0.30-1.50 | $9-45 |
| 500 | 1,500-2,500 | $1.50-7.50 | $45-225 |
| 1,000 | 3,000-5,000 | $3-15 | $90-450 |
| 5,000 | 15,000-25,000 | $15-75 | $450-2,250 |

**Assumptions:** 3-5 ad impressions per session, 1 session per DAU per day, $1-3 RPM. Reality will vary based on user geography, session length, and ad placement.

AdMob revenue at 500 users will not cover living expenses. It covers Supabase Pro and maybe a coffee. The real monetization event is the pre-seed round, not ad revenue. Ads exist to prove the revenue model works, not to fund the company.

---

## 11. Risks

### Risk 1: Reddit Anti-Spam Detection

**Severity:** High
**Likelihood:** Medium

Reddit's spam filters and moderators aggressively remove self-promotion. If your posts get flagged, you lose your primary acquisition channel.

**Mitigation:**
- Follow the 10:1 rule religiously: 10 helpful comments for every 1 mention of DogQuest.
- Build 6-8 weeks of post history before ANY self-promotion.
- Read each subreddit's rules before posting. Some have weekly self-promotion threads — use those.
- If a post is removed, message the mods politely. Ask what format would be acceptable.
- Diversify: don't put 100% of your acquisition strategy on Reddit. If Reddit shuts you down, TikTok and Facebook groups still work.
- Use your personal account, not a branded account. Humans get more leeway than brands.

### Risk 2: Low Retention After Novelty Wears Off

**Severity:** High
**Likelihood:** Medium

Users scan their own dog, maybe a friend's dog, then never open the app again. The "what breed?" question has a finite number of dogs in someone's life.

**Mitigation:**
- This is why gamification exists. The collection mechanic (294 breeds, rarity tiers, themed sets) gives users a reason to scan dogs beyond their immediate circle.
- Daily challenges and streaks create habitual check-ins independent of breed scanning.
- Social features (neighborhood feed, Dogs Nearby) provide content even when the user isn't scanning.
- Monitor D7 and D30 retention obsessively. If D7 drops below 20%, the gamification isn't working and needs redesign.
- The lost-dog feature and playdate matcher provide utility that doesn't depend on breed scanning at all.

### Risk 3: ML Accuracy Erodes Trust

**Severity:** High
**Likelihood:** Medium

The v5.1 model covers 150 breeds at 87.2% accuracy. That means 1 in 8 scans is wrong. If users' first experience is a wrong breed identification, they may uninstall immediately.

**Mitigation:**
- Show confidence scores, not just top-1 results. "85% Labrador, 10% Golden Retriever" feels honest. "This is a Labrador" when it's wrong feels broken.
- Show top-3 results so the correct breed is almost always visible.
- Add a "Not right? Try again" button that encourages a re-scan from a different angle.
- Prioritize shipping the v6 model (294 breeds, EfficientNetV2-S) which should improve accuracy on the expanded breed set.
- Collect user corrections as training data for future model versions.

### Risk 4: Competitor Response

**Severity:** Medium
**Likelihood:** Low (short-term), Medium (long-term)

Dog Scanner or a well-funded startup could copy the gamification + social approach.

**Mitigation:**
- **Speed is the moat.** Ship features faster than funded teams can hold meetings about them. You're already 34 screens and 50+ services deep — that's 6+ months of head start.
- **The local social graph is the real moat.** Once users have dog friendships, neighborhood connections, and playdate history in DogQuest, switching costs are high. This data doesn't transfer.
- **The Shazanimal platform story is defensible.** Competitors see a dog app. You see a multi-species platform. AviQuest (1,049 bird species) already proves the pattern. Investors fund vision, not features.
- First-mover advantage in "gamified breed ID" establishes the category association.

### Risk 5: Solo Founder Burnout

**Severity:** High
**Likelihood:** High

Coding, content creation, community management, user support, investor outreach, model training, and Play Store management — all on one person. Burnout is not a risk, it's a certainty without boundaries.

**Mitigation:**
- **Time-box everything.** Community management: 1 hour/day max. Content creation: 2 hours/week max (batch on weekends). Coding: whatever's left.
- **Automate what you can.** Scheduled posts (Buffer, free tier). Canned responses for common support questions. Firebase alerts instead of manual monitoring.
- **Batch content.** One park visit = 5-7 videos for the week. One Reddit session = 5 comments. Don't context-switch between channels throughout the day.
- **Set a "no work" day.** One day per week with zero DogQuest activity. Not negotiable.
- **Remember the 90-day scope.** The goal is 500 users and a pre-seed pitch, not 50,000 users and profitability. Scope your effort to the goal.

### Risk 6: Play Store Rejection or Policy Issues

**Severity:** Medium
**Likelihood:** Low

Google Play has policies around data collection (especially location for the map features), ad implementation, and content targeting.

**Mitigation:**
- Submit a complete privacy policy before your first upload. Disclose location data collection, analytics, and ad identifiers.
- Use Google's data safety form accurately — don't skip optional fields.
- Ensure AdMob implementation follows Google's ad placement policies (no ads on camera screen, no accidental click patterns).
- Test on multiple devices before submission. Crashes during review = rejection.
- If rejected, read the rejection reason carefully, fix it, and resubmit. Most rejections are procedural, not fundamental.

### Risk 7: Supabase Migration Complexity

**Severity:** Medium
**Likelihood:** Medium

The app currently uses local Hive storage. Migrating to Supabase for social features adds complexity: auth migration, data sync, real-time subscriptions, and a new failure mode (network dependency).

**Mitigation:**
- Keep the local-first architecture. Supabase augments Hive, it doesn't replace it. Core features (breed ID, collection, gamification) must work offline.
- Ship Supabase social features as a separate phase AFTER the core app is stable on Play Store.
- Use Supabase's offline-first patterns: queue writes locally, sync when connected.
- Don't block launch on Supabase. Launch with local-only features, then add social as a post-launch update. Users will see it as "new features" rather than delayed launch.

---

## Appendix: 90-Day Timeline Summary

| Week | Phase | Key Actions | Target |
|------|-------|-------------|--------|
| -8 to -6 | Pre-launch | Build Reddit/Facebook presence, answer breed questions daily | 50+ helpful comments |
| -5 to -4 | Beta recruitment | Recruit beta testers from communities | 50 beta installs |
| -3 to -2 | Beta iteration | Fix bugs, collect feedback, stockpile content | 15+ Play Store reviews |
| -1 | Final prep | Open listing, finalize assets, schedule launch content | Launch-ready |
| 1 | Launch week | Reddit + TikTok + Facebook + Product Hunt push | 150-250 installs |
| 2-4 | Fix the funnel | Analyze onboarding, fix retention leaks, iterate | D7 > 25% |
| 5-8 | Growth loops | Activate sharing, grow content cadence, optimize | 300+ total installs |
| 9-12 | Investor readiness | Compile metrics, begin outreach, pitch with live data | 500+ installs, pitch ready |

---

*This document is a living playbook. Update it weekly with what's working, what's not, and what's next. The tactics here are starting points — the real strategy emerges from user feedback and data.*
