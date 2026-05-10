# Dog Found Dialog — Redesign Spec

**Status:** Draft — for review before any T2 implementation.
**Author:** Claude (with Jesse review).
**Date:** 2026-04-26.
**Posture:** quality-first with closed beta as feedback loop (per `.second_brain/02_Context/Strategy.md`).
**Tier:** T2. Do not implement until T1 is closed and the empirical signal is incorporated.

---

## 0. Why this spec exists

The current dialog frames every identification as a confirmation: one breed shown prominently, with a primary "Add to Kennel" CTA, regardless of how well the model actually performed. The empirical data we collected during T1 (`docs/session_2026-04-25/dogquest_20image_test.md`, `dogquest_20image_test_random.md`) shows model top-1 accuracy on the supplemental random sample is in the **5–12%** band and top-3 is in the **30–56%** band. In other words: the answer the dialog leads with is wrong roughly 7 times out of 10 on hard breeds, and the user has no visual cue that the right answer might be one of the alternatives sitting below.

The redesign target is to make the dialog reflect the model's actual confidence structure: **a ranked shortlist, not a confirmation**. This document specifies what to build; it does not specify how. Implementation may surface considerations that force a revision — that is expected and acceptable.

---

## (a) Current dialog framing problems

These are observations from `lib/widgets/dog_found_dialog.dart` (as of commit `2c0fe18`) and the 20-image empirical reports.

### A1. Headline framing is "this IS your dog"

The current layout renders, top-to-bottom:
1. Amber **"NEW BREED DISCOVERED!"** banner (only when `!alreadyOwned`).
2. Hero image of the top-1 dog.
3. Top-1 dog name + rarity badge + XP earned.
4. Confidence bar / quality label ("Very confident", "Likely", etc.).
5. Optional **"Did you mean?"** comparison card (only when top-1 vs top-2 are within 10pp of each other).
6. Alternatives chip list ("Could also be:" / "Did you mean one of these?").
7. Manual search fallback (prominent at low tier, subtle link otherwise).
8. **"Add to Kennel"** primary CTA + "Skip" secondary.

The visual weight of items 1–4 is roughly 5–10× the weight of items 5–6. The user reads "Cavalier King Charles Spaniel — Very confident — +25 XP" before they see any alternatives. The default-press button adds top-1.

### A2. "Very confident" is dishonest on documented failure cases

From the random 20-image test:
- **Russell Terrier → Boston Terrier @ 0.83** (model wrong, displayed "Very confident").
- **Standard Poodle → Boxer @ 0.94** (model wrong, displayed "Very confident").
- **Working Kelpie → Australian Kelpie @ 0.84** (since clustered in T1, but illustrative of pre-cluster failure mode).
- Bichon → Bolognese, Cane Corso → Bullmastiff, Lagotto → Toy Poodle, Akita → Norwegian Elkhound — all with confidences in the 0.55–0.80 range, all rendered with confidence-tier "high" or "medium" copy that suggests certainty.

The confidence tier mapping (`_tier`: ≥0.35 high, ≥0.20 medium, else low; `_isVerySlow` at <0.15) is calibrated to the model's softmax distribution, not to the model's actual hit rate. A 0.83 raw score corresponds to "Very confident" in the UI but to "wrong about 30–40% of the time" in reality.

### A3. The cluster substitution is a partial mitigation, not a redesign

Synonym clustering (Option B, shipped 2026-04-25) prevents one specific failure: when Blenheim wins the raw score on a Cavalier-color photo, the dialog headlines "Cavalier" instead of "Blenheim". This was the right fix for that bug but it does not address A1 or A2 — it only ensures the headline name is the user-recognizable one. The dialog still says "this IS a Cavalier — Very confident" even when the runner-up is a different breed entirely.

### A4. The "Did you mean?" card only fires when top-1 and top-2 are within 10pp

This means the comparison UI is *suppressed* in exactly the cases A2 documents — high-confidence wrong answers. When top-1 = 0.83 and top-2 = 0.05, the comparison card does not render, even though the right answer might be down at top-3.

### A5. Add-to-Kennel pressure

The primary green button reads "Add to Kennel" and is the default-action position. Skipping requires reading the "Skip" outline button. For a user who is uncertain, the cognitive path of least resistance is to commit to the model's top-1 — exactly the wrong default for a model with 5–12% top-1.

### A6. XP banner appears before any choice is made

