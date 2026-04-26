# Patterns

Tags: #memory #patterns

## Response Patterns

- (Score: 0.8) User often wants implementation-ready outputs.
- (Score: 0.8) User often asks to expand a baseline into a complete system.
- (Score: 0.7) User prefers practical artifacts over abstract explanations.

## Project Patterns

- (Score: 0.7) Inference-path choice depends on workload type. **Single-image, latency-sensitive (on-device app)** → TFLite uint8 with TTA. **Batch, throughput-sensitive (audit, eval, benchmark)** → Keras float32 GPU. The two paths produce slightly different decision boundaries due to quantization; switching backends mid-task creates internal inconsistency. Pick once per task, restart if changing.

- (Score: 0.7) Ship-then-verify-on-device loop: every TFLite-related change should land an on-device canary photo before being declared complete. Twice now this caught issues a unit test couldn't (calibration scale 1/255 → 1.0; Blenheim-vs-Cavalier preferred-name UX).
- (Score: 0.7) Type changes to public top-level symbols ripple into test files via `firstWhere(orElse:)` defaults. Grep for the old type after any data-shape refactor.
- (Score: 0.6) Sandbox bash mount is stale against Windows writes — always Read-tool-verify, never bash-cat-verify, when checking what just landed.
- (Score: 0.6) `flutter install` defaults to release APK; use `flutter install --debug` or `flutter run --debug` after a debug build.

## Related Notes

- [[Memory]]
- [[Failure_Patterns]]
