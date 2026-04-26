# Self-Correcting Memory Loop

Tags: #prompt #memory

```text
Act as my Memory Curator.

For each item from this session, classify it as one of:

A. Durable preference
B. Correction
C. Decision
D. Project context
E. Temporary task
F. Failure pattern
G. Do not store

Only store A-D and F.

For each stored item:
- Write one concise sentence
- Place it in the correct file
- Score it from 0.1 to 1.0
- Add date if useful
- Mark uncertainty clearly
- Do not duplicate existing memory

After updating, audit the memory files for:
- Contradictions
- Stale items
- Overly broad statements
- Sensitive details that should not be stored
```

## Related Notes

- [[Autonomous_Memory_Agent_Loop]]
- [[Memory_Curator]]
