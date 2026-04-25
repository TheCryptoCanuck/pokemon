# Audit v2 — SUCCESS (quarantine kept)

**Decision:** `KEEP_SUCCESS`  
**Baseline measured:** 2026-04-25T02:06:54.896139Z  
**Post measured:** 2026-04-25T02:53:59.697498Z  
**Seeds:** [43, 100, 200]

## Headline

| Metric | Baseline | Post | Delta |
|---|---|---|---|
| Avg top-1 | 13.96% | 28.72% | +14.76pt |
| Avg top-3 | 41.17% | 63.08% | +21.91pt |

## Per-seed

| Seed | Baseline top-1 | Post top-1 | Δ | Baseline top-3 | Post top-3 | Δ |
|---|---|---|---|---|---|---|
| 43 | 15.4% | 46.2% | +30.8pt | 46.2% | 69.2% | +23.1pt |
| 100 | 15.4% | 20.0% | +4.6pt | 38.5% | 60.0% | +21.5pt |
| 200 | 11.1% | 20.0% | +8.9pt | 38.9% | 60.0% | +21.1pt |

## Decision rule

- top-1 Δ ≥ −1.0 pt → KEEP_SUCCESS
- top-1 Δ < −2.0 pt → ROLLBACK_REGRESSION (auto)
- otherwise → KEEP_MARGINAL (flag for human review)

This run's top-1 Δ = +14.76pt → **KEEP_SUCCESS**

## Rollback hint

```
python outputs/audit_supplemental_v2.py rollback
```
