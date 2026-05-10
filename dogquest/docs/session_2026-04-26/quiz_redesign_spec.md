# Quiz Fix — System Design

**Date:** 2026-04-26
**Trigger:** Jesse, 2026-04-25 — "quiz is boring and answers are repeated for the same question" (UX, sometimes).
**Posture:** quality-first with closed beta. This is T2-shaped — spec only until T1 closes.
**Scope:** `lib/services/quiz_engine.dart` (693 lines), `lib/screens/quiz_screen.dart` (781 lines), 4 widgets in `lib/widgets/quiz/`, `test/quiz_engine_test.dart`.

---

## (1) Requirements

### Functional (today)

- 13 question types (`QuizType` enum, lines 10-24): name-from-photo, photo-from-name, size, trait, odd-one-out, group, lifespan, silhouette, exercise, weight, origin, clue-from-lore, compare-breeds.
- 3 difficulty tiers (`QuizDifficulty`): beginner / normal / expert. XP multipliers 0.75 / 1.0 / 1.5.
- Type-weighting by player level + difficulty (`weightedTypes`, line 493).
- Hint system per question type (`getHint`, line 660).
- Fun fact per type (`getFunFact`, line 581).
- Streak bonus, per-question timer, kennel-aware pool filtering.

### Functional (must add)

- Distractor selection that respects synonym clusters (Cavalier↔Blenheim never appear together as distinct options).
- Some surface variety so a 10-question session doesn't feel like a 10-iteration loop of identical layouts.

### Non-functional

- Local-only, no network for question generation.
- Existing 95-test suite (incl. `test/quiz_engine_test.dart`) must still pass; cluster-aware distractor logic adds tests, doesn't break extant ones.
- App-tier engagement loop (XP, streaks, mastery) keeps working unchanged.

### Constraints

- Solo dev, 4-week quality-first window before reassess.
- No new packages without pub.dev compatibility review (per CLAUDE.md rules).
- Cluster table must stay in sync with 2 existing readers (`dogQuestSynonymClusters` in `lib/services/tflite_identification_service.dart`, `SYNONYM_CLUSTERS` in `outputs/test_20_images.py`); see (6).

---

## (2) Diagnosis — both symptoms

### A. Duplicate-answers bug

`pickDistractors` (lines 201-231) has an asymmetry between its two passes:

- **First pass** (line 209-211, "similar habitat" candidates): dedupes by **name equality only** — `!distractors.any((d) => d.name == b.name)`. Does NOT check `tooSimilar`.
- **Second pass** (line 218, general pool): dedupes by **name AND `tooSimilar`** — `!distractors.any((d) => d.name == c.name || tooSimilar(d.name, c.name))`.

Effect: when two breeds (a) share a habitat with the correct dog AND (b) are tooSimilar to each other (e.g. share a last word like "Terrier" or "Spaniel"), the first pass can pick both. They land in the option list as distinct strings even though `tooSimilar` would have caught them in pass two.

Worse, the synonym clusters defined for identification (Cavalier King Charles ↔ Blenheim Spaniel, Yorkshire ↔ Biewer Terrier, Belgian Sheepdog ↔ Belgian Tervuren, Siberian Husky ↔ Alaskan Husky, Standard Poodle ↔ Toy/Miniature Poodle, Australian Kelpie ↔ Working Kelpie) are **not consulted at all** by `pickDistractors`. A user who just learned "the cluster preferred name is Cavalier" sees both "Cavalier King Charles Spaniel" and "Blenheim Spaniel" as quiz options — the same breed twice.

This is the "answers are repeated" bug. Severity: medium (cosmetic + trust erosion, no data loss).

### B. Boredom

Surface inspection of the engine + quiz_screen reveals three sameness loops:

- **Layout sameness**: 12 of 13 question types render as "prompt + 4 string options" (compareBreeds and oddOneOut are the visual exceptions). The user's eye sees the same shape question after question.
- **Reward sameness**: every correct answer triggers the same XP-burst + fun-fact pattern. `getFunFact` (line 581) generates rich text but the *frame* never varies.
- **No structural surprise**: the session is a flat list of N questions of similar texture. No streaks-felt-as-events, no rare-event interruptions, no per-session arc.

