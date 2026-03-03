# Master Orchestrator v3 — Agent System

Autonomous KPI-driven orchestration system for AviQuest. The Master Orchestrator governs 6 specialized agents, dynamically reallocating focus based on risk, capital constraints, and performance metrics.

## Architecture

```
                    ┌─────────────────────────┐
                    │  Master Orchestrator v3  │
                    │  ─────────────────────── │
                    │  State Engine            │
                    │  KPI Governance          │
                    │  Auto-Reallocation       │
                    │  Capital-Aware Logic     │
                    └────────────┬────────────┘
                                 │
        ┌────────────┬───────────┼───────────┬────────────┐
        │            │           │           │            │
        ▼            ▼           ▼           ▼            ▼
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│ Strategy │ │ Product  │ │  Arch    │ │  Build   │ │Reliability│
│   Lead   │ │Execution │ │  Lead    │ │ Engineer │ │   Lead    │
└──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘
                                                          │
                                               ┌──────────┘
                                               ▼
                                        ┌──────────┐
                                        │  Growth  │
                                        │ Revenue  │
                                        │   Lead   │
                                        └──────────┘
```

## Agents

| Agent | File | Responsibility |
|-------|------|---------------|
| **Master Orchestrator v3** | `master-orchestrator-v3.md` | KPI governance, state management, agent reallocation |
| **Strategy Lead** | `strategy-lead.md` | Roadmap, prioritization, North Star alignment |
| **Product Execution** | `product-execution.md` | Feature scoping, UX, activation/retention optimization |
| **Architecture Lead** | `architecture-lead.md` | System design, tech debt, scalability planning |
| **Build Engineer** | `build-engineer.md` | Implementation, CI/CD, delivery velocity |
| **Reliability Lead** | `reliability-lead.md` | Stability, incident response, release gates |
| **Growth & Revenue Lead** | `growth-revenue-lead.md` | Acquisition, monetization, experimentation |

## Operating States

The system operates in one of 9 states:

| State | Description |
|-------|-------------|
| `DISCOVERY` | Validating problem-solution fit |
| `MVP_BUILD` | Shipping minimum viable product |
| `HARDENING` | Stabilizing before launch |
| `LAUNCH` | Going to market |
| `GROWTH_OPTIMIZATION` | Improving unit economics |
| `SCALE` | Expanding capacity and reach |
| `INCIDENT` | Emergency response |
| `RUNWAY_CRITICAL` | Cash preservation mode |
| `PIVOT` | Fundamental direction change |

## Execution Loop

```
1. growth-revenue-lead → runs experiment
2. Data → reports KPI shift
3. strategy-lead → reprioritizes roadmap
4. product-execution → refines scope
5. architecture-lead → adapts system design
6. build-engineer → implements changes
7. reliability-lead → validates stability
8. growth-revenue-lead → scales what works
```

## Schemas

| Schema | File | Purpose |
|--------|------|---------|
| KPI Snapshot | `schemas/kpi-snapshot.json` | Structure for KPI tracking data |
| Orchestration Cycle | `schemas/orchestration-cycle.json` | Mandatory output format for each cycle |
| Agent Assignment | `schemas/agent-assignment.json` | Task assignment format from orchestrator to agents |

## Templates

| Template | File | Purpose |
|----------|------|---------|
| Cycle Report | `templates/cycle-report.md` | Markdown template for orchestration cycle output |
| Experiment Card | `templates/experiment-card.md` | Structure for growth and product experiments |
| Incident Report | `templates/incident-report.md` | Incident documentation and post-mortem format |

## Non-Negotiable Rules

1. No feature without KPI mapping
2. No scaling paid traffic without retention proof
3. No launch without release gates
4. No roadmap without North Star alignment
5. No overbuilding beyond current risk tier

## Auto-Reallocation Triggers

| Trigger | Reallocation |
|---------|-------------|
| Retention drops | → product-execution + strategy-lead |
| CAC spikes | → growth-revenue-lead |
| Incidents rise | → reliability-lead |
| Delivery slows | → architecture-lead + build-engineer |
| Runway < 6 months | → growth-revenue-lead (revenue mode) |
| Growth flatlines | → experimentation sprint |

## Capital-Aware Decision Logic

| Runway | Optimization Target |
|--------|-------------------|
| > 18 months | Learning & product depth |
| > 12 months | Retention & engagement |
| > 6 months | Revenue acceleration |
| < 3 months | Survival |
