# Incident Report

> Incident ID: [INC-YYYY-MM-DD-NNN]
> Severity: [P0 | P1 | P2 | P3]
> Status: [active | mitigated | resolved | post-mortem complete]
> Commander: reliability-lead

---

## Summary

**What happened**: [One sentence description]
**Impact**: [User-facing impact description]
**Duration**: [start time] — [end time] ([total duration])

---

## Timeline

| Time | Event |
|------|-------|
| [HH:MM] | [Detection: how was this discovered] |
| [HH:MM] | [Triage: severity assessed] |
| [HH:MM] | [Communication: orchestrator notified] |
| [HH:MM] | [Containment: initial mitigation] |
| [HH:MM] | [Resolution: root cause fixed] |
| [HH:MM] | [Verification: confirmed stable] |

---

## Root Cause

[Detailed description of why this happened]

**Category**: [code bug | infrastructure | dependency | configuration | security | capacity]

---

## Impact Assessment

| Dimension | Impact |
|-----------|--------|
| Users Affected | [count or percentage] |
| Revenue Impact | [$amount or N/A] |
| Data Impact | [any data loss or corruption] |
| KPI Impact | [which KPIs were affected] |
| Brand Impact | [user trust, public visibility] |

---

## Response Actions

| Action | Owner | Status |
|--------|-------|--------|
| [containment action] | [agent] | [done/pending] |
| [resolution action] | [agent] | [done/pending] |
| [communication action] | [agent] | [done/pending] |

---

## State Transition

- **Previous State**: [state before incident]
- **During Incident**: INCIDENT
- **Return State**: [state to return to after stabilization]
- **Stabilization Criteria**: [what must be true before leaving INCIDENT state]

---

## Post-Mortem

### What went well
- [item]

### What went wrong
- [item]

### Action Items

| Action | Owner | Priority | Deadline |
|--------|-------|----------|----------|
| [preventive action] | [agent] | [P0-P3] | [date] |

### Lessons Learned
- [key takeaway for the system]

---

## Orchestrator Sign-Off

- [ ] Root cause identified and documented
- [ ] Preventive actions assigned with deadlines
- [ ] KPIs recovered to pre-incident levels
- [ ] Monitoring improved to detect similar issues
- [ ] Cleared to exit INCIDENT state
