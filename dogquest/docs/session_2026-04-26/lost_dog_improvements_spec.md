# Lost Dog Recognition Network — Improvements Spec

**Status**: spec only, no code authorized
**Tier**: T2 (UX) + T3 (sync architecture) + GDPR gate before public launch
**Authored**: 2026-04-25 evening, 4-agent parallel investigation
**Files investigated**: `lib/services/{lost_dog_service,supabase_lost_dog_service,lost_dog_alert_service,dog_embedding_service,photo_upload_service}.dart`, `lib/screens/lost_dog_*.dart`, `lib/widgets/lost_dog/`, `lib/models/lost_dog_report.dart`

---

## TL;DR — The three things you need to decide

### Decision 1: Is the matching feature shipping as-is acceptable?

The current "embedding" is the 150-dim breed-probability softmax output of EfficientNetB2 v5.1 — i.e. a probability distribution over breed labels, not a visual fingerprint. Two different golden retrievers will produce nearly identical distributions (cosine >0.85). The match threshold is 0.50, which is well below the same-breed false-positive floor. As deployed, the feature will surface **any same-breed dog within radius as a "match"** with no real individual-dog discrimination.

**Three paths** (ranked by effort/impact):

- **(a) Honesty pass — relabel as "breed match" not "found your dog"**, raise threshold to 0.75, encourage 3-photo averaging at report time. **2-3 hr.** Doesn't fix the fundamental issue but stops the false claim.
- **(b) Pre-softmax features from existing TFLite** — if the .tflite asset exposes the 1408-dim global average pooling layer as a named output, switch `dog_embedding_service.dart` to read that instead. Discriminative power jumps materially. **3-5 hr** if exposed; otherwise gated on a model re-export. **Audit first** — `tflite_flutter 0.11.0` multi-output support is unverified.
- **(c) Replace with a proper embedding model** (MobileNetV3 features pretrained on ImageNet, ~512-dim, separate from breed model). Architecturally clean. **8-12 hr** plus model size delta (~5 MB). Recommended if the feature is core to the value prop.

My read: **(a) is mandatory before any public launch** (false-claim exposure on a missing-pet feature is reputational + legal). **(b)** is the right next step after that. **(c)** is the long-term answer if Lost Dog is a flagship feature. Nothing here helps without **Decision 2** below — local-only matching means even a perfect embedding is matched against the wrong corpus.

---

### Decision 2: Is stray-scan supposed to query the network or the user's own device?

Currently `LostDogService.scanStray()` iterates `activeReports` from local Hive only. The remote table `lost_dog_reports` (with sightings, real-time stream, RPC for radius queries) is never consulted by the scan flow.

The user-facing promise — "scan a stray, see if anyone's lost dog matches" — only works if the network is queried. The current code asks "is this MY lost dog?", which has near-zero hit rate by definition (the user knows their own lost dog).

**Three paths**:

- **(a) Client-side: hit `getActiveNearby` then match locally**. Pull active remote reports within radius (the RPC exists), iterate cosine similarity client-side. Embeddings would need to ship in the RPC payload. **3-4 hr** if embeddings are added to the RPC; otherwise gated on a schema change.
- **(b) Server-side: pgvector column + `match_lost_dogs(embedding, threshold)` RPC**. Add `pgvector(150)` column to `lost_dog_reports`, create RPC, switch `scanStray` to call it. Scales past 1000+ reports without shipping vectors. **8-12 hr** including schema migration + RPC + client wiring.
- **(c) Both**: server is primary, local cache is fallback when offline. Most resilient, most code. **12-16 hr.**

My read: **(b)** is the right shape — Supabase is already wired, pgvector is a one-extension install, and matching nearby (geospatial filter first) keeps the search space tiny. **(a)** is technically faster to build but doesn't survive scale.

---

### Decision 3: When does GDPR compliance work happen?

Two Critical findings on the security audit:

**C-Lost-1: `contact_info` plaintext broadcast**. The `get_active_lost_dogs` RPC returns phone numbers + emails to any authenticated user within radius. No "request contact" flow. Stalking and scraping risk; GDPR Article 6 lawful-basis violation.

**C-Lost-2: No consent / lawful basis / privacy policy plumbing**. No on-screen opt-in, no documented retention, no DPA with Supabase. GDPR fine surface up to €10M / 4% revenue. Play Store also requires a privacy policy as a listing condition.

