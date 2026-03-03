# Experiment Card

> Owner: [growth-revenue-lead | product-execution]
> Created: [date]
> Status: [queued | running | completed | killed]

---

## Hypothesis

If we **[change/intervention]**, then **[metric]** will **[improve/increase/decrease]** by **[amount]** because **[reasoning/evidence]**.

---

## Design

| Parameter | Value |
|-----------|-------|
| Control | [baseline behavior] |
| Variant | [changed behavior] |
| Primary Metric | [what we measure for success] |
| Secondary Metrics | [guardrail metrics to protect] |
| Minimum Sample Size | [N for statistical significance] |
| Minimum Duration | [days to run] |
| Target Confidence | [95% default] |

---

## Kill Criteria

Stop experiment immediately if:
- [ ] [negative guardrail metric] exceeds [threshold]
- [ ] [safety metric] drops below [threshold]
- [ ] [time limit] reached without directional signal

---

## Decision Framework

| Outcome | Criteria | Action |
|---------|----------|--------|
| **Ship** | Primary metric improves by [X]% with [Y]% confidence | Roll out to 100% |
| **Iterate** | Directionally positive but below threshold | Modify variant, re-run |
| **Kill** | No significance after [Z] duration | Stop, document learnings |
| **Escalate** | Unexpected side effects observed | Notify Master Orchestrator |

---

## Results

**Start Date**: [date]
**End Date**: [date]
**Sample Size**: [N]

| Metric | Control | Variant | Delta | Significance |
|--------|---------|---------|-------|-------------|
| [primary] | [value] | [value] | [+/-X%] | [p-value] |
| [secondary] | [value] | [value] | [+/-X%] | [p-value] |

**Decision**: [Ship | Iterate | Kill]
**Learnings**: [What did we learn regardless of outcome]

---

## KPI Impact

- North Star impact: [description]
- Estimated annualized value: [if applicable]
- Next experiment suggested: [follow-up hypothesis]
