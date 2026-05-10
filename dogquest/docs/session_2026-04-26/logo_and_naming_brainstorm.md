# Logo (no-paw) + Naming Brainstorm

**Status:** Draft for review. T2 design exploration; do NOT implement until T1 closes.
**Author:** Claude (ui-ux-designer skill).
**Date:** 2026-04-26.
**Companion file:** `logo_and_naming_brainstorm_logos.svg` (visual mockups).
**Supersedes:** the paw-based logo directions in `visual_design_refresh_plan.md` §4.2 (those preserved recognition; this set goes for distinctiveness).

---

## 0. Why a non-paw mark

A paw is the obvious move and that's the problem. Rover, Wag, BarkBox, Pup-Park, Pawprint, Tractive, Fi, BringFido — basically the entire pet-app shelf is a paw on a coloured tile. DogQuest's current paw + spark is well-executed but indistinguishable from the rest of the shelf at thumbnail scale.

The directions below are picked for **category differentiation** first, **memorability** second, **production cost** third. None of them use a paw.

---

## 1. Twelve concepts considered

Brainstormed and discarded:

| # | Concept | Verdict |
|---|---|---|
| 1 | **Snout / nose mark** | KEEP → Direction C. Iconic dog detail, unused in the category. |
| 2 | **Dog head profile silhouette** | Discard. Generic; every shelter logo does this. |
| 3 | **Dog ID tag (collar tag)** | KEEP → Direction B. Unused in pet apps, perfect symbolic fit (ID + collection + lost-dog). |
| 4 | **Compass + ear** | Discard. Too literal a mash-up; reads "Boy Scouts for dogs". |
| 5 | **Constellation / Dog Star** | KEEP → Direction A. Sirius lore is gold, ownable, premium. |
| 6 | **Letter monogram with tail-tail descender** | KEEP → Direction D. Modern brand approach (Airbnb bélo, Slack hash). |
| 7 | **Heart-snout (kawaii)** | Discard. Too cute; clashes with collector/quest tone. |
| 8 | **Bone + arrow** | Discard. Bone is even more generic than paw. |
| 9 | **Eye-of-the-dog** | Discard. Reads cult/horror at small sizes. |
| 10 | **Two profiles facing (friendship)** | Discard. Reads dating app. |
| 11 | **Origami dog** | Discard. Trendy 2018; tired by 2026. |
| 12 | **Beacon/pin with dog ear** | Discard. Reads navigation app, not pet app. |

The four kept concepts are developed below and rendered in the SVG.

---

## 2. Direction A — **The Dog Star** (recommended)

**Concept.** Sirius is the brightest star in the night sky and the literal "Dog Star" — the head of constellation Canis Major. It is the perfect lore for an app that is simultaneously about discovery (questing), identification (find your dog among 294), and finding lost dogs (a beacon to follow home). One symbol carries all three meanings.

**Mark.** A bold 8-point star in amber on dark forest green. At >256px the star reveals a tiny minimal dog silhouette in negative space at its centre, and a faint scatter of smaller stars (constellation dots) around it. At launcher size (48px), the dog silhouette disappears and you see just the star — still clearly distinct from any paw.

**Why it wins.**
- Most ownable in the pet category. No competitor uses celestial symbolism.
- Scales perfectly: 16px favicon = star outline; 1024px hero = star + dog silhouette + constellation.
- Carries built-in marketing copy: *"Every dog has a star."* / *"Follow the Dog Star."* / *"294 stars to collect."*
- Pairs with the existing `amber500` brand colour without re-teaching users the palette.

**Risks.**
- Astrology/horoscope vibe if the star is too elaborate. Mitigated by keeping it geometric (4 or 8-point, not whimsical 5-point).
- Loses recognition with the existing paw-installed user base. For a pre-launch app with <100 installs, this is a fine cost.

---

## 3. Direction B — **The Tag** (strongest narrative)

**Concept.** A dog ID tag — the metal disc that hangs off every collar. Rounded rectangle or heart-shape, with a small ring at the top and the brand monogram engraved in the centre. Symbolically the most loaded shape in the entire pet category: identification (ML breed ID), collection (collector tags), and lost-dog recovery (the literal piece of metal that brings a lost dog home).

**Mark.** A warm-white tag silhouette with subtle brushed-metal gradient (one stop, low contrast — not skeumorphic), amber engraving of a single letterform (the brand initial — `D`, `H`, `Q`, etc., depending on final name). Tag hangs from a small amber ring. On dark forest green tile.

**Why it wins.**
- Unmistakably about dogs without resorting to a literal dog. The collar tag is dog-coded the way a bone is, but with adult sophistication a bone never has.
- Built-in lost-dog narrative. The tag *is* the metaphor for the Lost-Dog Hub feature.
- The monogram approach scales the brand: one tag, one letter, regenerates instantly if the name changes.
- Premium feel — closer to Wild One or The Farmer's Dog than to BarkBox.

**Risks.**
- Engraved letter must be readable at 48px; choose a high-contrast bold letterform.
- Brushed-metal effect can date quickly if overdone — keep to a single linear gradient stop.

---