Plus three High findings:
- **H-Lost-1**: Photos in `lost-dog-photos` bucket get `getPublicUrl()` — permanent, never expire. No cleanup on `markFound`/`cancelReport`.
- **H-Lost-2**: Last-seen GPS exposed at full ~11 cm precision. Industry pattern is to fuzz public display to ~500 m.
- **H-Lost-3**: No `expired` status, no retention. Reports stay active forever. PII accumulates indefinitely.

**Total compliant-baseline effort: ~20 hr** per Agent C's audit. Realistically more if a privacy policy needs legal review.

**Three timing options**:

- **(a) Gate public Play Store launch on full GDPR work**. Ship closed beta as-is (5-10 friends/family — limited risk if you have informed consent), full work before public.
- **(b) Strip `contact_info` and photos from the public broadcast for closed beta**, defer policy/consent work until just before public launch.
- **(c) Disable Lost Dog entirely until GDPR work lands**. Conservative; loses what looks like a flagship feature for the beta window.

My read: **(b)** is the honest option for closed beta. The closed-beta posture explicitly is "quality-first feedback loop", and Lost Dog is exactly the kind of feature that needs feedback. But shipping plaintext PII broadcast to 5-10 people you know is also fine — it's the public listing that triggers real GDPR exposure. **(a)** with closed-beta friends-only is defensible.

---

## Agent A — Embedding & matching quality (full)

### Diagnosis

Softmax-as-fingerprint is structurally weak for individual-dog matching. Softmax is a normalized probability distribution; two dogs of the same breed produce nearly identical distributions, differing only in noise from lighting/pose/quality. Within-breed cosine similarity floor is ~0.80; the deployed threshold is 0.50.

### Worked example
- Same-breed different-dog (golden vs. golden): cosine ≈ 0.85-0.95
- Same-dog two photos: cosine ≈ 0.90-0.98
- Different visually-similar breeds (golden vs. lab): cosine ≈ 0.80-0.90
- Different visually-distant breeds (golden vs. pug): cosine ≈ 0.60-0.75

The 0.50 threshold sits below all of these. It will return any same-breed dog (and many cross-breed near-misses) as a match.

### Improvement options

| # | Change | Effort | Impact |
|---|--------|--------|--------|
| 1 | Raise threshold 0.50 → 0.75 (`lost_dog_service.dart:25`) | 0.1 hr | -40% FP, modest |
| 2 | UX: encourage 3+ photos at report time, average via existing `averageEmbeddings()` | 1-2 hr | Tightens variance √3, modest-high |
| 3 | Switch to pre-softmax 1408-dim features if TFLite multi-output works | 3-5 hr | -80% FP, fundamental |
| 4 | Replace with separate MobileNetV3 ImageNet embedding model | 8-12 hr | Architecturally correct, model-size +5 MB |

Recommended sequence: 1 → 2 → audit 3 viability → if 3 blocked, schedule 4.

### Open question
Whether the deployed `assets/dog_model.tflite` exposes intermediate tensors as named outputs. Current `dog_embedding_service.dart:88` calls `getOutputTensor(0)` only. Need a one-off Python check on the TFLite asset to enumerate output tensors. ~30 min.

---

## Agent B — Sync architecture (full)

### Diagnosis

Two parallel services with no bridge: `LostDogService` (Hive, JSON-blob, local-only matching) and `SupabaseLostDogService` (Postgres, sightings, real-time, no embedding column). Outcomes:

- Reports made offline never reach Supabase
- Reports made online never trigger `LostDogAlertService` proximity alerts (which only reads local Hive)
- `scanStray` matches local-only (see Agent D #1)
- Distance unit drift: km local, miles remote
- ID generation in `_generateId()` is timestamp-based (collision-prone, not server-friendly)

### Recommended unification

**Hive remains local source of truth; Supabase is a non-authoritative replica with sync layer.**

Conflict policy (matching the existing project pattern in CLAUDE.md):
- New reports: localWins
- Status transitions (found/cancelled): serverWins
- Sightings: deduplicateById, server-side dedup on ingest

### Schema additions
```dart
class LostDogReport {
  final String id;             // local UUID via uuid.v4() (was: timestamp-random)
  final String? remoteId;      // Supabase row id, null until synced
  final SyncStatus syncStatus; // pending | synced | conflict
  // ... existing fields
}
```

### Server-side
- Add `local_id` UUID UNIQUE column to `lost_dog_reports` (idempotent upsert key)
- Add `embedding pgvector(150)` column (hooks Decision 2)
- Add `expires_at TIMESTAMPTZ` for retention (hooks GDPR retention)
- New RPC `sync_lost_dog_reports(reports[])` — idempotent batch upsert keyed on `local_id`

### Sightings
**Remote-only**. Local doesn't get a sighting model. Offline users see the "Report sighting" button greyed out with "Offline — sightings sync when online" tooltip. Simpler local data model, server-side dedup.

### Distance unit
Kilometers internally (storage, calculation, RPC). Locale-aware display via `intl` package's `NumberFormat`. Convert miles → km on the existing remote-side calls (Agent B's full report has the exact spots).

