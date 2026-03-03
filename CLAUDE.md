# AviQuest — Project Intelligence

## Project Overview

AviQuest is a Flutter-based mobile bird identification game with gamification mechanics (XP, leveling, achievements, rarity tiers). The app features 393 bird species across 4 rarity tiers, camera-based identification, audio playback, and a local Hive database for persistence.

## Orchestration System

This project is governed by **Master Orchestrator v3** — an autonomous KPI-driven multi-agent system. See `agents/` for full agent definitions, schemas, and templates.

### Agent Registry

| Agent | Definition | Role |
|-------|-----------|------|
| Master Orchestrator v3 | `agents/master-orchestrator-v3.md` | Governance, KPI tracking, reallocation |
| Strategy Lead | `agents/strategy-lead.md` | Roadmap & prioritization |
| Product Execution | `agents/product-execution.md` | Feature scoping & shipping |
| Architecture Lead | `agents/architecture-lead.md` | System design & tech debt |
| Build Engineer | `agents/build-engineer.md` | Implementation & CI/CD |
| Reliability Lead | `agents/reliability-lead.md` | Stability & incident response |
| Growth & Revenue Lead | `agents/growth-revenue-lead.md` | Acquisition & monetization |

### Key Principles

1. Every feature must map to a KPI
2. Ship smaller, faster — default to scope reduction
3. No scaling without retention proof
4. Architecture serves current state, not imagined future
5. Always maintain at least one active experiment

## Tech Stack

- **Framework**: Flutter (Dart)
- **Platform**: iOS / Android
- **Storage**: Hive (local NoSQL)
- **Key Libraries**: flutter_animate, just_audio, camera, cached_network_image

## Project Structure

```
AviQuest-/
├── CLAUDE.md                  ← You are here
├── agents/                    ← Orchestrator agent definitions
│   ├── master-orchestrator-v3.md
│   ├── strategy-lead.md
│   ├── product-execution.md
│   ├── architecture-lead.md
│   ├── build-engineer.md
│   ├── reliability-lead.md
│   ├── growth-revenue-lead.md
│   ├── schemas/               ← JSON schemas for data contracts
│   │   ├── kpi-snapshot.json
│   │   ├── orchestration-cycle.json
│   │   └── agent-assignment.json
│   └── templates/             ← Markdown templates for reports
│       ├── cycle-report.md
│       ├── experiment-card.md
│       └── incident-report.md
├── aviquest/                  ← Flutter application
│   ├── lib/main.dart          ← Main application (monolithic)
│   ├── pubspec.yaml           ← Dependencies
│   └── android/               ← Android build config
└── README.md                  ← Project README
```

## Development Guidelines

- **Single-file app**: `aviquest/lib/main.dart` (~5,400 lines) — consider modularization
- **No test suite**: Tests need to be added for critical paths
- **No CI/CD**: Pipeline needs to be configured
- **No backend**: Fully client-side; backend only when KPIs justify social features
