# Strategy

Tags: #context #strategy

## Strategy Rules

- Prefer MVP before scaling unless explicitly asked for a full system.
- Prefer offline-first architecture for app projects (DogQuest already follows this).
- Make monetization visible early — banner ads + capped interstitials, never paywall the core loop.
- Prefer testable implementation over vague conceptual planning.
- Default to practical next steps; ship-able beats perfect.

## DogQuest-Specific Strategy

- **POSTURE PIVOT 2026-04-25**: shifted from "ship-first" to "quality-first WITH closed beta as the feedback loop." Public Play Store launch deferred until the closed-beta quality bar is met. See [[Decisions]] for the explicit decision and trade-offs.
- Closed beta (5–10 friends/family) is the user-feedback mechanism — quality without users is conjecture. Skip the beta and "quality-first" silently becomes indefinite delay.
- TASK-049 (signing key) and TASK-050 (Sentry DSN) are now quality-instrumentation tasks, not launch ceremony — needed BEFORE closed beta, not after.
- Other Phase 4 manual tasks (TASK-058 screenshots, TASK-059 demo video, TASK-060/061 store upload) defer to post-beta.
- Model accuracy ceiling: 51.65% val_acc is good enough for closed beta; further gains come from data cleanup (cheap), backbone upgrade to V2-M (expensive), or rare-breed image expansion (medium).
- ML data hygiene > model architecture changes for current ROI. Spot-check 4 flagged folders first.
- UX wins (top-3 ranked alternatives, synonym clustering, confidence-labeling honesty) likely improve perceived accuracy more than +5 val_acc would.
- Phase 5 growth tasks (TASK-062–076) parallelize well — candidates for multi-agent execution.
- Time-box: 4 weeks of pure quality work before reassessing the ship/iterate question. Perfectionism is sticky.
- **Tier discipline rule (locked 2026-04-25):** when waiting on Tier N completion, agents may write *specs / design docs / research notes* for Tier N+1 — but NOT code, branches, or staged commits. Specs are revisable; code creates merge gravity. This protects against premature commitment to the wrong redesign before user signal arrives.

## Strategic Constraints

- Solo execution — favor automation, parallel agents, and Makefile targets over manual ceremony.
- 8GB GPU VRAM ceiling — any future training must respect OOM lessons in [[Failure_Patterns]].
- iOS untested — do not promise iOS parity in store assets.
- Avoid unnecessary complexity; do not optimize for novelty at the cost of execution.

## Reality-Check Defaults

- Treat any model accuracy claim above 90% as a calibration smell, not a result.
- Do not present spot-benchmark numbers (~12% top-1 on supplemental_dogs/) as the headline metric — Stanford val_acc is the apples-to-apples figure.

## Related Notes

- [[Reality_Check]]
- [[Decisions]]
- [[Business_Context]]
- [[Active_Tasks]]
- [[DogQuest]]