### Phased rollout (Agent B's plan)
| Phase | Scope | Effort | Unblocks |
|-------|-------|--------|----------|
| 1 | Local model unification (UUID, syncStatus, refactor `_generateId`) | 12 hr | Offline reports get proper IDs |
| 2 | Sync infrastructure (`syncLostDogReports`, schema, serialization) | 20 hr | Offline-online round-trip works |
| 3 | Proximity merge + status reconciliation + km canonicalization | 16 hr | Alerts fire across local + remote |
| 4 | Migration + remote pgvector matching | 14 hr | Decision 2(b) lands |
| **Total** | | **~62 hr** | |

This is the heaviest workstream in the spec. If you only do half of this, Phase 1 + Phase 4 give you the most value (UUID hygiene + remote matching) without the full bidirectional sync investment.

---

## Agent C — Privacy / GDPR (full)

### Posture
"Currently in a high-risk privacy posture for EU/GDPR compliance ... unsuitable for Play Store release in its current state without significant engineering and legal work." Solo dev in Berlin → GDPR from day one, even closed beta.

### Findings
| # | Severity | Finding | Min-fix | Effort |
|---|----------|---------|---------|--------|
| 1 | Critical | `contact_info` plaintext to anyone in radius | "Request contact" message flow OR masked display | 4-6 hr |
| 2 | Critical | No lawful basis / consent / privacy policy / DPA | Privacy policy + consent checkbox + DPA with Supabase | 6 hr (+ legal review) |
| 3 | High | Permanent public photo URLs | Signed URLs with TTL OR delete on `markFound`/`cancelReport` | 2-3 hr |
| 4 | High | Exact GPS broadcast | Fuzz public display to ~500 m, exact coords stay local for distance calc | 2-3 hr |
| 5 | High | No retention policy | `expires_at` column + auto-archive 90d active + hard-delete 1y closed | 3-4 hr |
| 6 | Medium | RLS verification gap on `lost_dog_reports` / `lost_dog_sightings` | Audit + write policies if missing | 1-2 hr |
| 7 | Critical | No on-screen consent mechanism | Pre-report disclosure + opt-in checkbox + consent table | 2-3 hr |

**Must-fix-before-public-launch checklist (~20 hr):**
1. Lawful basis & privacy policy (6 hr)
2. Contact info gating (5 hr)
3. Photo lifecycle (3 hr)
4. RLS audit + tighten (2 hr)
5. Retention + expiration (4 hr)

**Recommendation from Agent C**: defer Lost Dog from initial Play Store launch OR ship with closed-beta-only / research-use notice until the must-fix list is complete.

---

## Agent D — UX & feature completeness (full)

### Critical insight

> The network is **architecturally inverted** — it asks scanners to match *their own* lost dogs against a stray, instead of asking them to help *the community*.

### Prioritized list