This is "the quiz is boring." Severity: real but unbounded — engagement is a deep design surface, not a single-fix problem.

---

## (3) High-level design

### Component changes

```
┌────────────────────────────────────────────────────┐
│ Synonym cluster table (single source of truth)     │
│   assets/synonym_clusters.json (NEW)               │
└─────────────┬─────────────┬───────────────┬────────┘
              │             │               │
              ▼             ▼               ▼
   ┌──────────────────┐ ┌───────────┐ ┌────────────┐
   │ tflite_id_svc.dart│ │ test_20   │ │ quiz_engine│
   │ (identification)  │ │ _images.py│ │ (NEW reader)│
   └──────────────────┘ └───────────┘ └────────────┘
```

### Data flow (quiz construction, after fix)

```
makeQuestionOfType
  └─ pickDistractors(pool, correct, 3)
       ├─ similar = pool.where(habitat-match)
       ├─ filter: name ≠ correct.name
       ├─ filter: !tooSimilar(name, correct.name)
       ├─ filter: !sameCluster(name, correct.name)   ← NEW
       ├─ first pass dedupe: name AND tooSimilar AND sameCluster   ← NEW
       ├─ second pass dedupe: same                                  (already partial)
       └─ fallback dedupe: same                                     ← NEW (currently weakest)
```

---

## (4) Deep dive

### Fix B-1 — cluster-aware distractors (the bug)

**File:** `lib/services/quiz_engine.dart`

Add helper at class top:

```dart
/// Synonym clusters — same source as
/// lib/services/tflite_identification_service.dart#dogQuestSynonymClusters.
/// MUST stay in sync. See sec-6 of docs/session_2026-04-26/quiz_redesign_spec.md
/// for the planned shared-JSON refactor.
static const _clusters = <List<String>>[
  ['Cavalier King Charles Spaniel', 'Blenheim Spaniel'],
  ['Yorkshire Terrier', 'Biewer Terrier'],
  ['Belgian Sheepdog', 'Belgian Tervuren'],
  ['Siberian Husky', 'Alaskan Husky'],
  ['Standard Poodle', 'Toy Poodle', 'Miniature Poodle', 'Poodle'],
  ['Australian Kelpie', 'Working Kelpie'],
];

bool sameCluster(String a, String b) {
  for (final cluster in _clusters) {
    if (cluster.contains(a) && cluster.contains(b)) return true;
  }
  return false;
}
```

Tighten `pickDistractors` first pass (line 209-211):

```dart
for (final b in similar.take(count ~/ 2 + 1)) {
  if (!distractors.any((d) =>
      d.name == b.name ||
      tooSimilar(d.name, b.name) ||
      sameCluster(d.name, b.name))) {
    distractors.add(b);
  }
}
```

Apply same triple-check to the `similar` filter line 203-207 (exclude breeds in the same cluster as `correct` from `similar` upfront), and to the fallback at line 222-229.

**Test additions** in `test/quiz_engine_test.dart`:

```dart
test('pickDistractors never returns two breeds from the same cluster', () {
  final cavalier = Dog(name: 'Cavalier King Charles Spaniel', ...);
  final blenheim = Dog(name: 'Blenheim Spaniel', ...);
  final pool = [cavalier, blenheim, ... 20 others];
  final distractors = engine.pickDistractors(pool, cavalier, 3);
  expect(distractors.map((d) => d.name), isNot(contains('Blenheim Spaniel')));
});

test('pickDistractors never returns tooSimilar siblings as both distractors', () {
  // Two "Terrier" breeds should not co-appear when both are similar-habitat
});
```

**Effort:** 30 min implementation + 30 min tests. **Risk:** low — narrows existing logic; no new state.

### Fix B-2 — reaction variety (engagement)

**File:** `lib/widgets/quiz/quiz_question_card.dart` (or the answered-state component)

