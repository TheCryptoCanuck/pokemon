# Autonomous Memory Agent Loop

Tags: #prompt #memory #automation

Use this after any serious session.

```text
Execute full memory-system update.

Step 1: Extract candidates
Identify:
- Durable preferences
- Corrections
- Decisions
- Project context
- Failure patterns
- Active tasks
- Compressed insights

Step 2: Classify each item
A. Store in Memory.md
B. Store in Corrections.md
C. Store in Decisions.md
D. Store in Failure_Patterns.md
E. Store in Active_Tasks.md
F. Store in Compressed_Insights.md
G. Do not store

Step 3: Score each stored item
Use:
- 1.0 = critical
- 0.7–0.9 = strong
- 0.4–0.6 = situational
- Below 0.4 = do not store or archive

Step 4: Apply decay
For existing memory:
- Unused 14 days: reduce score by 0.1
- Unused 30 days and score < 0.5: move to Archive_Memory.md
- Contradicted: update or remove
- Duplicate: merge

Step 5: Update task state
Update:
- Active tasks
- Blocked tasks
- Completed tasks
- Next actions

Step 6: Compress context
Convert long session notes into 3–7 bullet insights.

Step 7: Reality check
Separate:
- Facts
- Assumptions
- Speculation

Step 8: Summarize
Report:
- Files updated
- Items added
- Items pruned
- Decisions made
- Next review date
```

## Related Notes

- [[Memory_Maintenance_Protocol]]
- [[Reality_Check]]
- [[Active_Tasks]]