## 4. Direction C — **The Snout** (purely dog, zero paw)

**Concept.** A geometric front-view dog nose — the wet leather nose pad with two nostrils — abstracted to its simplest readable shape. The single most recognisable dog feature that isn't a paw, ear, or tail.

**Mark.** A rounded triangular snout shape (top edge curved inward like a heart-cleft) in warm-white, with two amber nostril dots, on dark forest green. Optional: a tiny amber "boop" highlight on the upper-left of the nose pad to suggest gloss. At small sizes, the nostrils stay readable; at large sizes, the gloss highlight reads as a star/sparkle.

**Why it wins.**
- 100% dog, 0% paw. Differentiates aggressively from the category.
- Tactile and warm — invites the universal "boop the snoot" gesture. Lower brand temperature than the other three; would suit a redesign that leans more caregiver and less collector.
- Cheapest to execute: it's two shapes (snout + nostrils).

**Risks.**
- Less narratively rich than A or B. It says "dog" but doesn't say "quest" or "find" or "collect".
- Some viewers will read the silhouette as a heart on first glance — that's actually a positive for the lost-dog/caregiver feature but could feel off-brand for the gamification side.

---

## 5. Direction D — **The Letter-mark** (modern brand move)

**Concept.** A single bold letterform (the brand initial) where one stroke or descender curls into a stylised dog tail. Pure typographic mark in the lineage of the Airbnb "bélo", the Slack hash, the Stripe wordmark, the Spotify circle. Lowest production cost, highest brand confidence when executed well.

**Mark.** A heavy sans-serif capital letter — `H` for Hound, `Q` for Quest, `S` for Sirius, etc. — in amber on dark forest green. The right vertical stroke (or a serif/leg) curls outward and upward into a tight dog tail. The letter is the dog. No other elements.

**Why it wins.**
- Most brand-confident move in the set. Says "we know what we are."
- Instantly scalable from favicon to billboard with zero loss.
- Pairs with whichever name is picked — the mark is generated from the name, not bolted to it.
- Easiest to evolve: monochrome, inverse, animated all flow naturally.

**Risks.**
- Highest typography skill required. A bad custom letterform looks amateur where a bad paw still works as a paw.
- Less explicitly "dog" — depends on the wordmark next to it to anchor the meaning.

---

## 6. Recommendation

**Lead with A (Dog Star) for the icon. Pair with D (letter-mark wordmark) for the wordmark.** This combo gives you:

- A distinctive, ownable icon (star) that holds up at every scale and ties to the strongest naming candidate (Sirius / DogStar).
- A confident, modern wordmark (custom letterform with a tail-curl) that locks the brand visually.
- A coherent brand narrative: *"Every dog is a star. Find yours. Find them home."*

If the trademark risk on Sirius (see §7) blocks the name, fall back to **DogStar** as the name and keep both A and D unchanged.

If you want a softer, more caregiver-coded brand (e.g. you decide the lost-dog feature is the headline, not the gamification), pick **B (The Tag)** instead.

---

## 7. Naming brainstorm

Categorised, with vibe + a quick trademark/availability gut-check. Treat all TM notes as **drift** — confirm with USPTO TESS + EU TMView + a Google + App-Store search before committing to anything.

### 7.1 Discovery / Quest category

| Name | Vibe | TM gut-check |
|---|---|---|
| **Sirius** | Premium, lore-heavy (Dog Star). Single word. | Sirius XM is in radio not pet — likely OK with disclaimer + .app TLD, but TM lawyer required. |
| **DogStar** | Accessible Sirius. Two-word but readable. | Some smaller pet rescues use it. Likely available with descriptor. |
| **Polaris** | North-star vibe, navigation. | Polaris Industries (snowmobiles) holds broad TM — high risk. |
| **Beacon** | Lost-dog signal, premium. | Many SaaS Beacons. Crowded. |
| **Lumen** | Light, warm. | Crowded SaaS namespace. |
| **Trove** | Treasure / collector. | Some tech companies; low risk in pet. |
| **Quest** | Strong but generic. | Quest Diagnostics (massive). High risk. |
| **Scout** | Outdoor + dog (literal scout dog). | Many uses; pet shelters use it widely. Crowded. |
| **Compass** | Navigation / quest. | Compass Real Estate is huge — high risk. |
| **Lookout** | Watchful, beacon. | Lookout is a security company. Crowded. |

### 7.2 Dog-evocative single words

| Name | Vibe | TM gut-check |
|---|---|---|
| **Hound** | Verb (to hound = to track) + noun. Strong, single syllable. | Greyhound buses, Greyhound TV — but plain "Hound" is freer. Likely OK for pet app. |
| **Snout** | Distinctive, dog-specific. | Mostly available. |
| **Howl** | Communication, pack, slightly wild. | "Howl" as TM has some uses (party app) but pet-app namespace likely free. |
| **Snoot** | Friendly ("boop the snoot"). | Mostly available in pet. |
| **Yip** | Bright, small-dog. | Some uses, fairly clear. |
| **Wuff** / **Wuf** | Onomatopoeic, friendly. | Many small uses. |
| **Mutt** | Inclusive (no breed snobbery), warm. | Mutt is widely used as a brand prefix. Plain "Mutt" likely contested. |
| **Tag** | Multi-meaning (ID tag, photo tag, "you're it"). | Tag Heuer holds the standalone hard. High risk. |
| **Patch** | Friendly, dog-name-coded. | Patch.com holds the news space. Risk. |
| **Fido** | Classic dog-name. Friendly. | Fido is a Canadian telecom. High risk. |
| **Rex** | Classic dog-name, regal. | Many small uses. |
| **Pup** | Friendly, generic. | Pup.com, many uses. Crowded. |
| **Bork** | Meme, humour. | Niche meme TM risk lower. |