The "+25 XP" badge under the dog name displays the XP that *will be earned* upon adding top-1. It does not adapt if the user picks an alternative (the alternative's XP is implicit in its rarity, which is shown elsewhere). The reward signal is anchored to top-1 specifically.

---

## (b) Target visual hierarchy — "best guesses" framing

### B1. Header

Replace **"NEW BREED DISCOVERED!"** (anchored to top-1 being correct) with neutral copy that acknowledges this is a candidate set:

- High-tier copy (top-1 ≥ 0.45 AND top-1 / top-2 gap ≥ 0.20): **"Looks like a [Top-1 name]"** — still permissive about being wrong.
- Mid-tier copy (top-1 ≥ 0.20, gap < 0.20, OR cluster-pair detected in top-3): **"Best guesses"**.
- Low-tier copy (top-1 < 0.20 OR `_isVerySlow`): **"We're not sure — best guesses below"**.

The "NEW BREED DISCOVERED!" celebration moves: it appears *after* the user picks a tile, in a confirmation step or a snackbar on dismissal — not at the top of the dialog before any choice is made.

### B2. Body — top-3 equal-weight tiles

Wireframe:

```
┌──────────────────────────────────────────────┐
│  Best guesses                          [×]   │
│                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │  [img]   │  │  [img]   │  │  [img]   │    │
│  │ Cavalier │  │ Bichon   │  │ Maltese  │    │
│  │  ●●●○    │  │  ●●○○    │  │  ●○○○    │    │
│  │  uncomm. │  │  common  │  │  common  │    │
│  └──────────┘  └──────────┘  └──────────┘    │
│                                              │
│  Not these? [Search manually]                │
│                                              │
│  ────────────────────────────────────────    │
│  [   Skip   ]      [ Pick & continue ]       │
└──────────────────────────────────────────────┘
```

Tile rules:
- All three tiles share identical width, padding, image dimensions, and font sizes. **No tile is visually privileged.**
- Image: square (~96×96), rounded corner, network-cached.
- Name: single line, breed-display-name (cluster-preferred where applicable).
- Confidence: a 4-pip dot meter (●●●○ = "high", ●●○○ = "medium", ●○○○ = "low", ●○○○○ for very-low — same calibration as current `_tier`, but rendered in a non-quantitative way that does not invite over-reading the percent).
- Rarity: small color-coded chip below the meter (common/uncommon/rare/legendary). The full rarity-discovery badge animation does *not* fire here — that is reserved for the post-pick celebration.
- Tap: selects that tile (B3).

If only 2 results pass the model's emit threshold, render 2 tiles in equal width, centered. If only 1 result passes, see B5. If 0, see B6.

### B3. Selection state

When the user taps a tile, the dialog transitions (in-place, no new screen) to a **confirmation state**:

- The selected tile expands to fill the body width.
- The other two tiles collapse to small chips above with copy "Or: [Bichon] | [Maltese]".
- The XP / rarity-discovery badge / "NEW BREED DISCOVERED!" celebration appears under the selected tile (this is where the original celebration moves).
- The primary CTA changes to **"Add [Cavalier] to Kennel"** (named, not generic).
- The secondary action becomes **"Pick another"** (returns to the 3-tile state).

Default selection on dialog open: **none**. The CTA reads "Pick a guess to continue" and is disabled until a tile is tapped. (This is the single biggest behavioral shift — it forces a deliberate choice.)

Alternative considered and rejected: pre-select top-1 with the CTA active. This regresses to A5.

### B4. Confidence honesty

The dot-meter replaces all percent and "Very confident" copy. Mapping:

| Raw confidence | Dots | Meaning shown to user |
|---|---|---|
| ≥ 0.45 AND gap ≥ 0.20 | ●●●● | "Strong match" |
| ≥ 0.30 | ●●●○ | "Good match" |
| ≥ 0.18 | ●●○○ | "Possible match" |
| < 0.18 | ●○○○ | "Weak match" |

If two of the three tiles share the same dot count (e.g. all three render ●●○○), the header copy switches to "Best guesses (close call)" to telegraph that the model is genuinely undecided.

The literal "82%" / "0.83" number is removed from the user-facing UI entirely. We retain it in the analytics payload (B7) for evaluation. Power users who want raw numbers can opt in via Settings → Developer (out of scope for T2; would be its own task).

### B5. Single-result edge case

When only one breed passes the emit threshold:
- One large tile, centered, same shape as B2.
- Header: **"Looks like a [name]"** if confidence ≥ 0.30, else **"Closest match: [name]"**.
- A persistent **"This isn't right — search manually"** link is rendered below the tile.
- CTA: "Add [name] to Kennel" (enabled), with a secondary "Search instead" link.

### B6. Zero-result edge case

When no breed passes the emit threshold (rare; happens with completely off-distribution photos like a person, a couch, a bird):
- No tiles.
- Header: **"We couldn't recognize a dog in this photo"**.
- Body: short bullet list — "Try better light", "Get closer", "Make sure the dog fills the frame".
- CTA: **"Try another photo"** (closes dialog, returns to capture screen).
- Secondary: **"Search by breed name"** (manual lookup).

### B7. Analytics payload (no UI change, but spec the data shape)

Each dialog event emits a `dog_found_dialog_v2` analytics event with:
- `top3_breeds`: array of cluster-keyed breed names.
- `top3_raw_confidences`: matching array of model softmax values.
- `top3_dot_counts`: matching dot meter values.
- `picked_index`: 0/1/2/-1 (-1 = manual search).
- `time_to_pick_ms`: ms from dialog open to tile tap.
- `time_to_confirm_ms`: ms from tile tap to "Add" press.
- `skipped`: bool.
- `manual_search_after_dismiss`: bool (tracked via subsequent screen event correlation).

This is what we will use to validate (d).

---

## (c) Interaction flows

### C1. Happy path (3 results, user picks top-1)

1. User taps capture. Identification runs. Dialog opens with 3 equal-weight tiles.
2. CTA "Pick a guess to continue" is disabled.
3. User taps the leftmost tile (top-1).
4. Tile expands; XP badge animates in; CTA becomes "Add Cavalier to Kennel" enabled.
5. User taps CTA. Haptic; dialog dismisses; kennel updated; "Breeds N+1 / 296 in your kennel" toast (already shipped 2026-04-25).

### C2. Switch path (3 results, user picks top-2 or top-3)

1–2. Same as C1.
3. User taps middle or right tile.
4. Selected tile expands; the other two (including original top-1) collapse to small chips above with "Or: [name1] | [name2]". Tapping a chip returns to the 3-tile view.
5. CTA "Add [picked name] to Kennel". User confirms. Kennel updates with the user's choice.
6. Analytics: `picked_index = 1` or `2`. This is the metric that will tell us the redesign matters.

### C3. Manual search fallback (any state)

A persistent link **"Not these? Search manually"** is rendered below the tile row at all confidence tiers (currently it is only prominent at low tier). Tap → opens the existing manual-search screen (no spec change there). On return-with-pick, the dialog dismisses and the user's manual pick is added to the kennel as if they had tapped a tile. On return-without-pick, the dialog returns to its 3-tile state.

### C4. Skip / dismiss

The "Skip" button and the [×] in the upper right both dismiss with no kennel change. Analytics records `skipped=true`. Skipping is a valid signal — it likely means "none of these are right and I don't want to bother searching".

### C5. Already-owned breed

When `widget.alreadyOwned == true` for the picked tile:
- "Add to Kennel" CTA is replaced with **"+ mastery progress"** copy and the mastery progress section (already in current dialog at line 327) is rendered under the selected tile.
- The "Breeds N / 296" line does not increment (this is what the 2c0fe18 fix already handles correctly via the `widget.alreadyOwned ? 0 : 1` offset).
- Top-3 framing still applies — a user can still pick a different breed than the model's top-1.

### C6. Cluster-pair detected in top-3

Pre-redesign, the cluster substitution collapses cluster pairs to one tile. Verify this still happens in the top-3 layout: if Blenheim Spaniel wins raw score and Cavalier King Charles Spaniel is top-2, render only **Cavalier** in tile 1 (preferred name, raw score from Blenheim). Top-3 then becomes [Cavalier, top-3 from raw, top-4 from raw]. This preserves the synonym-cluster invariant from the 2026-04-25 decision.

### C7. Mock / demo source

When `widget.source == 'mock'`, the dialog skips all confidence treatment (no dot meter), shows a single tile with the demo breed, and a single "Add to Kennel" CTA. No top-3, no manual search, no analytics. This preserves demo-mode behavior.

---

## (d) Acceptance criteria — closed beta

The redesign ships behind the same APK as the closed-beta release. We do **not** A/B test against the current dialog (5–10 testers is too small). Instead, we measure the following on the redesigned dialog only and compare against documented prior baselines where available.

### D1. Pick-distribution metric (primary)

> **`picked_index` distribution across all closed-beta identifications**, ignoring `skipped` and mock events.

- **Pass criterion:** ≥ 15% of picks are `index ∈ {1, 2}` (i.e. user took an alternative). This validates that the equal-weight layout actually changes behavior. If <15%, the redesign visually privileged top-1 anyway and needs revision.
- **Calibration:** in the prior dialog, this number is structurally near 0% because the alt chips are visually demoted.

### D2. User-stated correctness (primary)

> Beta-feedback prompt at the end of the 2-week window: "Of the dogs you identified during the beta, what fraction would you say the app got right?"

- **Pass criterion:** median tester response ≥ 60% subjective accuracy. This is well above the model's raw 5–12% top-1 because the redesign converts the model's top-3 into the user's effective accuracy. We expect the math to land near the model's top-3 (~30–56% on hard breeds, higher on mainstream breeds in real photos).
- **Risk:** subjective recall is biased. We supplement with the audit prompt in D6.

### D3. Skip rate (secondary, guardrail)

> Fraction of dialog-open events where `skipped=true`.

- **Pass criterion:** skip rate does not exceed **30%**. A sky-high skip rate would mean the new framing made users disengage from the kennel-collection loop.
- **Calibration:** we lack a baseline number for the prior dialog. Plan to instrument the current dialog with a `dog_found_dialog_v1_dismissed` event before the redesign ships, so we have ~2 weeks of pre-redesign baseline.

### D4. Time-to-pick (secondary)

> Median `time_to_pick_ms` across all dialog opens with at least one tile-tap.

- **Pass criterion:** median ≤ **8 seconds**. If it climbs above this, the equal-weight layout is forcing analysis paralysis; we'd want to add a subtle "model's top guess" hint without regressing to A1.
- We expect this to be higher than the prior dialog (which had a default-press top-1) because the redesign requires a deliberate tap.

### D5. Manual-search-rate (secondary)

> Fraction of dialog-open events where the user uses manual search (either via the inline link or a follow-up search-screen visit within 60 s of dismiss).

- **Pass criterion:** manual-search-rate ≤ **25%**. If above, top-3 is failing too often and we need T3 (model retrain) before further dialog work.
- **Calibration:** we don't have this baseline either; same instrumentation plan as D3.

### D6. Spot-photo audit (qualitative, primary)

> At end of beta, ask 3 testers to walk through a randomly-chosen 10 of their identifications, photo by photo, and rate each "yes that's right / no that's wrong / I don't know".

- **Pass criterion:** ≥ 65% "yes" across the audit set. This is the closest we can get to ground truth without the user having known the correct breed up front.
- **Calibration:** prior dialog cannot be audited the same way (the audit prompt is new), but the 20-image harness gives us a comparable lab number.

### D7. Beta feedback themes (qualitative, primary)

> Read all written feedback. Code into themes. Look specifically for:

- **Pass criterion (anti-pattern):** the phrase "wrong" / "not my dog" / "this is the wrong breed" appears in <2 of the 5–10 testers' feedback.
- **Pass criterion (positive):** at least 3 testers spontaneously mention that they liked being able to pick. (We will not prompt for this; it must be unprompted.)

### D8. No regression on existing T1 metrics

> The 20-image lab harness (`outputs/run_test.py`, seeds 42 + 43) must continue to show top-1 and top-3 unchanged from the pre-redesign baseline. (The redesign only changes the dialog; the model and cluster table do not move. This is a regression guard, not a forward-progress metric.)

- **Pass criterion:** zero deltas. If a delta appears, the redesign accidentally touched the identification path and needs investigation.

---

## Things this spec deliberately does not specify

- **Animations / motion design** — covered at implementation time; the rule is "subtle and informational, not celebratory until post-pick".
- **Light/dark mode tokens** — DogQuest is dark-mode-only; no spec needed.
- **Localization** — DogQuest is en-US-only at closed beta; copy strings can be hard-coded for now.
- **Accessibility** — implementation must respect existing app-wide a11y patterns (semantic labels on tiles, tap target ≥ 48dp, screen-reader-friendly confidence dots). Not detailed here because it is a baseline, not a redesign decision.
- **Code structure** — left to implementation. Today's `dog_found_dialog.dart` already has the data shape (`alternatives`, `onSelectAlternative`, `onManualSearch`); the redesign is a UI-level change, not an architectural one.

---

## Revision conditions

This spec should be revisited if **any** of the following surfaces during T1 closure:

1. The 4-folder data spot-check (Active_Tasks T1) reveals heavy label noise — that changes our model-accuracy mental model and may make D1's 15% threshold wrong.
2. The on-device cluster verification (Active_Tasks T1) surfaces a UI failure mode that the dot-meter doesn't capture (e.g. cluster-pair where both members appear in the same top-3 anyway).
3. The Poodle → Boxer 94% outlier turns out to be a model bug rather than a hard image — that changes A2's framing from "calibration honesty" to "model correctness", which is a different kind of fix.
4. Beta-instrumentation work (D3 / D5 baseline plan) reveals the current dialog's skip rate is already > 50%, which would mean users are disengaging for reasons unrelated to top-1 framing.

---

## Cross-references

- Current dialog: `lib/widgets/dog_found_dialog.dart` (commit `2c0fe18`).
- Empirical baseline: `docs/session_2026-04-25/dogquest_20image_test.md`, `dogquest_20image_test_random.md`, `dogquest_accuracy_analysis.md`.
- Cluster decision: `.second_brain/01_Memory/Decisions.md` (2026-04-25, Option B preferred-name).
- Posture: `.second_brain/02_Context/Strategy.md` (quality-first with closed beta).
- Active task that points here: T2 "dog_found_dialog redesign — top-3 ranked alternatives".

---

## (e) Critic pass — gaps surfaced 2026-04-25 (Cowork)

These are gaps in the spec as written, not disagreements with its direction. Each item is a concrete decision the author or implementer will hit; if the spec doesn't pre-decide, the implementation will pick something arbitrarily and we'll lose audit-ability.

### E1. D1's 15% threshold has no derivation

D1 says "≥ 15% of picks are `index ∈ {1, 2}`" but doesn't anchor 15% to anything. From the random 20-image test on the supplemental partition, lab top-1 was 5% and top-3 was 30% — so the **theoretical ceiling for "model put the right answer at index 1 or 2"** is 30% − 5% = ~25% on hard breeds. The per-position split between index 1 and index 2 is not in the report; assume it's roughly even at ~12–13% each. (Drift: this 25% ceiling is verified from Decisions.md; the 12–13% per-position split is inferred, not measured.)

The threshold also conflates two different signals:
- **Engagement** — "did the equal-weight UI change behavior at all?" (any alt-pick, regardless of correctness)
- **Accuracy lift** — "did users end up with more correct identifications?" (alt-pick AND right)

A random-clicker would pass D1's 15% on chance alone (33% baseline if uniform). If we want to be confident the redesign moved the needle, the threshold has to separate these.

Suggested fix: split D1 into D1a "any alt-pick rate ≥ 15%" (engagement signal — matches current text) and D1b "correct alt-pick rate ≥ 8%" (validated against the D6 audit subset — actual accuracy lift). 8% is roughly one-third of the 25% ceiling, allowing for tester noise and breed-distribution variance vs. the lab harness.

### E2. D2's 60% subjective accuracy has no theoretical anchor

D2 says median tester says ≥60% subjective accuracy. The spec hopes "the math will land near top-3". But:
- Lab top-3 on supplemental random sample is 30%.
- Real-world photos skew toward mainstream breeds (Lab, Golden, GSD, mixes labeled as their dominant breed) where top-3 likely runs 60–80%.
- Subjective recall has a positivity bias (~+10pp).

Suggested fix: state the expected band explicitly — "we expect 50–70% based on top-3 × real-world breed-distribution × recall bias" — and set the **pass threshold at 50%** (the floor of that band), not 60%. 60% is somewhere in the middle and will fail more often than the spec implies.

### E3. C6 cluster-collapse semantics underspecified

C6 says "if Blenheim wins raw and Cavalier is top-2, render Cavalier in tile 1, raw score from Blenheim". Open questions:
- (a) Which raw score feeds the dot meter — Blenheim's, Cavalier's, or `max(Blenheim, Cavalier)`? Different choices produce different dot counts on the same photo.
- (b) After collapse, top-3 becomes `[Cavalier, raw_top_3, raw_top_4]`. What if `raw_top_4` is *also* a cluster partner of `raw_top_3`? Iterative dedup isn't specified.
- (c) When two cluster members are split across top-1 and top-3 (top-2 is unrelated), does the merge still happen? Currently the cluster substitution code only collapses the headline; whether it collapses across the full top-K is not stated.

Suggested fix: spec uses `max(raw)` for the dot meter (most generous to the merged tile, matches user mental model "this photo is somewhere in the cluster"). Iterative dedup runs over `top-K` until either 3 distinct clusters are filled or `K` is exhausted (`K = 5` should be sufficient). Cross-position merge IS allowed.

### E4. B4 "close call" trigger is ambiguous

"If two of the three tiles share the same dot count" — this fires when *any* two share, including the relatively benign top-2 and top-3 sharing while top-1 stands alone. That's actually NOT a close call (top-1 is clearly the lead).

Suggested fix: trigger "close call" header only when **top-1 and top-2 share a dot count**. Top-2 = top-3 with top-1 ahead is informational, not a close call.

### E5. Pre-redesign baseline instrumentation is missing from Active_Tasks

D3 (skip rate) and D5 (manual-search-rate) say "instrument current dialog with `dog_found_dialog_v1_dismissed` event before the redesign ships, so we have ~2 weeks of pre-redesign baseline." This is a real prep task (~30 min in `dog_found_dialog.dart` + analytics service) but it does not appear in `Active_Tasks.md`. If it's a prerequisite for D3/D5 validation, it needs to land before T2 implementation, not as part of it.

Suggested fix: file as a new T1 task ("Instrument current dog_found_dialog with v1 telemetry events") owned by Claude Code, ~30 min, queued behind the C1/C2/C3 closes.

### E6. B7 analytics payload missing cluster-substitution flag

Without `cluster_substituted_for_tile_N: bool[]`, we can't audit whether Option B's preferred-name substitution is firing where expected, or whether a wrong cluster picked the wrong preferred name. This was the exact failure mode that led to the 2026-04-25 cluster decision (Blenheim vs. Cavalier on the on-device photo); we should not re-introduce blindness to it.

Suggested fix: add `top3_cluster_substituted: [bool, bool, bool]` and `top3_raw_breed_pre_substitution: [str, str, str]` to the payload.

### E7. C7 mock/demo emits no analytics — risks dashboard gaps

"No analytics" for mock means dialog-open events don't all match. Downstream dashboards counting `dialog_open ÷ pick_or_skip` get implicit denominators that vary by demo-mode usage.

Suggested fix: emit `dog_found_dialog_v2` with `source: 'mock'` and `picked_index: -2` (sentinel for "demo, not real model output"). Most dashboards filter out mock; explicit sentinel beats implicit absence.

### E8. Network-image fallback not specified for tiles

Current `dog_found_dialog.dart` uses `CachedNetworkImage` with a placeholder for the hero image. Tiles in B2 inherit the same network dependency × 3. If the network is offline (a real DogQuest use case — outdoor photo of someone's dog, no signal), the user sees three placeholder boxes and has no visual cue which is which.

Suggested fix: tile fallback shows the breed name centered on a rarity-tinted background (common = grey, uncommon = green, rare = blue, legendary = gold) at the same dimensions as the image. Names alone are sufficient to pick.

### E9. "Pick another" + change-of-mind not analytics-spec'd

C2 says picking middle/right tile records `picked_index = 1` or `2`. C5's "Pick another" (B3 secondary action) returns to 3-tile state; what if the user then picks a different tile?

Suggested fix: only the **final** pick is recorded in `picked_index`, but emit a separate `tile_changes_before_confirm: int` counter. A high value here on hard breeds is signal that users are uncertain (useful for D6 audit selection).

### E10. Low-information case (all three tiles tie) ↔ B1 header copy

B1 picks header copy from top-1 confidence alone. B4 picks "close call" from tile dot-counts. These can disagree: top-1 = 0.22, top-2 = 0.21, top-3 = 0.20 → B1 says "Best guesses" (mid-tier, top-1 ≥ 0.20) while B4 dot meters render `●●○○` for all three and B4's close-call rule should fire — but only the *body* gets "(close call)" appended. The header still reads "Best guesses" without acknowledging the tie.

Suggested fix: when B4 close-call fires, B1's header copy is **always** demoted one tier (high → mid, mid → low). The user's first read should reflect the model's actual decisiveness.

---

**Action requested:** review (a)–(e). Flag any criteria you want stricter or looser. Once approved, this spec moves to "Ready for T2 implementation" — but only after T1 is closed.
