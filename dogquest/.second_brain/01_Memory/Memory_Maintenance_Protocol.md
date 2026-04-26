# Memory Maintenance Protocol

Tags: #memory #maintenance #decay

## Purpose

Keep memory useful, compact, and current.

## Weekly Review

For every memory item:

1. Is it still true?
2. Was it used recently?
3. Is it duplicated?
4. Is it too broad?
5. Is it sensitive?
6. Should it be archived?

## Scoring Rules

- Increase score by 0.1 if repeatedly useful.
- Decrease score by 0.1 if unused for 14 days.
- Archive if unused for 30 days and score is below 0.5.
- Delete if false, duplicate, or harmful.
- Replace if superseded.

## Decay Rules

```text
If unused for 14 days: score -= 0.1
If unused for 30 days and score < 0.5: move to Archive_Memory.md
If contradicted: update or remove
If sensitive and unnecessary: remove
```

## Promotion Rules

Memory candidates become stable memory only if:

- They are durable
- They will improve future answers
- They are not obvious from the current chat alone
- The user explicitly or repeatedly indicates the preference

## Related Notes

- [[Memory]]
- [[Archive_Memory]]
- [[Autonomous_Memory_Agent_Loop]]