### 7.3 Collector / Codex category

| Name | Vibe | TM gut-check |
|---|---|---|
| **Pawdex** | Pokédex pun, instant gamification read. | Some small uses. Likely OK. |
| **Houndex** | Dex framing without paw. | Mostly available. |
| **Caninex** | Premium, sciencey. | Mostly available, harder to pronounce. |
| **Pedigree** | Refined, breed-aware. | Pedigree dog food is massive. High risk. |
| **Kennelist** | Niche, slightly clunky. | Free namespace. |

### 7.4 Modern brandables (invented)

| Name | Vibe | TM gut-check |
|---|---|---|
| **Snoutly** | Cute + functional suffix. | Free. |
| **Houndee** | Friendly. | Free. |
| **Pawly** | Cute. | Some small uses. |
| **Yipster** | Edgy, hip-coded. | Free. |
| **Furli** | Soft, premium-ish. | Furla (handbags) close. Risk. |
| **Doggio** | Italian flair. | Mostly free in pet apps. |

### 7.5 Compound names

| Name | Vibe | TM gut-check |
|---|---|---|
| **DogQuest** (current) | Clear, descriptive. | Some indie uses. |
| **DogStar** | Strong dual-meaning. | Likely OK. |
| **MuttMap** | Map-feature-forward. | Free. |
| **PupTrail** | Outdoor + collection. | Free. |
| **TailMark** | Identification framing. | Free. |
| **SniffLog** | Identification + journaling. | Free. |

---

## 8. Shortlist — top 6 names ranked

1. **Hound** — Single syllable. Verb + noun. Dog-coded without saying "dog". Captures the identification mechanic ("hound out the breed"), the lost-dog feature ("hound them home"), and the explorer tone. Pairs with letter-mark logo Direction D (a bold "H" with a tail-curl). **My #1 recommendation.**

2. **Sirius** — Strongest brand lore in the entire shortlist. The Dog Star itself. Pairs perfectly with logo Direction A. Premium, ownable, internationally pronounceable. *Caveat:* trademark risk — Sirius XM doesn't compete in pet, but a lawyer call is mandatory before commit.

3. **DogStar** — The fall-back if Sirius is blocked. Same lore, more descriptive, lower TM risk. Two-word but reads as one. Still pairs with Direction A.

4. **Snout** — Best fit for logo Direction C. Dog-only, distinctive, tactile. Less bold than Hound; suits a more caregiver-coded brand pivot.

5. **Howl** — Pack-coded, communication-coded, has a built-in social-feature pitch ("Howl about your dog"). Pairs with letter-mark Direction D (the "H" with a tail-curl works for both Howl and Hound). Strong second choice.

6. **Pawdex** — Keeps a paw in the *name* (the user said no paw in the *logo*) and has the clearest gamification signal of the whole list (Pokédex pun). If the gamification angle is the headline marketing message, this is the most efficient name. Pairs less well with Directions A/B/C/D — better with a re-tooled paw mark, which defeats the purpose of this brainstorm.

**Final recommendation: name = Hound, icon = Direction A (Dog Star), wordmark = Direction D (H with tail-curl).** Combination story: *"Hound — every dog is a star. Find yours."*

If staying with the existing name **DogQuest** for now (cheapest path), the same icon (A) and wordmark approach (D, with a custom Q-curl-tail) still apply with minimal changes to the brainstorm.

---

## 9. Open questions for Jesse

1. **Rename or keep DogQuest?** Renaming has costs (re-listing, marketing reset, .com/.app domain re-acquisition, social handles). Closed-beta posture means now is the cheapest possible window if you're going to do it.
2. **Logo direction pick?** A (Dog Star, recommended), B (Tag), C (Snout), or D (Letter-mark)?
3. **TM clearance** — happy to commit to a name pending TM clearance, or want to clear before mockup investment?
4. **Brand archetype lean** — caregiver (lost-dog as headline) or explorer (collector as headline)? Affects which direction wins.

---

## 10. Confidence tags

- §1 concept brainstorm: **solid** on the discard reasoning, **uncertain** on whether the four picks are the four strongest of all conceivable directions.
- §2-5 direction development: **solid** on the symbolism rationale, **drift** on user-research validation (no actual user testing done).
- §7 TM gut-checks: **drift** — these are 30-second sanity checks, not legal opinions. Always consult a TM lawyer.
- §8 shortlist ranking: **uncertain** — naming is a taste call, and Jesse's taste is the one that matters.
