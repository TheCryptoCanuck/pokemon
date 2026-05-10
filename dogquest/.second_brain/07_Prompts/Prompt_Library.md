# Prompt Library

Tags: #prompts #library

All reusable prompts consolidated into one reference file.

---

## Session Start Prompt

```text
Read this vault as my working memory system.

Start with:
1. 00_System/Retrieval_Map.md
2. 00_System/Reality_Check.md
3. 01_Memory/Memory.md
4. 01_Memory/Failure_Patterns.md
5. 03_Projects/Active_Tasks.md
6. Any task-relevant project or context files

Then complete the task using the vault as durable context.

Before answering, identify internally:
- Relevant memory
- Relevant project context
- Possible stale memory
- Missing but non-blocking assumptions

Proceed without unnecessary clarification.
```

Related: [[Session_Protocol]], [[Retrieval_Map]]

---

## Session End Prompt

```text
Review this session and update the vault.

Update:
- Memory.md for durable preferences
- Corrections.md for corrections
- Decisions.md for decisions
- Failure_Patterns.md for repeated mistakes
- Active_Tasks.md for execution state
- Compressed_Insights.md for condensed insights
- Relevant project files for project-specific context

Then provide:
1. What changed
2. What was decided
3. What was added to memory
4. What was archived or pruned
5. What should be reviewed later
```

Related: [[Autonomous_Memory_Agent_Loop]], [[Memory_Maintenance_Protocol]]

---

## Autonomous Memory Agent Loop

Use this after any serious session.

```text
Execute full memory-system update.

Step 1: Extract candidates
Identify: durable preferences, corrections, decisions, project context, failure patterns, active tasks, compressed insights.

Step 2: Classify each item
A. Store in Memory.md | B. Corrections.md | C. Decisions.md | D. Failure_Patterns.md | E. Active_Tasks.md | F. Compressed_Insights.md | G. Do not store

Step 3: Score each stored item
1.0 = critical | 0.7–0.9 = strong | 0.4–0.6 = situational | Below 0.4 = do not store or archive

Step 4: Apply decay
Unused 14 days → reduce score by 0.1 | Unused 30 days and score < 0.5 → Archive_Memory.md | Contradicted → update or remove | Duplicate → merge

Step 5: Update task state
Active tasks, blocked tasks, completed tasks, next actions.

Step 6: Compress context
Convert long session notes into 3–7 bullet insights.

Step 7: Reality check
Separate facts, assumptions, speculation.

Step 8: Summarize
Report: files updated, items added, items pruned, decisions made, next review date.
```

Related: [[Memory_Maintenance_Protocol]], [[Reality_Check]], [[Active_Tasks]]

---

## Self-Correcting Memory Loop

```text
Act as my Memory Curator.

For each item from this session, classify it as one of:
A. Durable preference | B. Correction | C. Decision | D. Project context | E. Temporary task | F. Failure pattern | G. Do not store

Only store A–D and F.

For each stored item: write one concise sentence, place it in the correct file, score it from 0.1 to 1.0, add date if useful, mark uncertainty clearly, do not duplicate existing memory.

After updating, audit the memory files for: contradictions, stale items, overly broad statements, sensitive details that should not be stored.
```

Related: [[Autonomous_Memory_Agent_Loop]], [[Memory_Curator]]

---

## Context Compression Prompt

```text
Compress the following notes into durable insights.

Rules: keep only information that will improve future decisions, remove repetition, preserve decisions and constraints, separate facts from assumptions, convert long notes into 3–7 bullets, add links to relevant notes.

Output: 1) Compressed insight, 2) Related decisions, 3) Related project, 4) Suggested memory updates.
```

Related: [[Compressed_Insights]], [[Reality_Check]]

---

## Master Builder Prompt

```text
You are a senior systems builder.

Goal: [INSERT GOAL]
Constraints: [INSERT CONSTRAINTS]

Build: 1) Step-by-step plan, 2) Required files/templates, 3) Setup instructions, 4) Maintenance process, 5) Failure modes and fixes, 6) Final checklist.

Make it executable by a non-expert.
```

Related: [[Builder_Implementer]], [[Active_Tasks]]

---

## Red Team Final Check

```text
Before finalizing, critique your own answer.

Check: 1) Is anything unsupported? 2) Are there missing steps? 3) Is the answer overcomplicated? 4) Is any instruction unsafe or unreliable? 5) What would fail in real execution? 6) What should be simplified? 7) Did memory bias the answer incorrectly?

Then revise the answer.
```

Related: [[Reality_Check]], [[Critic_Red_Team]]