| # | Item | Severity | Effort |
|---|------|----------|--------|
| 1 | Stray-scan queries entire network (not just user's reports) | P0 | 3 hr |
| 2 | FCM push fan-out on lost-dog report creation (Firebase already wired for analytics + Crashlytics) | P0 | 8 hr |
| 3 | Alert dedupe persistence — Hive box + 72 hr TTL replaces in-memory `_alertedReportIds` | P1 | 2 hr |
| 4 | Stray-scan matches community-wide via `getActiveNearby` (overlaps with Decision 2) | P1 | 4 hr |
| 5 | Empty state for new users on hub | P2 | 1 hr |
| 6 | Reunion celebration / "Charlie is home" closure ping to recent supporters | P2 | 3 hr |
| 7 | Real bidirectional contact request flow (replaces dummy "Notify Owner" dialog) | P2 | 5 hr |
| 8 | `lost_dog_map_screen.dart` (1390 lines) seam split — heat layer / stats / sighting stream | P2 | 6 hr |
| 9 | Poster QR target (currently `tel:` / SMS, should be public sighting URL or deep link) | P2 | 1 hr |
| 10 | Location permission onboarding banner | P3 | 1 hr |
| 11 | User-adjustable alert radius (1-10 km) | P3 | 2 hr |
| 12 | Network stats banner on home/identify | P3 | 1.5 hr |

### "Top 3 if I had only 1 day"
1. #1 stray-scan queries network
2. #2 FCM push fan-out
3. #3 Hive-persisted alert dedupe

#1 + #4 are arguably the same item; both reduce to Decision 2 above (server-side or client-side network match).

---

## Suggested rollout (my synthesis)

The 4 agents collectively name ~40 hr of P0/P1/Critical work plus ~60 hr of follow-on. A coherent sequencing that respects tier discipline:

### Pre-closed-beta (~6 hr — gate before any beta-tester touches the feature)
- Threshold honesty pass (Agent A #1, 0.1 hr)
- Hive-persisted alert dedupe (Agent D #3, 2 hr)
- Strip plaintext `contact_info` from public broadcast — return a per-report opaque token, owner replies via in-app message only (Agent C #1, 4 hr)
- Add 90 d `expires_at` and auto-archive (Agent C #5, ~half effort, 2 hr)

### Closed-beta-shippable (~12 hr more)
- Multi-photo averaging at report time (Agent A #2, 2 hr)
- 3-photo upload UX (Agent D adjacent)
- TFLite multi-output audit (~30 min) → Agent A #3 if green (3-5 hr)
- Stray-scan queries `getActiveNearby` (Agent D #1, 3 hr) — assumes embeddings ride along in the RPC payload as a stopgap before pgvector
- Photo lifecycle: delete on `markFound`/`cancelReport` (Agent C #3, 2-3 hr)
- GPS fuzzing on public display (Agent C #4, 2 hr)

### Pre-public-launch (~25 hr more — GDPR gate)
- Privacy policy, consent UX, DPA, ToS update (Agent C #2 + #7, 8-10 hr)
- Contact-request message flow finished (Agent C #1 polish, 2 hr)
- RLS audit + tighten (Agent C #6, 1-2 hr)
- FCM push fan-out (Agent D #2, 8 hr) — needs nearby-users index server-side
- Reunion ping (Agent D #6, 3 hr)
- Map screen god-class split (Agent D #8, 6 hr)

### Architecture investment (~40 hr — schedule when bandwidth opens)
- Sync unification Phases 1-4 from Agent B (62 hr total, but Phase 1 + Phase 4 alone = ~26 hr is a viable subset; embedding match RPC + pgvector lands in Phase 4)
- Proper visual embedding model if Lost Dog is flagship (Agent A #4, 8-12 hr)

---

## Open questions to resolve before scheduling

1. **TFLite multi-output viability** — does the deployed `dog_model.tflite` expose the 1408-dim pooling layer as a named output, and does `tflite_flutter 0.11.0` support `getOutputTensors()` indexing? **30 min Python audit on the asset.**
2. **Embedding-in-RPC vs pgvector** — for Decision 2(a) vs 2(b), is shipping 150 floats per report in the RPC payload acceptable bandwidth-wise at ~1000 reports per radius? Probably yes (1000 × 150 × 8 bytes = 1.2 MB), but worth confirming.
3. **Closed-beta GDPR posture** — is friends-and-family with informed verbal consent sufficient to defer full GDPR plumbing to pre-public-launch, or do you want it ship-blocked from day one?
4. **Lost Dog as flagship vs. supporting feature** — drives whether Agent A #4 (separate embedding model) is worth the investment.
5. **Sync ambition** — full Phase 1-4 sync (~62 hr) or just Phase 1 + Phase 4 (~26 hr) — depends on whether offline-first is part of the value prop or just a nice-to-have.

---

## Cross-references

- [[Active_Tasks]] — schedule items into existing T2/T3 buckets
- [[Failure_Patterns]] — apply god-class extract pattern to `lost_dog_map_screen.dart`
- [[Decisions]] — record Decision 1/2/3 once Jesse picks
- `.full-review/05-final-report.md` — comprehensive review's pre-closed-beta gate has overlap with the GDPR work here
- `dog_found_dialog_redesign_spec.md` — adjacent T2 spec; both ship the same "honesty about what the model knows" theme
