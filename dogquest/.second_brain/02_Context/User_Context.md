# User Context

Tags: #context #user

## Identity

- Name: Jesse
- Email: jesseg.8899@gmail.com

## Role / Work

- Independent app developer / founder.
- Working through PLAID-style structured product build.

## Main Projects

- **DogQuest** (active) — Flutter dog breed identification app forked from AviQuest.
  - 296 dog breeds, TFLite v6 model (EfficientNetV2-S, 51.65% val_acc Stanford Dogs).
  - 56/76 PLAID code tasks complete across 6 phases.
  - Phase 4 launch prep is the current frontier (signing key, Sentry DSN, Play Store assets).

## Tools / Stack

- Flutter (Dart), Riverpod, go_router, Hive, Supabase, Firebase Analytics, Sentry, AdMob.
- TensorFlow 2.21.0 + CUDA in WSL2 Ubuntu for ML training (RTX 3060 Ti 8GB).
- Android primary; iOS untested.
- Makefile-driven build/deploy workflow.

## Constraints

- 8GB GPU VRAM ceiling — OOM-sensitive, training must use small batch sizes + careful caching.
- Solo or near-solo execution — favors automation, parallel agents, minimal manual ceremony.

## Important Background

- Forked AviQuest (bird ID app) into DogQuest; same architecture, different domain.
- Shipped a critical TFLite calibration bug fix on 2026-04-25 (quant scale 1/255 → 1.0).
- On-device canary verified post-fix (Dalmatian → "High Match / Very confident").

## Related Notes

- [[Memory]]
- [[Strategy]]
- [[Active_Tasks]]
