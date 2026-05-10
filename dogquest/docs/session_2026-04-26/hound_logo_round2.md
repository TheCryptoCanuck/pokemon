# Hound — Logo Round 2

**Status:** Draft. Round 1 directions rejected.
**Picked from round 1:** name = **Hound**, tagline = **BOOP · IDENTIFY · COLLECT**.
**Companion:** `hound_logo_round2_logos.svg`.

---

## What was wrong with round 1

Honest read on each:

- **A · Dog Star.** Conceptually strongest but the star alone doesn't say "dog" — it relied on the tiny silhouette inside, which is invisible at launcher scale. Without the lore explanation, it's just a star.
- **B · The Tag.** The metal-gradient look read as cheap-skeumorphic, not premium. Engraving the monogram inside a tag is a 2010 design move.
- **C · The Snout.** The geometry came out cartoonish (the cleft + nostril proportions), and the "boop highlight" leaned cute when it should have been confident.
- **D · Letter-mark H.** The structural problem: jamming a tail-curl into a Roman capital H produces an awkward path because the H's right leg has no natural place to curl from. It worked as a description, not as a shape.

The unifying issue: round 1 over-reached on metaphor. Each direction tried to encode 2-3 ideas (dog + quest + lost-dog + collection). Best app icons encode **one** idea, well. Round 2 picks one idea per direction and executes it.

---

## Round 2 — four fresh directions

All built around the name **Hound**, the tagline **BOOP · IDENTIFY · COLLECT**, and the existing dark-forest + amber palette. None use a paw.

### A · The "h" that's also a sitting dog *(recommended)*

**One idea:** the lowercase letter "h" already looks like a sitting dog in profile — left vertical is the back, the curve over is the head, the right vertical is the front leg/chest. Add a single tiny eye dot on the curve and the letter is a dog. The letter is the dog. The dog is the letter.

**Why it wins.** Maximum brand confidence per pixel. The icon IS the wordmark IS the brand. Scales atomically — at favicon size you see an "h" with a dot, at hero size same. No metaphor stretch. Lineage: Stripe's S, Spotify's circle, Notion's N — apps that became their letterform.

**Drawback.** Requires the user to *see* the dog the first time. Some won't; that's OK because it still reads as a strong "h" mark, and once seen it's permanent.

### B · The Hound profile silhouette

**One idea:** a side-view bloodhound head in single filled silhouette. Long droopy ear, soft snout, single eye dot, nose dot. Specifically a **hound** (not a generic dog), so it earns the name.

**Why it wins.** Most "obvious" of the four — instantly readable as a dog, instantly readable as specifically a hound. Premium, illustrative, in the lineage of Lacoste's crocodile or Penguin Books' penguin.

**Drawback.** Most illustrative direction = highest production cost to nail (every curve matters, and amateur execution shows immediately). Cannot be drawn well in raw SVG — needs a real designer pass in Illustrator/Figma. The mockup in the SVG is a structural sketch only.

### C · The Peek

**One idea:** the top of a hound head poking up from the bottom of the icon tile — two ear tips, two eye dots, one amber nose. The tile becomes the surface the hound is peeking over. Plays directly into the **BOOP** tagline (the user's tap is the boop).

**Why it wins.** Most personality of the four. Inviting, warm, very specifically yours. The negative space (top 70% of tile = empty dark green) makes the hound feel like it's hiding/waiting/watching — which is exactly the *hound* personality.

**Drawback.** Cute risks. Has to be drawn with restraint or it slides into kawaii-mascot territory (which would be on-brand for a different app, off-brand for the collector + lost-dog feel).

### D · The Scent trail to a star

**One idea:** three small amber dots forming an arc from the lower-left up to a single 4-point amber star at upper-right. Pure abstraction of "a hound following a scent toward its star." No figurative dog at all.

**Why it wins.** Zero literal-dog imagery means infinite abstraction headroom. Most "logo" of the four (in the Apple-circle / Vercel-triangle sense — geometric symbol, no representational figure). Ties the *Hound* name and the *Dog Star* lore together via metaphor without committing to either.

**Drawback.** Most demanding on the wordmark to anchor the brand — without "Hound" written next to it, this is just dots and a star. App icons are increasingly seen without their wordmark (homescreen, push notifications), so this is a real cost.

---

## Recommendation

**Go with A (the "h" that's also a sitting dog).** It is the most honest, most modern, lowest-execution-risk move. The letter and the dog converge into one mark, the wordmark below repeats the same letterform, and the tagline **BOOP · IDENTIFY · COLLECT** sits beneath in `forest500` caps.

If A reads as too minimal for you and you want something more illustratively "dog", go with **B (Hound profile)**. If you want maximum personality and warmth, go with **C (the Peek)**. **D** is the safest if you ever plan to expand beyond dogs (Hound for cats, Hound for any pet) — keep it in your back pocket.

---

## Honest caveats on the SVG

Raw SVG hand-drawn paths are not a substitute for a designer's vector pass in Figma or Illustrator. Treat the mockups as **structural sketches** that show the idea — the actual shipped logo for any of these would need a real designer hour or two to:
- True up the letterform curves (direction A)
- Refine the silhouette tangent points (direction B)
- Calibrate ear/eye/nose proportions (direction C)
- Pick the exact star geometry and dot sizes (direction D)

For round 2, the goal is for you to pick a **direction** — not to ship the file.

---

## Open questions

1. Pick a direction (A / B / C / D)?
2. Wordmark casing — lowercase "hound" (recommended, friendlier, matches direction A's letter), or capital-H "Hound"?
3. Tagline placement — under the wordmark always, or only on splash/marketing?
