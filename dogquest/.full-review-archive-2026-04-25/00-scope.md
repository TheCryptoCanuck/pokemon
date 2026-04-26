# Review Scope

## Target

Whole DogQuest project. Comprehensive multi-phase review across code quality, architecture, security, performance, testing, documentation, best practices, and DevOps. Auto-detected stack: Flutter/Dart (primary) + Python (ML / audit / FastAPI backend).

## Files in scope

| Surface | Path | Size |
|---|---|---|
| Flutter app | `lib/` | 152 files, ~50,300 LOC Dart |
| Tests | `test/` | 21 files |
| ML / audit / harness | `outputs/test_20_images.py`, `outputs/run_test.py`, `outputs/audit_supplemental_v2.py`, `outputs/wsl_gpu_env.sh` | session output |
| TFLite export pipeline | `export_tflite.py`, `train_model_v6.py`, `continue_training_v6.py` | training entrypoints |
| Legacy FastAPI backend | `backend/app/` | 2,173 LOC Python (Supabase is the live backend per CLAUDE.md — backend/ may be vestigial; flag for cleanup) |
| Project intelligence | `CLAUDE.md`, `.second_brain/` | docs |
| Build / DevOps | `Makefile`, `pubspec.yaml`, `package.json`, `.mcp.json`, `android/` | config |

## Files out of scope

- `node_modules/`, `.dart_tool/`, `build/`, `.claude-flow/` — dependency caches
- `supplemental_dogs/`, `supplemental_dogs_quarantine_v2/`, `tf_cache/` — training data + checkpoints
- 30+ one-off Python scripts (`download_*.py`, `fix_*.py`, `dup_analysis.py`, etc.) — dev-only tooling, not shipped
- `assets/dogs.json`, `dog_labels.txt`, `dog_model.tflite` — data assets, reviewed only insofar as they're referenced

## Flags

- Security Focus: no
- Performance Critical: no
- **Strict Mode: yes** — Phase 1+2 checkpoint will recommend halting if any Critical findings emerge
- Framework: auto (Flutter + Python multi-stack)

## Review Phases

1. Code Quality & Architecture (parallel: code-reviewer + architect-review)
2. Security & Performance (parallel: security-auditor + performance review)
3. **Checkpoint 1** — strict-mode review of Critical findings before proceeding
4. Testing & Documentation (parallel)
5. Best Practices & DevOps (parallel)
6. Final consolidated report with priority tiers

## Special context for reviewers

- This project is mid-migration: Phase 4 of a PLAID-style build. Posture pivoted today (2026-04-25) from ship-first to **quality-first with closed beta as feedback loop** — see `.second_brain/02_Context/Strategy.md`. Findings should reflect this pre-launch context, not as if the app were already in production.
- Recent session changes (2026-04-25): synonym clustering + preferred-name substitution in `lib/services/tflite_identification_service.dart`, counter dissonance fix in `lib/widgets/dog_found_dialog.dart`, new test harness + audit tool in `outputs/`. These are the freshest surfaces and most worth scrutinizing.
- An agentic data-quality audit is running concurrently in the user's WSL2 environment — it may modify `supplemental_dogs/` and write to `outputs/audit_v2/` during this review. Reviewers should treat the audit's outputs as out-of-scope for review at this moment.
- The `backend/` FastAPI directory exists in the repo but Supabase is documented as the live backend. Reviewers should flag whether `backend/` is dead code, vestigial, or actively wired into the app.
- claude-flow MCP is installed and active (see `.mcp.json` pinned to `@claude-flow/cli@3.5.80`). Reviewers may treat its presence as an external tooling dependency, not a security finding in itself.

## Known issues going in (to avoid duplicate findings)

- Top-3 accuracy drops 9.4pt from Keras float32 to TFLite uint8 — quantization headroom, logged as task #32
- Five "god class" files >800 lines remain post-refactor (CLAUDE.md notes)
- iOS untested
- Phase 4 launch tasks deferred (TASK-049 signing key, TASK-050 Sentry DSN, TASK-058/059/060/061 store assets)