After each correct answer, surface ONE of N reaction frames (cycle with seed so consecutive different):

1. **Fun fact** (today's behavior — keep as one of N).
2. **Comparison snippet** — "Cavaliers weigh as much as 2 cats" (use `dog.weight` parsed against pre-baked household-object table).
3. **Origin pin** — small map dot for the breed's country (use `parseOrigin(dog.habitat)`). No flag images, just country name in a styled badge.
4. **Lifespan-vs-yours** — "If you adopted one tomorrow, you'd celebrate ${dog.lifespan} birthdays together" (recompute from `parseMidLifespan`).
5. **Rarity flex** — for legendary breeds: "You're one of <5% of players who can ID this breed".

Implementation: a `Reaction` sealed class + a `nextReaction(QuizQuestion, int sessionIndex)` selector. Skip frames whose data isn't available for this dog (empty `weight`, `habitat`, etc.).

**Effort:** 2-3 hr (text content + 5 visual frames). **Risk:** low — additive, doesn't touch quiz logic.

### Fix B-3 — themed mini-quizzes (engagement)

**File:** `lib/screens/quiz_screen.dart` (entry/setup state)

Pre-built themed pools, surfaced as a 4-tile carousel on quiz entry:

- "Toy Group" — `pool.where((d) => d.sizeCategory == 'small')`.
- "Snow Pack" — already a defined breed set in `breed_collection_service.dart`.
- "Working Dogs" — group filter.
- "Top 20 Most Popular" — needs an authoritative ranking; defer until popularity data exists, OR seed with a manually-curated list of 20 mainstream breeds.
- "Surprise Me" — full pool (today's behavior).

Question count fixed at 10 per themed run. XP unchanged.

**Effort:** 3 hr. **Risk:** low — pool is just a filter; engine unchanged.

### Fix B-4 — result-screen progression (engagement)

**File:** `lib/widgets/quiz/quiz_result_view.dart`

End-of-session screen surfaces:

- **Per-session arc**: "8/10 correct, longest streak 5, 165 XP earned." (some of this likely exists; audit at impl time).
- **Cross-session progression**: "You've now mastered 47 breeds — 12 more than last week." Pull from existing player/mastery service.
- **Next nudge**: "Try the Toy Group quiz next?" → 1-tap re-entry to a different theme.

**Effort:** 2 hr. **Risk:** low.

### Defer — lightning round (B-5 in earlier draft)

Skipped. New state machine, 4-6 hr, biggest engagement lever but biggest impl risk during a quality-first window. Revisit only if B-1 through B-4 ship and quiz still feels flat.

---

## (5) Trade-off analysis

| Fix | Effort | Risk | Bug or engagement | Notes |
|---|---|---|---|---|
| B-1 cluster-aware distractors | 1 hr | Low | Bug | Concrete fix; ships first |
| B-2 reaction variety | 2-3 hr | Low | Engagement | Additive; multi-frame |
| B-3 themed mini-quizzes | 3 hr | Low | Engagement | Pool filter only |
| B-4 result-screen progression | 2 hr | Low | Engagement | Pulls existing data |
| (deferred) B-5 lightning round | 4-6 hr | Med | Engagement | Revisit if needed |
| (separate) cluster JSON refactor | 1 hr | Low | Hygiene | See sec-6 |

**Recommended sequence:** B-1 → cluster JSON refactor (sec-6) → B-3 → B-4 → B-2.

Why this order: the bug fix wins user trust fastest. The JSON refactor prevents the failure pattern of cluster-table drift across 3 readers (already documented in `Failure_Patterns.md` for 2 readers; adding the quiz engine makes 3). Themes give the most differentiated visual experience per hour. Result-screen progression closes the per-session loop. Reaction variety is multiplicative — best layered on top of the structural changes.

---

## (6) Cluster-table sync requirement

Today: 2 readers — `dogQuestSynonymClusters` in `lib/services/tflite_identification_service.dart`, `SYNONYM_CLUSTERS` in `outputs/test_20_images.py`. Already a documented failure pattern (`.second_brain/01_Memory/Failure_Patterns.md`: "Test harness cluster table drifts from the Dart cluster table"). B-1 above adds a 3rd reader (the quiz engine).

**Proposed:** extract to `assets/synonym_clusters.json`:

```json
{
  "version": "1",
  "clusters": [
    ["Cavalier King Charles Spaniel", "Blenheim Spaniel"],
    ...
  ]
}
```

- Dart side: read at app startup via `rootBundle.loadString`, expose via `dogService.synonymClusters`.
- Python harness: read at script init.
- Quiz engine: read via injected `DogService.synonymClusters`.

Single source, three consumers, no drift.

**Effort:** 1 hr. **Risk:** low (Hive boxes / Riverpod providers don't touch this).

---

## (7) Scale and reliability

Mostly N/A — quiz construction is local, in-memory, single-user. Two notes:

- **Determinism**: today's `Random rng` is wired through; tests pass a seeded RNG. Cluster-aware logic must respect that — no `DateTime.now()` shortcuts.
- **Pool size**: 296 breeds. `pickDistractors` is O(N) per call; cluster check is O(C × cluster_size) ≈ O(20). No perf concern.

---

## (8) Open questions

- B-2 reaction frame "Origin pin": pure-text country badge or actual flag SVG? Flag adds asset weight (~50 KB for 50 countries). **Default: text-only badge** unless Jesse specifies.
- B-3 themed pools: "Top 20 Most Popular" needs a ranking source. **Default: skip this theme until popularity data exists from closed beta usage.**
- B-4 result screen: does an end-of-quiz mastery delta already exist? Audit at implementation time.
- The CLAUDE.md project intel says quiz_screen was refactored to **680** lines + 4 widgets (TASK-046). Current `wc -l` says **781**. ~100-line drift since the refactor — worth flagging that the file is creeping back toward the god-class threshold but not actionable here.

---

## (9) What I'd revisit as the system grows

- If themed mini-quizzes (B-3) generate 10× more sessions than the surprise-me pool, lightning round (B-5) becomes worth the implementation cost.
- If beta testers don't surface "answers repeated" feedback after B-1 ships, the synonym cluster table might be missing entries — re-run the audit at the 4-week mark.
- If the cluster JSON refactor (sec-6) doesn't happen and a 3rd cluster pair is added by some future change, expect ~2 weeks before the test harness or quiz engine drifts and a regression slips through CI.
- Engagement instrumentation: today the quiz has no analytics. Closed beta should add `quiz_session_started`, `quiz_question_answered{type, correct, time_ms}`, `quiz_session_completed{score, streak_max, xp_earned}` to feed B-3 (which themes are popular?) and B-4 (real cross-session progression numbers).

---

## (10) Cross-references

- `lib/services/quiz_engine.dart` — engine source.
- `lib/screens/quiz_screen.dart` — UI host (781 lines, post-TASK-046 refactor).
- `lib/widgets/quiz/` — 4 component widgets.
- `lib/services/tflite_identification_service.dart` — current `dogQuestSynonymClusters` source.
- `outputs/test_20_images.py` — Python `SYNONYM_CLUSTERS` mirror.
- `test/quiz_engine_test.dart` — test bed for B-1 additions.
- `.second_brain/01_Memory/Failure_Patterns.md` — cluster-drift failure pattern.
- `.second_brain/01_Memory/Decisions.md` — 2026-04-25 Option B synonym clustering decision.

---

**Action requested:** confirm sequencing (B-1 → JSON refactor → B-3 → B-4 → B-2). Flag any boredom dimension I missed (analytics, leaderboards, social challenges all out of scope here).

Confidence: solid on the diagnosis (read every relevant code path); solid on B-1 fix (tests will catch regressions); uncertain on the engagement-lift estimates for B-2/B-3/B-4 (no closed-beta data yet); drift on the "100-line creep since TASK-046" claim — I'm comparing CLAUDE.md memory (680) against current `wc -l` (781), didn't audit the diff.
